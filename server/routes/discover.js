const express = require("express");
const router = express.Router();
const axios = require("axios");
const auth = require("../middleware/auth");
const admin = require("firebase-admin");
const { v4: uuidv4 } = require("uuid");
const { getFirestore } = require("firebase-admin/firestore");
const errorHandler = require("../utils/errorHandler");

// Get Firestore database instance
const db = getFirestore();

// Search recipes from Spoonacular API
router.get("/search", auth, async (req, res) => {
	try {
		const { query, difficulty, tag } = req.query;
		const page = parseInt(req.query.page) || 1;
		const limitParam = parseInt(req.query.limit);
		const limit = isNaN(limitParam) ? 10 : Math.min(limitParam, 100);

		// Build Firestore query
		let recipesRef = db.collection("recipes");

		if (query) {
			console.log("Search query:", query);
			const searchTerms = query
				.toLowerCase()
				.split(/\s+/)
				.filter((term) => term.length > 0);
			console.log("Search terms:", searchTerms);

			recipesRef = db.collection("recipes");

			const searchQueries = searchTerms.map((term) => {
				return db
					.collection("recipes")
					.where("searchableFields", "array-contains", term);
			});

			if (searchQueries.length > 0) {
				recipesRef = searchQueries[0];
			}
		}
		if (difficulty) {
			// Normalize difficulty to capitalized (Easy/Medium/Hard) for stored format
			recipesRef = recipesRef.where(
				"difficulty",
				"==",
				difficulty.charAt(0).toUpperCase() + difficulty.slice(1).toLowerCase()
			);
		}
		if (tag) {
			// Match tags case-insensitively using searchableFields which contains lower-cased tags
			recipesRef = recipesRef.where(
				"searchableFields",
				"array-contains",
				tag.toLowerCase()
			);
		}

		// Get total count for pagination (before deduplication)
		const totalQuery = await recipesRef.count().get();
		const totalRecipes = totalQuery.data().count;

		// Reduced buffer multiplier for better performance
		const bufferMultiplier = 1.2; // Reduced from 1.5x
		const fetchLimit = Math.min(Math.floor(limit * bufferMultiplier), 150); // Reduced cap
		const startAt = Math.max(0, (page - 1) * limit);

		// Fetch recipes with smaller buffer for deduplication
		let snapshot;
		try {
			snapshot = await recipesRef
				.orderBy("createdAt", "desc")
				.limit(fetchLimit)
				.offset(startAt)
				.get();
		} catch (orderErr) {
			// Fallback if some docs have non-timestamp createdAt or field missing
			console.warn(
				"Falling back to un-ordered fetch due to createdAt orderBy error:",
				orderErr?.message || orderErr
			);
			snapshot = await recipesRef.limit(fetchLimit).offset(startAt).get();
		}

		// Collect all recipes
		const allRecipes = [];
		snapshot.forEach((doc) => {
			const data = doc.data();
			allRecipes.push({
				id: doc.id,
				...data,
			});
		});

		// Server-side deduplication (should be minimal now after cleanup)
		const uniqueRecipesMap = new Map();
		for (const recipe of allRecipes) {
			const key = `${recipe.title?.toLowerCase() || ""}|${
				recipe.description?.toLowerCase() || ""
			}`;
			if (!uniqueRecipesMap.has(key)) {
				uniqueRecipesMap.set(key, recipe);
			}
		}

		// Convert back to array and apply pagination to deduplicated results
		const deduplicatedRecipes = Array.from(uniqueRecipesMap.values());
		const paginatedRecipes = deduplicatedRecipes.slice(0, limit);

		console.log(
			`Fetched ${allRecipes.length} recipes, deduplicated to ${deduplicatedRecipes.length}, returning ${paginatedRecipes.length}`
		);

		// Calculate pagination info based on deduplicated results
		// More accurate now since we have fewer duplicates
		const estimatedTotalPages = Math.ceil((totalRecipes * 0.95) / limit); // Assume ~5% duplicates now
		const hasMore =
			deduplicatedRecipes.length > limit || page * limit < totalRecipes;

		res.json({
			recipes: paginatedRecipes,
			pagination: {
				total: Math.floor(totalRecipes * 0.95), // Estimated total after minimal deduplication
				page,
				limit,
				totalPages: estimatedTotalPages,
				hasNextPage: hasMore && page < estimatedTotalPages,
				hasPrevPage: page > 1,
			},
		});
	} catch (error) {
		console.error("Error searching recipes:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't search recipes right now. Please try again shortly."
		);
	}
});

// Admin endpoint to remove duplicate recipes
router.post("/cleanup-duplicates", auth, async (req, res) => {
	try {
		console.log("Starting duplicate recipe cleanup...");

		const recipesRef = db.collection("recipes");
		const snapshot = await recipesRef.get();

		const recipeMap = new Map();
		const duplicatesToDelete = [];

		// Group recipes by title and description
		snapshot.forEach((doc) => {
			const data = doc.data();
			const key = `${data.title?.toLowerCase() || ""}|${
				data.description?.toLowerCase() || ""
			}`;

			if (recipeMap.has(key)) {
				// This is a duplicate - keep the older one (assuming it was added first)
				const existing = recipeMap.get(key);
				const existingDate = existing.createdAt?.toDate() || new Date(0);
				const currentDate = data.createdAt?.toDate() || new Date(0);

				if (currentDate > existingDate) {
					// Current recipe is newer, mark it for deletion
					duplicatesToDelete.push({
						id: doc.id,
						title: data.title,
						createdAt: currentDate,
					});
				} else {
					// Existing recipe is newer, replace it and mark the old one for deletion
					duplicatesToDelete.push({
						id: existing.id,
						title: existing.title,
						createdAt: existingDate,
					});
					recipeMap.set(key, {
						id: doc.id,
						title: data.title,
						createdAt: currentDate,
					});
				}
			} else {
				recipeMap.set(key, {
					id: doc.id,
					title: data.title,
					createdAt: data.createdAt?.toDate() || new Date(0),
				});
			}
		});

		console.log(
			`Found ${duplicatesToDelete.length} duplicate recipes to delete`
		);

		// Delete duplicates in batches of 500 (Firestore limit)
		let deletedCount = 0;
		for (let i = 0; i < duplicatesToDelete.length; i += 500) {
			const batch = db.batch();
			const batchItems = duplicatesToDelete.slice(i, i + 500);

			batchItems.forEach((duplicate) => {
				const docRef = recipesRef.doc(duplicate.id);
				batch.delete(docRef);
			});

			await batch.commit();
			deletedCount += batchItems.length;

			console.log(
				`Deleted batch of ${batchItems.length} recipes. Total: ${deletedCount}/${duplicatesToDelete.length}`
			);
		}

		res.json({
			message: "Duplicate cleanup completed",
			duplicatesFound: duplicatesToDelete.length,
			duplicatesDeleted: deletedCount,
			uniqueRecipesRemaining: recipeMap.size,
		});
	} catch (error) {
		console.error("Error during duplicate cleanup:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't complete duplicate cleanup right now. Please try again later."
		);
	}
});

module.exports = router;

// Add after existing routes above export

// Update canonical image for a discover recipe (global)
router.patch("/recipes/:id/image", auth, async (req, res) => {
    try {
        const { id } = req.params;
        const { imageUrl } = req.body || {};

        if (!id || typeof id !== "string" || id.trim().length === 0) {
            return errorHandler.badRequest(res, "Recipe id is required");
        }
        if (!imageUrl || typeof imageUrl !== "string") {
            return errorHandler.badRequest(res, "imageUrl is required");
        }
        const trimmedUrl = imageUrl.trim();
        if (!/^https?:\/\//i.test(trimmedUrl)) {
            return errorHandler.badRequest(res, "imageUrl must be http(s)");
        }

        // Validate the URL points to an image via HEAD
        const headers = {
            "User-Agent":
                "Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1",
            Accept: "image/avif,image/webp,image/apng,image/*,*/*;q=0.8",
        };
        try {
            const head = await axios.head(trimmedUrl, { maxRedirects: 3, timeout: 5000, headers });
            const ct = (head.headers["content-type"] || "").toString();
            if (!ct.startsWith("image/")) {
                return errorHandler.badRequest(res, "imageUrl does not point to an image");
            }
        } catch (e) {
            // If the host blocks HEAD, try GET with small range
            try {
                const getResp = await axios.get(trimmedUrl, {
                    headers: { ...headers, Range: "bytes=0-1024" },
                    responseType: "arraybuffer",
                    maxRedirects: 3,
                    timeout: 6000,
                    validateStatus: (s) => s >= 200 && s < 400,
                });
                const ct = (getResp.headers["content-type"] || "").toString();
                if (!ct.startsWith("image/")) {
                    return errorHandler.badRequest(res, "imageUrl does not point to an image");
                }
            } catch (err) {
                return errorHandler.badRequest(res, "Unable to validate imageUrl");
            }
        }

        // Update Firestore canonical recipe image
        const docRef = db.collection("recipes").doc(id);
        const doc = await docRef.get();
        if (!doc.exists) {
            return errorHandler.notFound(res, "Recipe not found");
        }

        await docRef.update({
            imageUrl: trimmedUrl,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        return res.json({
            success: true,
            id,
            imageUrl: trimmedUrl,
        });
    } catch (error) {
        console.error("Error updating discover recipe image:", error);
        return errorHandler.serverError(res, "Failed to update recipe image");
    }
});
