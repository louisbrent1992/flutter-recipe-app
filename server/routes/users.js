const express = require("express");
const router = express.Router();
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const auth = require("../middleware/auth");
const axios = require("axios");

// Google Custom Search configuration (same as in generatedRecipes)
const GOOGLE_API_KEY = process.env.GOOGLE_API_KEY;
const GOOGLE_CX = process.env.GOOGLE_CX;
const GOOGLE_SEARCH_URL = "https://www.googleapis.com/customsearch/v1";

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
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't load your profile right now. Please try again shortly."
		);
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
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't update your profile right now. Please try again shortly."
		);
	}
});

// Get all recipes for a user with pagination
router.get("/recipes", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const page = parseInt(req.query.page) || 1;
		const limit = parseInt(req.query.limit) || 10;
		const startAt = (page - 1) * limit;

		// Use a single query with pagination instead of separate count query
		const recipesRef = db.collection("recipes");
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

		// Get total count only if this is the first page or if we need pagination info
		let totalRecipes = 0;
		let totalPages = 0;
		let hasNextPage = false;
		let hasPrevPage = page > 1;

		if (page === 1 || recipes.length === limit) {
			const totalQuery = await recipesRef
				.where("userId", "==", userId)
				.count()
				.get();
			totalRecipes = totalQuery.data().count;
			totalPages = Math.ceil(totalRecipes / limit);
			hasNextPage = page * limit < totalRecipes;
		}

		res.json({
			recipes,
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
		console.error("Error getting user recipes:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't load your recipes right now. Please try again shortly."
		);
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
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't load that recipe right now. Please try again shortly."
		);
	}
});

// Create a new user recipe
router.post("/recipes", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const {
			title,
			cuisineType = "Fusion",
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
			tiktok = null,
			youtube = null,
			aiGenerated = false,
			toEdit = false,
			nutrition = null,
		} = req.body;

		if (!title) {
			return res.status(400).json({ error: "Title is required" });
		}

        // Generate searchable fields (only title, ingredients, and tags)
        const searchableFields = [
            title.toLowerCase(),
            ...ingredients.map((i) => i.toLowerCase()),
            ...tags.map((t) => t.toLowerCase()),
        ].filter((field) => field.length > 0);

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
			tiktok,
			youtube,
			aiGenerated,
			toEdit,
			nutrition,
			createdAt: new Date().toISOString(),
			updatedAt: new Date().toISOString(),
			isFavorite: false,
			searchableFields,
		};

		const docRef = await db.collection("recipes").add(newRecipe);

		res.status(201).json({
			id: docRef.id,
			...newRecipe,
		});
	} catch (error) {
		console.error("Error creating recipe:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't save your recipe right now. Please try again shortly."
		);
	}
});

// Refresh a recipe's image by querying Google Custom Search and persisting the new URL
router.post("/recipes/:id/refresh-image", auth, async (req, res) => {
	try {
		if (!GOOGLE_API_KEY || !GOOGLE_CX) {
			return res.status(500).json({
				error: "Google Custom Search is not configured",
				message: "Missing GOOGLE_API_KEY or GOOGLE_CX",
			});
		}

		const userId = req.user.uid;
		const recipeId = req.params.id;

		// Load recipe and verify ownership
		const db = getFirestore();
		const recipeRef = db.collection("recipes").doc(recipeId);
		const recipeDoc = await recipeRef.get();
		if (!recipeDoc.exists) {
			return res.status(404).json({ error: "Recipe not found" });
		}
		const recipeData = recipeDoc.data();
		if (recipeData.userId !== userId) {
			return res.status(403).json({ error: "Not authorized to update this recipe" });
		}

		const query = (recipeData.title || "recipe").trim().toLowerCase();
		let newImageUrl = null;
		const started = Date.now();
		try {
			const resp = await axios.get(GOOGLE_SEARCH_URL, {
				params: {
					key: GOOGLE_API_KEY,
					cx: GOOGLE_CX,
					q: `${query}`,
					searchType: "image",
					num: 3,
					safe: "active",
					start: 1,
				},
			});
			// Pick first valid link
			const items = (resp.data && resp.data.items) || [];
			for (const item of items) {
				if (item && item.link) {
					newImageUrl = item.link;
					break;
				}
			}
		} catch (err) {
			console.error("Error fetching replacement image from Google:", err?.response?.status || err?.message || err);
		}

		if (!newImageUrl) {
			return res.status(200).json({
				success: false,
				message: "No replacement image found",
			});
		}

		// Update recipe imageUrl
		await recipeRef.update({
			imageUrl: newImageUrl,
			updatedAt: new Date().toISOString(),
		});

		// Optionally update embedded copies in user's collections
		let collectionsUpdated = 0;
		try {
			const collectionsSnapshot = await db
				.collection("users")
				.doc(userId)
				.collection("collections")
				.get();
			for (const collectionDoc of collectionsSnapshot.docs) {
				const data = collectionDoc.data();
				const recipes = Array.isArray(data.recipes) ? data.recipes : [];
				let changed = false;
				const updatedRecipes = recipes.map((r) => {
					if (r && r.id === recipeId) {
						changed = true;
						return { ...r, imageUrl: newImageUrl };
					}
					return r;
				});
				if (changed) {
					await collectionDoc.ref.update({
						recipes: updatedRecipes,
						updatedAt: new Date().toISOString(),
					});
					collectionsUpdated++;
				}
			}
		} catch (e) {
			console.error("Error updating embedded recipes in collections:", e?.message || e);
		}

		return res.json({
			success: true,
			recipeId,
			imageUrl: newImageUrl,
			collectionsUpdated,
		});
	} catch (error) {
		console.error("Error refreshing recipe image:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't refresh the image right now. Please try again shortly."
		);
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

        // Generate searchable fields from the updated data (only title, ingredients, tags)
        const searchableFields = [
            (req.body.title || recipeData.title).toLowerCase(),
            ...(req.body.ingredients || recipeData.ingredients).map((i) =>
                i.toLowerCase()
            ),
            ...(req.body.tags || recipeData.tags).map((t) => t.toLowerCase()),
        ].filter((field) => field.length > 0);

		const updates = {
			...req.body,
			userId: recipeData.userId,
			searchableFields,
			updatedAt: new Date().toISOString(),
		};

		await recipeRef.update(updates);

		// Return the fully updated document to ensure fields like createdAt are preserved
		const updatedDoc = await recipeRef.get();
		res.json({
			id: updatedDoc.id,
			...updatedDoc.data(),
		});
	} catch (error) {
		console.error("Error updating recipe:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't update the recipe right now. Please try again shortly."
		);
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

		// Start a batch to ensure all operations succeed or fail together
		const batch = db.batch();

		// 1. Delete the recipe document
		batch.delete(recipeRef);

		// Favorites removed: endpoints deleted

		// 3. Remove from all user's collections
		const collectionsSnapshot = await db
			.collection("users")
			.doc(userId)
			.collection("collections")
			.get();

		for (const collectionDoc of collectionsSnapshot.docs) {
			const collectionData = collectionDoc.data();
			const recipes = collectionData.recipes || [];

			// Check if this recipe is in this collection
			const updatedRecipes = recipes.filter((r) => r.id !== recipeId);

			// Only update if the recipe was actually in this collection
			if (updatedRecipes.length !== recipes.length) {
				batch.update(collectionDoc.ref, {
					recipes: updatedRecipes,
					updatedAt: new Date().toISOString(),
				});
			}
		}

		// Commit all operations
		await batch.commit();

		res.json({
			message: "Recipe deleted successfully and removed from collections",
		});
	} catch (error) {
		console.error("Error deleting recipe:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't delete the recipe right now. Please try again shortly."
		);
	}
});

// Delete user account
router.delete("/account", auth, async (req, res) => {
	try {
		const userId = req.user.uid;

		// 5. Delete user profile from Firestore
		await db.collection("users").doc(userId).delete();

		res.json({ success: true, message: "Account deleted successfully" });
	} catch (error) {
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't delete your account data right now. Please try again shortly."
		);
	}
});

module.exports = router;
