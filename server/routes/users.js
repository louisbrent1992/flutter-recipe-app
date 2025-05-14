const express = require("express");
const router = express.Router();
const { getFirestore } = require("firebase-admin/firestore");
const auth = require("../middleware/auth");

// Get Firestore database instance
const db = getFirestore();

// Get user profile
router.get("/profile", auth, async (req, res) => {
	try {
		const userDoc = await db.collection("users").doc(req.user.uid).get();
		if (!userDoc.exists) {
			return res.status(404).json({ error: "User not found" });
		}
		res.json(userDoc.data());
	} catch (error) {
		console.error("Error fetching user profile:", error);
		res.status(500).json({ error: "Internal server error" });
	}
});

// Update user profile
router.put("/profile", auth, async (req, res) => {
	try {
		const { displayName, email } = req.body;
		await db.collection("users").doc(req.user.uid).update({
			displayName,
			email,
			updatedAt: new Date().toISOString(),
		});
		res.json({ message: "Profile updated successfully" });
	} catch (error) {
		console.error("Error updating user profile:", error);
		res.status(500).json({ error: "Internal server error" });
	}
});

// Get all recipes for a user with pagination
router.get("/recipes", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const page = parseInt(req.query.page) || 1;
		const limit = parseInt(req.query.limit) || 10;
		const startAt = (page - 1) * limit;

		const recipesRef = db.collection("recipes");
		const totalQuery = await recipesRef
			.where("userId", "==", userId)
			.count()
			.get();
		const totalRecipes = totalQuery.data().count;

		const snapshot = await recipesRef
			.where("userId", "==", userId)
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
				hasNextPage: page * limit < totalRecipes,
				hasPrevPage: page > 1,
			},
		});
	} catch (error) {
		console.error("Error getting user recipes:", error);
		res.status(500).json({ error: "Failed to retrieve recipes" });
	}
});

// Get a specific user recipe by ID
router.get("/recipes/:id", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const recipeId = req.params.id;

		const recipeDoc = await db.collection("recipes").doc(recipeId).get();

		if (!recipeDoc.exists) {
			return res.status(404).json({ error: "Recipe not found" });
		}

		const recipeData = recipeDoc.data();

		if (recipeData.userId !== userId) {
			return res
				.status(403)
				.json({ error: "Not authorized to access this recipe" });
		}

		res.json({
			id: recipeDoc.id,
			...recipeData,
		});
	} catch (error) {
		console.error("Error getting recipe:", error);
		res.status(500).json({ error: "Failed to retrieve recipe" });
	}
});

// Create a new user recipe
router.post("/recipes", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const {
			title,
			cuisineType = "",
			description = "",
			ingredients = [],
			instructions = [],
			imageUrl = null,
			cookingTime = "",
			difficulty = "",
			servings = "",
			tags = [],
			source = "user-created",
			sourcePlatform = null,
			sourceUrl = null,
			author = null,
			instagram = null,
		} = req.body;

		if (!title) {
			return res.status(400).json({ error: "Title is required" });
		}

		const newRecipe = {
			userId,
			title,
			cuisineType,
			description,
			ingredients: Array.isArray(ingredients) ? ingredients : [],
			instructions: Array.isArray(instructions) ? instructions : [],
			imageUrl,
			cookingTime,
			difficulty,
			servings,
			tags: Array.isArray(tags) ? tags : [],
			source,
			sourcePlatform,
			sourceUrl,
			author,
			instagram,
			createdAt: new Date().toISOString(),
			updatedAt: new Date().toISOString(),
			isFavorite: false,
		};

		const docRef = await db.collection("recipes").add(newRecipe);

		res.status(201).json({
			id: docRef.id,
			...newRecipe,
		});
	} catch (error) {
		console.error("Error creating recipe:", error);
		res.status(500).json({ error: "Failed to create recipe" });
	}
});

// Update a user recipe
router.put("/recipes/:id", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const recipeId = req.params.id;

		const recipeRef = db.collection("recipes").doc(recipeId);
		const recipeDoc = await recipeRef.get();

		if (!recipeDoc.exists) {
			return res.status(404).json({ error: "Recipe not found" });
		}

		const recipeData = recipeDoc.data();

		if (recipeData.userId !== userId) {
			return res
				.status(403)
				.json({ error: "Not authorized to update this recipe" });
		}

		const updates = {
			...req.body,
			updatedAt: new Date().toISOString(),
		};

		await recipeRef.update(updates);

		res.json({
			id: recipeId,
			...updates,
		});
	} catch (error) {
		console.error("Error updating recipe:", error);
		res.status(500).json({ error: "Failed to update recipe" });
	}
});

// Delete a user recipe
router.delete("/recipes/:id", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const recipeId = req.params.id;

		const recipeRef = db.collection("recipes").doc(recipeId);
		const recipeDoc = await recipeRef.get();

		if (!recipeDoc.exists) {
			return res.status(404).json({ error: "Recipe not found" });
		}

		const recipeData = recipeDoc.data();

		if (recipeData.userId !== userId) {
			return res
				.status(403)
				.json({ error: "Not authorized to delete this recipe" });
		}

		await recipeRef.delete();

		res.json({ message: "Recipe deleted successfully" });
	} catch (error) {
		console.error("Error deleting recipe:", error);
		res.status(500).json({ error: "Failed to delete recipe" });
	}
});

// Get user's favorite recipes
router.get("/favorites", auth, async (req, res) => {
	try {
		const favoritesDoc = await db
			.collection("favorites")
			.doc(req.user.uid)
			.get();
		if (!favoritesDoc.exists) {
			return res.json([]);
		}
		console.log(favoritesDoc.data().recipes);
		res.json(favoritesDoc.data().recipes || []);
	} catch (error) {
		console.error("Error fetching favorites:", error);
		res.status(500).json({ error: "Internal server error" });
	}
});

// Add recipe to favorites
router.post("/favorites", auth, async (req, res) => {
	try {
		const { recipeId } = req.body;
		await db
			.collection("favorites")
			.doc(req.user.uid)
			.set(
				{
					recipes: db.FieldValue.arrayUnion(recipeId),
					updatedAt: new Date().toISOString(),
				},
				{ merge: true }
			);
		res.json({ message: "Recipe added to favorites" });
	} catch (error) {
		console.error("Error adding to favorites:", error);
		res.status(500).json({ error: "Internal server error" });
	}
});

// Remove recipe from favorites
router.delete("/favorites/:recipeId", auth, async (req, res) => {
	try {
		const { recipeId } = req.params;
		await db
			.collection("favorites")
			.doc(req.user.uid)
			.update({
				recipes: db.FieldValue.arrayRemove(recipeId),
				updatedAt: new Date().toISOString(),
			});
		res.json({ message: "Recipe removed from favorites" });
	} catch (error) {
		console.error("Error removing from favorites:", error);
		res.status(500).json({ error: "Internal server error" });
	}
});

module.exports = router;
