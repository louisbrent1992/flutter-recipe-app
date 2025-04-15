const express = require("express");
const router = express.Router();
const { admin, db } = require("../config/firebase");

// Middleware to verify Firebase token
const authenticateUser = async (req, res, next) => {
	try {
		const authHeader = req.headers.authorization;
		if (!authHeader) {
			return res.status(401).json({ error: "No authorization header" });
		}

		const token = authHeader.split("Bearer ")[1];
		const decodedToken = await admin.auth().verifyIdToken(token);
		req.user = decodedToken;
		next();
	} catch (error) {
		console.error("Authentication error:", error);
		res.status(401).json({ error: "Invalid token" });
	}
};

// Get user profile
router.get("/profile", authenticateUser, async (req, res) => {
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
router.put("/profile", authenticateUser, async (req, res) => {
	try {
		const { displayName, email } = req.body;
		await db.collection("users").doc(req.user.uid).update({
			displayName,
			email,
			updatedAt: admin.firestore.FieldValue.serverTimestamp(),
		});
		res.json({ message: "Profile updated successfully" });
	} catch (error) {
		console.error("Error updating user profile:", error);
		res.status(500).json({ error: "Internal server error" });
	}
});

// Get user's favorite recipes
router.get("/favorites", authenticateUser, async (req, res) => {
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
router.post("/favorites", authenticateUser, async (req, res) => {
	try {
		const { recipeId } = req.body;
		await db
			.collection("favorites")
			.doc(req.user.uid)
			.set(
				{
					recipes: admin.firestore.FieldValue.arrayUnion(recipeId),
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
router.delete("/favorites/:recipeId", authenticateUser, async (req, res) => {
	try {
		const { recipeId } = req.params;
		await db
			.collection("favorites")
			.doc(req.user.uid)
			.update({
				recipes: admin.firestore.FieldValue.arrayRemove(recipeId),
			});
		res.json({ message: "Recipe removed from favorites" });
	} catch (error) {
		console.error("Error removing from favorites:", error);
		res.status(500).json({ error: "Internal server error" });
	}
});

module.exports = router;
