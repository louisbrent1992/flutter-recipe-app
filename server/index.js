/**
 * Recipe App Server
 *
 * Main server entrypoint that configures Express and registers routes
 */

const express = require("express");
const cors = require("cors");
require("dotenv").config();
const errorHandler = require("./utils/errorHandler");
const cron = require("node-cron");
const axios = require("axios");
const admin = require("firebase-admin");

// Initialize Firebase
require("./config/firebase").initFirebase();

// Import routes
const aiRoutes = require("./routes/generatedRecipes");
const discoverRoutes = require("./routes/discover");
const userRoutes = require("./routes/users");
const authRoutes = require("./middleware/auth");
const collectionRoutes = require("./routes/collections");

const app = express();
const port = process.env.PORT || 3001;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cors());

// Add request logger in development
if (process.env.NODE_ENV !== "production") {
	app.use((req, res, next) => {
		console.log(`${req.method} ${req.url}`);
		next();
	});
}

// API Routes with clean naming structure
app.use("/api/ai/recipes", aiRoutes);
app.use("/api/discover", discoverRoutes);
app.use("/api/users", userRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/collections", collectionRoutes);

// Health check endpoint
app.get("/health", (req, res) => {
	res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// 404 handler for undefined routes
app.use((req, res) => {
	errorHandler.notFound(res, `Route not found: ${req.method} ${req.url}`);
});

// Global error handler
app.use(errorHandler.globalHandler);

// Schedule a daily job to fetch recipes from Spoonacular
cron.schedule("40 20 * * *", async () => {
	console.log("Running scheduled recipe fetch job...");
	try {
		const db = admin.firestore();
		const recipesRef = db.collection("recipes");
		let offset = 0;
		const limit = 100; // Maximum allowed for random recipes endpoint
		let totalFetched = 0;
		let totalSaved = 0;
		let totalPointsUsed = 0;
		const maxPoints = 150; // Daily quota limit

		while (totalPointsUsed < maxPoints) {
			const params = {
				apiKey: process.env.SPOONACULAR_API_KEY,
				number: limit,
				instructionsRequired: true,
				fillIngredients: true,
				addRecipeInformation: true,
			};

			console.log("Fetching random recipes...");
			const response = await axios.get(
				"https://api.spoonacular.com/recipes/random",
				{ params }
			);
			if (
				!response.data ||
				!response.data.recipes ||
				response.data.recipes.length === 0
			)
				break;

			// Extract quota information from headers
			const pointsUsed = parseInt(response.headers["x-api-quota-used"] || "0");
			const pointsRemaining = parseInt(
				response.headers["x-api-quota-left"] || "0"
			);

			totalPointsUsed += pointsUsed;
			console.log(
				`API call used ${pointsUsed} points. ${pointsRemaining} points remaining.`
			);

			if (totalPointsUsed >= maxPoints || pointsRemaining <= 0) {
				console.log(
					`Stopping recipe fetch: Reached quota limit (${totalPointsUsed}/${maxPoints} points used)`
				);
				break;
			}

			const recipes = response.data.recipes.map((recipe) => ({
				id: recipe.id.toString(),
				title: recipe.title || "",
				description: recipe.summary || "",
				ingredients: (recipe.extendedIngredients || []).map((ing) => ({
					name: ing.name || "",
					amount: ing.amount || 0,
					unit: ing.unit || "",
				})),
				instructions: (recipe.analyzedInstructions?.[0]?.steps || []).map(
					(step) => step.step || ""
				),
				cookingTime: recipe.readyInMinutes || "Not Specified",
				servings: recipe.servings || 1,
				difficulty:
					recipe.readyInMinutes <= 30
						? "Easy"
						: recipe.readyInMinutes <= 60
						? "Medium"
						: "Hard",
				tags: recipe.dishTypes || [],
				imageUrl: recipe.image || "",
				sourceUrl: recipe.sourceUrl || "",
				createdAt: new Date().toISOString(),
				updatedAt: new Date().toISOString(),
				isExternal: true,
				externalId: recipe.id.toString(),
			}));

			// Check which recipes already exist
			const recipesToSave = [];

			// Process recipes in smaller chunks to avoid hitting Firestore limits
			for (let i = 0; i < recipes.length; i++) {
				const recipe = recipes[i];
				const docRef = recipesRef.doc(recipe.id);
				const doc = await docRef.get();

				if (!doc.exists) {
					recipesToSave.push(recipe);
				} else {
					// Optionally update certain fields if needed
					// For now, we're skipping existing recipes
				}
			}

			// Save recipes in batches of 20
			for (let i = 0; i < recipesToSave.length; i += 20) {
				const batch = db.batch(); // Create a new batch for each group
				const chunk = recipesToSave.slice(i, i + 20);

				chunk.forEach((recipe) => {
					const docRef = recipesRef.doc(recipe.id);
					batch.set(docRef, recipe);
				});

				await batch.commit();
			}

			totalSaved += recipesToSave.length;
			totalFetched += recipes.length;
			offset += limit;

			if (response.data.recipes.length < limit) break;
		}

		console.log(
			`Fetched ${totalFetched} recipes. Saved ${totalSaved} new recipes. Points used: ${totalPointsUsed}`
		);
	} catch (error) {
		console.error("Error in scheduled recipe fetch job:", error);
	}
});

// Start server
app.listen(port, () => {
	console.log(`🚀 Server running on port ${port}`);
	console.log(`🔗 API available at http://localhost:${port}/api`);
});
