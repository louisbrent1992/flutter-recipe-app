const express = require("express");
const router = express.Router();
const axios = require("axios");
const { v4: uuidv4 } = require("uuid");
const OpenAI = require("openai");
const { z } = require("zod");
const { zodResponseFormat } = require("openai/helpers/zod");
const recipeData = require("../data/recipeData");
const { getInstagramMediaFromUrl } = require("../utils/instagramAPI");
const { getTikTokVideoFromUrl } = require("../utils/tiktokAPI");
const { getYouTubeVideoFromUrl } = require("../utils/youtubeAPI");

const client = new OpenAI({
	api_key: process.env.LlamaAI_API_KEY,
	base_url: process.env.LlamaAI_API_URL,
});

const nutritionSchema = z.object({
	calories: z.string().optional(),
	protein: z.string().optional(),
	carbs: z.string().optional(),
	fat: z.string().optional(),
	fiber: z.string().optional(),
	sugar: z.string().optional(),
	sodium: z.string().optional(),
	iron: z.string().optional(),
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
	nutrition: nutritionSchema.optional(),
});

const recipesArrSchema = z.object({
	recipes: z.array(recipeObjSchema),
});

// In-memory recipes database (for AI-generated recipes that haven't been saved yet)
let tempRecipes = [];

// Replace BING constants with GOOGLE
const GOOGLE_API_KEY = process.env.GOOGLE_API_KEY; // Add this to your .env file
const GOOGLE_CX = process.env.GOOGLE_CX; // Add Custom Search Engine ID
const GOOGLE_SEARCH_URL = "https://www.googleapis.com/customsearch/v1";

// Image cache
const imageCache = {};

let previousIngredients = [];

// AI response cache
const aiResponseCache = new Map();
const recipeCache = new Map();

// Cache duration constants (in milliseconds)
const CACHE_DURATIONS = {
	SOCIAL_MEDIA: 24 * 60 * 60 * 1000, // 24 hours for social media data
	AI_GENERATED: 7 * 24 * 60 * 60 * 1000, // 7 days for AI generations
	IMAGES: 30 * 24 * 60 * 60 * 1000, // 30 days for images
	RECIPES: 7 * 24 * 60 * 60 * 1000, // 7 days for recipes
};

// Maximum entries to process per cleanup cycle
const MAX_ENTRIES_PER_CLEANUP = 100;

// Maximum cache size
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

// POST /ai/recipes/generate - AI-generated recipe creation
router.post("/generate", async (req, res) => {
	let {
		ingredients = [],
		dietaryRestrictions = [],
		cuisineType = "",
		random = false,
	} = req.body;

	console.log("Generating recipes with:", {
		ingredients,
		dietaryRestrictions,
		cuisineType,
		random,
	});

	try {
		if (!ingredients.length && !cuisineType) {
			random = true;
		}

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
                        - Provide approximate nutrition per serving as fields: calories (number, no unit), protein (g), carbs (g), fat (g), fiber (g), sugar (g), sodium (mg), iron (% DV numeric only)
					`,
				},
			],
			response_format: zodResponseFormat(recipesArrSchema, "recipes"),
		});

		const recipesData = response.choices[0].message.parsed.recipes;

		const generatedRecipes = await Promise.all(
			recipesData.map(async (recipeData) => ({
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
				nutrition: recipeData.nutrition || null,
				aiGenerated: true,
				createdAt: new Date().toISOString(),
			}))
		);

		tempRecipes.push(...generatedRecipes);
		res.json(generatedRecipes);
	} catch (error) {
		console.error("Error generating recipes:", error);
		res.status(500).json({ error: "Failed to generate recipes" });
	}
});

// Helper functions for cache management
const getCacheKey = (type, data) => `${type}_${JSON.stringify(data)}`;

const handleCache = (cache, key, data, timestamp = Date.now()) => {
	if (data) {
		cache.set(key, { data, timestamp });
	}
	return data;
};

const getFromCache = (cache, key, maxAge = CACHE_DURATIONS.AI_GENERATED) => {
	const cached = cache.get(key);
	if (cached && Date.now() - cached.timestamp < maxAge) {
		return cached.data;
	}
	return null;
};

// Helper function for social media processing
const processSocialMedia = async (url, type, getDataFn) => {
	const cacheKey = `${type}_${url}`;
	let socialData = getFromCache(
		recipeCache,
		cacheKey,
		CACHE_DURATIONS.SOCIAL_MEDIA
	);

	if (!socialData) {
		try {
			console.log(`Processing ${type} URL:`, url);
			socialData = await getDataFn(url);
			handleCache(recipeCache, cacheKey, socialData);
		} catch (error) {
			console.error(`Error processing ${type} URL:`, error);
			throw new Error(`Failed to process ${type} URL`);
		}
	} else {
		console.log(`${type} data found in cache`);
	}

	return socialData;
};

// Helper function to extract site name from URL
const extractSiteName = (url) => {
	try {
		const urlObj = new URL(url);
		const hostname = urlObj.hostname;
		// Remove www. prefix and get the main domain
		const siteName = hostname.replace(/^www\./, "").split(".")[0];
		// Capitalize first letter
		return siteName.charAt(0).toUpperCase() + siteName.slice(1);
	} catch (error) {
		return "Web";
	}
};

// Helper function for recipe data processing
const processRecipeData = async (
	recipeData,
	socialData,
	url,
	isInstagram,
	isTikTok,
	isYouTube
) => {
	const contentKey = getCacheKey("content", recipeData.slice(0, 100));
	const cachedRecipe = getFromCache(aiResponseCache, contentKey);

	if (cachedRecipe) {
		console.log("Recipe parsing found in AI cache");
		return {
			...cachedRecipe,
			id: uuidv4(),
			imageUrl:
				socialData?.imageUrl ||
				socialData?.coverUrl ||
				socialData?.thumbnailUrl ||
				(await fetchImage(cachedRecipe.title || "recipe")),
			sourceUrl: url,
			sourcePlatform: isInstagram
				? "instagram"
				: isTikTok
				? "tiktok"
				: isYouTube
				? "youtube"
				: "web",
			author:
				socialData?.username ||
				socialData?.author?.username ||
				socialData?.channelTitle,
			createdAt: new Date().toISOString(),
		};
	}

	// Process new recipe data
	const response = await client.beta.chat.completions.parse({
		model: "gpt-4o-mini",
		messages: [
			{
				role: "system",
				content:
					isInstagram || isTikTok || isYouTube
						? "Extract recipe details from this social media post. Return title, ingredients (array), instructions (array), description, tags (array), and approximate nutrition per serving. Use these fields: calories (number, no unit), protein (g), carbs (g), fat (g), fiber (g), sugar (g), sodium (mg), iron (percent DV numeric only). Fill in any missing recipe details."
						: "Extract recipe details from this text. Return title, ingredients (array), instructions (array), description, tags (array), and approximate nutrition per serving. Use these fields: calories (number, no unit), protein (g), carbs (g), fat (g), fiber (g), sugar (g), sodium (mg), iron (percent DV numeric only). Fill in any missing recipe details.",
			},
			{
				role: "user",
				content: recipeData,
			},
		],
		response_format: zodResponseFormat(recipeObjSchema, "recipe"),
	});

	const parsedRecipe = response.choices[0].message.parsed;
	if (!parsedRecipe) {
		throw new Error("Unable to parse recipe from URL");
	}

	handleCache(aiResponseCache, contentKey, parsedRecipe);

	return {
		id: uuidv4(),
		title: parsedRecipe.title || "Imported Recipe",
		ingredients: Array.isArray(parsedRecipe.ingredients)
			? parsedRecipe.ingredients
			: [],
		instructions: Array.isArray(parsedRecipe.instructions)
			? parsedRecipe.instructions
			: [],
		description: parsedRecipe.description || "Imported recipe",
		imageUrl:
			socialData?.imageUrl ||
			socialData?.coverUrl ||
			socialData?.thumbnailUrl ||
			(await fetchImage(parsedRecipe.title || "recipe")),
		cookingTime: parsedRecipe.cookingTime || "30 minutes",
		difficulty: parsedRecipe.difficulty || "medium",
		servings: parsedRecipe.servings || "4",
		source: isInstagram
			? `Instagram: @${socialData?.username}`
			: isTikTok
			? `TikTok: @${socialData?.author?.username}`
			: isYouTube
			? `YouTube: ${socialData?.channelTitle}`
			: `${extractSiteName(url).toUpperCase()}`,
		sourceUrl: url,
		author:
			socialData?.username ||
			socialData?.author?.username ||
			socialData?.channelTitle,
		tags: parsedRecipe.tags || [],
		nutrition: parsedRecipe.nutrition || null,
		createdAt: new Date().toISOString(),
		...(isInstagram && {
			instagram: {
				shortcode: socialData?.shortcode,
				username: socialData?.username,
			},
		}),
		...(isTikTok && {
			tiktok: {
				videoId: socialData?.videoId,
				username: socialData?.author?.username,
				nickname: socialData?.author?.nickname,
			},
		}),
		...(isYouTube && {
			youtube: {
				videoId: socialData?.videoId,
				channelTitle: socialData?.channelTitle,
				channelId: socialData?.channelId,
				thumbnailUrl: socialData?.thumbnailUrl,
				duration: socialData?.duration,
				viewCount: socialData?.viewCount,
				likeCount: socialData?.likeCount,
				commentCount: socialData?.commentCount,
			},
		}),
	};
};

// Import endpoint with Instagram, TikTok, and YouTube support
router.post("/import", async (req, res) => {
	const { url } = req.body;

	if (!url) {
		return res.status(400).json({ error: "URL is required" });
	}

	try {
		console.log(`Starting recipe import for URL: ${url}`);
		
		// Check recipe cache first
		const cachedRecipe = getFromCache(recipeCache, url);
		if (cachedRecipe) {
			console.log("Recipe found in cache");
			return res.json(cachedRecipe);
		}

		const isInstagram =
			url.includes("instagram.com/p/") || url.includes("instagram.com/reel/");
		const isTikTok = url.includes("tiktok.com/");
		const isYouTube = url.includes("youtube.com/") || url.includes("youtu.be/");
		let socialData = null;
		let pageContent = "";

		if (isInstagram) {
			socialData = await processSocialMedia(
				url,
				"instagram",
				getInstagramMediaFromUrl
			);
			pageContent = socialData.caption;
		} else if (isTikTok) {
			socialData = await processSocialMedia(
				url,
				"tiktok",
				getTikTokVideoFromUrl
			);
			pageContent = socialData.description;
		} else if (isYouTube) {
			socialData = await processSocialMedia(
				url,
				"youtube",
				getYouTubeVideoFromUrl
			);
			pageContent = socialData.description;
		} else {
			console.log("Processing web URL with textfrom.website");
			const textUrl = `https://textfrom.website/${url}`;
			const { data } = await axios.get(textUrl);
			pageContent = data;
		}

		if (!pageContent) {
			return res.status(500).json({ error: "Failed to process URL" });
		}

		console.log("Processing recipe data with AI...");
		const importedRecipe = await processRecipeData(
			pageContent,
			socialData,
			url,
			isInstagram,
			isTikTok,
			isYouTube
		);
		
		console.log("Recipe processed successfully, caching and saving...");
		handleCache(recipeCache, url, importedRecipe);
		tempRecipes.push(importedRecipe);

		console.log(`Recipe import completed for: ${importedRecipe.title}`);
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
	Object.keys(imageCache).forEach((key) => delete imageCache[key]);
	aiResponseCache.clear();
	res.json({ message: "Cache cleared successfully" });
});

// Optimized cache cleanup function
const cleanupCaches = () => {
	const now = Date.now();
	let entriesProcessed = 0;

	// Clean up AI response cache
	for (const [key, value] of aiResponseCache.entries()) {
		if (entriesProcessed >= MAX_ENTRIES_PER_CLEANUP) break;
		if (now - value.timestamp > CACHE_DURATIONS.AI_GENERATED) {
			aiResponseCache.delete(key);
			entriesProcessed++;
		}
	}

	// Clean up recipe cache
	entriesProcessed = 0;
	for (const [key, value] of recipeCache.entries()) {
		if (entriesProcessed >= MAX_ENTRIES_PER_CLEANUP) break;
		if (now - value.timestamp > CACHE_DURATIONS.RECIPES) {
			recipeCache.delete(key);
			entriesProcessed++;
		}
	}

	// Clean up image cache
	entriesProcessed = 0;
	const imageEntries = Object.entries(imageCache);
	if (imageEntries.length > MAX_CACHE_SIZE) {
		const newImageCache = {};
		imageEntries
			.sort((a, b) => b[1].timestamp - a[1].timestamp) // Sort by most recent
			.slice(0, MAX_CACHE_SIZE) // Keep most recent entries
			.forEach(([key, value]) => {
				if (entriesProcessed >= MAX_ENTRIES_PER_CLEANUP) return;
				if (now - value.timestamp > CACHE_DURATIONS.IMAGES) {
					delete imageCache[key];
					entriesProcessed++;
				} else {
					newImageCache[key] = value;
				}
			});

		// Replace the old cache with the new one
		Object.keys(imageCache).forEach((key) => delete imageCache[key]);
		Object.entries(newImageCache).forEach(([key, value]) => {
			imageCache[key] = value;
		});
	}
};

// Run cleanup more frequently but process fewer items each time
setInterval(cleanupCaches, 1 * 60 * 60 * 1000); // Every hour

// Enhanced cache status endpoint
router.get("/cache/status", (req, res) => {
	const used = process.memoryUsage();
	const cacheStats = {
		aiCache: {
			size: aiResponseCache.size,
			maxSize: MAX_CACHE_SIZE,
			hitRate: calculateHitRate(aiResponseCache),
		},
		recipeCache: {
			size: recipeCache.size,
			maxSize: MAX_CACHE_SIZE,
			hitRate: calculateHitRate(recipeCache),
		},
		imageCache: {
			size: Object.keys(imageCache).length,
			maxSize: MAX_CACHE_SIZE,
			hitRate: calculateHitRate(imageCache),
		},
		memoryUsage: {
			heapTotal: Math.round(used.heapTotal / 1024 / 1024) + "MB",
			heapUsed: Math.round(used.heapUsed / 1024 / 1024) + "MB",
			rss: Math.round(used.rss / 1024 / 1024) + "MB",
		},
		cacheDurations: {
			socialMedia: CACHE_DURATIONS.SOCIAL_MEDIA / (60 * 60 * 1000) + " hours",
			aiGenerated:
				CACHE_DURATIONS.AI_GENERATED / (24 * 60 * 60 * 1000) + " days",
			images: CACHE_DURATIONS.IMAGES / (24 * 60 * 60 * 1000) + " days",
			recipes: CACHE_DURATIONS.RECIPES / (24 * 60 * 60 * 1000) + " days",
		},
	};
	res.json(cacheStats);
});

// Helper function to calculate cache hit rate
const calculateHitRate = (cache) => {
	if (!cache.hits) cache.hits = 0;
	if (!cache.misses) cache.misses = 0;
	const total = cache.hits + cache.misses;
	return total > 0 ? ((cache.hits / total) * 100).toFixed(2) + "%" : "0%";
};

// Helper function to get paginated recipes
const getPaginatedRecipes = (recipes, page = 1, limit = 10) => {
	const startIndex = (page - 1) * limit;
	const endIndex = startIndex + limit;
	const paginatedRecipes = recipes.slice(startIndex, endIndex);

	return {
		recipes: paginatedRecipes,
		pagination: {
			total: recipes.length,
			page,
			limit,
			totalPages: Math.ceil(recipes.length / limit),
			hasNextPage: endIndex < recipes.length,
			hasPrevPage: page > 1,
		},
	};
};

// GET /ai/recipes - Get all generated recipes with pagination
router.get("/", (req, res) => {
	try {
		const page = parseInt(req.query.page) || 1;
		const limit = parseInt(req.query.limit) || 10;

		const result = getPaginatedRecipes(tempRecipes, page, limit);
		res.json(result);
	} catch (error) {
		console.error("Error getting generated recipes:", error);
		res.status(500).json({ error: "Failed to retrieve generated recipes" });
	}
});

module.exports = router;
