/**
 * Script to find and replace expired TikTok images in discover recipes
 * TikTok CDN URLs expire and cause 403 errors
 * This script replaces them with Google Image Search results
 */

const admin = require('firebase-admin');
require('dotenv').config();

// Initialize Firebase Admin
const { initFirebase } = require('../config/firebase.js');
const { searchImage, getDefaultImage } = require('../utils/imageService');

initFirebase();

const db = admin.firestore();

/**
 * Check if a URL is a TikTok CDN URL
 */
function isTikTokImage(url) {
  if (!url) return false;
  return url.includes('tiktokcdn') || url.includes('tiktok.com');
}

/**
 * Find and fix recipes with TikTok images
 */
async function fixTikTokImages() {
  console.log('🔍 Searching for recipes with TikTok images...\n');
  
  try {
    const recipesRef = db.collection('recipes');
    const snapshot = await recipesRef.get();
    
    let tiktokCount = 0;
    let fixedCount = 0;
    let errors = [];
    
    console.log(`📊 Total recipes to check: ${snapshot.size}\n`);
    
    for (const doc of snapshot.docs) {
      const recipe = doc.data();
      
      if (isTikTokImage(recipe.imageUrl)) {
        tiktokCount++;
        const recipeTitle = recipe.title || 'Unknown Recipe';
        
        console.log(`🎯 Found TikTok image in: ${recipeTitle}`);
        console.log(`   ID: ${doc.id}`);
        console.log(`   Old URL: ${recipe.imageUrl.substring(0, 80)}...`);
        
        // Try to find a replacement image using Google Image Search
        let newImageUrl = null;
        
        if (recipe.title) {
          console.log(`   🔎 Searching Google Images for: ${recipe.title}`);
          newImageUrl = await searchImage(`${recipe.title} recipe`, 1, false);
          
          // If no results, try with cuisine type (if available)
          if (!newImageUrl && recipe.cuisineType) {
            console.log(`   🔎 Trying with cuisine type: ${recipe.cuisineType}`);
            newImageUrl = await searchImage(`${recipe.cuisineType} food recipe`, 1, false);
          }
          
          // If still no results and no cuisineType, try generic food search
          if (!newImageUrl && !recipe.cuisineType) {
            console.log(`   🔎 No cuisineType, trying generic food search`);
            newImageUrl = await searchImage('delicious food dish recipe', 1, false);
          }
        }
        
        // Fallback to Unsplash only if Google fails
        if (!newImageUrl) {
          const fallbackType = recipe.cuisineType || 'default';
          console.log(`   📸 Google Search failed, using Unsplash fallback: ${fallbackType}`);
          newImageUrl = getDefaultImage(recipe.cuisineType);
        }
        
        // Update the recipe
        if (newImageUrl) {
          await doc.ref.update({
            imageUrl: newImageUrl,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          
          console.log(`   ✅ Updated with: ${newImageUrl.substring(0, 80)}...`);
          fixedCount++;
        } else {
          errors.push({ id: doc.id, title: recipeTitle });
          console.log(`   ❌ Failed to find replacement image`);
        }
        
        console.log('');
        
        // Rate limiting - wait between requests
        await new Promise(resolve => setTimeout(resolve, 1000));
      }
    }
    
    // Summary
    console.log('\n' + '='.repeat(60));
    console.log('📋 SUMMARY');
    console.log('='.repeat(60));
    console.log(`✅ Fixed: ${fixedCount} recipes`);
    console.log(`🔍 TikTok images found: ${tiktokCount}`);
    console.log(`❌ Errors: ${errors.length}`);
    
    if (errors.length > 0) {
      console.log('\n⚠️  Recipes that failed to update:');
      errors.forEach(err => console.log(`   - ${err.title} (${err.id})`));
    }
    
    console.log('\n✨ Done!');
    
  } catch (error) {
    console.error('❌ Error:', error);
    throw error;
  }
}

// Run the script
fixTikTokImages()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });

