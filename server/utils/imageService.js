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
const VALIDATION_CACHE_DURATION = 24 * 60 * 60 * 1000; // 24 hours for validation results
const imageCache = {};
const validationCache = {}; // Cache validation results to avoid re-validating same URLs

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
 * Uses the same headers as the client to ensure compatibility
 * Caches validation results to avoid re-validating same URLs
 */
async function validateImageUrl(url) {
  if (!url || isPlaceholderUrl(url)) {
    return false;
  }

  // Check validation cache first
  if (validationCache[url]) {
    const cached = validationCache[url];
    if (Date.now() - cached.timestamp < VALIDATION_CACHE_DURATION) {
      console.log(`✅ Image validation found in cache for ${url}`);
      return cached.isValid;
    } else {
      // Cache expired, remove it
      delete validationCache[url];
    }
  }

  let isValid = false;
  try {
    // Use the same User-Agent headers as the client for better compatibility
    const response = await axios.head(url, {
      timeout: 8000, // Increased timeout to match client
      maxRedirects: 5,
      validateStatus: (status) => status < 400,
      headers: {
        'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1',
        'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
      },
    });
    
    // Also verify the content-type is an image
    const contentType = response.headers['content-type'] || '';
    const isImage = contentType.startsWith('image/');
    
    isValid = response.status >= 200 && response.status < 400 && isImage;
  } catch (error) {
    // If HEAD fails, try a GET request with range to verify it's actually an image
    // This helps catch cases where HEAD is blocked but GET works
    try {
      const getResponse = await axios.get(url, {
        timeout: 8000,
        maxRedirects: 5,
        headers: {
          'User-Agent': 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_6 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.6 Mobile/15E148 Safari/604.1',
          'Accept': 'image/avif,image/webp,image/apng,image/*,*/*;q=0.8',
          'Range': 'bytes=0-1023', // Only fetch first 1KB to verify it's an image
        },
        validateStatus: (status) => status < 400,
        maxContentLength: 1024, // Limit to 1KB for validation
      });
      
      const contentType = getResponse.headers['content-type'] || '';
      const isImage = contentType.startsWith('image/');
      
      isValid = getResponse.status >= 200 && getResponse.status < 400 && isImage;
    } catch (getError) {
      console.log(`Image validation failed for ${url}:`, error.message);
      isValid = false;
    }
  }

  // Cache the validation result
  validationCache[url] = {
    isValid,
    timestamp: Date.now(),
  };

  return isValid;
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

    // Try to find the best image from the results (excluding placeholders and checking validity)
    for (const item of response.data.items) {
      const imageUrl = item.link;
      if (imageUrl && !isPlaceholderUrl(imageUrl)) {
        // Validate the image before accepting it
        // This ensures we don't return broken links (403, 404, etc.)
        const isValid = await validateImageUrl(imageUrl);
        
        if (isValid) {
        // Store with timestamp for proper cache management
        if (useCache) {
          imageCache[cacheKey] = {
            url: imageUrl,
            timestamp: Date.now(),
          };
        }
        return imageUrl;
        } else {
          console.log(`⚠️ Skipped invalid image from search results: ${imageUrl}`);
        }
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
 * Search for multiple images and validate them in parallel
 * Returns an array of validated image URLs for client selection
 * @param {string} query - Search query
 * @param {number} count - Number of validated images to return
 * @param {number[]} startOffsets - Starting indices to try (for variety)
 * @returns {Promise<string[]>} - Array of validated image URLs
 */
async function searchMultipleImages(query, count = 3, startOffsets = [1, 4, 7]) {
  if (!query || typeof query !== 'string') {
    console.log('No query provided for image search');
    return [];
  }

  if (!GOOGLE_API_KEY || !GOOGLE_CX) {
    console.error('Google Custom Search API not configured');
    return [];
  }

  const normalizedQuery = query.trim().toLowerCase();
  const validatedUrls = [];

  // Fetch images from multiple start positions in parallel
  const searchPromises = startOffsets.map(async (start) => {
    try {
      const response = await axios.get(GOOGLE_SEARCH_URL, {
        params: {
          key: GOOGLE_API_KEY,
          cx: GOOGLE_CX,
          q: normalizedQuery,
          searchType: 'image',
          num: 5, // Get 5 results per offset
          safe: 'active',
          start: start,
        },
        timeout: 10000,
      });

      if (!response.data.items || response.data.items.length === 0) {
        return [];
      }

      // Return all non-placeholder URLs
      return response.data.items
        .filter(item => item.link && !isPlaceholderUrl(item.link))
        .map(item => item.link);
    } catch (error) {
      console.error(`Image search error for start=${start}:`, error.message);
      return [];
    }
  });

  // Wait for all searches to complete
  const searchResults = await Promise.all(searchPromises);
  
  // Flatten results and deduplicate
  const allUrls = [...new Set(searchResults.flat())];
  
  if (allUrls.length === 0) {
    return [];
  }

  // Validate URLs in parallel (up to 10 at a time for performance)
  const validationPromises = allUrls.slice(0, 15).map(async (url) => {
    const isValid = await validateImageUrl(url);
    return isValid ? url : null;
  });

  const validationResults = await Promise.all(validationPromises);
  
  // Filter out nulls and return up to requested count
  const validated = validationResults.filter(url => url !== null);
  
  console.log(`Found ${validated.length} validated images out of ${allUrls.length} candidates`);
  
  return validated.slice(0, count);
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
  Object.keys(validationCache).forEach(key => delete validationCache[key]);
  console.log('Image cache and validation cache cleared');
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
  searchMultipleImages,
  validateImageUrl,
  isPlaceholderUrl,
  getDefaultImage,
  clearCache,
  getCacheStats,
};

