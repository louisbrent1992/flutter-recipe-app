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

// Get user's recipes
router.get("/recipes", auth, async (req, res) => {
	try {
		const recipesDoc = await db.collection("recipes").doc(req.user.uid).get();
		if (!recipesDoc.exists) {
			return res.json([]);
		}
		res.json(recipesDoc.data().recipes || []);
	} catch (error) {
		console.error("Error fetching user recipes:", error);
	}
});

// Add recipe to user's recipes
router.post("/recipes", auth, async (req, res) => {
	try {
		const { recipeId } = req.body;
		await db
			.collection("recipes")
			.doc(req.user.uid)
			.update({
				recipes: db.FieldValue.arrayUnion(recipeId),
				updatedAt: new Date().toISOString(),
			});
		res.json({ message: "Recipe added to user's recipes" });
	} catch (error) {
		console.error("Error adding recipe to user's recipes:", error);
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
