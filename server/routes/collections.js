const express = require("express");
const router = express.Router();
const { getFirestore } = require("firebase-admin/firestore");
const auth = require("../middleware/auth");

// Get Firestore database instance
const db = getFirestore();

/**
 * @route   GET /collections
 * @desc    Get all collections for a user
 * @access  Private
 */
router.get("/", auth, async (req, res) => {
	try {
		const userId = req.user.uid;

		// Get collections from Firestore
		const collectionsRef = db
			.collection("users")
			.doc(userId)
			.collection("collections");
		const snapshot = await collectionsRef.get();

		// Transform snapshot into array of collections
		const collections = [];
		snapshot.forEach((doc) => {
			collections.push({
				id: doc.id,
				...doc.data(),
			});
		});

		res.json(collections);
	} catch (error) {
		console.error("Error getting collections:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't load your collections right now. Please try again shortly."
		);
	}
});

/**
 * @route   GET /collections/:id
 * @desc    Get a specific collection by ID
 * @access  Private
 */
router.get("/:id", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const collectionId = req.params.id;

		const collectionDoc = await db
			.collection("users")
			.doc(userId)
			.collection("collections")
			.doc(collectionId)
			.get();

		if (!collectionDoc.exists) {
			return res.status(404).json({ error: "Collection not found" });
		}

		res.json({
			id: collectionDoc.id,
			...collectionDoc.data(),
		});
	} catch (error) {
		console.error("Error getting collection:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't load that collection right now. Please try again shortly."
		);
	}
});

/**
 * @route   POST /collections
 * @desc    Create a new collection
 * @access  Private
 */
router.post("/", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const { name, color, icon, recipes = [] } = req.body;

		if (!name) {
			return res.status(400).json({ error: "Collection name is required" });
		}

		// Create new collection document
		const newCollection = {
			name,
			color,
			recipes,
			createdAt: new Date().toISOString(),
			updatedAt: new Date().toISOString(),
		};

		// Only add icon if it's a valid object
		if (icon && typeof icon === "object" && icon.codePoint) {
			newCollection.icon = {
				codePoint: icon.codePoint,
				fontFamily: icon.fontFamily || null,
				fontPackage: icon.fontPackage || null,
			};
		}

		// Save to Firestore
		const docRef = await db
			.collection("users")
			.doc(userId)
			.collection("collections")
			.add(newCollection);

		// Return the created collection with ID
		res.status(201).json({
			id: docRef.id,
			...newCollection,
		});
	} catch (error) {
		console.error("Error creating collection:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't create the collection right now. Please try again shortly."
		);
	}
});

/**
 * @route   PUT /collections/:id
 * @desc    Update a collection
 * @access  Private
 */
router.put("/:id", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const collectionId = req.params.id;
		const { name, color, icon, recipes } = req.body;

		// Get existing collection to verify ownership
		const collectionRef = db
			.collection("users")
			.doc(userId)
			.collection("collections")
			.doc(collectionId);
		const collectionDoc = await collectionRef.get();

		if (!collectionDoc.exists) {
			return res.status(404).json({ error: "Collection not found" });
		}

		// Build update object with only provided fields
		const updateData = {
			updatedAt: new Date().toISOString(),
		};

		if (name !== undefined) updateData.name = name;
		if (color !== undefined) updateData.color = color;
		if (recipes !== undefined) updateData.recipes = recipes;

		// Only update icon if it's a valid object
		if (icon && typeof icon === "object" && icon.codePoint) {
			updateData.icon = {
				codePoint: icon.codePoint,
				fontFamily: icon.fontFamily || null,
				fontPackage: icon.fontPackage || null,
			};
		}

		// Update the collection
		await collectionRef.update(updateData);

		// Get the updated collection
		const updatedDoc = await collectionRef.get();

		res.json({
			id: updatedDoc.id,
			...updatedDoc.data(),
		});
	} catch (error) {
		console.error("Error updating collection:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't update the collection right now. Please try again shortly."
		);
	}
});

/**
 * @route   DELETE /collections/:id
 * @desc    Delete a collection
 * @access  Private
 */
router.delete("/:id", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const collectionId = req.params.id;

		// Get collection to verify ownership
		const collectionRef = db
			.collection("users")
			.doc(userId)
			.collection("collections")
			.doc(collectionId);
		const collectionDoc = await collectionRef.get();

		if (!collectionDoc.exists) {
			return res.status(404).json({ error: "Collection not found" });
		}

		// Delete the collection
		await collectionRef.delete();

		res.json({ message: "Collection deleted successfully" });
	} catch (error) {
		console.error("Error deleting collection:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't delete the collection right now. Please try again shortly."
		);
	}
});

/**
 * @route   POST /collections/:id/recipes
 * @desc    Add a recipe to a collection
 * @access  Private
 */
router.post("/:id/recipes", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const collectionId = req.params.id;
		const { recipe } = req.body;

		if (!recipe) {
			return res.status(400).json({ error: "Recipe data is required" });
		}

		// Get collection to verify ownership
		const collectionRef = db
			.collection("users")
			.doc(userId)
			.collection("collections")
			.doc(collectionId);
		const collectionDoc = await collectionRef.get();

		if (!collectionDoc.exists) {
			return res.status(404).json({ error: "Collection not found" });
		}

		const collectionData = collectionDoc.data();
		const recipes = collectionData.recipes || [];

		// Check if recipe already exists in collection
		if (recipes.some((r) => r.id === recipe.id)) {
			return res.status(400).json({ error: "Recipe already in collection" });
		}

		// Add recipe to collection
		recipes.push(recipe);

		// Update collection
		await collectionRef.update({
			recipes,
			updatedAt: new Date().toISOString(),
		});

		res.json({ message: "Recipe added to collection successfully" });
	} catch (error) {
		console.error("Error adding recipe to collection:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't add that recipe to the collection right now. Please try again shortly."
		);
	}
});

/**
 * @route   DELETE /collections/:id/recipes/:recipeId
 * @desc    Remove a recipe from a collection
 * @access  Private
 */
router.delete("/:id/recipes/:recipeId", auth, async (req, res) => {
	try {
		const userId = req.user.uid;
		const collectionId = req.params.id;
		const recipeId = req.params.recipeId;

		// Get collection to verify ownership
		const collectionRef = db
			.collection("users")
			.doc(userId)
			.collection("collections")
			.doc(collectionId);
		const collectionDoc = await collectionRef.get();

		if (!collectionDoc.exists) {
			return res.status(404).json({ error: "Collection not found" });
		}

		const collectionData = collectionDoc.data();
		const recipes = collectionData.recipes || [];

		// Remove recipe from collection
		const updatedRecipes = recipes.filter((r) => r.id !== recipeId);

		// Update collection
		await collectionRef.update({
			recipes: updatedRecipes,
			updatedAt: new Date().toISOString(),
		});

		res.json({ message: "Recipe removed from collection successfully" });
	} catch (error) {
		console.error("Error removing recipe from collection:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't remove that recipe from the collection right now. Please try again shortly."
		);
	}
});

module.exports = router;
