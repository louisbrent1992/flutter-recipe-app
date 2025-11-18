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
	// Try multiple patterns to extract video ID from any YouTube URL format
	const patterns = [
		/[?&]v=([A-Za-z0-9_-]{11})/i,                      // ?v=xxx or &v=xxx
		/youtu\.be\/([A-Za-z0-9_-]{11})/i,                 // youtu.be/xxx
		/\/shorts\/([A-Za-z0-9_-]{11})/i,                  // /shorts/xxx
		/\/embed\/([A-Za-z0-9_-]{11})/i,                   // /embed/xxx
		/\/v\/([A-Za-z0-9_-]{11})/i,                       // /v/xxx
		/\/watch\/([A-Za-z0-9_-]{11})/i,                   // /watch/xxx
		/youtube\.com\/([A-Za-z0-9_-]{11})/i,              // Direct after domain
		/video_id[=:]([A-Za-z0-9_-]{11})/i,                // video_id=xxx
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
	try {
		console.log("Processing YouTube URL:", url);
		let videoId = extractYouTubeVideoId(url);

		// If no video ID found, try fetching the page and parsing HTML
		if (!videoId) {
			try {
				console.log("Could not extract video ID from URL, trying HTML fetch...");
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
					// Try to find video ID in HTML
					const idPatterns = [
						/"videoId":"([A-Za-z0-9_-]{11})"/i,
						/"video_id":"([A-Za-z0-9_-]{11})"/i,
						/\bvideoId\b\s*[:=]\s*"([A-Za-z0-9_-]{11})"/i,
					];
					
					for (const pattern of idPatterns) {
						const match = response.data.match(pattern);
						if (match && match[1]) {
							videoId = match[1];
							console.log("Found video ID from HTML:", videoId);
							break;
						}
					}
				}
			} catch (fetchError) {
				console.log("Could not fetch page HTML:", fetchError.message);
			}
		}

		if (!videoId) {
			throw new Error(
				"Could not extract video ID from YouTube URL. Please ensure the URL is a valid YouTube video link."
			);
		}

		console.log("Extracted video ID:", videoId);
		return await getVideoInfoById(videoId);
	} catch (error) {
		console.error("Error processing YouTube URL:", url, error);
		throw new Error(`Failed to process YouTube URL: ${error.message}`);
	}
}

module.exports = {
	getVideoInfoById,
	getYouTubeVideoFromUrl,
	extractYouTubeVideoId,
};
