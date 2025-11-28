const express = require("express");
const router = express.Router();
const auth = require("../middleware/auth");
const admin = require("firebase-admin");
const { getFirestore } = require("firebase-admin/firestore");
const errorHandler = require("../utils/errorHandler");

// Get Firestore database instance
const db = getFirestore();

// Get community recipes (user-shared recipes)
router.get("/recipes", auth, async (req, res) => {
	try {
		const { query, difficulty, tag, random } = req.query;
		const page = parseInt(req.query.page) || 1;
		const limitParam = parseInt(req.query.limit);
		const limit = isNaN(limitParam) ? 12 : Math.min(limitParam, 500);
		const isRandom = random === 'true';
		const currentUserId = req.user.uid;

		// Build Firestore query - community recipes (isDiscoverable === true, not external, not current user's)
		// Note: We can't use != in Firestore for isExternal, so we'll filter it out after fetching
		let recipesRef = db.collection("recipes")
			.where("isDiscoverable", "==", true);

		// Aggregate tokens from query and tag, treating comma-separated chunks as phrases
		const gatherTokens = (input) => {
			if (!input || typeof input !== 'string') return [];
			return input
				.toLowerCase()
				.split(',')
				.map((s) => s.trim().replace(/\s+/g, ' '))
				.filter((s) => s.length > 0);
		};

		// Generate both hyphen and space variations of a phrase
		const generateVariations = (phrase) => {
			const variations = new Set([phrase]);
			const spaceVersion = phrase.replace(/-/g, ' ');
			if (spaceVersion !== phrase) variations.add(spaceVersion);
			const hyphenVersion = phrase.replace(/\s+/g, '-');
			if (hyphenVersion !== phrase) variations.add(hyphenVersion);
			return Array.from(variations);
		};

		let phraseTokens = [];
		phraseTokens = phraseTokens.concat(gatherTokens(query));
		phraseTokens = phraseTokens.concat(gatherTokens(tag));

		// Build final tokens list prioritizing each tag phrase, then its hyphen/space variations
		let tokens = [];
		const addedTokens = new Set();

		// Step 1: Add each phrase exactly once (de-duplicated)
		for (const phrase of phraseTokens) {
			if (tokens.length >= 10) break;
			if (!addedTokens.has(phrase)) {
				tokens.push(phrase);
				addedTokens.add(phrase);
			}
		}

		// Step 2: Add hyphen/space variations for phrases that contain hyphen/space
		for (const phrase of phraseTokens) {
			if (tokens.length >= 10) break;
			const hyphenVersion = phrase.replace(/\s+/g, "-");
			if (hyphenVersion !== phrase && !addedTokens.has(hyphenVersion) && tokens.length < 10) {
				tokens.push(hyphenVersion);
				addedTokens.add(hyphenVersion);
			}
			if (tokens.length >= 10) break;
			const spaceVersion = phrase.replace(/-/g, " ");
			if (spaceVersion !== phrase && !addedTokens.has(spaceVersion) && tokens.length < 10) {
				tokens.push(spaceVersion);
				addedTokens.add(spaceVersion);
			}
			if (tokens.length >= 10) break;
		}

		// Step 3: Optionally add individual words if we still have room
		if (tokens.length < 10) {
			for (const phrase of phraseTokens) {
				if (tokens.length >= 10) break;
				const words = phrase.split(/[\s-]+/).filter((w) => w.length > 0);
				for (const word of words) {
					if (tokens.length >= 10) break;
					if (word.length > 2 && !addedTokens.has(word)) {
						tokens.push(word);
						addedTokens.add(word);
					}
				}
			}
		}

		if (tokens.length > 10) {
			console.warn(
				`array-contains-any supports up to 10 values; capped to 10 (had ${tokens.length})`
			);
			tokens = tokens.slice(0, 10);
		}

		// Apply search tokens if available
		if (tokens.length > 0) {
			recipesRef = recipesRef.where(
				"searchableFields",
				"array-contains-any",
				tokens
			);
		}

		// Apply difficulty filter
		if (difficulty) {
			recipesRef = recipesRef.where(
				"difficulty",
				"==",
				difficulty.charAt(0).toUpperCase() + difficulty.slice(1).toLowerCase()
			);
		}

		// Get total count for pagination
		const totalQuery = await recipesRef.count().get();
		const totalRecipes = totalQuery.data().count;

		// Calculate pagination offsets
		const startAt = (page - 1) * limit;

		// Fetch recipes
		let snapshot;
		try {
			if (isRandom) {
				if (limit === 1) {
					const dailyPoolSize = Math.min(500, totalRecipes);
					snapshot = await recipesRef.limit(dailyPoolSize).get();
				} else {
					// For random mode, fetch all available recipes (up to max) to maximize results after filtering
					// This ensures we get as many recipes as possible after filtering out isExternal and current user's recipes
					const maxFetchSize = Math.min(500, totalRecipes); // Fetch up to 500 or all available
					snapshot = await recipesRef.limit(maxFetchSize).get();
				}
			} else {
				snapshot = await recipesRef
					.orderBy("createdAt", "desc")
					.limit(limit)
					.offset(startAt)
					.get();
			}
		} catch (orderErr) {
			console.warn(
				"Falling back to un-ordered fetch due to createdAt orderBy error:",
				orderErr?.message || orderErr
			);
			// For random mode fallback, fetch all available
			const fallbackLimit = isRandom ? Math.min(500, totalRecipes) : limit;
			snapshot = await recipesRef.limit(fallbackLimit).offset(startAt).get();
		}

		// Collect recipes and fetch user profiles
		const recipes = [];
		const userIds = new Set();
		const recipeIds = [];

		snapshot.forEach((doc) => {
			const data = doc.data();
			// Exclude Spoonacular recipes (isExternal === true) and current user's recipes
			// Only include user-generated or user-imported recipes (has userId, not external)
			if (data.isExternal !== true && 
			    data.userId && 
			    data.userId !== currentUserId) {
				const recipeId = doc.id;
				recipes.push({
					id: recipeId,
					...data,
				});
				recipeIds.push(recipeId);
				if (data.userId) {
					userIds.add(data.userId);
				}
			}
		});

		// Fetch user profiles for attribution (respecting privacy settings)
		const userProfiles = new Map();
		if (userIds.size > 0) {
			const userPromises = Array.from(userIds).map(async (userId) => {
				try {
					const userDoc = await db.collection("users").doc(userId).get();
					if (userDoc.exists) {
						const userData = userDoc.data();
						// Check if user wants to show their profile in community
						// Defaults to true if not set
						const showProfile = userData.showProfileInCommunity !== false;
						userProfiles.set(userId, {
							displayName: showProfile ? (userData.displayName || null) : null,
							photoURL: showProfile ? (userData.photoURL || null) : null,
							showProfile: showProfile,
						});
					}
				} catch (error) {
					console.error(`Error fetching user profile for ${userId}:`, error);
				}
			});
			await Promise.all(userPromises);
		}

		// Fetch user's likes for these recipes
		const userLikes = new Set();
		if (recipeIds.length > 0) {
			// Query likes for the current user and these specific recipes
			const likesSnapshot = await db.collection("recipeLikes")
				.where("userId", "==", currentUserId)
				.where("recipeId", "in", recipeIds.length > 10 ? recipeIds.slice(0, 10) : recipeIds)
				.get();
			likesSnapshot.forEach((doc) => {
				const likeData = doc.data();
				if (likeData.recipeId) {
					userLikes.add(likeData.recipeId);
				}
			});
			
			// If we have more than 10 recipes, query in batches
			if (recipeIds.length > 10) {
				for (let i = 10; i < recipeIds.length; i += 10) {
					const batch = recipeIds.slice(i, i + 10);
					const batchSnapshot = await db.collection("recipeLikes")
						.where("userId", "==", currentUserId)
						.where("recipeId", "in", batch)
						.get();
					batchSnapshot.forEach((doc) => {
						const likeData = doc.data();
						if (likeData.recipeId) {
							userLikes.add(likeData.recipeId);
						}
					});
				}
			}
		}

		// Attach user attribution, like status, and save count to recipes
		const recipesWithAttribution = recipes.map((recipe) => {
			const userProfile = recipe.userId ? userProfiles.get(recipe.userId) : null;
			return {
				...recipe,
				sharedByUserId: recipe.userId,
				sharedByDisplayName: userProfile?.displayName || null,
				sharedByPhotoUrl: userProfile?.photoURL || null,
				likeCount: recipe.likeCount || 0,
				saveCount: recipe.saveCount || 0,
				isLiked: userLikes.has(recipe.id),
			};
		});

		// For random mode with limit=1: use date-based seeding
		// For other random modes: return all available recipes (don't limit to requested amount)
		// This ensures we return all available community recipes, not just up to the limit
		let returnedRecipes = recipesWithAttribution;
		if (isRandom) {
			if (limit === 1 && recipesWithAttribution.length > 0) {
				const now = new Date();
				const start = new Date(now.getFullYear(), 0, 0);
				const dayOfYear = Math.floor((now - start) / (1000 * 60 * 60 * 24));
				const dailyIndex = (now.getFullYear() * 365 + dayOfYear) % recipesWithAttribution.length;
				returnedRecipes = [recipesWithAttribution[dailyIndex]];
			}
			// For random mode with limit > 1, return all available recipes (don't slice)
			// The client will handle pagination from the full cache
		}

		// Calculate pagination info
		const totalPages = Math.ceil(totalRecipes / limit);
		const hasNextPage = page < totalPages;
		const hasPrevPage = page > 1;

		console.log(
			`Fetched ${recipes.length} community recipes, returning ${returnedRecipes.length} for page ${page} of ${totalPages} (total: ${totalRecipes})`
		);

		res.json({
			recipes: returnedRecipes,
			pagination: {
				total: totalRecipes,
				page,
				limit,
				totalPages,
				hasNextPage,
				hasPrevPage,
			},
		});
	} catch (error) {
		console.error("Error fetching community recipes:", error);
		errorHandler.serverError(
			res,
			"We couldn't load community recipes right now. Please try again shortly."
		);
	}
});

module.exports = router;

