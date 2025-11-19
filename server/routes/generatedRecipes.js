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
const { 
	searchImage, 
	validateImageUrl, 
	isPlaceholderUrl,
	clearCache: clearImageCache,
	getCacheStats: getImageCacheStats
} = require("../utils/imageService");

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

// Cache management
// Image caching is now handled by imageService

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
// Image functions are now imported from imageService

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
				content: `You are a professional chef and recipe creator. Generate creative, delicious, and practical recipes with accurate nutritional information.

IMPORTANT: ALL recipe fields must be filled with realistic values. NEVER use "unknown":
- cookingTime: Provide realistic estimates (e.g., "15 minutes", "45 minutes", "2 hours")
- servings: Specify clear serving sizes (e.g., "2", "4", "6-8")
- difficulty: Assign "easy", "medium", or "hard" based on technique complexity
- nutrition: Provide accurate estimates per serving based on ingredients`
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
										description: "Total cooking time. NEVER use 'unknown'. Provide realistic estimates (e.g., '30 minutes', '1 hour')"
									},
									difficulty: {
										type: "string",
										description: "Difficulty level: MUST be 'easy', 'medium', or 'hard' based on technique complexity"
									},
									servings: {
										type: "string",
										description: "Number of servings. NEVER use 'unknown'. Specify clear serving sizes (e.g., '2', '4', '6-8')"
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
					imageUrl = await searchImage(imageQuery);
				}
				
				// Validate that the image URL is accessible before sending to client
				if (imageUrl) {
					console.log(`🖼️  Validating image for "${recipeTitle}"...`);
					const isValid = await validateImageUrl(imageUrl);
					if (!isValid) {
						console.log(`⚠️ Image validation failed, setting to null`);
						imageUrl = null;
					} else {
						console.log(`✅ Image validated successfully`);
					}
				}
				
			// Clean up any "unknown" values that might slip through
			const cleanValue = (value, defaultValue) => {
				if (!value || value.toLowerCase() === 'unknown' || value.trim() === '') {
					return defaultValue;
				}
				return value;
			};

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
			cookingTime: cleanValue(recipeData.cookingTime, "30 minutes"),
			difficulty: cleanValue(recipeData.difficulty, "medium"),
			servings: cleanValue(recipeData.servings, "4"),
			tags: recipeData.tags || [],
			nutrition: recipeData.nutrition || null,
			aiGenerated: true,
			isDiscoverable: true, // AI-generated recipes are discoverable in community
			createdAt: new Date().toISOString(),
			};
			})
		);

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
			
			// Check for API key if needed
			if (type === 'tiktok' && !process.env.RAPID_API_KEY) {
				throw new Error('TikTok import is temporarily unavailable. API configuration is missing.');
			}
			
			socialData = await getDataFn(url);
			handleCache(recipeCache, cacheKey, socialData);
			logPerformance(`${type.toUpperCase()} API call`, startTime);
		} catch (error) {
			console.error(`Error processing ${type} URL:`, error);
			logPerformance(`${type.toUpperCase()} API call FAILED`, startTime);
			
			// Provide more specific error messages
			const errorMessage = error.message || `Failed to process ${type} URL`;
			if (errorMessage.includes('API configuration')) {
				throw new Error(errorMessage);
			} else if (errorMessage.includes('rate limit') || errorMessage.includes('quota')) {
				throw new Error(`${type} import temporarily unavailable due to high demand. Please try again in a few minutes.`);
			} else if (errorMessage.includes('Invalid') || errorMessage.includes('unsupported')) {
				throw new Error(`Invalid ${type} URL format. Please check the link and try again.`);
			} else {
				throw new Error(`Unable to process ${type} content at this time. Please try another link or try again later.`);
			}
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
		// Use social media image URLs when available (Instagram and YouTube URLs are stable)
		// Only TikTok URLs expire, so we use Google Image Search for those
		let imageUrl;
		if (isYouTube && socialData?.thumbnailUrl) {
			imageUrl = socialData.thumbnailUrl;
		} else if (isInstagram && socialData?.imageUrl) {
			imageUrl = socialData.imageUrl;
		} else if (isTikTok) {
			// TikTok URLs expire quickly, so use Google Image Search
			imageUrl = await searchImage(cachedRecipe.title || "recipe");
		} else {
			// For other sources or if no stable URL exists, use Google Image Search
			imageUrl = await searchImage(cachedRecipe.title || "recipe");
		}
		
		// Filter out placeholder URLs
		if (isPlaceholderUrl(imageUrl)) {
			imageUrl = null;
		}
		
		// Validate image URL before returning (cached recipe)
		if (imageUrl) {
			console.log(`🖼️  Validating image for "${cachedRecipe.title}"...`);
			const isValid = await validateImageUrl(imageUrl);
			if (!isValid) {
				console.log(`⚠️ Image validation failed, setting to null`);
				imageUrl = null;
			} else {
				console.log(`✅ Image validated successfully`);
			}
		}
		
		logPerformance("Image fetch (from cache hit)", imageStartTime);

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
					? `You are an expert recipe analyzer. Extract the recipe from this social media post.

IMPORTANT: For ANY missing information, you MUST provide reasonable estimates based on the recipe type and ingredients. NEVER use "unknown" or leave fields empty:
- cookingTime: Estimate based on recipe complexity (e.g., "15 minutes", "1 hour", "2 hours")
- servings: Estimate based on ingredient quantities (e.g., "2", "4", "6-8")
- difficulty: Analyze the steps and assign "easy", "medium", or "hard"
- nutrition: Provide reasonable estimates per serving based on ingredients

If the recipe mentions "follow the video" or "watch the video" but lacks written instructions, create detailed step-by-step instructions based on common cooking techniques for that type of dish.`
					: `You are an expert recipe analyzer. Extract the recipe from this text.

IMPORTANT: For ANY missing information, you MUST provide reasonable estimates based on the recipe type and ingredients. NEVER use "unknown" or leave fields empty:
- cookingTime: Estimate based on recipe complexity (e.g., "15 minutes", "1 hour", "2 hours")
- servings: Estimate based on ingredient quantities (e.g., "2", "4", "6-8")
- difficulty: Analyze the steps and assign "easy", "medium", or "hard"
- nutrition: Provide reasonable estimates per serving based on ingredients`,
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
						description: "Total cooking time. NEVER use 'unknown'. Estimate if not explicitly stated (e.g., '30 minutes', '1 hour')"
					},
					difficulty: {
						type: "string",
						description: "Difficulty level: MUST be one of 'easy', 'medium', or 'hard'. Analyze the recipe to determine appropriate level."
					},
					servings: {
						type: "string",
						description: "Number of servings. NEVER use 'unknown'. Estimate based on ingredient quantities (e.g., '2', '4', '6-8')"
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
	// Use social media image URLs when available (Instagram and YouTube URLs are stable)
	// Only TikTok URLs expire, so we use Google Image Search for those
	let imageUrl;
	if (isYouTube && socialData?.thumbnailUrl) {
		imageUrl = socialData.thumbnailUrl;
	} else if (isInstagram && socialData?.imageUrl) {
		imageUrl = socialData.imageUrl;
	} else if (isTikTok) {
		// TikTok URLs expire quickly, so use Google Image Search
		imageUrl = await searchImage(parsedRecipe.title || "recipe");
	} else {
		// For other sources or if no stable URL exists, use Google Image Search
		imageUrl = await searchImage(parsedRecipe.title || "recipe");
	}
	
	// Filter out placeholder URLs
	if (isPlaceholderUrl(imageUrl)) {
		imageUrl = null;
	}
	
	// Validate image URL before returning (new recipe)
	if (imageUrl) {
		console.log(`🖼️  Validating image for "${parsedRecipe.title}"...`);
		const isValid = await validateImageUrl(imageUrl);
		if (!isValid) {
			console.log(`⚠️ Image validation failed, setting to null`);
			imageUrl = null;
		} else {
			console.log(`✅ Image validated successfully`);
		}
	}
	
	logPerformance("Image fetch (after AI parsing)", imageStartTime);

	// Clean up any "unknown" values that might slip through
	const cleanValue = (value, defaultValue) => {
		if (!value || value.toLowerCase() === 'unknown' || value.trim() === '') {
			return defaultValue;
		}
		return value;
	};

	return {
		id: uuidv4(),
		title: parsedRecipe.title || "Imported Recipe",
		ingredients: finalIngredients,
		instructions: finalInstructions,
		description: parsedRecipe.description || "Imported recipe",
		imageUrl: imageUrl || null,
		cookingTime: cleanValue(parsedRecipe.cookingTime, "30 minutes"),
		difficulty: cleanValue(parsedRecipe.difficulty, "medium"),
		servings: cleanValue(parsedRecipe.servings, "4"),
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
		isDiscoverable: true, // Imported recipes are discoverable in community
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

		// Detect social media platforms - if URL contains platform name, process it
		const isInstagram = /instagram/i.test(url);
		const isTikTok = /tiktok/i.test(url);
		const isYouTube = /youtube|youtu\.be/i.test(url);
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
		
		// Use specific error message if available, otherwise use generic message
		const userMessage = error.message && 
			(error.message.includes('TikTok') || 
			 error.message.includes('Instagram') ||
			 error.message.includes('YouTube') ||
			 error.message.includes('temporarily unavailable') ||
			 error.message.includes('Invalid') ||
			 error.message.includes('API configuration'))
			? error.message
			: "We couldn't import that link right now. Please try another link or try again shortly.";
		
		errorHandler.serverError(
			res,
			userMessage,
			error.message
		);
	}
});

// Optional: Add cache management endpoints
router.post("/cache/clear", (req, res) => {
	recipeCache.clear();
	clearImageCache(); // Clear image cache from imageService
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

	// Image cache cleanup is now handled by imageService
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
		imageCache: getImageCacheStats(), // Get stats from imageService
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
		const imageUrl = await searchImage(query, startParam);

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
