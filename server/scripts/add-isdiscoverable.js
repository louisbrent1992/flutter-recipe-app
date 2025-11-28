/**
 * Migration Script: Add isDiscoverable field to existing recipes
 * 
 * This script scans all recipes in the database and adds the `isDiscoverable` field:
 * - Sets `isDiscoverable: true` for AI-generated recipes (aiGenerated === true)
 * - Sets `isDiscoverable: true` for imported recipes (has sourcePlatform: instagram, tiktok, or youtube)
 * - Sets `isDiscoverable: false` for manually created recipes (has userId but no aiGenerated and no sourcePlatform)
 * - Leaves Spoonacular recipes unchanged (isExternal === true, no userId)
 */

const admin = require('firebase-admin');
const path = require('path');
require('dotenv').config();

// Initialize Firebase Admin
const { initFirebase } = require('../config/firebase.js');
initFirebase();

const db = admin.firestore();

/**
 * Determine if a recipe should be discoverable
 */
function shouldBeDiscoverable(recipe) {
  // Spoonacular recipes (isExternal === true) - not discoverable (they're in Discover screen)
  if (recipe.isExternal === true) {
    return false;
  }

  // AI-generated recipes - discoverable
  if (recipe.aiGenerated === true) {
    return true;
  }

  // Imported recipes (have sourcePlatform) - discoverable
  if (recipe.sourcePlatform && 
      (recipe.sourcePlatform === 'instagram' || 
       recipe.sourcePlatform === 'tiktok' || 
       recipe.sourcePlatform === 'youtube')) {
    return true;
  }

  // Manually created recipes (have userId but no aiGenerated and no sourcePlatform) - not discoverable
  if (recipe.userId && !recipe.aiGenerated && !recipe.sourcePlatform) {
    return false;
  }

  // Default: if it has a userId and we're not sure, make it discoverable (safer default)
  // This handles edge cases where recipes might have been imported but don't have sourcePlatform set
  return !!recipe.userId;
}

/**
 * Main migration function
 */
async function addIsDiscoverableField() {
  try {
    console.log('🚀 Starting migration: Adding isDiscoverable field to recipes...\n');

    const recipesRef = db.collection('recipes');
    const snapshot = await recipesRef.get();
    
    if (snapshot.empty) {
      console.log('📭 No recipes found in database');
      return;
    }

    console.log(`📊 Found ${snapshot.size} recipes to process\n`);

    let updated = 0;
    let skipped = 0;
    let errors = 0;
    let batch = db.batch();
    let batchCount = 0;
    const BATCH_SIZE = 500; // Firestore batch limit

    for (const doc of snapshot.docs) {
      try {
        const recipe = doc.data();
        const recipeId = doc.id;

        // Determine if recipe should be discoverable
        const isDiscoverable = shouldBeDiscoverable(recipe);

        // Skip if isDiscoverable already exists and matches the desired value
        if (recipe.isDiscoverable === isDiscoverable) {
          skipped++;
          continue;
        }

        // Add to batch update
        const recipeRef = recipesRef.doc(recipeId);
        batch.update(recipeRef, {
          isDiscoverable: isDiscoverable,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        batchCount++;
        updated++;

        // Log details for recipes being updated (especially imported ones)
        if (updated <= 10 || (recipe.sourcePlatform && updated <= 20)) {
          console.log(`   📝 Recipe "${recipe.title?.substring(0, 40)}..." (${recipeId})`);
          console.log(`      - aiGenerated: ${recipe.aiGenerated || false}`);
          console.log(`      - sourcePlatform: ${recipe.sourcePlatform || 'none'}`);
          console.log(`      - userId: ${recipe.userId ? 'yes' : 'no'}`);
          console.log(`      - isExternal: ${recipe.isExternal || false}`);
          console.log(`      - Previous isDiscoverable: ${recipe.isDiscoverable}`);
          console.log(`      - Setting isDiscoverable: ${isDiscoverable}\n`);
        }

        // Commit batch if we've reached the limit
        if (batchCount >= BATCH_SIZE) {
          await batch.commit();
          console.log(`   ✅ Committed batch of ${BATCH_SIZE} updates (Total updated: ${updated})`);
          batch = db.batch(); // Create new batch
          batchCount = 0;
        }
      } catch (error) {
        errors++;
        console.error(`   ❌ Error processing recipe ${doc.id}:`, error.message);
      }
    }

    // Commit remaining batch
    if (batchCount > 0) {
      await batch.commit();
      console.log(`   ✅ Committed final batch of ${batchCount} updates\n`);
    }

    console.log('✅ Migration completed!\n');
    console.log(`📊 Summary:`);
    console.log(`   - Total recipes processed: ${snapshot.size}`);
    console.log(`   - Updated: ${updated}`);
    console.log(`   - Skipped (already had field): ${skipped}`);
    console.log(`   - Errors: ${errors}\n`);

  } catch (error) {
    console.error('❌ Migration failed:', error);
    process.exit(1);
  }
}

// Run the migration
addIsDiscoverableField()
  .then(() => {
    console.log('🎉 Migration script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('💥 Migration script failed:', error);
    process.exit(1);
  });

