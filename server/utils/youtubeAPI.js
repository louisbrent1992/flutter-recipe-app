/**
 * YouTube API Integration
 *
 * Provides functions to get YouTube video information using the YouTube Data API.
 */
const axios = require("axios");

/**
 * Extract the video ID from a YouTube URL
 * @param {string} url - YouTube video URL
 * @returns {string|null} - The video ID or null if not found
 */
function extractYouTubeVideoId(url) {
	const patterns = [
		/(?:https?:\/\/)?(?:www\.)?youtube\.com\/watch\?v=([A-Za-z0-9_-]+)/i,
		/(?:https?:\/\/)?(?:www\.)?youtu\.be\/([A-Za-z0-9_-]+)/i,
		/(?:https?:\/\/)?(?:www\.)?youtube\.com\/shorts\/([A-Za-z0-9_-]+)/i,
	];

	for (const pattern of patterns) {
		const match = url.match(pattern);
		if (match) return match[1];
	}
	return null;
}

/**
 * Get video information from YouTube by video ID
 * @param {string} videoId - YouTube video ID
 * @returns {Promise<Object>} - Video information including description and basic info
 */
async function getVideoInfoById(videoId) {
	try {
		const options = {
			method: "GET",
			url: "https://www.googleapis.com/youtube/v3/videos",
			params: {
				part: "snippet,contentDetails,statistics",
				id: videoId,
				key: process.env.YOUTUBE_API_KEY,
			},
		};

		const response = await axios.request(options);

		if (
			!response.data ||
			!response.data.items ||
			response.data.items.length === 0
		) {
			throw new Error("No video found with the given ID");
		}

		const videoData = response.data.items[0];
		const snippet = videoData.snippet;

		console.log(videoData.snippet);

		// Return only the essential information
		return {
			videoId: videoId,
			title: snippet.title,
			description: snippet.description,
			channelTitle: snippet.channelTitle,
			channelId: snippet.channelId,
			thumbnailUrl:
				snippet.thumbnails?.maxres?.url || snippet.thumbnails?.high?.url,
			publishedAt: snippet.publishedAt,
			duration: videoData.contentDetails?.duration,
			viewCount: videoData.statistics?.viewCount,
			likeCount: videoData.statistics?.likeCount,
			commentCount: videoData.statistics?.commentCount,
		};
	} catch (error) {
		console.error("Error fetching YouTube video:", error);
		throw error;
	}
}

/**
 * Get YouTube video information from a URL
 * @param {string} url - YouTube video URL
 * @returns {Promise<Object>} - Video information
 */
async function getYouTubeVideoFromUrl(url) {
	const videoId = extractYouTubeVideoId(url);

	if (!videoId) {
		throw new Error("Invalid YouTube URL. Could not extract video ID.");
	}

	return getVideoInfoById(videoId);
}

module.exports = {
	getVideoInfoById,
	getYouTubeVideoFromUrl,
	extractYouTubeVideoId,
};
