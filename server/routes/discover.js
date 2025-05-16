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

module.exports = router;
