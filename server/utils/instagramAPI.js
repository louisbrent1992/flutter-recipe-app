/**
 * Instagram API Integration
 *
 * Provides functions to get Instagram post caption and minimal media info using RapidAPI.
 */
const axios = require("axios");

/**
 * Extract the shortcode from an Instagram URL
 * @param {string} url - Instagram post URL
 * @returns {string|null} - The shortcode or null if not found
 */
function extractInstagramShortcode(url) {
	// Try multiple patterns to extract shortcode from any Instagram URL format
	const patterns = [
		/\/(?:p|reel|reels|tv)\/([A-Za-z0-9_-]+)/i,  // /p/, /reel/, /reels/, /tv/
		/instagram\.com\/([A-Za-z0-9_-]{11})/i,       // Direct shortcode after domain
		/shortcode[=:]([A-Za-z0-9_-]+)/i,             // ?shortcode=xxx
	];
	
	for (const pattern of patterns) {
		const match = url.match(pattern);
		if (match && match[1]) {
			return match[1];
		}
	}
	
	return null;
}

/**
 * Get caption and basic media info from Instagram by shortcode
 * @param {string} shortcode - Instagram post shortcode
 * @returns {Promise<Object>} - Media caption and basic info
 */
async function getMediaInfoByShortcode(shortcode) {
	try {
		const options = {
			method: "POST",
			url: "https://rocketapi-for-developers.p.rapidapi.com/instagram/media/get_info_by_shortcode",
			headers: {
				"X-RapidAPI-Key": process.env.RAPID_API_KEY,
				"X-RapidAPI-Host": "rocketapi-for-developers.p.rapidapi.com",
				"Content-Type": "application/json",
			},
			data: {
				shortcode: shortcode,
			},
		};

		const response = await axios.request(options);

		if (!response.data || response.data.response.status_code !== 200) {
			throw new Error(
				`Failed to fetch Instagram media info: ${
					response.data?.message || "Unknown error"
				}`
			);
		}

		const responseData = response.data.response.body;

		if (!responseData.items || responseData.items.length === 0) {
			throw new Error("No media found for this shortcode");
		}

		const mediaItem = responseData.items[0];
		const imageUrl =
			mediaItem.media_type === 8 &&
			mediaItem.carousel_media &&
			mediaItem.carousel_media.length > 0
				? mediaItem.carousel_media[0].image_versions2?.candidates?.[0]?.url
				: mediaItem.image_versions2?.candidates?.[0]?.url;

		// Return only the caption and minimal additional info
		return {
			shortcode: shortcode,
			caption: mediaItem.caption?.text || "",
			username: mediaItem.user?.username || "",
			imageUrl: imageUrl,
		};
	} catch (error) {
		console.error("Error fetching Instagram post:", error);
		throw error;
	}
}

/**
 * Get Instagram caption from a post URL
 * @param {string} url - Instagram post URL
 * @returns {Promise<Object>} - Post caption and basic info
 */
async function getInstagramMediaFromUrl(url) {
	try {
		console.log("Processing Instagram URL:", url);
		let shortcode = extractInstagramShortcode(url);

		// If no shortcode found, try fetching the page and parsing HTML
		if (!shortcode) {
			try {
				console.log("Could not extract shortcode from URL, trying HTML fetch...");
				const response = await axios.get(url, {
					maxRedirects: 5,
					timeout: 10000,
					headers: {
						"User-Agent":
							"Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/124.0.0.0 Safari/537.36",
						Accept:
							"text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
					},
					validateStatus: () => true,
				});

				if (typeof response.data === "string") {
					// Try to find shortcode in HTML
					const shortcodeMatch = response.data.match(/"shortcode":"([A-Za-z0-9_-]+)"/i);
					if (shortcodeMatch && shortcodeMatch[1]) {
						shortcode = shortcodeMatch[1];
						console.log("Found shortcode from HTML:", shortcode);
					}
				}
			} catch (fetchError) {
				console.log("Could not fetch page HTML:", fetchError.message);
			}
		}

		if (!shortcode) {
			throw new Error(
				"Could not extract shortcode from Instagram URL. Please ensure the URL is a valid Instagram post link."
			);
		}

		console.log("Extracted shortcode:", shortcode);
		return await getMediaInfoByShortcode(shortcode);
	} catch (error) {
		console.error("Error processing Instagram URL:", url, error);
		throw new Error(`Failed to process Instagram URL: ${error.message}`);
	}
}

module.exports = {
	getMediaInfoByShortcode,
	getInstagramMediaFromUrl,
	extractInstagramShortcode,
};
