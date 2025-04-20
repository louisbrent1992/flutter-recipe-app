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
	const match = url.match(
		/(?:https?:\/\/)?(?:www\.)?instagram\.com\/(?:p|reel)\/([A-Za-z0-9_-]+)/i
	);
	return match ? match[1] : null;
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
	const shortcode = extractInstagramShortcode(url);

	if (!shortcode) {
		throw new Error("Invalid Instagram URL. Could not extract shortcode.");
	}

	return getMediaInfoByShortcode(shortcode);
}

module.exports = {
	getMediaInfoByShortcode,
	getInstagramMediaFromUrl,
	extractInstagramShortcode,
};
