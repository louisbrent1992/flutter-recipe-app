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
        const { query, difficulty, tag, random } = req.query;
		const page = parseInt(req.query.page) || 1;
		const limitParam = parseInt(req.query.limit);
		const limit = isNaN(limitParam) ? 10 : Math.min(limitParam, 100);
		const isRandom = random === 'true';

        // Build Firestore query - only Spoonacular recipes (isExternal === true)
        let recipesRef = db.collection("recipes").where("isExternal", "==", true);

        // Aggregate tokens from query and tag, treating comma-separated chunks as phrases.
        // For each phrase, prefer the full phrase token, then (if room) include individual word tokens.
        // Also generate both hyphen and space variations for matching.
        const gatherTokens = (input) => {
            if (!input || typeof input !== 'string') return [];
            return input
                .toLowerCase()
                .split(',') // split on commas only; keep spaces inside phrase
                .map((s) => s.trim()
                    .replace(/\s+/g, ' ')) // normalize inner spaces
                .filter((s) => s.length > 0);
        };

        // Generate both hyphen and space variations of a phrase
        const generateVariations = (phrase) => {
            const variations = new Set([phrase]);
            // Add space version (replace hyphens with spaces)
            const spaceVersion = phrase.replace(/-/g, ' ');
            if (spaceVersion !== phrase) variations.add(spaceVersion);
            // Add hyphen version (replace spaces with hyphens)
            const hyphenVersion = phrase.replace(/\s+/g, '-');
            if (hyphenVersion !== phrase) variations.add(hyphenVersion);
            return Array.from(variations);
        };

        let phraseTokens = [];
        phraseTokens = phraseTokens.concat(gatherTokens(query));
        phraseTokens = phraseTokens.concat(gatherTokens(tag));

        // Build final tokens list prioritizing each tag phrase, then its hyphen/space variations
        let tokens = [];
        const addedTokens = new Set();

        // Step 1: Add each phrase exactly once (de-duplicated)
        for (const phrase of phraseTokens) {
            if (tokens.length >= 10) break;
            if (!addedTokens.has(phrase)) {
                tokens.push(phrase);
                addedTokens.add(phrase);
            }
        }

        // Step 2: Add hyphen/space variations for phrases that contain hyphen/space
        for (const phrase of phraseTokens) {
            if (tokens.length >= 10) break;
            const hyphenVersion = phrase.replace(/\s+/g, "-");
            if (hyphenVersion !== phrase && !addedTokens.has(hyphenVersion) && tokens.length < 10) {
                tokens.push(hyphenVersion);
                addedTokens.add(hyphenVersion);
            }
            if (tokens.length >= 10) break;
            const spaceVersion = phrase.replace(/-/g, " ");
            if (spaceVersion !== phrase && !addedTokens.has(spaceVersion) && tokens.length < 10) {
                tokens.push(spaceVersion);
                addedTokens.add(spaceVersion);
            }
            if (tokens.length >= 10) break;
        }

        // Step 3: Optionally add individual words if we still have room
        if (tokens.length < 10) {
            for (const phrase of phraseTokens) {
                if (tokens.length >= 10) break;
                const words = phrase.split(/[\s-]+/).filter((w) => w.length > 0);
                for (const word of words) {
                    if (tokens.length >= 10) break;
                    if (word.length > 2 && !addedTokens.has(word)) {
                        tokens.push(word);
                        addedTokens.add(word);
                    }
                }
            }
        }
        if (tokens.length > 10) {
            console.warn(
                `array-contains-any supports up to 10 values; capped to 10 (had ${tokens.length})`
            );
            tokens = tokens.slice(0, 10);
        }

        // Debug logging
        if (tag) {
            console.log(`Search tags: ${tag}`);
            console.log(`Generated search tokens (${tokens.length}):`, tokens);
        }

        if (tokens.length > 0) {
            recipesRef = recipesRef.where(
                "searchableFields",
                "array-contains-any",
                tokens
            );
        }

        if (difficulty) {
			// Normalize difficulty to capitalized (Easy/Medium/Hard) for stored format
			recipesRef = recipesRef.where(
				"difficulty",
				"==",
				difficulty.charAt(0).toUpperCase() + difficulty.slice(1).toLowerCase()
			);
		}
        // Note: 'tag' terms are already merged into tokens above for OR semantics

        // Get total count for pagination
        const totalQuery = await recipesRef.count().get();
        const totalRecipes = totalQuery.data().count;

        // Calculate pagination offsets
        const startAt = (page - 1) * limit;

        // Fetch recipes with simple Firestore pagination
			let snapshot;
			try {
				if (isRandom) {
                // For random: fetch a larger sample, shuffle, then paginate
                // Fetch up to 500 recipes to get a good random sample
                const randomSampleSize = Math.min(500, totalRecipes);
					snapshot = await recipesRef
                    .limit(randomSampleSize)
						.get();
				} else {
					// Default: order by creation date (latest first)
					snapshot = await recipesRef
						.orderBy("createdAt", "desc")
                    .limit(limit)
                    .offset(startAt)
						.get();
				}
			} catch (orderErr) {
				// Fallback if some docs have non-timestamp createdAt or field missing
				console.warn(
					"Falling back to un-ordered fetch due to createdAt orderBy error:",
					orderErr?.message || orderErr
				);
            snapshot = await recipesRef
                .limit(limit)
                .offset(startAt)
                .get();
			}

        // Collect recipes from snapshot
        const recipes = [];
			snapshot.forEach((doc) => {
				const data = doc.data();
            recipes.push({
					id: doc.id,
					...data,
				});
			});

        // Apply random shuffling if requested (after fetching)
        let paginatedRecipes = recipes;
        if (isRandom && recipes.length > 0) {
			// Fisher-Yates shuffle algorithm for true randomization
            const shuffled = [...recipes];
            for (let i = shuffled.length - 1; i > 0; i--) {
				const j = Math.floor(Math.random() * (i + 1));
                [shuffled[i], shuffled[j]] = [shuffled[j], shuffled[i]];
			}
            // Then apply pagination to shuffled results
        const pageStart = Math.max(0, (page - 1) * limit);
            paginatedRecipes = shuffled.slice(pageStart, pageStart + limit);
        }

        // Calculate accurate pagination info
        const totalPages = Math.ceil(totalRecipes / limit);
        const hasNextPage = page < totalPages;
        const hasPrevPage = page > 1;

		console.log(
            `Fetched ${recipes.length} recipes, returning ${paginatedRecipes.length} for page ${page} of ${totalPages} (total: ${totalRecipes})`
		);

		res.json({
			recipes: paginatedRecipes,
			pagination: {
				total: totalRecipes,
				page,
				limit,
				totalPages,
				hasNextPage,
				hasPrevPage,
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

// Deduplication function (can be called manually or automatically)
async function cleanupDuplicates() {
	try {
		console.log("🧹 Starting duplicate recipe cleanup...");

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
			`📊 Found ${duplicatesToDelete.length} duplicate recipes to delete`
		);

		if (duplicatesToDelete.length === 0) {
			console.log("✅ No duplicates found. Cleanup complete.");
			return {
				message: "Duplicate cleanup completed",
				duplicatesFound: 0,
				duplicatesDeleted: 0,
				uniqueRecipesRemaining: recipeMap.size,
			};
		}

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
				`🗑️  Deleted batch of ${batchItems.length} recipes. Total: ${deletedCount}/${duplicatesToDelete.length}`
			);
		}

		console.log(
			`✅ Duplicate cleanup completed: ${deletedCount} duplicates deleted, ${recipeMap.size} unique recipes remaining`
		);

		return {
			message: "Duplicate cleanup completed",
			duplicatesFound: duplicatesToDelete.length,
			duplicatesDeleted: deletedCount,
			uniqueRecipesRemaining: recipeMap.size,
		};
	} catch (error) {
		console.error("❌ Error during duplicate cleanup:", error);
		throw error;
	}
}

// Admin endpoint to remove duplicate recipes (manual trigger)
router.post("/cleanup-duplicates", auth, async (req, res) => {
	try {
		const result = await cleanupDuplicates();
		res.json(result);
	} catch (error) {
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't complete duplicate cleanup right now. Please try again later."
		);
	}
});

// Export both the router and the cleanup function
const discoverRouter = router;
discoverRouter.cleanupDuplicates = cleanupDuplicates;
module.exports = discoverRouter;

// Developer-only endpoint to delete a discover recipe
// Only available in development/debug mode
router.delete("/recipes/:id", auth, async (req, res) => {
	try {
		// Only allow in development mode
		if (process.env.NODE_ENV === 'production') {
			return errorHandler.forbidden(
				res,
				"This endpoint is only available in development mode"
			);
		}

		const { id } = req.params;

		if (!id || typeof id !== "string" || id.trim().length === 0) {
			return errorHandler.badRequest(res, "Recipe id is required");
		}

		const recipeRef = db.collection("recipes").doc(id);
		const recipeDoc = await recipeRef.get();

		if (!recipeDoc.exists) {
			return errorHandler.notFound(res, "Recipe not found");
		}

		const recipeData = recipeDoc.data();

		// Log recipe fields for debugging
		console.log(`[DEV] Recipe ${id} fields:`, {
			title: recipeData.title,
			userId: recipeData.userId || 'NOT SET',
			isExternal: recipeData.isExternal || false,
			externalId: recipeData.externalId || 'NOT SET',
			hasUserId: !!recipeData.userId,
			hasIsExternal: !!recipeData.isExternal,
			hasExternalId: !!recipeData.externalId,
		});

		// In development mode, allow deletion of ANY recipe from discover screen
		// Developer has full control to delete any recipe, regardless of userId
		if (recipeData.userId) {
			console.warn(
				`[DEV] Deleting recipe with userId: ${recipeData.userId}. This is allowed in development mode.`
			);
		}

		// Delete the recipe
		await recipeRef.delete();

		console.log(`🗑️  [DEV] Deleted discover recipe: ${id} - ${recipeData.title}`);

		res.json({
			message: "Recipe deleted successfully",
			recipeId: id,
			title: recipeData.title,
		});
	} catch (error) {
		console.error("Error deleting discover recipe:", error);
		errorHandler.serverError(
			res,
			"We couldn't delete the recipe right now. Please try again shortly."
		);
	}
});

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
