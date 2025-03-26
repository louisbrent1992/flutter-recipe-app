const express = require("express");
const router = express.Router();
const axios = require("axios");
// For calling an external AI API if needed
const cheerio = require("cheerio");
const { v4: uuidv4 } = require("uuid");
const OpenAI = require("openai");
const { z } = require("zod");
const { zodResponseFormat } = require("openai/helpers/zod");
const recipeData = require("../data/recipeData");
const puppeteer = require("puppeteer"); // Add Puppeteer

const client = new OpenAI({
	api_key: process.env.LlamaAI_API_KEY,
	base_url: process.env.LlamaAI_API_URL,
});

const recipeObjSchema = z.object({
	id: z.string(),
	name: z.string(),
	description: z.string(),
	image: z.string(),
	ingredients: z.array(z.string()),
	instructions: z.array(z.string()),
	tags: z.array(z.string()),
});

const recipesArrSchema = z.object({
	recipes: z.array(recipeObjSchema),
});

// In-memory recipes database
let recipes = [];

const PEXELS_API_KEY = process.env.PEXELS_API_KEY; // Add this to your .env file

// Image cache
const imageCache = {};

let previousIngredients = [];

// Add recipe URL cache at the top with your other cache
const recipeCache = new Map();

// Function to fetch an image from Pexels with caching
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
		const response = await axios.get(
			`https://api.pexels.com/v1/search?query=${normalizedQuery}&per_page=1`,
			{
				headers: {
					Authorization: PEXELS_API_KEY,
				},
			}
		);

		// Check if photos array exists and has items
		if (!response.data.photos || response.data.photos.length === 0) {
			console.log("No images found for query:", normalizedQuery);
			return null;
		}

		const imageUrl = response.data.photos[0].src.medium;
		imageCache[normalizedQuery] = imageUrl;
		return imageUrl;
	} catch (error) {
		console.error("Error fetching image from Pexels:", error);
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
		ingredients,
		dietaryRestrictions,
		cuisineType,
		autoFill = false,
		random = false,
	} = req.body;

	try {
		// If no ingredients or cuisine type is provided, generate a random recipe
		if (!ingredients && !cuisineType) {
			random = true;
		}

		let recipesData = [];

		if (!autoFill) {
			// Call OpenAI API to generate multiple recipes
			const response = await client.beta.chat.completions.parse({
				model: "gpt-4o-mini",
				messages: [
					{
						role: "user",
						content: `Generate three recipes that include the following:
					- Ingredients: ${
						random ? await randomIngredient() : `${ingredients}`
					} (for each recipe).
					- Dietary restrictions: ${dietaryRestrictions}.
					- Cuisine type: ${cuisineType}.
					- Additional ingredients if needed.
					`,
					},
				],
				response_format: zodResponseFormat(recipesArrSchema, "recipesData"),
			});

			recipesData = response.choices[0].message.parsed.recipes;
		} else {
			// Similar logic for autoFill if needed
			console.log("Auto-fill not implemented yet");
		}

		const generatedRecipes = await Promise.all(
			recipesData.map(async (recipeData) => {
				// Fetch an image based on the recipe title
				const imageUrl = await fetchImage(recipeData.name);

				return {
					id: uuidv4(),
					title: recipeData.name,
					ingredients: recipeData.ingredients || [],
					steps: recipeData.instructions || [],
					description: recipeData.description,
					imageUrl: imageUrl,
					tags: recipeData.tags || [],
				};
			})
		);

		// Store the generated recipes
		recipes.push(...generatedRecipes);

		res.json(generatedRecipes);
	} catch (error) {
		console.error("Error generating recipes:", error);
		res.status(500).json({ error: "Failed to generate recipes" });
	}
});

// Function to extract structured data (Schema.org/Recipe)
const extractStructuredData = ($) => {
	const jsonLd = $('script[type="application/ld+json"]')
		.contents()
		.first()
		.text();
	try {
		const data = JSON.parse(jsonLd);
		// Handle both single recipe and array of items
		const recipe = Array.isArray(data)
			? data.find((item) => item["@type"] === "Recipe")
			: data["@type"] === "Recipe"
			? data
			: null;

		if (recipe) {
			return {
				title: recipe.name,
				ingredients: recipe.recipeIngredient || [],
				instructions: recipe.recipeInstructions.map((step) =>
					typeof step === "string" ? step : step.text
				),
				description: recipe.description,
				image: recipe.image?.[0] || recipe.image,
				tags: recipe.keywords,
			};
		}
	} catch (e) {
		console.error("Error parsing structured data:", e);
	}
	return null;
};

// Function to clean HTML before sending to AI
const cleanHtmlForAI = (html) => {
	const $ = cheerio.load(html);

	// Remove unnecessary elements
	$("script").remove();
	$("style").remove();
	$("head").remove();
	$("nav").remove();
	$("footer").remove();
	$("header").remove();
	$("aside").remove();
	$(".sidebar").remove();
	$(".advertisement").remove();
	$(".comments").remove();

	// Get only the main content area
	const mainContent = $(
		"main, article, .content, .recipe-content, .post-content"
	).first();
	return mainContent.length ? mainContent.html() : $.html();
};

// Updated parseWithAI function
const parseWithAI = async (html) => {
	try {
		// Clean and trim HTML before sending to AI
		const cleanedHtml = cleanHtmlForAI(html);

		const response = await client.beta.chat.completions.parse({
			model: "gpt-4o-mini",
			messages: [
				{
					role: "system",
					content:
						"Extract recipe details from the HTML. Return title, ingredients (array), instructions (array), description, and tags (array).",
				},
				{
					role: "user",
					content: cleanedHtml,
				},
			],
			response_format: zodResponseFormat(recipeObjSchema, "recipe"),
		});

		return response.choices[0].message.parsed;
	} catch (error) {
		console.error("Error parsing with AI:", error);
		return null;
	}
};

// Add this helper function
const getPageText = async (page) => {
	// Get all text content from the page
	const text = await page.evaluate(() => {
		// Remove scripts and styles first
		const scripts = document.getElementsByTagName("script");
		const styles = document.getElementsByTagName("style");
		Array.from(scripts).forEach((script) => script.remove());
		Array.from(styles).forEach((style) => style.remove());

		// Get main content if it exists
		const main = document.querySelector(
			"main, article, .content, .recipe-content, .post-content"
		);
		if (main) {
			return main.innerText;
		}
		// Fallback to body text
		return document.body.innerText;
	});
	return text;
};

// Helper function to parse recipe data
const parseRecipeData = async (html, pageText) => {
	const $ = cheerio.load(html);

	// Try structured data first
	const structuredData = extractStructuredData($);
	if (structuredData) return structuredData;

	// Fallback to AI parsing with page text
	const response = await client.beta.chat.completions.parse({
		model: "gpt-4o-mini",
		messages: [
			{
				role: "system",
				content:
					"Extract recipe details from this text. Return title (string), ingredients (array), instructions (array), description (string), and tags (array).",
			},
			{
				role: "user",
				content: pageText,
			},
		],
		response_format: zodResponseFormat(recipeObjSchema, "recipe"),
	});

	return response.choices[0].message.parsed;
};

// Simplified import endpoint
router.post("/import", async (req, res) => {
	const { url } = req.body;

	try {
		// Check cache first
		if (recipeCache.has(url)) {
			console.log("Recipe found in cache");
			return res.json(recipeCache.get(url));
		}

		// Launch and configure browser
		const browser = await puppeteer.launch({
			headless: "new",
			args: ["--no-sandbox"],
		});
		const page = await browser.newPage();
		page.setDefaultNavigationTimeout(15000);

		// Block unnecessary resources
		await page.setRequestInterception(true);
		page.on("request", (request) => {
			if (
				["image", "stylesheet", "font", "media", "other"].includes(
					request.resourceType()
				)
			) {
				request.abort();
			} else {
				request.continue();
			}
		});

		// Get page content
		await page.goto(url, { waitUntil: "domcontentloaded" });
		const [html, pageText] = await Promise.all([
			page.content(),
			getPageText(page),
		]);
		await browser.close();

		// Parse recipe data
		const recipeData = await parseRecipeData(html, pageText);
		if (!recipeData) {
			throw new Error("Unable to parse recipe from URL");
		}

		// Format and cache recipe
		const importedRecipe = {
			id: uuidv4(),
			title: recipeData.title || recipeData.name || "Imported Recipe",
			ingredients: Array.isArray(recipeData.ingredients)
				? recipeData.ingredients
				: [],
			instructions: Array.isArray(recipeData.instructions)
				? recipeData.instructions
				: [],
			description: recipeData.description || "Imported recipe",
			imageUrl:
				recipeData.image ||
				(await fetchImage(recipeData.title || recipeData.name || "recipe")) ||
				null,
			sourceUrl: url,
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
	res.json({ message: "Cache cleared successfully" });
});

module.exports = router;
