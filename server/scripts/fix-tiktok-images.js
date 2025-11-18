/**
 * Script to find and replace expired TikTok images in discover recipes
 * TikTok CDN URLs expire and cause 403 errors
 * This script replaces them with Google Image Search results
 */

const admin = require('firebase-admin');
const axios = require('axios');
const path = require('path');
require('dotenv').config();

// Initialize Firebase Admin
const { initFirebase } = require('../config/firebase.js');
initFirebase();

const db = admin.firestore();

/**
 * Search for an image using Google Custom Search API
 */
async function searchGoogleImage(query) {
  try {
    const apiKey = process.env.GOOGLE_API_KEY;
    const searchEngineId = process.env.GOOGLE_CX;
    
    if (!apiKey || !searchEngineId) {
      console.log('⚠️  Google Search API credentials not found');
      return null;
    }

    const url = 'https://www.googleapis.com/customsearch/v1';
    const params = {
      key: apiKey,
      cx: searchEngineId,
      q: `${query} recipe`,
      searchType: 'image',
      num: 1,
      imgSize: 'large',
      safe: 'active',
    };

    console.log(`   🔍 Calling Google Custom Search API...`);
    const response = await axios.get(url, { params, timeout: 10000 });
    
    if (response.data.items && response.data.items.length > 0) {
      const imageUrl = response.data.items[0].link;
      console.log(`   ✅ Found image from Google: ${imageUrl.substring(0, 60)}...`);
      return imageUrl;
    }
    
    console.log(`   ⚠️  No images found in Google results`);
    return null;
  } catch (error) {
    console.error(`   ❌ Error searching for image: ${error.message}`);
    return null;
  }
}

/**
 * Get a default recipe image based on cuisine type
 */
function getDefaultImage(cuisineType) {
  const defaults = {
    'Italian': 'https://images.unsplash.com/photo-1621996346565-e3dbc646d9a9?w=800',
    'Mexican': 'https://images.unsplash.com/photo-1565299585323-38d6b0865b47?w=800',
    'Asian': 'https://images.unsplash.com/photo-1617196034796-73dfa7b1fd56?w=800',
    'American': 'https://images.unsplash.com/photo-1568901346375-23c9450c58cd?w=800',
    'Mediterranean': 'https://images.unsplash.com/photo-1529042410759-befb1204b468?w=800',
    'default': 'https://images.unsplash.com/photo-1495521821757-a1efb6729352?w=800',
  };
  
  return defaults[cuisineType] || defaults.default;
}

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
          newImageUrl = await searchGoogleImage(recipe.title);
          
          // If no results, try with cuisine type (if available)
          if (!newImageUrl && recipe.cuisineType) {
            console.log(`   🔎 Trying with cuisine type: ${recipe.cuisineType}`);
            newImageUrl = await searchGoogleImage(`${recipe.cuisineType} food`);
          }
          
          // If still no results and no cuisineType, try generic food search
          if (!newImageUrl && !recipe.cuisineType) {
            console.log(`   🔎 No cuisineType, trying generic food search`);
            newImageUrl = await searchGoogleImage('delicious food dish');
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

