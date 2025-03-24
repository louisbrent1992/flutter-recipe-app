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

const recipeSchema = z.object({
	name: z.string(),
	image: z.string(),
	ingredients: z.array(z.string()),
	instructions: z.array(z.string()),
});

const recipesSchema = z.array({
	id: z.array(recipeSchema),
	id: z.array(recipeSchema),
	id: z.array(recipeSchema),
});

// In-memory recipes database
let recipes = [];

const UNSPLASH_ACCESS_KEY = process.env.UNSPLASH_ACCESS_KEY; // Use environment variable
const UNSPLASH_API_URL = "https://api.unsplash.com/photos/random";

// Image cache
const imageCache = {};

let previousIngredients = [];

// Function to fetch an image from Unsplash with caching
const fetchImage = async (query) => {
	// Normalize the query by trimming and converting to lowercase
	const normalizedQuery = query.trim().toLowerCase();

	// Check if the image is already cached
	if (imageCache[normalizedQuery]) {
		return imageCache[normalizedQuery]; // Return cached image URL
	}

	try {
		const response = await axios.get(UNSPLASH_API_URL, {
			params: {
				query: normalizedQuery,
				collections: "food",
				client_id: UNSPLASH_ACCESS_KEY,
			},
		});
		const imageUrl = response.data.urls.regular; // Return the regular size image URL

		// Cache the image URL using the normalized query
		imageCache[normalizedQuery] = imageUrl;

		return imageUrl;
	} catch (error) {
		console.error("Error fetching image from Unsplash:", error);
		return null; // Return null if there's an error
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
		ingredients = "",
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
				response_format: zodResponseFormat(
					z.array(recipesSchema),
					"recipesData"
				),
			});

			recipesData = response.choices[0].message.parsed;
		} else {
			// Similar logic for autoFill if needed
		}

		const generatedRecipes = await Promise.all(
			recipesData.map(async (recipeData) => {
				// Fetch an image based on the recipe title
				const imageUrl = await fetchImage(recipeData.name);

				return {
					id: uuidv4(),
					title: recipeData.name || "Generated Recipe",
					ingredients: recipeData.ingredients || [],
					steps: recipeData.instructions || [],
					description: recipeData.description || "Enjoy your generated recipe!",
					imageUrl: imageUrl,
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

// POST /recipes/import - Social media recipe import parser
router.post("/import", async (req, res) => {
	const { url } = req.body;

	try {
		// Launch Puppeteer browser
		const browser = await puppeteer.launch();
		const page = await browser.newPage();

		// Block images and stylesheets to speed up page loading
		await page.setRequestInterception(true);
		page.on("request", (request) => {
			if (["image", "stylesheet", "font"].includes(request.resourceType())) {
				request.abort();
			} else {
				request.continue();
			}
		});

		// Navigate to the URL
		await page.goto(url, { waitUntil: "domcontentloaded" });

		// Get the HTML content of the page
		const html = await page.content();

		// Close the browser
		await browser.close();

		// Load the HTML into cheerio
		const $ = cheerio.load(html);

		// Extract recipe data using selectors
		const title =
			$('meta[property="og:title"]').attr("content") || $("title").text();
		const ingredients = [];
		$("ul.ingredients li, .ingredient").each((i, elem) => {
			ingredients.push($(elem).text().trim());
		});
		const steps = [];
		$("ol.steps li, .step").each((i, elem) => {
			steps.push($(elem).text().trim());
		});
		const description = $('meta[name="description"]').attr("content") || "";
		const imageUrl = $('meta[property="og:image"]').attr("content") || "";

		const importedRecipe = {
			id: uuidv4(),
			title: title || "Imported Recipe",
			ingredients: ingredients,
			steps: steps,
			description: description || "Enjoy your imported recipe!",
			imageUrl: imageUrl,
		};

		recipes.push(importedRecipe);

		res.json(importedRecipe);
	} catch (error) {
		console.error("Error importing recipe:", error);
		res.status(500).json({ error: "Failed to import recipe" });
	}
});

module.exports = router;
