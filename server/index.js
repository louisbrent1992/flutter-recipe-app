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

// Simple in-memory cache for performance
const cache = new Map();
const CACHE_TTL = 5 * 60 * 1000; // 5 minutes

// Cache middleware
const cacheMiddleware = (duration = CACHE_TTL) => {
	return (req, res, next) => {
		const key = `${req.method}:${req.originalUrl}`;
		const cached = cache.get(key);

		if (cached && Date.now() - cached.timestamp < duration) {
			return res.json(cached.data);
		}

		// Store original send method
		const originalSend = res.json;

		// Override send method to cache response
		res.json = function (data) {
			cache.set(key, {
				data,
				timestamp: Date.now(),
			});

			// Clean up old cache entries
			const now = Date.now();
			for (const [cacheKey, value] of cache.entries()) {
				if (now - value.timestamp > CACHE_TTL) {
					cache.delete(cacheKey);
				}
			}

			originalSend.call(this, data);
		};

		next();
	};
};

// Import routes
const aiRoutes = require("./routes/generatedRecipes");
const discoverRoutes = require("./routes/discover");
const userRoutes = require("./routes/users");
const authRoutes = require("./middleware/auth");
const collectionRoutes = require("./routes/collections");
const dataDeletionRoutes = require("./routes/data-deletion");
const uiRoutes = require("./routes/ui");

const app = express();
const port = process.env.PORT || 8080;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cors());

// Timeout middleware removed to prevent conflicts with long-running operations

// Trust proxy for rate limiting and IP detection (needed for data deletion)
app.set("trust proxy", 1);

// Serve static files from public directory (for data deletion page)
app.use(express.static(require("path").join(__dirname, "public")));

// Add request logger in development
if (process.env.NODE_ENV !== "production") {
	app.use((req, res, next) => {
		console.log(`${req.method} ${req.url}`);
		next();
	});
}

// API Routes with clean naming structure
app.use("/api/ai/recipes", aiRoutes);
app.use("/api/discover", cacheMiddleware(2 * 60 * 1000), discoverRoutes); // Cache discover routes for 2 minutes
app.use("/api/users", userRoutes);
app.use("/api/auth", authRoutes);
app.use("/api/collections", collectionRoutes);
app.use("/api", dataDeletionRoutes);
app.use("/api", uiRoutes);

// Server homepage
app.get("/", (req, res) => {
	res.sendFile(require("path").join(__dirname, "public", "index.html"));
});

// Serve the data deletion page (for Google Play Console compliance)
app.get("/data-deletion", (req, res) => {
	res.sendFile(require("path").join(__dirname, "public", "data-deletion.html"));
});

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

// Schedule a weekly job to fetch recipes from Spoonacular
// Runs every Sunday at 11:59 PM
cron.schedule("59 23 * * 0", async () => {
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

			const recipes = response.data.recipes.map((recipe) => {
				// Generate searchable fields
				const searchableFields = [
					// Split title into words
					...(recipe.title ? recipe.title.toLowerCase().split(/\s+/) : []),
					// Split summary into words
					...(recipe.summary ? recipe.summary.toLowerCase().split(/\s+/) : []),
					// Split ingredient names into words
					...(recipe.extendedIngredients || []).reduce((acc, ing) => {
						if (ing?.name) {
							acc.push(...ing.name.toLowerCase().split(/\s+/));
						}
						return acc;
					}, []),
					// Split instruction steps into words
					...(recipe.analyzedInstructions?.[0]?.steps || []).reduce(
						(acc, step) => {
							if (step?.step) {
								acc.push(...step.step.toLowerCase().split(/\s+/));
							}
							return acc;
						},
						[]
					),
					// Split dish types into words
					...(recipe.dishTypes || []).reduce((acc, tag) => {
						if (tag) {
							acc.push(...tag.toLowerCase().split(/\s+/));
						}
						return acc;
					}, []),
					// Add difficulty level
					(recipe.readyInMinutes <= 30
						? "Easy"
						: recipe.readyInMinutes <= 60
						? "Medium"
						: "Hard"
					).toLowerCase(),
				].filter((field) => field && field.length > 0);

				return {
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
					// Store canonical Firestore timestamps for consistent querying
					createdAt: admin.firestore.FieldValue.serverTimestamp(),
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
					isExternal: true,
					externalId: recipe.id.toString(),
					searchableFields,
				};
			});

			// Check which recipes already exist
			const recipesToSave = [];

			// Process recipes in smaller chunks to avoid hitting Firestore limits
			for (let i = 0; i < recipes.length; i++) {
				const recipe = recipes[i];

				// Check for existing recipe by ID
				const docRef = recipesRef.doc(recipe.id);
				const doc = await docRef.get();

				if (!doc.exists) {
					// Also check for duplicates by title only (description can be too large for Firestore queries)
					const duplicateQuery = await recipesRef
						.where("title", "==", recipe.title)
						.limit(1)
						.get();

					if (duplicateQuery.empty) {
						recipesToSave.push(recipe);
					} else {
						console.log(`Skipping duplicate recipe: ${recipe.title}`);
					}
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

// Schedule automatic duplicate recipe cleanup
// Runs weekly on Monday at 2:00 AM (when traffic is typically lower)
cron.schedule("0 2 * * 1", async () => {
	console.log("🔄 Running scheduled duplicate recipe cleanup...");
	try {
		const { cleanupDuplicates } = require("./routes/discover");
		await cleanupDuplicates();
	} catch (error) {
		console.error("❌ Error in scheduled duplicate cleanup job:", error);
	}
});

// Start server
app.listen(port, () => {
	console.log(`🚀 Server running on port ${port}`);
	console.log(`🔗 API available at http://localhost:${port}/api`);
});
