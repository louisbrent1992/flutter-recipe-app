/**
 * API Test Utility
 *
 * Comprehensive test script for Recipe App API
 * Tests both AI-generated recipes and user-specific recipes
 *
 * Usage:
 * 1. For AI recipe tests: node test-api.js ai
 * 2. For user recipe tests: node test-api.js user <firebase-id-token>
 * 3. For all tests: node test-api.js all <firebase-id-token>
 */

require("dotenv").config();
const axios = require("axios");
const { initFirebase } = require("./config/firebase");

// Initialize Firebase
initFirebase();

// Constants
const API_BASE_URL = "http://localhost:3001/api";
const INSTAGRAM_TEST_URL = "https://www.instagram.com/p/CqQFDxTOKtd/";

// Display usage information
function showUsage() {
	console.log(`
Usage:
  1. For AI recipe tests: node test-api.js ai
  2. For user recipe tests: node test-api.js user <firebase-id-token>
  3. For all tests: node test-api.js all <firebase-id-token>
  `);
	process.exit(1);
}

// Test AI recipe endpoints
async function testAiRecipes() {
	try {
		console.log("🧪 Testing AI Recipes API");
		console.log("========================");

		// 1. Generate recipe with random ingredient
		console.log("\n🔄 Generating recipe with random ingredient...");
		const generateRandomResponse = await axios.post(
			`${API_BASE_URL}/ai/recipes/generate`,
			{ random: true }
		);

		console.log(`✅ Generated ${generateRandomResponse.data.length} recipes`);
		console.log(`First recipe: ${generateRandomResponse.data[0].title}`);

		// 2. Generate recipe with specific ingredients
		console.log("\n🍳 Generating recipe with specific ingredients...");
		const generateSpecificResponse = await axios.post(
			`${API_BASE_URL}/ai/recipes/generate`,
			{
				ingredients: ["chicken", "broccoli", "garlic"],
				cuisineType: "Asian",
				dietaryRestrictions: ["gluten-free"],
			}
		);

		console.log(`✅ Generated ${generateSpecificResponse.data.length} recipes`);
		console.log(`First recipe: ${generateSpecificResponse.data[0].title}`);
		console.log(
			`Cuisine type: ${generateSpecificResponse.data[0].cuisineType}`
		);

		// 3. Import recipe from Instagram
		console.log("\n📱 Importing recipe from Instagram...");
		try {
			const importResponse = await axios.post(
				`${API_BASE_URL}/ai/recipes/import`,
				{ url: INSTAGRAM_TEST_URL },
				{ timeout: 20000 } // Extended timeout for AI processing
			);

			console.log(`✅ Imported recipe: ${importResponse.data.title}`);
			console.log(`Source: ${importResponse.data.source}`);
			if (importResponse.data.instagram) {
				console.log(
					`Instagram username: ${importResponse.data.instagram.username}`
				);
			}
		} catch (importError) {
			console.log(
				"⚠️ Instagram import failed (possibly demo URL not available)"
			);
			console.log(importError.message);
		}

		// 4. Check cache status
		console.log("\n🔍 Checking cache status...");
		const cacheResponse = await axios.get(
			`${API_BASE_URL}/ai/recipes/cache/status`
		);

		console.log("✅ Cache status:");
		console.log(
			`AI Cache: ${cacheResponse.data.aiCache.size}/${cacheResponse.data.aiCache.maxSize}`
		);
		console.log(
			`Recipe Cache: ${cacheResponse.data.recipeCache.size}/${cacheResponse.data.recipeCache.maxSize}`
		);
		console.log(
			`Image Cache: ${cacheResponse.data.imageCache.size}/${cacheResponse.data.imageCache.maxSize}`
		);

		console.log("\n🎉 All AI recipe tests completed successfully!");
		return true;
	} catch (error) {
		console.error("\n❌ AI recipe tests failed:");
		if (error.response) {
			console.error("Status:", error.response.status);
			console.error("Response:", error.response.data);
		} else {
			console.error(error.message);
		}
		return false;
	}
}

// Test user recipe endpoints
async function testUserRecipes(idToken) {
	if (!idToken) {
		console.error("Error: Firebase ID token is required for user recipe tests");
		return false;
	}

	const headers = {
		Authorization: `Bearer ${idToken}`,
		"Content-Type": "application/json",
	};

	try {
		console.log("🧪 Testing User Recipes API");
		console.log("==========================");

		// 1. Create a new recipe
		console.log("\n📝 Creating a new recipe...");
		const createResponse = await axios.post(
			`${API_BASE_URL}/user/recipes`,
			{
				title: "Test Recipe",
				description: "A recipe for testing the API",
				ingredients: ["Ingredient 1", "Ingredient 2", "Ingredient 3"],
				instructions: ["Step 1", "Step 2", "Step 3"],
				cuisineType: "Test",
				cookingTime: "30 minutes",
				difficulty: "easy",
				servings: "2",
				tags: ["test", "api"],
			},
			{ headers }
		);

		const createdRecipe = createResponse.data;
		console.log(`✅ Recipe created with ID: ${createdRecipe.id}`);
		console.log(`Title: ${createdRecipe.title}`);

		// 2. Get all recipes
		console.log("\n📋 Getting all recipes...");
		const getAllResponse = await axios.get(`${API_BASE_URL}/user/recipes`, {
			headers,
		});
		console.log(`✅ Found ${getAllResponse.data.length} recipes`);

		// 3. Get the specific recipe
		console.log(`\n🔍 Getting recipe with ID: ${createdRecipe.id}...`);
		const getOneResponse = await axios.get(
			`${API_BASE_URL}/user/recipes/${createdRecipe.id}`,
			{ headers }
		);
		console.log(`✅ Retrieved recipe: ${getOneResponse.data.title}`);

		// 4. Update the recipe
		console.log("\n✏️ Updating recipe...");
		const updateResponse = await axios.put(
			`${API_BASE_URL}/user/recipes/${createdRecipe.id}`,
			{
				title: "Updated Test Recipe",
				description: "This recipe has been updated",
			},
			{ headers }
		);
		console.log(`✅ Recipe updated: ${updateResponse.data.title}`);

		// 5. Toggle favorite status
		console.log("\n⭐ Setting as favorite...");
		await axios.put(
			`${API_BASE_URL}/user/recipes/${createdRecipe.id}/favorite`,
			{ isFavorite: true },
			{ headers }
		);
		console.log("✅ Recipe marked as favorite");

		// 6. Get favorites
		console.log("\n🌟 Getting favorite recipes...");
		const favoritesResponse = await axios.get(
			`${API_BASE_URL}/user/recipes/favorites`,
			{ headers }
		);
		console.log(`✅ Found ${favoritesResponse.data.length} favorite recipes`);

		// 7. Delete the recipe
		console.log(`\n🗑️ Deleting recipe with ID: ${createdRecipe.id}...`);
		await axios.delete(`${API_BASE_URL}/user/recipes/${createdRecipe.id}`, {
			headers,
		});
		console.log("✅ Recipe deleted successfully");

		// 8. Verify deletion
		console.log("\n🔍 Verifying deletion...");
		try {
			await axios.get(`${API_BASE_URL}/user/recipes/${createdRecipe.id}`, {
				headers,
			});
			console.log("❌ Error: Recipe still exists");
			return false;
		} catch (error) {
			if (error.response && error.response.status === 404) {
				console.log("✅ Verified: Recipe no longer exists");
			} else {
				throw error;
			}
		}

		console.log("\n🎉 All user recipe tests completed successfully!");
		return true;
	} catch (error) {
		console.error("\n❌ User recipe tests failed:");
		if (error.response) {
			console.error("Status:", error.response.status);
			console.error("Response:", error.response.data);
		} else {
			console.error(error.message);
		}
		return false;
	}
}

// Main function to run tests based on command line args
async function main() {
	const args = process.argv.slice(2);

	if (args.length === 0) {
		showUsage();
	}

	const command = args[0].toLowerCase();
	const idToken = args[1];

	let aiSuccess = true;
	let userSuccess = true;

	try {
		if (command === "ai" || command === "all") {
			aiSuccess = await testAiRecipes();
		}

		if (command === "user" || command === "all") {
			if (!idToken) {
				console.error(
					"Error: Firebase ID token is required for user recipe tests"
				);
				showUsage();
			}
			userSuccess = await testUserRecipes(idToken);
		}

		if (command !== "ai" && command !== "user" && command !== "all") {
			console.error(`Unknown command: ${command}`);
			showUsage();
		}

		// Exit with appropriate code
		if (aiSuccess && userSuccess) {
			process.exit(0);
		} else {
			process.exit(1);
		}
	} catch (error) {
		console.error("Unexpected error:", error);
		process.exit(1);
	}
}

// Run the main function
main();
