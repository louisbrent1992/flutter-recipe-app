/**
 * User Recipes API Routes
 *
 * Provides CRUD operations for user recipes stored in Firebase
 */

const express = require("express");
const router = express.Router();
const { v4: uuidv4 } = require("uuid");
const { getFirestore } = require("firebase-admin/firestore");
const auth = require("../middleware/auth");

// Get Firestore database instance
const db = getFirestore();

/**
 * @route   GET /user/recipes
 * @desc    Get all recipes for a user
 * @access  Private
 */
router.get("/", auth, async (req, res) => {
	try {
		const userId = req.user.uid;

		// Query Firestore for user's recipes
		const recipesRef = db.collection("recipes");
		const snapshot = await recipesRef
			.where("userId", "==", userId)
			.orderBy("createdAt", "desc")
			.get();

		// Transform snapshot into array of recipes
		const recipes = [];
		snapshot.forEach((doc) => {
			recipes.push({
				id: doc.id,
				...doc.data(),
			});
		});

		res.json(recipes);
	} catch (error) {
		console.error("Error getting user recipes:", error);
		res.status(500).json({ error: "Failed to retrieve recipes" });
	}
});

/**
 * @route   GET /user/recipes/:id
 * @desc    Get a specific recipe by ID
 * @access  Private
 */
router.get("/:id", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const recipeId = req.params.id;

		const recipeDoc = await db.collection("recipes").doc(recipeId).get();

		if (!recipeDoc.exists) {
			return res.status(404).json({ error: "Recipe not found" });
		}

		const recipeData = recipeDoc.data();

		// Verify the recipe belongs to the authenticated user
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

/**
 * @route   POST /user/recipes
 * @desc    Create a new recipe
 * @access  Private
 */
router.post("/", auth, async (req, res) => {
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

		// Validate required fields
		if (!title) {
			return res.status(400).json({ error: "Title is required" });
		}

		// Create new recipe document
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

		// Save to Firestore
		const docRef = await db.collection("recipes").add(newRecipe);

		// Return the created recipe with ID
		res.status(201).json({
			id: docRef.id,
			...newRecipe,
		});
	} catch (error) {
		console.error("Error creating recipe:", error);
		res.status(500).json({ error: "Failed to create recipe" });
	}
});

/**
 * @route   PUT /user/recipes/:id
 * @desc    Update a recipe
 * @access  Private
 */
router.put("/:id", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const recipeId = req.params.id;

		// Get existing recipe to verify ownership
		const recipeRef = db.collection("recipes").doc(recipeId);
		const recipeDoc = await recipeRef.get();

		if (!recipeDoc.exists) {
			return res.status(404).json({ error: "Recipe not found" });
		}

		const recipeData = recipeDoc.data();

		// Verify the recipe belongs to the authenticated user
		if (recipeData.userId !== userId) {
			return res
				.status(403)
				.json({ error: "Not authorized to update this recipe" });
		}

		// Extract fields to update
		const {
			title,
			cuisineType,
			description,
			ingredients,
			instructions,
			imageUrl,
			cookingTime,
			difficulty,
			servings,
			tags,
			isFavorite,
		} = req.body;

		// Build update object with only provided fields
		const updateData = {
			updatedAt: new Date().toISOString(),
		};

		if (title !== undefined) updateData.title = title;
		if (cuisineType !== undefined) updateData.cuisineType = cuisineType;
		if (description !== undefined) updateData.description = description;
		if (ingredients !== undefined)
			updateData.ingredients = Array.isArray(ingredients) ? ingredients : [];
		if (instructions !== undefined)
			updateData.instructions = Array.isArray(instructions) ? instructions : [];
		if (imageUrl !== undefined) updateData.imageUrl = imageUrl;
		if (cookingTime !== undefined) updateData.cookingTime = cookingTime;
		if (difficulty !== undefined) updateData.difficulty = difficulty;
		if (servings !== undefined) updateData.servings = servings;
		if (tags !== undefined) updateData.tags = Array.isArray(tags) ? tags : [];
		if (isFavorite !== undefined) updateData.isFavorite = !!isFavorite;

		// Update the recipe
		await recipeRef.update(updateData);

		// Return the updated recipe
		const updatedRecipeDoc = await recipeRef.get();

		res.json({
			id: updatedRecipeDoc.id,
			...updatedRecipeDoc.data(),
		});
	} catch (error) {
		console.error("Error updating recipe:", error);
		res.status(500).json({ error: "Failed to update recipe" });
	}
});

/**
 * @route   DELETE /user/recipes/:id
 * @desc    Delete a recipe
 * @access  Private
 */
router.delete("/:id", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const recipeId = req.params.id;

		// Get recipe to verify ownership
		const recipeRef = db.collection("recipes").doc(recipeId);
		const recipeDoc = await recipeRef.get();

		if (!recipeDoc.exists) {
			return res.status(404).json({ error: "Recipe not found" });
		}

		const recipeData = recipeDoc.data();

		// Verify the recipe belongs to the authenticated user
		if (recipeData.userId !== userId) {
			return res
				.status(403)
				.json({ error: "Not authorized to delete this recipe" });
		}

		// Delete the recipe
		await recipeRef.delete();

		res.json({ message: "Recipe deleted successfully" });
	} catch (error) {
		console.error("Error deleting recipe:", error);
		res.status(500).json({ error: "Failed to delete recipe" });
	}
});

/**
 * @route   PUT /user/recipes/:id/favorite
 * @desc    Toggle favorite status of a recipe
 * @access  Private
 */
router.put("/:id/favorite", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const recipeId = req.params.id;
		const { isFavorite } = req.body;

		if (isFavorite === undefined) {
			return res.status(400).json({ error: "isFavorite field is required" });
		}

		// Get recipe to verify ownership
		const recipeRef = db.collection("recipes").doc(recipeId);
		const recipeDoc = await recipeRef.get();

		if (!recipeDoc.exists) {
			return res.status(404).json({ error: "Recipe not found" });
		}

		const recipeData = recipeDoc.data();

		// Verify the recipe belongs to the authenticated user
		if (recipeData.userId !== userId) {
			return res
				.status(403)
				.json({ error: "Not authorized to update this recipe" });
		}

		// Update favorite status
		await recipeRef.update({
			isFavorite: !!isFavorite,
			updatedAt: new Date().toISOString(),
		});

		res.json({ message: "Recipe favorite status updated" });
	} catch (error) {
		console.error("Error updating favorite status:", error);
		res.status(500).json({ error: "Failed to update favorite status" });
	}
});

/**
 * @route   POST /user/recipes/save-from-ai
 * @desc    Save an AI-generated recipe to user's collection
 * @access  Private
 */
router.post("/save-from-ai", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const { recipe } = req.body;

		if (!recipe) {
			return res.status(400).json({ error: "Recipe data is required" });
		}

		// Extract recipe fields
		const {
			title,
			cuisineType = "",
			description = "",
			ingredients = [],
			instructions = [],
			imageUrl,
			cookingTime = "",
			difficulty = "",
			servings = "",
			tags = [],
			source = "ai-generated",
			sourcePlatform = null,
			sourceUrl = null,
			author = null,
			instagram = null,
		} = recipe;

		// Validate required fields
		if (!title) {
			return res.status(400).json({ error: "Recipe title is required" });
		}

		// Create new recipe document
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

		// Save to Firestore
		const docRef = await db.collection("recipes").add(newRecipe);

		// Return the created recipe with ID
		res.status(201).json({
			id: docRef.id,
			...newRecipe,
		});
	} catch (error) {
		console.error("Error saving AI recipe:", error);
		res.status(500).json({ error: "Failed to save AI recipe" });
	}
});

/**
 * @route   GET /user/recipes/favorites
 * @desc    Get all favorite recipes for a user
 * @access  Private
 */
router.get("/favorites", auth, async (req, res) => {
	try {
		const userId = req.user.uid;

		// Query Firestore for user's favorite recipes
		const recipesRef = db.collection("recipes");
		const snapshot = await recipesRef
			.where("userId", "==", userId)
			.where("isFavorite", "==", true)
			.orderBy("updatedAt", "desc")
			.get();

		// Transform snapshot into array of recipes
		const recipes = [];
		snapshot.forEach((doc) => {
			recipes.push({
				id: doc.id,
				...doc.data(),
			});
		});

		res.json(recipes);
	} catch (error) {
		console.error("Error getting favorite recipes:", error);
		res.status(500).json({ error: "Failed to retrieve favorite recipes" });
	}
});

module.exports = router;
