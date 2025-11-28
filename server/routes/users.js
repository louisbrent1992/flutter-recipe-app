const express = require("express");
const router = express.Router();
const { getFirestore, FieldValue } = require("firebase-admin/firestore");
const auth = require("../middleware/auth");
const axios = require("axios");
const { searchImage } = require("../utils/imageService");
const { checkAndSendMilestoneNotification } = require("../utils/notifications");

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
			originalRecipeId = null, // ID of the original recipe if saving from community
		} = req.body;

		if (!title) {
			return res.status(400).json({ error: "Title is required" });
		}

		// Check for duplicates by sourceUrl first (most reliable)
		if (sourceUrl) {
			const urlDuplicateQuery = await db.collection("recipes")
				.where("userId", "==", userId)
				.where("sourceUrl", "==", sourceUrl)
				.limit(1)
				.get();
			
			if (!urlDuplicateQuery.empty) {
				return res.status(409).json({ 
					error: true,
					message: "This recipe already exists in your collection",
					existingRecipeId: urlDuplicateQuery.docs[0].id 
				});
			}
		}

		// Check for duplicates by userId, title, and description
		const duplicateQuery = await db.collection("recipes")
			.where("userId", "==", userId)
			.where("title", "==", title)
			.limit(10) // Get a few to check descriptions
			.get();

		if (!duplicateQuery.empty) {
			// Check if any have matching description
			const normalizedDescription = (description || "").toLowerCase().trim();
			for (const doc of duplicateQuery.docs) {
				const existingRecipe = doc.data();
				const existingDescription = (existingRecipe.description || "").toLowerCase().trim();
				
				// If descriptions match (or both are empty), it's a duplicate
				if (existingDescription === normalizedDescription) {
					return res.status(409).json({ 
						error: true,
						message: "This recipe already exists in your collection",
						existingRecipeId: doc.id 
					});
				}
			}
		}

        // Generate searchable fields (only title, ingredients, and tags)
        // Normalize hyphens to spaces in tags for consistent searching
		const searchableFields = [
			title.toLowerCase(),
			...ingredients.map((i) => i.toLowerCase()),
			...tags.map((t) => t.toLowerCase().replace(/-/g, ' ')),
		].filter((field) => field.length > 0);

		// Determine if recipe should be discoverable
		// Discoverable if: AI-generated OR imported from social media (has sourcePlatform)
		// Not discoverable if: manually created by user
		const isDiscoverable = aiGenerated || !!sourcePlatform;

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
			isDiscoverable,
			toEdit,
			nutrition,
			createdAt: new Date().toISOString(),
			updatedAt: new Date().toISOString(),
			isFavorite: false,
			likeCount: 0, // Initialize like count
			saveCount: 0, // Initialize save count
			shareCount: 0, // Initialize share count
			searchableFields,
		};

		const docRef = await db.collection("recipes").add(newRecipe);

		// If this is a save from a community recipe, track the save and increment saveCount
		if (originalRecipeId && originalRecipeId !== docRef.id) {
			try {
				const originalRecipeRef = db.collection("recipes").doc(originalRecipeId);
				const originalRecipeDoc = await originalRecipeRef.get();

				if (originalRecipeDoc.exists) {
					const originalRecipeData = originalRecipeDoc.data();
					
					// Only increment saveCount if:
					// 1. Original recipe is discoverable (community recipe)
					// 2. Original recipe belongs to a different user
					// 3. User hasn't already saved this recipe
					if (originalRecipeData.isDiscoverable && 
					    originalRecipeData.userId !== userId) {
						
						const saveRef = db.collection("recipeSaves").doc(`${originalRecipeId}_${userId}`);
						const saveDoc = await saveRef.get();

						if (!saveDoc.exists) {
							// Use a transaction to atomically increment saveCount
							let newSaveCount = 0;
							await db.runTransaction(async (transaction) => {
								const currentRecipe = await transaction.get(originalRecipeRef);
								if (!currentRecipe.exists) {
									throw new Error("Original recipe not found");
								}

								const currentSaveCount = currentRecipe.data().saveCount || 0;
								newSaveCount = currentSaveCount + 1;

								// Create save document
								transaction.set(saveRef, {
									recipeId: originalRecipeId,
									userId: userId,
									createdAt: FieldValue.serverTimestamp(),
								});

								// Increment saveCount
								transaction.update(originalRecipeRef, {
									saveCount: newSaveCount,
									updatedAt: FieldValue.serverTimestamp(),
								});
							});

							// Send milestone notification for saves
							checkAndSendMilestoneNotification(
								originalRecipeData.userId,
								originalRecipeId,
								originalRecipeData.title,
								'saves',
								newSaveCount
							);
						}
					}
				}
			} catch (error) {
				// Log error but don't fail the save operation
				console.error("Error tracking recipe save:", error);
			}
		}

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
		const newImageUrl = await searchImage(query, 1, false); // Don't use cache for refresh

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
        // Normalize hyphens to spaces in tags for consistent searching
		const searchableFields = [
            (req.body.title || recipeData.title).toLowerCase(),
			...(req.body.ingredients || recipeData.ingredients).map((i) =>
				i.toLowerCase()
			),
			...(req.body.tags || recipeData.tags).map((t) => t.toLowerCase().replace(/-/g, ' ')),
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

// Like or unlike a community recipe
router.post("/recipes/:id/like", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const recipeId = req.params.id;

		// Get the recipe
		const recipeRef = db.collection("recipes").doc(recipeId);
		const recipeDoc = await recipeRef.get();

		if (!recipeDoc.exists) {
			return res.status(404).json({ error: "Recipe not found" });
		}

		const recipeData = recipeDoc.data();

		// Only allow liking community recipes (isDiscoverable === true, not current user's)
		if (!recipeData.isDiscoverable || recipeData.userId === userId) {
			return res.status(403).json({ 
				error: "You can only like community recipes shared by other users" 
			});
		}

		// Check if user already liked this recipe
		const likeRef = db.collection("recipeLikes").doc(`${recipeId}_${userId}`);
		const likeDoc = await likeRef.get();
		const alreadyLiked = likeDoc.exists;

		// Use a transaction to atomically update like count
		await db.runTransaction(async (transaction) => {
			const currentRecipe = await transaction.get(recipeRef);
			if (!currentRecipe.exists) {
				throw new Error("Recipe not found");
			}

			const currentLikeCount = currentRecipe.data().likeCount || 0;

			if (alreadyLiked) {
				// Unlike: remove like document and decrement count
				transaction.delete(likeRef);
				transaction.update(recipeRef, {
					likeCount: Math.max(0, currentLikeCount - 1),
					updatedAt: FieldValue.serverTimestamp(),
				});
			} else {
				// Like: create like document and increment count
				transaction.set(likeRef, {
					recipeId: recipeId,
					userId: userId,
					createdAt: FieldValue.serverTimestamp(),
				});
				transaction.update(recipeRef, {
					likeCount: currentLikeCount + 1,
					updatedAt: FieldValue.serverTimestamp(),
				});
			}
		});

		// Get updated recipe data
		const updatedRecipeDoc = await recipeRef.get();
		const updatedRecipe = updatedRecipeDoc.data();

		// Send milestone notification if a new like was added
		if (!alreadyLiked) {
			checkAndSendMilestoneNotification(
				recipeData.userId,
				recipeId,
				recipeData.title,
				'likes',
				updatedRecipe.likeCount || 0
			);
		}

		res.json({
			success: true,
			liked: !alreadyLiked,
			likeCount: updatedRecipe.likeCount || 0,
		});
	} catch (error) {
		console.error("Error toggling like:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't update the like status right now. Please try again shortly."
		);
	}
});

// Track a share of a community recipe
router.post("/recipes/:id/share", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const recipeId = req.params.id;

		// Get the recipe
		const recipeRef = db.collection("recipes").doc(recipeId);
		const recipeDoc = await recipeRef.get();

		if (!recipeDoc.exists) {
			return res.status(404).json({ error: "Recipe not found" });
		}

		const recipeData = recipeDoc.data();

		// Only track shares for community recipes (isDiscoverable === true, not current user's)
		if (!recipeData.isDiscoverable || recipeData.userId === userId) {
			return res.status(403).json({ 
				error: "Share tracking is only for community recipes shared by other users" 
			});
		}

		// Increment share count (we don't track individual shares, just count)
		await recipeRef.update({
			shareCount: FieldValue.increment(1),
			updatedAt: FieldValue.serverTimestamp(),
		});

		// Get updated recipe data
		const updatedRecipeDoc = await recipeRef.get();
		const updatedRecipe = updatedRecipeDoc.data();

		// Send milestone notification for shares
		checkAndSendMilestoneNotification(
			recipeData.userId,
			recipeId,
			recipeData.title,
			'shares',
			updatedRecipe.shareCount || 0
		);

		res.json({
			success: true,
			shareCount: updatedRecipe.shareCount || 0,
		});
	} catch (error) {
		console.error("Error tracking share:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't track the share right now. Please try again shortly."
		);
	}
});

module.exports = router;
