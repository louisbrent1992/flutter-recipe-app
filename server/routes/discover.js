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
		const limit = Math.min(parseInt(req.query.limit) || 10, 100); // Ensure limit is between 1 and 100
		const startAt = (page - 1) * limit;

		// Build Firestore query
		let recipesRef = db.collection("recipes");

		if (query) {
			console.log("Search query:", query);
			// Create a compound query to search across multiple fields
			const searchTerms = query
				.toLowerCase()
				.split(/\s+/) // Split on any whitespace
				.filter((term) => term.length > 0);
			console.log("Search terms:", searchTerms);

			// Start with the base query
			recipesRef = db.collection("recipes");

			// Create a compound query that matches any of the search terms
			const searchQueries = searchTerms.map((term) => {
				return db
					.collection("recipes")
					.where("searchableFields", "array-contains", term);
			});

			// If we have search terms, use the first query as base
			if (searchQueries.length > 0) {
				recipesRef = searchQueries[0];
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

		// Get total count for pagination
		const totalQuery = await recipesRef.count().get();
		const totalRecipes = totalQuery.data().count;
		console.log("Total recipes found:", totalRecipes);

		// Fetch paginated recipes
		const snapshot = await recipesRef
			.orderBy("createdAt", "desc")
			.limit(limit)
			.offset(startAt)
			.get();

		const recipes = [];
		snapshot.forEach((doc) => {
			const data = doc.data();

			recipes.push({
				id: doc.id,
				...data,
			});
		});

		res.json({
			recipes,
			pagination: {
				total: totalRecipes,
				page,
				limit,
				totalPages: Math.ceil(totalRecipes / limit),
				hasNextPage: startAt + limit < totalRecipes,
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
