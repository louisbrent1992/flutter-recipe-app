/**
 * Generated Recipes Routes
 * 
 * This module handles AI-powered recipe generation and import using OpenAI's Chat Completion API.
 * 
 * OpenAI API References:
 * - Chat Completion: https://platform.openai.com/docs/api-reference/chat/create
 * - Structured Outputs: https://platform.openai.com/docs/guides/structured-outputs
 * 
 * API Method Used:
 * - chat.completions.create() - Standard chat completion API for all requests
 * - Structured Outputs with JSON Schema for reliable JSON responses
 * 
 * Key Parameters (supported by gpt-5-nano):
 * - model: The model to use (e.g., "gpt-5-nano", "gpt-4o-mini", "gpt-4o")
 * - messages: Array of message objects with role (developer/user/assistant) and content
 * - reasoning_effort: "low" | "minimal" | "medium" | "high" (gpt-5/o-series only)
 *   - Set to "low" for faster responses with fewer reasoning tokens
 * - max_completion_tokens: Maximum tokens to generate (12,000-16,000 to allow for reasoning + output)
 * - response_format: 
 *   - { type: "text" } for text responses
 *   - { type: "json_schema", json_schema: {...} } for Structured Outputs with strict schema validation
 * - stream: Boolean to enable streaming responses
 * - store: Boolean to store output for model distillation/evals
 * - safety_identifier: Stable identifier for abuse detection
 * 
 * Structured Outputs Implementation:
 * - Uses JSON Schema with strict: true to enforce schema compliance
 * - Ensures consistent and reliable JSON-formatted responses
 * - Eliminates need for manual JSON parsing validation
 * - Applied to /generate and /import endpoints
 * 
 * Parameters NOT supported by gpt-5-nano (removed from implementation):
 * - temperature (only supports default value of 1)
 * - top_p
 * - frequency_penalty
 * - presence_penalty
 * 
 * Token Management & Performance Optimization:
 * - reasoning_effort: Set to "low" for faster responses with fewer reasoning tokens
 *   - Dramatically reduces internal thinking time for recipe tasks
 *   - Typical reduction: ~6-8k reasoning tokens → ~2-3k reasoning tokens
 *   - Values: minimal | low | medium (default) | high
 * - Input: 
 *   - Recipe generation: No truncation needed (prompts are small ~400 tokens)
 *   - Recipe imports: Truncated to 10,000 chars for optimal performance
 *     (Reduces prompt tokens from ~4k to ~2.5k, speeds up AI reasoning)
 *     (Performance: ~50s → ~10-15s for most imports with low reasoning effort)
 * - Output: 
 *   - Recipe generation: 16,000 tokens (3 recipes: typical ~2-3k reasoning + ~4-5k output)
 *   - Recipe imports: 6,000 tokens (1 recipe: typical ~1.5k reasoning + ~1.5k output)
 *   - gpt-5-nano uses reasoning tokens internally before generating output
 *   - max_completion_tokens includes BOTH reasoning and output tokens
 *   - Lower reasoning effort + token limits = faster responses
 * - Timeout: 120 seconds for both client and server
 * 
 * Environment Variables Required:
 * - OPENAI_API_KEY: Your OpenAI API key
 * - OPENAI_BASE_URL (optional): Custom base URL for OpenAI-compatible APIs
 * - GOOGLE_API_KEY: For image search functionality
 * - GOOGLE_CX: Google Custom Search Engine ID
 */

const express = require("express");
const router = express.Router();
const axios = require("axios");
const { v4: uuidv4 } = require("uuid");
const OpenAI = require("openai");
const recipeData = require("../data/recipeData");
const { getInstagramMediaFromUrl } = require("../utils/instagramAPI");
const { getTikTokVideoFromUrl } = require("../utils/tiktokAPI");
const { getYouTubeVideoFromUrl } = require("../utils/youtubeAPI");

// Initialize OpenAI client with configuration
// Generous timeout and retry settings to handle large recipe data
const client = new OpenAI({
	apiKey: process.env.OPENAI_API_KEY || process.env.LlamaAI_API_KEY,
	baseURL: process.env.OPENAI_BASE_URL || process.env.LlamaAI_API_URL,
	timeout: 120000, // 2 minutes - increased for large requests
	maxRetries: 3,
	defaultHeaders: {
		"User-Agent": "RecipeaseApp/1.0",
	},
});

/**
 * Structured Output Schemas:
 * 
 * The following JSON schemas are enforced via OpenAI's Structured Outputs feature
 * using strict: true for guaranteed schema compliance.
 * 
 * Recipe Generation Schema (recipe_generation):
 * {
 *   recipes: [
 *     {
 *       title: string,
 *       cuisineType: string,
 *       description: string,
 *       ingredients: string[],
 *       instructions: string[],
 *       cookingTime: string,
 *       difficulty: string,
 *       servings: string,
 *       tags: string[],
 *       nutrition: {
 *         calories: string,
 *         protein: string,
 *         carbs: string,
 *         fat: string,
 *         fiber: string,
 *         sugar: string,
 *         sodium: string,
 *         iron: string
 *       }
 *     }
 *   ]
 * }
 * 
 * Recipe Import Schema (recipe_import):
 * {
 *   title: string,
 *   ingredients: string[],
 *   instructions: string[],
 *   description: string,
 *   tags: string[],
 *   cookingTime: string,
 *   difficulty: string,
 *   servings: string,
 *   nutrition: {
 *     calories: string,
 *     protein: string,
 *     carbs: string,
 *     fat: string,
 *     fiber: string,
 *     sugar: string,
 *     sodium: string,
 *     iron: string
 *   }
 * }
 */

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

// Performance logging helper
const logPerformance = (label, startTime) => {
	const duration = Date.now() - startTime;
	console.log(`⏱️  [PERFORMANCE] ${label}: ${duration}ms (${(duration / 1000).toFixed(2)}s)`);
	return duration;
};

// Helper function to check if a URL is a placeholder
const isPlaceholderUrl = (url) => {
	if (!url || typeof url !== 'string') return false;
	return url.includes('placeholder.com') || url.includes('via.placeholder.com');
};

// Function to fetch an image from Google with caching
const fetchImage = async (query, start = 1) => {
	// Handle undefined or null query
	if (!query) {
		console.log("No query provided for image search");
		return null;
	}

	// Normalize the query by trimming and converting to lowercase
	const normalizedQuery = query.trim().toLowerCase();
	const cacheKey = `${normalizedQuery}_${start}`;

	// Check if the image is already cached
	if (imageCache[cacheKey]) {
		const cached = imageCache[cacheKey];
		// Handle both old format (string) and new format (object with url and timestamp)
		const cachedUrl = typeof cached === 'string' ? cached : cached.url;
		const cachedTimestamp = typeof cached === 'string' ? Date.now() : cached.timestamp;
		
		// Check if cache entry is expired
		if (Date.now() - cachedTimestamp > CACHE_DURATIONS.IMAGES) {
			console.log("⚠️ Cached image expired, fetching new one");
			delete imageCache[cacheKey];
		} else if (isPlaceholderUrl(cachedUrl)) {
			console.log("⚠️ Cached image is a placeholder, fetching new one");
			delete imageCache[cacheKey];
		} else {
		console.log("✅ Image found in cache");
			return cachedUrl;
		}
	}

	const startTime = Date.now();
	try {
		// Check if Google API credentials are configured
		if (!GOOGLE_API_KEY || !GOOGLE_CX) {
			console.error("Google Custom Search API not configured");
			return null;
		}

		const response = await axios.get(GOOGLE_SEARCH_URL, {
			params: {
				key: GOOGLE_API_KEY,
				cx: GOOGLE_CX,
				q: `${normalizedQuery}`,
				searchType: "image",
				num: 3, // Get more results to have options
				safe: "active",
				start: start,
			},
			timeout: 10000, // 10 second timeout
		});

		logPerformance(`Google Image Search for "${normalizedQuery}"`, startTime);

		// Check if images exist in response
		if (!response.data.items || response.data.items.length === 0) {
			console.log("No images found for query:", normalizedQuery);
			return null;
		}

		// Try to find the best image from the results (excluding placeholders)
		for (const item of response.data.items) {
			const imageUrl = item.link;
			if (imageUrl && !isPlaceholderUrl(imageUrl)) {
				// Store with timestamp for proper cache management
				imageCache[cacheKey] = {
					url: imageUrl,
					timestamp: Date.now()
				};
				return imageUrl;
			}
		}

		// If all results were placeholders, try next page
		if (start === 1) {
			console.log("All results were placeholders, trying next page");
			return await fetchImage(query, 4);
		}

		return null;
	} catch (error) {
		// Handle specific error cases
		if (error.response) {
			const status = error.response.status;
			const statusText = error.response.statusText;
			
			if (status === 429) {
				console.error("⚠️ Google API rate limit exceeded. Please try again later.");
			} else if (status === 403) {
				console.error("⚠️ Google API access forbidden. Check API key and quota.");
			} else if (status === 400) {
				console.error("⚠️ Google API bad request:", error.response.data?.error?.message || statusText);
			} else {
				console.error(`⚠️ Google API error (${status}):`, statusText);
			}
		} else if (error.code === 'ECONNABORTED') {
			console.error("⚠️ Google API request timeout");
		} else {
			console.error("Error fetching image from Google:", error.message || error);
		}
		
		logPerformance(`Google Image Search FAILED for "${normalizedQuery}"`, startTime);
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

// Helper function to truncate long content intelligently
const truncateContent = (content, maxLength = 50000) => {
	if (!content || content.length <= maxLength) {
		return content;
	}
	
	console.log(`⚠️  Content too long (${content.length} chars), truncating to ${maxLength} chars`);
	
	// Keep the beginning (usually has key info) and try to end at a sentence
	const truncated = content.substring(0, maxLength);
	const lastPeriod = truncated.lastIndexOf('.');
	const lastNewline = truncated.lastIndexOf('\n');
	const cutPoint = Math.max(lastPeriod, lastNewline);
	
	if (cutPoint > maxLength * 0.8) {
		return truncated.substring(0, cutPoint + 1);
	}
	
	return truncated + '...';
};

// Helper function for standard OpenAI chat completion
// Default max_completion_tokens set to 8000 for flexible output
// Input content is automatically truncated if needed via truncateContent()
// Note: gpt-5-nano only supports default values - temperature, frequency_penalty, presence_penalty removed
const createChatCompletion = async (messages, options = {}) => {
	const {
		model = "gpt-5-nano",
		max_completion_tokens = 8000, // Generous default for complete recipe data
		stream = false,
		response_format = { type: "text" },
		safety_identifier,
	} = options;

	try {
		const response = await client.chat.completions.create({
			model,
			messages,
			max_completion_tokens,
			stream,
			response_format,
			...(safety_identifier && { safety_identifier }),
		});

		if (stream) {
			return response; // Return stream for handling
		}

		return {
			content: response.choices[0].message.content,
			role: response.choices[0].message.role,
			finishReason: response.choices[0].finish_reason,
			usage: response.usage,
			model: response.model,
		};
	} catch (error) {
		console.error("Error creating chat completion:", error);
		throw error;
	}
};

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

		const response = await client.chat.completions.create({
			model: "gpt-5-nano",
			messages: [
				{
					role: "developer",
					content: "You are a professional chef and recipe creator. Generate creative, delicious, and practical recipes with accurate nutritional information."
				},
				{
					role: "user",
					content: `Generate three recipes with these requirements:
						- Ingredients: ${random ? await randomIngredient() : ingredients.join(", ")}
						- Dietary restrictions: ${dietaryRestrictions.join(", ") || "None"}
						- Cuisine type: ${cuisineType || "Any"}`,
				},
			],
			reasoning_effort: "low", // Reduces reasoning time and tokens for faster responses
			response_format: {
				type: "json_schema",
				json_schema: {
					name: "recipe_generation",
					strict: true,
					schema: {
						type: "object",
						properties: {
							recipes: {
								type: "array",
								items: {
									type: "object",
									properties: {
										title: {
											type: "string",
											description: "The name of the recipe"
										},
										cuisineType: {
											type: "string",
											description: "The cuisine type (e.g., Italian, Mexican, Asian)"
										},
										description: {
											type: "string",
											description: "A brief description of the recipe"
										},
										ingredients: {
											type: "array",
											items: {
												type: "string"
											},
											description: "List of ingredients needed"
										},
										instructions: {
											type: "array",
											items: {
												type: "string"
											},
											description: "Step-by-step cooking instructions"
										},
										cookingTime: {
											type: "string",
											description: "Total cooking time (e.g., '30 minutes')"
										},
										difficulty: {
											type: "string",
											description: "Difficulty level: easy, medium, or hard"
										},
										servings: {
											type: "string",
											description: "Number of servings"
										},
										tags: {
											type: "array",
											items: {
												type: "string"
											},
											description: "Tags for categorizing the recipe"
										},
										nutrition: {
											type: "object",
											properties: {
												calories: {
													type: "string",
													description: "Calorie count"
												},
												protein: {
													type: "string",
													description: "Protein content (e.g., '25g')"
												},
												carbs: {
													type: "string",
													description: "Carbohydrate content (e.g., '40g')"
												},
												fat: {
													type: "string",
													description: "Fat content (e.g., '12g')"
												},
												fiber: {
													type: "string",
													description: "Fiber content (e.g., '5g')"
												},
												sugar: {
													type: "string",
													description: "Sugar content (e.g., '8g')"
												},
												sodium: {
													type: "string",
													description: "Sodium content (e.g., '600mg')"
												},
												iron: {
													type: "string",
													description: "Iron content percentage"
												}
											},
											required: ["calories", "protein", "carbs", "fat", "fiber", "sugar", "sodium", "iron"],
											additionalProperties: false
										}
									},
									required: ["title", "cuisineType", "description", "ingredients", "instructions", "cookingTime", "difficulty", "servings", "tags", "nutrition"],
									additionalProperties: false
								}
							}
						},
						required: ["recipes"],
						additionalProperties: false
					}
				}
			},
			max_completion_tokens: 16000, // Increased to allow for reasoning tokens + output tokens
			store: true,
		});

		if (!response?.choices?.[0]?.message?.content) {
			console.error("❌ No content in AI response");
			throw new Error("OpenAI returned empty content");
		}
		
		const parsedContent = JSON.parse(response.choices[0].message.content);
		const recipesData = parsedContent.recipes || [];
		
		console.log(`✅ Generated ${recipesData.length} recipes`);

		const generatedRecipes = await Promise.all(
			recipesData.map(async (recipeData) => {
				const recipeTitle = recipeData.title || "Generated Recipe";
				const imageQuery = recipeTitle !== "Generated Recipe" ? recipeTitle : `${cuisineType || 'delicious'} food dish`;
				
				// Get image URL, filtering out placeholders
				let imageUrl = null;
				if (typeof recipeData.image === "object" && recipeData.image.url) {
					// Check if AI provided image is a placeholder
					if (!isPlaceholderUrl(recipeData.image.url)) {
						imageUrl = recipeData.image.url;
					}
				}
				
				// If no valid image from AI, fetch from Google
				if (!imageUrl) {
					imageUrl = await fetchImage(imageQuery);
				}
				
				return {
				id: uuidv4(),
					title: recipeTitle,
				cuisineType: recipeData.cuisineType || cuisineType,
				description: recipeData.description || "Enjoy your generated recipe!",
				ingredients: Array.isArray(recipeData.ingredients)
					? recipeData.ingredients
					: [],
				instructions: Array.isArray(recipeData.instructions)
					? recipeData.instructions
					: [],
					imageUrl: imageUrl || null, // Use null instead of placeholder
				cookingTime: recipeData.cookingTime || "30 minutes",
				difficulty: recipeData.difficulty || "medium",
				servings: recipeData.servings || "4",
				tags: recipeData.tags || [],
				nutrition: recipeData.nutrition || null,
				aiGenerated: true,
				createdAt: new Date().toISOString(),
				};
			})
		);

		tempRecipes.push(...generatedRecipes);
		res.json(generatedRecipes);
	} catch (error) {
		console.error("Error generating recipes:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't generate recipes right now. Please try again shortly."
		);
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
	const startTime = Date.now();
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
			logPerformance(`${type.toUpperCase()} API call`, startTime);
		} catch (error) {
			console.error(`Error processing ${type} URL:`, error);
			logPerformance(`${type.toUpperCase()} API call FAILED`, startTime);
			throw new Error(`Failed to process ${type} URL`);
		}
	} else {
		console.log(`✅ ${type} data found in cache`);
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
		console.log("✅ Recipe parsing found in cache");
		
		// Check if cached recipe has empty ingredients or instructions
		const cachedIngredients = Array.isArray(cachedRecipe.ingredients) && cachedRecipe.ingredients.length > 0
			? cachedRecipe.ingredients
			: [];
		const cachedInstructions = Array.isArray(cachedRecipe.instructions) && cachedRecipe.instructions.length > 0
			? cachedRecipe.instructions
			: [];
		
		let finalIngredients = cachedIngredients;
		let finalInstructions = cachedInstructions;
		
		// If either is empty, generate them from the recipe title
		if (finalIngredients.length === 0 || finalInstructions.length === 0) {
			console.log("⚠️ Cached recipe missing details, generating from title...");
			const generateStartTime = Date.now();
			
			try {
				const generateResponse = await client.chat.completions.create({
					model: "gpt-5-nano",
					messages: [
						{
							role: "developer",
							content: "You are an expert chef. Generate a complete recipe based on the recipe title provided. Create realistic ingredients and step-by-step cooking instructions.",
						},
						{
							role: "user",
							content: `Generate a complete recipe for: ${cachedRecipe.title}\n\nProvide a list of ingredients and step-by-step cooking instructions.`,
						},
					],
					reasoning_effort: "low",
					response_format: {
						type: "json_schema",
						json_schema: {
							name: "recipe_generation_fallback",
							strict: true,
							schema: {
								type: "object",
								properties: {
									ingredients: {
										type: "array",
										items: { type: "string" },
										description: "List of ingredients needed for this recipe",
										minItems: 3,
									},
									instructions: {
										type: "array",
										items: { type: "string" },
										description: "Step-by-step cooking instructions",
										minItems: 3,
									},
								},
								required: ["ingredients", "instructions"],
								additionalProperties: false,
							},
						},
					},
					max_completion_tokens: 4000,
				});

				const generatedRecipe = JSON.parse(generateResponse.choices[0].message.content);
				
				if (finalIngredients.length === 0 && Array.isArray(generatedRecipe.ingredients) && generatedRecipe.ingredients.length > 0) {
					finalIngredients = generatedRecipe.ingredients;
					console.log("✅ Generated ingredients from title (cached recipe)");
				}
				
				if (finalInstructions.length === 0 && Array.isArray(generatedRecipe.instructions) && generatedRecipe.instructions.length > 0) {
					finalInstructions = generatedRecipe.instructions;
					console.log("✅ Generated instructions from title (cached recipe)");
				}
				
				logPerformance("AI Recipe Generation (fallback from title - cached)", generateStartTime);
			} catch (error) {
				console.error("Error generating recipe details from title (cached):", error);
				// If generation fails, at least ensure we have some default values
				if (finalIngredients.length === 0) {
					finalIngredients = ["Ingredients not available"];
				}
				if (finalInstructions.length === 0) {
					finalInstructions = ["Instructions not available"];
				}
			}
		}
		
		const imageStartTime = Date.now();
		let imageUrl = socialData?.imageUrl ||
			socialData?.coverUrl ||
			socialData?.thumbnailUrl ||
			(await fetchImage(cachedRecipe.title || "recipe"));
		
		// Filter out placeholder URLs
		if (isPlaceholderUrl(imageUrl)) {
			imageUrl = null;
		}
		
		if (!socialData?.imageUrl && !socialData?.coverUrl && !socialData?.thumbnailUrl) {
			logPerformance("Image fetch (from cache hit)", imageStartTime);
		}

		return {
			...cachedRecipe,
			id: uuidv4(),
			ingredients: finalIngredients,
			instructions: finalInstructions,
			imageUrl: imageUrl || null,
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

	// Process new recipe data with AI
	const aiStartTime = Date.now();
	
	// Truncate input content for faster AI processing
	const processedContent = truncateContent(recipeData, 10000);
	
	const response = await client.chat.completions.create({
		model: "gpt-5-nano",
		messages: [
			{
				role: "developer",
				content:
					isInstagram || isTikTok || isYouTube
						? "You are an expert recipe analyzer. Extract the recipe from this social media post."
						: "You are an expert recipe analyzer. Extract the recipe from this text.",
			},
			{
				role: "user",
				content: processedContent,
			},
		],
		reasoning_effort: "low", // Reduces reasoning time and tokens for faster recipe parsing
		response_format: {
			type: "json_schema",
			json_schema: {
				name: "recipe_import",
				strict: true,
				schema: {
					type: "object",
					properties: {
						title: {
							type: "string",
							description: "The recipe title"
						},
						ingredients: {
							type: "array",
							items: {
								type: "string"
							},
							description: "List of ingredients"
						},
						instructions: {
							type: "array",
							items: {
								type: "string"
							},
							description: "Step-by-step instructions"
						},
						description: {
							type: "string",
							description: "A brief description of the recipe"
						},
						tags: {
							type: "array",
							items: {
								type: "string"
							},
							description: "Recipe tags for categorization"
						},
						cookingTime: {
							type: "string",
							description: "Total cooking time (e.g., '30 minutes')"
						},
						difficulty: {
							type: "string",
							description: "Difficulty level: easy, medium, or hard"
						},
						servings: {
							type: "string",
							description: "Number of servings"
						},
						nutrition: {
							type: "object",
							properties: {
								calories: {
									type: "string",
									description: "Calorie count per serving (number only)"
								},
								protein: {
									type: "string",
									description: "Protein in grams (e.g., '25g')"
								},
								carbs: {
									type: "string",
									description: "Carbohydrates in grams (e.g., '40g')"
								},
								fat: {
									type: "string",
									description: "Fat in grams (e.g., '12g')"
								},
								fiber: {
									type: "string",
									description: "Fiber in grams (e.g., '5g')"
								},
								sugar: {
									type: "string",
									description: "Sugar in grams (e.g., '8g')"
								},
								sodium: {
									type: "string",
									description: "Sodium in milligrams (e.g., '600mg')"
								},
								iron: {
									type: "string",
									description: "Iron as percent daily value (number only)"
								}
							},
							required: ["calories", "protein", "carbs", "fat", "fiber", "sugar", "sodium", "iron"],
							additionalProperties: false
						}
					},
					required: ["title", "ingredients", "instructions", "description", "tags", "cookingTime", "difficulty", "servings", "nutrition"],
					additionalProperties: false
				}
		}
	},
	max_completion_tokens: 6000, // Optimized for single recipe: typical usage ~3k (reasoning + output)
	store: true,
	});

	logPerformance("AI Recipe Parsing (OpenAI gpt-5-nano)", aiStartTime);

	const parsedRecipe = JSON.parse(response.choices[0].message.content);
	if (!parsedRecipe || !parsedRecipe.title) {
		throw new Error("Unable to parse recipe from URL");
	}

	handleCache(aiResponseCache, contentKey, parsedRecipe);

	// Check if ingredients or instructions are empty and generate them from title if needed
	let finalIngredients = Array.isArray(parsedRecipe.ingredients) && parsedRecipe.ingredients.length > 0
		? parsedRecipe.ingredients
		: [];
	let finalInstructions = Array.isArray(parsedRecipe.instructions) && parsedRecipe.instructions.length > 0
		? parsedRecipe.instructions
		: [];

	// If either is empty, generate them from the recipe title
	if (finalIngredients.length === 0 || finalInstructions.length === 0) {
		console.log("⚠️ Missing recipe details detected, generating from title...");
		const generateStartTime = Date.now();
		
		try {
			const generateResponse = await client.chat.completions.create({
				model: "gpt-5-nano",
				messages: [
					{
						role: "developer",
						content: "You are an expert chef. Generate a complete recipe based on the recipe title provided. Create realistic ingredients and step-by-step cooking instructions.",
					},
					{
						role: "user",
						content: `Generate a complete recipe for: ${parsedRecipe.title}\n\nProvide a list of ingredients and step-by-step cooking instructions.`,
					},
				],
				reasoning_effort: "low",
				response_format: {
					type: "json_schema",
					json_schema: {
						name: "recipe_generation_fallback",
						strict: true,
						schema: {
							type: "object",
							properties: {
								ingredients: {
									type: "array",
									items: { type: "string" },
									description: "List of ingredients needed for this recipe",
									minItems: 3,
								},
								instructions: {
									type: "array",
									items: { type: "string" },
									description: "Step-by-step cooking instructions",
									minItems: 3,
								},
							},
							required: ["ingredients", "instructions"],
							additionalProperties: false,
						},
					},
				},
				max_completion_tokens: 4000,
			});

			const generatedRecipe = JSON.parse(generateResponse.choices[0].message.content);
			
			if (finalIngredients.length === 0 && Array.isArray(generatedRecipe.ingredients) && generatedRecipe.ingredients.length > 0) {
				finalIngredients = generatedRecipe.ingredients;
				console.log("✅ Generated ingredients from title");
			}
			
			if (finalInstructions.length === 0 && Array.isArray(generatedRecipe.instructions) && generatedRecipe.instructions.length > 0) {
				finalInstructions = generatedRecipe.instructions;
				console.log("✅ Generated instructions from title");
			}
			
			logPerformance("AI Recipe Generation (fallback from title)", generateStartTime);
		} catch (error) {
			console.error("Error generating recipe details from title:", error);
			// If generation fails, at least ensure we have some default values
			if (finalIngredients.length === 0) {
				finalIngredients = ["Ingredients not available"];
			}
			if (finalInstructions.length === 0) {
				finalInstructions = ["Instructions not available"];
			}
		}
	}

	// Fetch image
	const imageStartTime = Date.now();
	let imageUrl = socialData?.imageUrl ||
		socialData?.coverUrl ||
		socialData?.thumbnailUrl ||
		(await fetchImage(parsedRecipe.title || "recipe"));
	
	// Filter out placeholder URLs
	if (isPlaceholderUrl(imageUrl)) {
		imageUrl = null;
	}
	
	if (!socialData?.imageUrl && !socialData?.coverUrl && !socialData?.thumbnailUrl) {
		logPerformance("Image fetch (after AI parsing)", imageStartTime);
	}

	return {
		id: uuidv4(),
		title: parsedRecipe.title || "Imported Recipe",
		ingredients: finalIngredients,
		instructions: finalInstructions,
		description: parsedRecipe.description || "Imported recipe",
		imageUrl: imageUrl || null,
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

	const totalStartTime = Date.now();
	console.log(`\n🚀 ========== STARTING RECIPE IMPORT ==========`);
	console.log(`📎 URL: ${url}`);

	try {
		// Check recipe cache first
		const cacheStartTime = Date.now();
		const cachedRecipe = getFromCache(recipeCache, url, CACHE_DURATIONS.RECIPES);
		if (cachedRecipe) {
			logPerformance("Cache lookup (HIT)", cacheStartTime);
			console.log("✅ Recipe found in cache, returning cached result");
			logPerformance("TOTAL IMPORT TIME (from cache)", totalStartTime);
			console.log(`✓ ========== IMPORT COMPLETE ==========\n`);
			return res.json({ ...cachedRecipe, fromCache: true });
		}
		logPerformance("Cache lookup (MISS)", cacheStartTime);

		const isInstagram =
			url.includes("instagram.com/p/") || url.includes("instagram.com/reel/");
		// Detect TikTok URLs (case-insensitive, handles www, short links, etc.)
		const isTikTok = /tiktok\.com/i.test(url) || /vm\.tiktok\.com/i.test(url) || /vt\.tiktok\.com/i.test(url);
		const isYouTube = url.includes("youtube.com/") || url.includes("youtu.be/");
		let socialData = null;
		let pageContent = "";

		// Step 1: Fetch content from source
		const fetchStartTime = Date.now();
		console.log("📥 Step 1: Fetching content from source...");
		
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
			console.log("🌐 Processing web URL with textfrom.website");
			const webFetchStart = Date.now();
			const textUrl = `https://textfrom.website/${url}`;
			const { data } = await axios.get(textUrl);
			pageContent = data;
			logPerformance("textfrom.website API call", webFetchStart);
		}
		
		logPerformance("Content Fetching (Step 1)", fetchStartTime);

		if (!pageContent) {
			const errorHandler = require("../utils/errorHandler");
			console.log("❌ No content extracted from URL");
			logPerformance("TOTAL IMPORT TIME (failed - no content)", totalStartTime);
			console.log(`✗ ========== IMPORT FAILED ==========\n`);
			return errorHandler.serverError(
				res,
				"We couldn't process that URL right now. Please try again shortly."
			);
		}

		// Step 2: Process recipe data with AI
		console.log("🤖 Step 2: Processing recipe data with AI...");
		const processStartTime = Date.now();
		
		const importedRecipe = await processRecipeData(
			pageContent,
			socialData,
			url,
			isInstagram,
			isTikTok,
			isYouTube
		);
		
		logPerformance("Recipe Data Processing (Step 2)", processStartTime);
		
		// Step 3: Cache and save
		console.log("💾 Step 3: Caching and saving...");
		const saveStartTime = Date.now();
		handleCache(recipeCache, url, importedRecipe);
		tempRecipes.push(importedRecipe);
		logPerformance("Caching and Saving (Step 3)", saveStartTime);

		logPerformance("🎉 TOTAL IMPORT TIME", totalStartTime);
		console.log(`✓ Recipe import completed: "${importedRecipe.title}"`);
		console.log(`✓ ========== IMPORT COMPLETE ==========\n`);
		
		res.json({ ...importedRecipe, fromCache: false });
	} catch (error) {
		console.error("❌ Error importing recipe:", error);
		logPerformance("TOTAL IMPORT TIME (failed - error)", totalStartTime);
		console.log(`✗ ========== IMPORT FAILED ==========\n`);
		
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't import that link right now. Please try another link or try again shortly.",
			error.message
		);
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
	const initialImageCacheSize = Object.keys(imageCache).length;
	
	// Always clean up expired entries, regardless of cache size
	for (const [key, value] of Object.entries(imageCache)) {
		if (entriesProcessed >= MAX_ENTRIES_PER_CLEANUP) break;
		
		// Handle both old format (string) and new format (object with timestamp)
		let entryTimestamp;
		if (typeof value === 'string') {
			// Old format: treat as expired to migrate to new format
			entryTimestamp = 0;
		} else if (value && typeof value === 'object' && value.timestamp) {
			entryTimestamp = value.timestamp;
		} else {
			// Invalid entry, remove it
					delete imageCache[key];
					entriesProcessed++;
			continue;
		}
		
		// Remove expired entries
		if (now - entryTimestamp > CACHE_DURATIONS.IMAGES) {
			delete imageCache[key];
			entriesProcessed++;
		}
	}
	
	// If cache is still too large after cleanup, trim to most recent entries
	const currentCacheSize = Object.keys(imageCache).length;
	if (currentCacheSize > MAX_CACHE_SIZE) {
		const sortedEntries = Object.entries(imageCache)
			.map(([key, value]) => {
				// Handle both formats for sorting
				const timestamp = typeof value === 'string' 
					? 0  // Old format entries go to the end
					: (value?.timestamp || 0);
				return { key, value, timestamp };
			})
			.sort((a, b) => b.timestamp - a.timestamp) // Sort by most recent
			.slice(0, MAX_CACHE_SIZE); // Keep most recent entries
		
		// Rebuild cache with only the most recent entries
		const newImageCache = {};
		sortedEntries.forEach(({ key, value }) => {
			newImageCache[key] = value;
			});

		// Replace the old cache with the new one
		Object.keys(imageCache).forEach((key) => delete imageCache[key]);
		Object.entries(newImageCache).forEach(([key, value]) => {
			imageCache[key] = value;
		});
		
		console.log(`🧹 Trimmed image cache from ${currentCacheSize} to ${Object.keys(newImageCache).length} entries`);
	}
};

// Run cleanup more frequently but process fewer items each time
// Clean up every 30 minutes to prevent memory buildup
setInterval(cleanupCaches, 30 * 60 * 1000);

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
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't load generated recipes. Please try again in a moment."
		);
	}
});

// POST /ai/recipes/chat - Conversational recipe advice using standard chat completion
router.post("/chat", async (req, res) => {
	const { message, conversationHistory = [] } = req.body;

	if (!message) {
		return res.status(400).json({ error: "Message is required" });
	}

	console.log("💬 Processing chat request:", message);

	try {
		// Build messages array with conversation history
		const messages = [
			{
				role: "developer",
				content: "You are a helpful culinary assistant specializing in recipes, cooking techniques, ingredient substitutions, and meal planning. Provide practical, creative, and detailed advice to help users with their cooking questions."
			},
			...conversationHistory,
			{
				role: "user",
				content: message
			}
		];

		const response = await createChatCompletion(messages, {
			model: "gpt-5-nano",
			max_completion_tokens: 4000,
		});

		res.json({
			reply: response.content,
			usage: response.usage,
			model: response.model,
		});
	} catch (error) {
		console.error("Error in chat completion:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't process your message right now. Please try again shortly."
		);
	}
});

// POST /ai/recipes/stream - Streaming recipe generation for real-time responses
router.post("/stream", async (req, res) => {
	const { message } = req.body;

	if (!message) {
		return res.status(400).json({ error: "Message is required" });
	}

	console.log("🌊 Starting streaming response...");

	try {
		// Set headers for Server-Sent Events (SSE)
		res.setHeader("Content-Type", "text/event-stream");
		res.setHeader("Cache-Control", "no-cache");
		res.setHeader("Connection", "keep-alive");

		const messages = [
			{
				role: "developer",
				content: "You are a helpful culinary assistant. Provide detailed, step-by-step cooking advice."
			},
			{
				role: "user",
				content: message
			}
		];

		const stream = await client.chat.completions.create({
			model: "gpt-5-nano",
			messages,
			max_completion_tokens: 5000,
			stream: true,
			store: true,
		});

		// Stream the response chunks to the client
		for await (const chunk of stream) {
			const content = chunk.choices[0]?.delta?.content || "";
			if (content) {
				res.write(`data: ${JSON.stringify({ content })}\n\n`);
			}

			// Check if streaming is complete
			if (chunk.choices[0]?.finish_reason) {
				res.write(`data: ${JSON.stringify({ done: true, finish_reason: chunk.choices[0].finish_reason })}\n\n`);
				break;
			}
		}

		res.end();
	} catch (error) {
		console.error("Error in streaming completion:", error);
		res.write(`data: ${JSON.stringify({ error: "Streaming failed" })}\n\n`);
		res.end();
	}
});

// POST /ai/recipes/suggest - Get recipe suggestions using standard chat completion
router.post("/suggest", async (req, res) => {
	const { ingredients = [], preferences = "" } = req.body;

	if (!ingredients.length && !preferences) {
		return res.status(400).json({ error: "Please provide ingredients or preferences" });
	}

	console.log("💡 Generating recipe suggestions...");

	try {
		const messages = [
			{
				role: "developer",
				content: "You are a creative chef who suggests interesting recipe ideas based on available ingredients and user preferences. Provide 3-5 recipe suggestions with brief descriptions."
			},
			{
				role: "user",
				content: `Suggest some recipe ideas based on:\n${ingredients.length ? `Available ingredients: ${ingredients.join(", ")}` : ""}\n${preferences ? `Preferences: ${preferences}` : ""}`
			}
		];

		const response = await createChatCompletion(messages, {
			model: "gpt-5-nano",
			max_completion_tokens: 3000,
		});

		res.json({
			suggestions: response.content,
			usage: response.usage,
			model: response.model,
		});
	} catch (error) {
		console.error("Error generating suggestions:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't generate suggestions right now. Please try again shortly."
		);
	}
});

// GET /ai/recipes/search-image - Search for images using Google Custom Search
router.get("/search-image", async (req, res) => {
	try {
		const { query, start } = req.query;
		
		if (!query) {
			return res.status(400).json({
				error: true,
				message: "Query parameter is required"
			});
		}

		const startParam = start ? parseInt(start) : 1;
		const imageUrl = await fetchImage(query, startParam);

		if (imageUrl) {
			res.json({
				imageUrl: imageUrl,
				query: query,
				start: startParam
			});
		} else {
			res.json({
				imageUrl: null,
				query: query,
				start: startParam,
				message: "No image found for the given query"
			});
		}
	} catch (error) {
		console.error("Error searching for image:", error);
		const errorHandler = require("../utils/errorHandler");
		errorHandler.serverError(
			res,
			"We couldn't search for images right now. Please try again in a moment."
		);
	}
});

module.exports = router;
