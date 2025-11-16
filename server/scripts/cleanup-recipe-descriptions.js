/**
 * Cleanup Script: Remove "Try" and similar recipe sections from Spoonacular recipe descriptions
 * 
 * This script:
 * 1. Fetches only Spoonacular recipes (isExternal: true) from Firestore
 * 2. Checks if their descriptions need cleaning
 * 3. Updates recipes in batches (500 at a time for efficiency)
 * 4. Provides progress reporting
 * 
 * Usage: node server/scripts/cleanup-recipe-descriptions.js
 * 
 * Note: This script only targets Spoonacular recipes, as they are the ones
 * that contain the problematic "Try" and "Users who liked" sections.
 * Uses Firestore batch writes (max 500 operations per batch) to efficiently
 * update recipes without hitting rate limits.
 */

require("dotenv").config({ path: require("path").join(__dirname, "../.env") });
const admin = require("firebase-admin");
const { cleanRecipeDescription } = require("../utils/recipeUtils");

// Initialize Firebase
require("../config/firebase").initFirebase();

const db = admin.firestore();
const BATCH_SIZE = 500; // Firestore batch limit

async function cleanupRecipeDescriptions() {
	console.log("🧹 Starting recipe description cleanup...\n");

	try {
		// Fetch only Spoonacular recipes (identified by isExternal: true)
		console.log("📥 Fetching Spoonacular recipes from Firestore...");
		const recipesSnapshot = await db
			.collection("recipes")
			.where("isExternal", "==", true)
			.get();
		const totalRecipes = recipesSnapshot.size;
		console.log(`   Found ${totalRecipes} Spoonacular recipes\n`);

		if (totalRecipes === 0) {
			console.log("✅ No Spoonacular recipes found. Exiting.");
			return;
		}

		// Process recipes and identify which need cleaning
		console.log("🔍 Analyzing recipes...");
		const recipesToUpdate = [];
		let analyzedCount = 0;

		recipesSnapshot.forEach((doc) => {
			analyzedCount++;
			const recipe = doc.data();
			const originalDescription = recipe.description || "";
			const cleanedDescription = cleanRecipeDescription(originalDescription);

			// Only add to update list if description changed
			if (originalDescription !== cleanedDescription) {
				recipesToUpdate.push({
					id: doc.id,
					title: recipe.title || "Unknown",
					originalLength: originalDescription.length,
					cleanedLength: cleanedDescription.length,
					cleanedDescription,
				});
			}

			// Progress indicator every 1000 recipes
			if (analyzedCount % 1000 === 0) {
				process.stdout.write(`   Analyzed ${analyzedCount}/${totalRecipes} recipes...\r`);
			}
		});

		console.log(`\n   Analysis complete: ${recipesToUpdate.length} recipes need cleaning\n`);

		if (recipesToUpdate.length === 0) {
			console.log("✅ All Spoonacular recipes are already clean. No updates needed.");
			return;
		}

		// Show some examples
		console.log("📋 Sample recipes that will be updated:");
		const samples = recipesToUpdate.slice(0, 5);
		samples.forEach((recipe) => {
			console.log(`   - "${recipe.title}" (ID: ${recipe.id})`);
			console.log(`     Original: ${recipe.originalLength} chars → Cleaned: ${recipe.cleanedLength} chars`);
		});
		if (recipesToUpdate.length > 5) {
			console.log(`   ... and ${recipesToUpdate.length - 5} more\n`);
		} else {
			console.log();
		}

		// Confirm before proceeding
		console.log(`⚠️  About to update ${recipesToUpdate.length} recipes.`);
		console.log("   This will modify the 'description' field in Firestore.\n");

		// In a real scenario, you might want to add a confirmation prompt here
		// For now, we'll proceed automatically (you can add readline for interactive confirmation)

		// Update recipes in batches
		console.log("💾 Updating recipes in batches...\n");
		let updatedCount = 0;
		let errorCount = 0;
		const batches = [];

		// Create batches
		for (let i = 0; i < recipesToUpdate.length; i += BATCH_SIZE) {
			batches.push(recipesToUpdate.slice(i, i + BATCH_SIZE));
		}

		// Process each batch
		for (let batchIndex = 0; batchIndex < batches.length; batchIndex++) {
			const batch = batches[batchIndex];
			const firestoreBatch = db.batch();

			batch.forEach((recipe) => {
				const recipeRef = db.collection("recipes").doc(recipe.id);
				firestoreBatch.update(recipeRef, {
					description: recipe.cleanedDescription,
					updatedAt: admin.firestore.FieldValue.serverTimestamp(),
				});
			});

			try {
				await firestoreBatch.commit();
				updatedCount += batch.length;
				console.log(
					`   ✅ Batch ${batchIndex + 1}/${batches.length}: Updated ${batch.length} recipes (${updatedCount}/${recipesToUpdate.length} total)`
				);
			} catch (error) {
				errorCount += batch.length;
				console.error(
					`   ❌ Batch ${batchIndex + 1}/${batches.length}: Error updating ${batch.length} recipes:`,
					error.message
				);
			}

			// Small delay between batches to avoid rate limiting
			if (batchIndex < batches.length - 1) {
				await new Promise((resolve) => setTimeout(resolve, 100));
			}
		}

		// Summary
		console.log("\n" + "=".repeat(60));
		console.log("📊 Cleanup Summary:");
		console.log(`   Total Spoonacular recipes analyzed: ${totalRecipes}`);
		console.log(`   Recipes needing cleanup: ${recipesToUpdate.length}`);
		console.log(`   Successfully updated: ${updatedCount}`);
		console.log(`   Errors: ${errorCount}`);
		console.log("=".repeat(60));

		if (errorCount === 0) {
			console.log("\n✅ Cleanup completed successfully!");
		} else {
			console.log(`\n⚠️  Cleanup completed with ${errorCount} errors.`);
		}
	} catch (error) {
		console.error("\n❌ Fatal error during cleanup:", error);
		process.exit(1);
	}
}

// Run the cleanup
if (require.main === module) {
	cleanupRecipeDescriptions()
		.then(() => {
			console.log("\n👋 Script finished. Exiting...");
			process.exit(0);
		})
		.catch((error) => {
			console.error("\n❌ Unhandled error:", error);
			process.exit(1);
		});
}

module.exports = { cleanupRecipeDescriptions };

