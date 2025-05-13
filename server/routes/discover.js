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
router.get("/search", async (req, res) => {
	try {
		const { query, difficulty, tag } = req.query;
		const page = parseInt(req.query.page) || 1;
		const limit = Math.min(parseInt(req.query.limit) || 10, 100); // Ensure limit is between 1 and 100
		const startAt = (page - 1) * limit;

		// Build Firestore query
		let recipesRef = admin.firestore().collection("recipes");
		if (query) {
			recipesRef = recipesRef
				.where("title", ">=", query)
				.where("title", "<=", query + "\uf8ff");
		}
		if (difficulty) {
			recipesRef = recipesRef.where("difficulty", "==", difficulty);
		}
		if (tag) {
			recipesRef = recipesRef.where("tags", "array-contains", tag);
		}

		// Get total count for pagination
		const totalQuery = await recipesRef.count().get();
		const totalRecipes = totalQuery.data().count;

		// Fetch paginated recipes
		const snapshot = await recipesRef
			.orderBy("createdAt", "desc")
			.limit(limit)
			.offset(startAt)
			.get();

		const recipes = [];
		snapshot.forEach((doc) => {
			recipes.push({
				id: doc.id,
				...doc.data(),
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
