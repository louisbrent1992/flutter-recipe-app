const express = require("express");
const router = express.Router();
const axios = require("axios"); // For calling an external AI API if needed
const { v4: uuidv4 } = require("uuid");
const OpenAI = require("openai");
const recipeData = require("../data/recipeData");

const client = new OpenAI({
	api_key: process.env.Llame_API_KEY,
	base_url: process.env.LlamaAI_API_URL,
});

// In-memory recipes database
let recipes = [];

const UNSPLASH_ACCESS_KEY = process.env.UNSPLASH_ACCESS_KEY; // Use environment variable
const UNSPLASH_API_URL = "https://api.unsplash.com/photos/random";

// Image cache
const imageCache = {};

let previousIngredients = [];

// GET /recipes - Fetch all recipes
router.get("/", (req, res) => {
	res.json(recipes);
});

// GET /recipes/:id - Get a specific recipe
router.get("/:id", (req, res) => {
	const recipe = recipes.find((r) => r.id === req.params.id);
	if (recipe) {
		res.json(recipe);
	} else {
		res.status(404).json({ error: "Recipe not found" });
	}
});

// POST /recipes - Create a new recipe
router.post("/", (req, res) => {
	const newRecipe = { id: uuidv4(), ...req.body };
	recipes.push(newRecipe);
	res.status(201).json(newRecipe);
});

// PUT /recipes/:id - Update an existing recipe
router.put("/:id", (req, res) => {
	const index = recipes.findIndex((r) => r.id === req.params.id);
	if (index !== -1) {
		recipes[index] = { ...recipes[index], ...req.body };
		res.json(recipes[index]);
	} else {
		res.status(404).json({ error: "Recipe not found" });
	}
});

// DELETE /recipes/:id - Delete a recipe
router.delete("/:id", (req, res) => {
	const index = recipes.findIndex((r) => r.id === req.params.id);
	if (index !== -1) {
		const deleted = recipes.splice(index, 1);
		res.json(deleted[0]);
	} else {
		res.status(404).json({ error: "Recipe not found" });
	}
});

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
	const { ingredients = "", dietaryRestrictions, cuisineType } = req.body;

	try {
		let random = false;
		if (!ingredients && !cuisineType) {
			random = true;
		}

		// Call OpenAI API to generate a recipe
		const response = await client.chat.completions.create({
			model: "gpt-4o-mini",
			messages: [
				{
					role: "user",
					content: `Generate a recipe that includes the following:
					- Ingredients: ${random ? await randomIngredient() : `${ingredients}`}.
					- Dietary restrictions: ${dietaryRestrictions}.
					- Cuisine type: ${cuisineType}.
					- Additional ingredients.
					The recipe should be in JSON format as follows:
					{
						"title": "Recipe Name",
						"ingredients": ["ingredient 1", "ingredient 2", "ingredient 3"],
						"steps": ["step 1", "step 2", "step 3"],
						"description": "A unique dish."
					}`,
				},
			],
			response_format: { type: "json_object" },
			temperature: 0.7,
		});

		const generatedContent = response.choices[0].message.content;
		const foundRecipe = JSON.parse(generatedContent);

		// Fetch an image based on the recipe title
		const imageUrl = await fetchImage(foundRecipe.title);

		const generatedRecipe = {
			id: uuidv4(),
			title: foundRecipe.title || "Generated Recipe",
			ingredients: foundRecipe.ingredients || [],
			steps: foundRecipe.steps || [],
			description: foundRecipe.description || "Enjoy your generated recipe!",
			imageUrl: imageUrl,
		};

		// Store the generated recipe
		recipes.push(generatedRecipe);

		res.json(generatedRecipe);
	} catch (error) {
		console.error("Error generating recipe:", error);
		res.status(500).json({ error: "Failed to generate recipe" });
	}
});

// POST /recipes/import - Social media recipe import parser
router.post("/import", async (req, res) => {
	const { url } = req.body;

	// Dummy parsing logic: In a real scenario, perform web scraping or use an API
	const importedRecipe = {
		id: uuidv4(),
		title: "Imported Recipe from Social Media",
		ingredients: ["1 cup flour", "2 eggs", "1/2 cup milk"],
		steps: ["Mix ingredients", "Cook on a skillet", "Serve warm"],
		description:
			"This recipe was imported and parsed from a social media post.",
		imageUrl: await fetchImage("recipe"), // Fetch an image for the imported recipe
	};

	recipes.push(importedRecipe);

	res.json(importedRecipe);
});

module.exports = router;
