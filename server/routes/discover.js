const express = require("express");
const router = express.Router();
const axios = require("axios");
const auth = require("../middleware/auth");
const admin = require("firebase-admin");
const { v4: uuidv4 } = require("uuid");
const { getFirestore } = require("firebase-admin/firestore");

// Get Firestore database instance
const db = getFirestore();

// Search recipes from Spoonacular API
router.get("/search", auth, async (req, res) => {
	try {
		const { query, difficulty, tag } = req.query;
		const page = parseInt(req.query.page) || 1;
		const limit = Math.min(parseInt(req.query.limit) || 10, 100);

		// Build Firestore query
		let recipesRef = db.collection("recipes");

		if (query) {
			console.log("Search query:", query);
			const searchTerms = query
				.toLowerCase()
				.split(/\s+/)
				.filter((term) => term.length > 0)
				.slice(0, 3); // Limit to first 3 terms for performance
			console.log("Search terms:", searchTerms);

			// Use the most relevant search term for the primary query
			if (searchTerms.length > 0) {
				recipesRef = db
					.collection("recipes")
					.where("searchableFields", "array-contains", searchTerms[0]);
			}
		}
		if (difficulty) {
			recipesRef = recipesRef.where(
				"difficulty",
				"==",
				difficulty.charAt(0).toUpperCase() + difficulty.slice(1).toLowerCase()
			);
		}
		if (tag) {
			recipesRef = recipesRef.where(
				"tags",
				"array-contains",
				tag.toLowerCase()
			);
		}

		// Get total count for pagination (before deduplication)
		const totalQuery = await recipesRef.count().get();
		const totalRecipes = totalQuery.data().count;
		console.log("Total recipes found:", totalRecipes);

		// Reduced buffer multiplier for better performance
		const bufferMultiplier = 1.2; // Reduced from 1.5x
		const fetchLimit = Math.min(limit * bufferMultiplier, 150); // Reduced cap
		const startAt = Math.max(0, (page - 1) * limit);

		// Fetch recipes with smaller buffer for deduplication
		const snapshot = await recipesRef
			.orderBy("createdAt", "desc")
			.limit(fetchLimit)
			.offset(startAt)
			.get();

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
		res.status(500).json({ error: "Failed to search recipes" });
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
		res.status(500).json({ error: "Failed to cleanup duplicates" });
	}
});

module.exports = router;
