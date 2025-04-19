const express = require("express");
const router = express.Router();
const axios = require("axios");
const { v4: uuidv4 } = require("uuid");
const OpenAI = require("openai");
const { z } = require("zod");
const { zodResponseFormat } = require("openai/helpers/zod");
const recipeData = require("../data/recipeData");
const client = new OpenAI({
	api_key: process.env.LlamaAI_API_KEY,
	base_url: process.env.LlamaAI_API_URL,
});

const recipeObjSchema = z.object({
	id: z.string(),
	title: z.string(),
	cuisineType: z.string(),
	description: z.string(),
	image: z.string(),
	ingredients: z.array(z.string()),
	instructions: z.array(z.string()),
	cookingTime: z.string(),
	difficulty: z.string(),
	servings: z.string(),
	tags: z.array(z.string()),
});

const recipesArrSchema = z.object({
	recipes: z.array(recipeObjSchema),
});

// In-memory recipes database
let recipes = [];

// Replace BING constants with GOOGLE
const GOOGLE_API_KEY = process.env.GOOGLE_API_KEY; // Add this to your .env file
const GOOGLE_CX = process.env.GOOGLE_CX; // Add Custom Search Engine ID
const GOOGLE_SEARCH_URL = "https://www.googleapis.com/customsearch/v1";

// Image cache
const imageCache = {};

let previousIngredients = [];

// Add recipe URL cache at the top with your other cache
const recipeCache = new Map();

// Add at the top with other caches
const aiResponseCache = new Map();
const CACHE_DURATION = 7 * 24 * 60 * 60 * 1000; // 7 days in milliseconds

// Add at the top with other constants
const MAX_CACHE_SIZE = 1000; // Maximum number of entries in each cache

// Function to fetch an image from Google with caching
const fetchImage = async (query) => {
	// Handle undefined or null query
	if (!query) {
		console.log("No query provided for image search");
		return null;
	}

	// Normalize the query by trimming and converting to lowercase
	const normalizedQuery = query.trim().toLowerCase();

	// Check if the image is already cached
	if (imageCache[normalizedQuery]) {
		return imageCache[normalizedQuery];
	}

	try {
		const response = await axios.get(GOOGLE_SEARCH_URL, {
			params: {
				key: GOOGLE_API_KEY,
				cx: GOOGLE_CX,
				q: `${normalizedQuery}`,
				searchType: "image",
				num: 1,
				safe: "active",
			},
		});

		// Check if images exist in response
		if (!response.data.items || response.data.items.length === 0) {
			console.log("No images found for query:", normalizedQuery);
			return null;
		}

		const imageUrl = response.data.items[0].link;

		imageCache[normalizedQuery] = imageUrl;
		return imageUrl;
	} catch (error) {
		console.error("Error fetching image from Google:", error);
		return null;
	}
};

// Function to get a random ingredient
const getRandomIngredient = async () => {
	const availableIngredients = await recipeData.ingredients.filter(
		(ingredient) => !previousIngredients.includes(ingredient)
	);
	if (availableIngredients.length === 0) {
		// Reset previous ingredients if all have been used
		previousIngredients = [];
		return getRandomIngredient(); // Retry
	}
	const randomIndex = Math.floor(Math.random() * availableIngredients.length);
	const selectedIngredient = await availableIngredients[randomIndex];
	previousIngredients.push(selectedIngredient);

	return selectedIngredient;
};

const randomIngredient = async () => await getRandomIngredient();

// POST /recipes/generate - AI-generated recipe creation
router.post("/generate", async (req, res) => {
	let {
		ingredients = [],
		dietaryRestrictions = [],
		cuisineType = "",
		autoFill = false,
		random = false,
	} = req.body;

	try {
		// Check AI cache first
		const cacheKey = JSON.stringify({
			ingredients,
			dietaryRestrictions,
			cuisineType,
			autoFill,
			random,
		});

		const cachedResponse = aiResponseCache.get(cacheKey);
		if (
			cachedResponse &&
			Date.now() - cachedResponse.timestamp < CACHE_DURATION
		) {
			console.log("Recipe found in AI cache");
			return res.json(cachedResponse.data);
		}

		if (!ingredients.length && !cuisineType) {
			random = true;
		}

		let recipesData = [];

		if (!autoFill) {
			const response = await client.beta.chat.completions.parse({
				model: "gpt-4o-mini",
				messages: [
					{
						role: "user",
						content: `Generate three recipes that include the following:
							- Ingredients: ${random ? await randomIngredient() : ingredients}
							- Dietary restrictions: ${dietaryRestrictions}
							- Cuisine type: ${cuisineType}
							- Include cooking time, difficulty level, and number of servings
							- Additional ingredients if needed
						`,
					},
				],
				response_format: zodResponseFormat(recipesArrSchema, "recipes"),
			});

			recipesData = response.choices[0].message.parsed.recipes;
		} else {
			const response = await client.beta.chat.completions.parse({
				model: "gpt-4o-mini",
				messages: [
					{
						role: "user",
						content: `Complete this recipe with any missing details except for imageUrl: ${JSON.stringify(
							req.body
						)}`,
					},
				],
				response_format: zodResponseFormat(recipeObjSchema, "recipe"),
			});

			recipesData = [response.choices[0].message.parsed];
		}

		const generatedRecipes = await Promise.all(
			(Array.isArray(recipesData) ? recipesData : [recipesData]).map(
				async (recipeData) => ({
					id: uuidv4(),
					title: recipeData.title || "Generated Recipe",
					cuisineType: recipeData.cuisineType || cuisineType,
					description: recipeData.description || "Enjoy your generated recipe!",
					ingredients: Array.isArray(recipeData.ingredients)
						? recipeData.ingredients
						: [],
					instructions: Array.isArray(recipeData.instructions)
						? recipeData.instructions
						: [],
					imageUrl:
						typeof recipeData.image === "object"
							? recipeData.image.url
							: await fetchImage(recipeData.title),
					cookingTime: recipeData.cookingTime || "30 minutes",
					difficulty: recipeData.difficulty || "medium",
					servings: recipeData.servings || "4",

					tags: recipeData.tags || [],
				})
			)
		);

		// Cache the AI response
		aiResponseCache.set(cacheKey, {
			data: generatedRecipes,
			timestamp: Date.now(),
		});

		recipes.push(...generatedRecipes);
		res.json(generatedRecipes);
	} catch (error) {
		console.error("Error generating recipes:", error);
		res.status(500).json({ error: "Failed to generate recipes" });
	}
});

// Simplified import endpoint
router.post("/import", async (req, res) => {
	const { url } = req.body;

	try {
		// Check recipe cache first
		if (recipeCache.has(url)) {
			console.log("Recipe found in cache");
			return res.json(recipeCache.get(url));
		}

		const textUrl = `https://textfrom.website/${url}`;
		const { data: pageText } = await axios.get(textUrl);

		// Check AI cache for this text content
		const textCacheKey = pageText.slice(0, 100); // Use first 100 chars as key
		const cachedAIResponse = aiResponseCache.get(textCacheKey);
		if (
			cachedAIResponse &&
			Date.now() - cachedAIResponse.timestamp < CACHE_DURATION
		) {
			console.log("Recipe parsing found in AI cache");
			const importedRecipe = {
				...cachedAIResponse.data,
				id: uuidv4(),
				imageUrl: await fetchImage(cachedAIResponse.data.title || "recipe"),
				sourceUrl: url,
			};
			recipeCache.set(url, importedRecipe);
			return res.json(importedRecipe);
		}

		// Parse recipe data using AI
		const response = await client.beta.chat.completions.parse({
			model: "gpt-4o-mini",
			messages: [
				{
					role: "system",
					content:
						"Extract recipe details from this text. Return title, ingredients (array), instructions (array), description, and tags (array).",
				},
				{
					role: "user",
					content: pageText,
				},
			],
			response_format: zodResponseFormat(recipeObjSchema, "recipe"),
		});

		const recipeData = response.choices[0].message.parsed;
		if (!recipeData) {
			throw new Error("Unable to parse recipe from URL");
		}

		// Cache the AI parsing result
		aiResponseCache.set(textCacheKey, {
			data: recipeData,
			timestamp: Date.now(),
		});

		// Format and cache recipe
		const importedRecipe = {
			id: uuidv4(),
			title: recipeData.title || "Imported Recipe",
			ingredients: Array.isArray(recipeData.ingredients)
				? recipeData.ingredients
				: [],
			instructions: Array.isArray(recipeData.instructions)
				? recipeData.instructions
				: [],
			description: recipeData.description || "Imported recipe",
			imageUrl: await fetchImage(recipeData.title || "recipe"),
			cookingTime: recipeData.cookingTime || "30 minutes",
			difficulty: recipeData.difficulty || "medium",
			servings: recipeData.servings || "4",
			source: url,
			tags: recipeData.tags || [],
		};

		recipeCache.set(url, importedRecipe);
		recipes.push(importedRecipe);

		res.json(importedRecipe);
	} catch (error) {
		console.error("Error importing recipe:", error);
		res.status(500).json({
			error: "Failed to import recipe",
			details: error.message,
		});
	}
});

// Optional: Add cache management endpoints
router.post("/cache/clear", (req, res) => {
	recipeCache.clear();
	imageCache = {};
	aiResponseCache.clear();
	res.json({ message: "Cache cleared successfully" });
});

// Update the cleanup function
const cleanupCaches = () => {
	const now = Date.now();

	// Clean up by age
	for (const [key, value] of aiResponseCache.entries()) {
		if (now - value.timestamp > CACHE_DURATION) {
			aiResponseCache.delete(key);
		}
	}

	// Clean up by size
	if (aiResponseCache.size > MAX_CACHE_SIZE) {
		// Convert to array to sort by timestamp
		const entries = Array.from(aiResponseCache.entries());
		entries.sort((a, b) => a[1].timestamp - b[1].timestamp);

		// Delete oldest entries until we're under the limit
		while (aiResponseCache.size > MAX_CACHE_SIZE) {
			const [oldestKey] = entries.shift();
			aiResponseCache.delete(oldestKey);
		}
	}

	// Do the same for recipe cache
	if (recipeCache.size > MAX_CACHE_SIZE) {
		const entries = Array.from(recipeCache.entries());
		entries.sort((a, b) => a[1].timestamp - b[1].timestamp);
		while (recipeCache.size > MAX_CACHE_SIZE) {
			const [oldestKey] = entries.shift();
			recipeCache.delete(oldestKey);
		}
	}

	// Clean up image cache
	const imageEntries = Object.entries(imageCache);
	if (imageEntries.length > MAX_CACHE_SIZE) {
		const newImageCache = {};
		imageEntries
			.slice(-MAX_CACHE_SIZE) // Keep most recent entries
			.forEach(([key, value]) => {
				newImageCache[key] = value;
			});
		imageCache = newImageCache;
	}
};

// Run cleanup more frequently
setInterval(cleanupCaches, 6 * 60 * 60 * 1000); // Every 6 hours

router.get("/cache/status", (req, res) => {
	res.json({
		aiCache: {
			size: aiResponseCache.size,
			maxSize: MAX_CACHE_SIZE,
		},
		recipeCache: {
			size: recipeCache.size,
			maxSize: MAX_CACHE_SIZE,
		},
		imageCache: {
			size: Object.keys(imageCache).length,
			maxSize: MAX_CACHE_SIZE,
		},
	});
});

module.exports = router;
