/**
 * TikTok API Integration
 *
 * Provides functions to get TikTok video information using RapidAPI.
 */
const axios = require("axios");

/**
 * Extract the video ID from a TikTok URL
 * @param {string} url - TikTok video URL
 * @returns {string|null} - The video ID or null if not found
 */
function extractTikTokVideoId(url) {
	// Handle both old format (/video/) and new short format (/t/)
	const match = url.match(
		/(?:https?:\/\/)?(?:www\.)?tiktok\.com\/(?:@[\w.-]+\/video\/|t\/)(\d+)(?:\?.*)?/i
	);
	return match ? match[1] : null;
}

/**
 * Get video information from TikTok by video ID
 * @param {string} videoId - TikTok video ID
 * @returns {Promise<Object>} - Video information including description and basic info
 */
async function getVideoInfoById(videoId) {
	try {
		console.log("Getting video info by ID:", videoId);
		const options = {
			method: "GET",
			url: "https://tiktok-api23.p.rapidapi.com/api/post/detail",
			params: {
				videoId: videoId,
			},
			headers: {
				"X-RapidAPI-Key": process.env.RAPID_API_KEY,
				"X-RapidAPI-Host": "tiktok-api23.p.rapidapi.com",
			},
		};

		const response = await axios.request(options);

		if (!response.data || response.data.statusCode !== 0) {
			throw new Error(
				`Failed to fetch TikTok video info: ${
					response.data?.message || "Unknown error"
				}`
			);
		}

		const videoData = response.data.itemInfo.itemStruct;

		// Return only the essential information
		return {
			videoId: videoId,
			description: videoData.desc || "",
			username: videoData.author?.uniqueId || "",
			videoUrl: videoData.video?.downloadAddr || "",
			coverUrl: videoData.video?.cover || "",
			createTime: videoData.createTime || "",
			author: {
				username: videoData.author?.uniqueId || "",
				nickname: videoData.author?.nickname || "",
				avatar: videoData.author?.avatarThumb || "",
			},
		};
	} catch (error) {
		console.error("Error fetching TikTok video:", error);
		throw error;
	}
}

/**
 * Get TikTok video information from a URL
 * @param {string} url - TikTok video URL
 * @returns {Promise<Object>} - Video information
 */
async function getTikTokVideoFromUrl(url) {
	try {
		console.log("Processing TikTok URL:", url);
		const videoId = extractTikTokVideoId(url);

		if (!videoId) {
			throw new Error(
				"Invalid TikTok URL. Could not extract video ID. Please check the URL format."
			);
		}

		console.log("Extracted video ID:", videoId);
		return await getVideoInfoById(videoId);
	} catch (error) {
		console.error("Error processing TikTok URL:", url, error);
		throw new Error(`Failed to process TikTok URL: ${error.message}`);
	}
}

module.exports = {
	getVideoInfoById,
	getTikTokVideoFromUrl,
	extractTikTokVideoId,
};
