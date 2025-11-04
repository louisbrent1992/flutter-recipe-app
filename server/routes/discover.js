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

        // Build Firestore query
        let recipesRef = db.collection("recipes");

        // Aggregate tokens from query and tag, treating comma-separated chunks as phrases.
        // For each phrase, prefer the full phrase token, then (if room) include individual word tokens.
        const gatherTokens = (input) => {
            if (!input || typeof input !== 'string') return [];
            return input
                .toLowerCase()
                .split(',') // split on commas only; keep spaces inside phrase
                .map((s) => s.trim().replace(/\s+/g, ' ')) // normalize inner spaces
                .filter((s) => s.length > 0);
        };

        let phraseTokens = [];
        phraseTokens = phraseTokens.concat(gatherTokens(query));
        phraseTokens = phraseTokens.concat(gatherTokens(tag));

        // De-duplicate phrases
        phraseTokens = Array.from(new Set(phraseTokens));

        // Build final tokens list with phrases first, then individual words from those phrases
        let tokens = [...phraseTokens];
        // Add individual words if space permits (Firestore limit 10)
        for (const phrase of phraseTokens) {
            if (tokens.length >= 10) break;
            const words = phrase.split(/\s+/).filter((w) => w.length > 0);
            for (const w of words) {
                if (tokens.length >= 10) break;
                if (!tokens.includes(w)) tokens.push(w);
            }
        }
        if (tokens.length > 10) {
            console.warn(
                `array-contains-any supports up to 10 values; capped to 10 (had ${tokens.length})`
            );
            tokens = tokens.slice(0, 10);
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

        // Get total count for pagination (before deduplication)
        const totalQuery = await recipesRef.count().get();
        const totalRecipes = totalQuery.data().count;

        // Fetch recipes ensuring we get enough unique results for the requested page
        // We collect up to targetUnique = page * limit unique items, then slice the page segment
        const uniqueRecipesMap = new Map();
        const targetUnique = Math.max(page * limit, limit);
        let currentOffset = 0;
        let fetchAttempts = 0;
        const maxFetchAttempts = 10; // allow more attempts to satisfy deeper pages
        const batchSize = Math.max(limit * 2, 50); // Fetch larger batches to account for deduplication

		// Keep fetching until we have enough unique recipes or hit max attempts
        while (uniqueRecipesMap.size < targetUnique && fetchAttempts < maxFetchAttempts) {
			let snapshot;
			try {
				if (isRandom) {
					// For random ordering, fetch more recipes and randomize client-side
					const randomBatchSize = Math.min(batchSize * 3, 300); // Fetch more for better randomization
					snapshot = await recipesRef
						.limit(randomBatchSize)
						.offset(currentOffset)
						.get();
				} else {
					// Default: order by creation date (latest first)
					snapshot = await recipesRef
						.orderBy("createdAt", "desc")
						.limit(batchSize)
						.offset(currentOffset)
						.get();
				}
			} catch (orderErr) {
				// Fallback if some docs have non-timestamp createdAt or field missing
				console.warn(
					"Falling back to un-ordered fetch due to createdAt orderBy error:",
					orderErr?.message || orderErr
				);
				snapshot = await recipesRef.limit(batchSize).offset(currentOffset).get();
			}

			// If no more recipes, break
			if (snapshot.empty) {
				break;
			}

            // Collect recipes from this batch
			const batchRecipes = [];
			snapshot.forEach((doc) => {
				const data = doc.data();
				batchRecipes.push({
					id: doc.id,
					...data,
				});
			});

            // Helper: ensure token matches only title, ingredients, or tags
            const tokensSet = new Set(tokens || []);
            const matchesAllowedFields = (recipe) => {
                // Build normalized fields
                const title = (recipe.title || "").toString().toLowerCase();
                const ingredients = Array.isArray(recipe.ingredients)
                    ? recipe.ingredients.map((v) => (v || "").toString().toLowerCase())
                    : [];
                const tags = Array.isArray(recipe.tags)
                    ? recipe.tags.map((v) => (v || "").toString().toLowerCase())
                    : [];

                // For each token (phrase or word), check containment in allowed fields
                for (const tok of tokensSet) {
                    if (!tok || typeof tok !== 'string') continue;
                    if (title.includes(tok)) return true;
                    if (ingredients.some((ing) => ing.includes(tok))) return true;
                    // Tags are typically single words; use contains to allow phrases too
                    if (tags.some((tagVal) => tagVal.includes(tok))) return true;
                }
                return false;
            };

            // Add unique recipes to our map (union across terms already applied in query),
            // but only if matches occur in title, ingredients, or tags (omit description/instructions)
            for (const recipe of batchRecipes) {
                if (tokens && tokens.length > 0 && !matchesAllowedFields(recipe)) {
                    continue;
                }
				const key = `${recipe.title?.toLowerCase() || ""}|${
					recipe.description?.toLowerCase() || ""
				}`;
                if (!uniqueRecipesMap.has(key)) {
                    uniqueRecipesMap.set(key, recipe);
                    // Stop if we have enough unique recipes for the requested page window
                    if (uniqueRecipesMap.size >= targetUnique) {
                        break;
                    }
                }
			}

            currentOffset += batchSize;
			fetchAttempts++;
		}

		// Convert back to array and apply pagination to deduplicated results
		let deduplicatedRecipes = Array.from(uniqueRecipesMap.values());
		
		// Apply random shuffling if requested
		if (isRandom) {
			// Fisher-Yates shuffle algorithm for true randomization
			for (let i = deduplicatedRecipes.length - 1; i > 0; i--) {
				const j = Math.floor(Math.random() * (i + 1));
				[deduplicatedRecipes[i], deduplicatedRecipes[j]] = [deduplicatedRecipes[j], deduplicatedRecipes[i]];
			}
		}
		
        const pageStart = Math.max(0, (page - 1) * limit);
        const paginatedRecipes = deduplicatedRecipes.slice(pageStart, pageStart + limit);

		console.log(
			`Performed ${fetchAttempts} fetch attempts, deduplicated to ${deduplicatedRecipes.length} unique recipes, returning ${paginatedRecipes.length}`
		);

		// Calculate pagination info based on deduplicated results
		// More accurate now since we have fewer duplicates
        const estimatedTotalPages = Math.ceil((totalRecipes * 0.95) / limit); // Rough estimate
        const hasMore = deduplicatedRecipes.length > pageStart + paginatedRecipes.length || page * limit < totalRecipes;

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
