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
	// Try to extract video ID from any TikTok URL format
	// Match any numeric ID that looks like a video ID (18-19 digits)
	const patterns = [
		/\/video\/(\d{18,19})/i,           // /video/123456789012345678
		/\/v\/(\d{18,19})/i,               // /v/123456789012345678
		/video_id[=:](\d{18,19})/i,        // video_id=123456789012345678
		/item_id[=:](\d{18,19})/i,         // item_id=123456789012345678
		/tiktok\.com\/(\d{18,19})/i,       // tiktok.com/123456789012345678
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
 * Attempt to extract canonical URL or videoId from HTML
 * @param {string} html
 * @returns {{url?: string, videoId?: string}}
 */
function extractFromHtml(html) {
	if (typeof html !== "string" || !html) return {};
	const result = {};
	
	// Try to find canonical URL from meta tags
	const ogUrlMatch = html.match(/<meta[^>]+property=["']og:url["'][^>]+content=["']([^"']+)["']/i);
	if (ogUrlMatch && ogUrlMatch[1]) {
		result.url = ogUrlMatch[1];
	}
	
	// Try multiple patterns to find video ID in HTML
	const idPatterns = [
		/\bvideoId\b\s*[:=]\s*["'](\d{18,19})["']/i,
		/\bitem_id\b\s*[:=]\s*["'](\d{18,19})["']/i,
		/\bid\b\s*[:=]\s*["'](\d{18,19})["']/i,
		/"videoId":"(\d{18,19})"/i,
		/"itemId":"(\d{18,19})"/i,
		/"aweme_id":"(\d{18,19})"/i,
	];
	
	for (const pattern of idPatterns) {
		const match = html.match(pattern);
		if (match && match[1]) {
			result.videoId = match[1];
			break;
		}
	}
	
	return result;
}

/**
 * Resolve TikTok short links (e.g. /t/, vm.tiktok.com) to canonical URL
 * @param {string} url
 * @returns {Promise<{finalUrl: string, html?: string}>}
 */
async function resolveTikTokUrl(url) {
	try {
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
		const html = typeof response.data === "string" ? response.data : undefined;
		const finalUrl =
			response?.request?.res?.responseUrl ||
			response?.request?.responseURL ||
			response?.config?.url ||
			url;
		const { url: canonicalUrl } = extractFromHtml(html || "");
		return { finalUrl: canonicalUrl || finalUrl, html };
	} catch (_) {
		return { finalUrl: url };
	}
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
		let workingUrl = (url || "").trim();

		// Always try to resolve the URL first to get canonical form
		let resolvedHtml;
		try {
			const { finalUrl, html } = await resolveTikTokUrl(workingUrl);
			if (finalUrl && finalUrl !== workingUrl) {
				workingUrl = finalUrl;
				resolvedHtml = html;
				console.log("Resolved TikTok URL to:", workingUrl);
			}
		} catch (resolveError) {
			console.log("Could not resolve URL, continuing with original:", resolveError.message);
		}

		// Try to extract video ID from the URL
		let videoId = extractTikTokVideoId(workingUrl);

		// If no video ID found, try fetching the page and parsing HTML
		if (!videoId) {
			try {
				const resp = await axios.get(workingUrl, {
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
				const html = typeof resp.data === "string" ? resp.data : resolvedHtml;
				const { url: canonicalUrl, videoId: inlineId } = extractFromHtml(html || "");
				
				if (canonicalUrl) {
					console.log("Found canonical URL from HTML:", canonicalUrl);
					videoId = extractTikTokVideoId(canonicalUrl);
				}
				if (!videoId && inlineId) {
					console.log("Found inline video ID from HTML:", inlineId);
					videoId = inlineId;
				}
			} catch (fetchError) {
				console.log("Could not fetch page HTML:", fetchError.message);
			}
		}

		if (!videoId) {
			throw new Error(
				"Could not extract video ID from TikTok URL. Please ensure the URL is a valid TikTok video link."
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
