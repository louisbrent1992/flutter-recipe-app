/**
 * Script to find where TikTok images are located
 */

const admin = require('firebase-admin');
require('dotenv').config();

const { initFirebase } = require('../config/firebase.js');
initFirebase();

const db = admin.firestore();

function isTikTokImage(url) {
  if (!url) return false;
  return url.includes('tiktokcdn') || url.includes('tiktok.com');
}

async function searchCollection(collectionName) {
  console.log(`\n🔍 Searching ${collectionName}...`);
  
  try {
    const snapshot = await db.collection(collectionName).get();
    console.log(`   Found ${snapshot.size} documents`);
    
    let tiktokCount = 0;
    const tiktokDocs = [];
    
    for (const doc of snapshot.docs) {
      const data = doc.data();
      
      // Check if it's a recipe with imageUrl
      if (data.imageUrl && isTikTokImage(data.imageUrl)) {
        tiktokCount++;
        tiktokDocs.push({
          id: doc.id,
          title: data.title || 'Unknown',
          imageUrl: data.imageUrl,
        });
      }
      
      // Check if it has recipes sub-collection
      if (data.recipes) {
        for (const recipe of data.recipes) {
          if (recipe.imageUrl && isTikTokImage(recipe.imageUrl)) {
            tiktokCount++;
            tiktokDocs.push({
              id: doc.id,
              title: recipe.title || 'Unknown',
              imageUrl: recipe.imageUrl,
              location: 'nested in document',
            });
          }
        }
      }
    }
    
    if (tiktokCount > 0) {
      console.log(`   ⚠️  Found ${tiktokCount} TikTok images!`);
      tiktokDocs.forEach(doc => {
        console.log(`      - ${doc.title} (${doc.id})`);
        console.log(`        ${doc.imageUrl.substring(0, 100)}...`);
      });
    } else {
      console.log(`   ✅ No TikTok images found`);
    }
    
    return tiktokDocs;
    
  } catch (error) {
    console.log(`   ❌ Error: ${error.message}`);
    return [];
  }
}

async function findAllTikTokImages() {
  console.log('🔍 Searching for TikTok images across all collections...\n');
  
  const collectionsToCheck = [
    'discover_recipes',
    'recipes',
    'users',
    'generated_recipes',
    'user_recipes',
  ];
  
  const allResults = [];
  
  for (const collectionName of collectionsToCheck) {
    const results = await searchCollection(collectionName);
    allResults.push(...results);
  }
  
  // Also check users' recipes subcollection
  console.log(`\n🔍 Searching users' recipe subcollections...`);
  try {
    const usersSnapshot = await db.collection('users').get();
    console.log(`   Checking ${usersSnapshot.size} users...`);
    
    let totalChecked = 0;
    let tiktokFound = 0;
    
    for (const userDoc of usersSnapshot.docs) {
      const recipesSnapshot = await userDoc.ref.collection('recipes').get();
      totalChecked += recipesSnapshot.size;
      
      for (const recipeDoc of recipesSnapshot.docs) {
        const recipe = recipeDoc.data();
        if (recipe.imageUrl && isTikTokImage(recipe.imageUrl)) {
          tiktokFound++;
          console.log(`      ⚠️  Found in user ${userDoc.id}:`);
          console.log(`         Recipe: ${recipe.title || 'Unknown'} (${recipeDoc.id})`);
          console.log(`         URL: ${recipe.imageUrl.substring(0, 100)}...`);
          
          allResults.push({
            userId: userDoc.id,
            recipeId: recipeDoc.id,
            title: recipe.title || 'Unknown',
            imageUrl: recipe.imageUrl,
            location: `users/${userDoc.id}/recipes/${recipeDoc.id}`,
          });
        }
      }
    }
    
    console.log(`   ✅ Checked ${totalChecked} user recipes, found ${tiktokFound} TikTok images`);
    
  } catch (error) {
    console.log(`   ❌ Error: ${error.message}`);
  }
  
  // Summary
  console.log('\n' + '='.repeat(60));
  console.log('📋 SUMMARY');
  console.log('='.repeat(60));
  console.log(`Total TikTok images found: ${allResults.length}`);
  
  if (allResults.length > 0) {
    console.log('\n📍 Locations:');
    allResults.forEach((result, index) => {
      console.log(`\n${index + 1}. ${result.title}`);
      console.log(`   Location: ${result.location || result.id}`);
      console.log(`   URL: ${result.imageUrl.substring(0, 100)}...`);
    });
  }
  
  console.log('\n✨ Done!');
}

findAllTikTokImages()
  .then(() => process.exit(0))
  .catch(error => {
    console.error('Fatal error:', error);
    process.exit(1);
  });

