/**
 * Image Service
 * 
 * Centralized service for handling image operations including:
 * - Google Custom Search API integration
 * - Image caching
 * - Image validation
 * - Placeholder detection
 */

const axios = require('axios');

// Configuration
const GOOGLE_API_KEY = process.env.GOOGLE_API_KEY;
const GOOGLE_CX = process.env.GOOGLE_CX;
const GOOGLE_SEARCH_URL = 'https://www.googleapis.com/customsearch/v1';

// Cache configuration
const CACHE_DURATION = 7 * 24 * 60 * 60 * 1000; // 7 days
const imageCache = {};

/**
 * Check if a URL is a placeholder or invalid
 */
function isPlaceholderUrl(url) {
  if (!url || typeof url !== 'string') return true;
  
  const placeholderPatterns = [
    'via.placeholder.com',
    'placeholder.com',
    'placehold.it',
    'placekitten.com',
    'lorempixel.com',
    'dummyimage.com',
    'example.com',
  ];
  
  return placeholderPatterns.some(pattern => url.includes(pattern));
}

/**
 * Validate if an image URL is accessible
 */
async function validateImageUrl(url) {
  if (!url || isPlaceholderUrl(url)) {
    return false;
  }

  try {
    const response = await axios.head(url, {
      timeout: 5000,
      maxRedirects: 5,
      validateStatus: (status) => status < 400,
    });
    return response.status >= 200 && response.status < 400;
  } catch (error) {
    console.log(`Image validation failed for ${url}:`, error.message);
    return false;
  }
}

/**
 * Search for an image using Google Custom Search API
 * @param {string} query - Search query
 * @param {number} start - Starting index for results (1-based)
 * @param {boolean} useCache - Whether to use cached results
 * @returns {Promise<string|null>} - Image URL or null
 */
async function searchImage(query, start = 1, useCache = true) {
  // Handle invalid query
  if (!query || typeof query !== 'string') {
    console.log('No query provided for image search');
    return null;
  }

  // Check API configuration
  if (!GOOGLE_API_KEY || !GOOGLE_CX) {
    console.error('Google Custom Search API not configured (missing GOOGLE_API_KEY or GOOGLE_CX)');
    return null;
  }

  // Normalize the query
  const normalizedQuery = query.trim().toLowerCase();
  const cacheKey = `${normalizedQuery}_${start}`;

  // Check cache if enabled
  if (useCache && imageCache[cacheKey]) {
    const cached = imageCache[cacheKey];
    const cachedUrl = typeof cached === 'string' ? cached : cached.url;
    const cachedTimestamp = typeof cached === 'string' ? Date.now() : cached.timestamp;

    // Check if cache entry is expired or is a placeholder
    if (Date.now() - cachedTimestamp > CACHE_DURATION) {
      console.log('⚠️  Cached image expired, fetching new one');
      delete imageCache[cacheKey];
    } else if (isPlaceholderUrl(cachedUrl)) {
      console.log('⚠️  Cached image is a placeholder, fetching new one');
      delete imageCache[cacheKey];
    } else {
      console.log('✅ Image found in cache');
      return cachedUrl;
    }
  }

  try {
    const response = await axios.get(GOOGLE_SEARCH_URL, {
      params: {
        key: GOOGLE_API_KEY,
        cx: GOOGLE_CX,
        q: normalizedQuery,
        searchType: 'image',
        num: 3, // Get multiple results to have options
        safe: 'active',
        start: start,
      },
      timeout: 10000,
    });

    // Check if images exist in response
    if (!response.data.items || response.data.items.length === 0) {
      console.log('No images found for query:', normalizedQuery);
      return null;
    }

    // Try to find the best image from the results (excluding placeholders)
    for (const item of response.data.items) {
      const imageUrl = item.link;
      if (imageUrl && !isPlaceholderUrl(imageUrl)) {
        // Store with timestamp for proper cache management
        if (useCache) {
          imageCache[cacheKey] = {
            url: imageUrl,
            timestamp: Date.now(),
          };
        }
        return imageUrl;
      }
    }

    // If all results were placeholders, try next page
    if (start === 1) {
      console.log('All results were placeholders, trying next page');
      return await searchImage(query, 4, useCache);
    }

    return null;
  } catch (error) {
    // Handle specific error cases
    if (error.response) {
      const status = error.response.status;
      if (status === 429) {
        console.error('Google Image Search: Rate limit exceeded');
      } else if (status === 403) {
        console.error('Google Image Search: Invalid API key or access forbidden');
      } else {
        console.error(`Google Image Search error (${status}):`, error.response.data);
      }
    } else if (error.code === 'ECONNABORTED') {
      console.error('Google Image Search: Request timeout');
    } else {
      console.error('Google Image Search error:', error.message);
    }
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
    'Chinese': 'https://images.unsplash.com/photo-1525755662778-989d0524087e?w=800',
    'Japanese': 'https://images.unsplash.com/photo-1579584425555-c3ce17fd4351?w=800',
    'Indian': 'https://images.unsplash.com/photo-1585937421612-70a008356fbe?w=800',
  };
  
  return defaults[cuisineType] || 'https://images.unsplash.com/photo-1546069901-ba9599a7e63c?w=800';
}

/**
 * Clear the image cache (useful for testing or maintenance)
 */
function clearCache() {
  Object.keys(imageCache).forEach(key => delete imageCache[key]);
  console.log('Image cache cleared');
}

/**
 * Get cache statistics
 */
function getCacheStats() {
  return {
    size: Object.keys(imageCache).length,
    keys: Object.keys(imageCache),
  };
}

module.exports = {
  searchImage,
  validateImageUrl,
  isPlaceholderUrl,
  getDefaultImage,
  clearCache,
  getCacheStats,
};

