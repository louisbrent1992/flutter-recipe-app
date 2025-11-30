const { getMessaging } = require("firebase-admin/messaging");
const { getFirestore } = require("firebase-admin/firestore");

const db = getFirestore();

// Milestone thresholds for different metrics
const MILESTONES = {
	likes: [10, 50, 100, 500, 1000, 5000, 10000],
	saves: [10, 50, 100, 500, 1000, 5000, 10000],
	shares: [10, 50, 100, 500, 1000],
};

/**
 * Check if a count matches a milestone threshold
 * @param {number} count - The current count
 * @param {string} metricType - 'likes', 'saves', or 'shares'
 * @returns {boolean} - Whether the count matches a milestone
 */
function isMilestone(count, metricType) {
	const thresholds = MILESTONES[metricType];
	if (!thresholds) return false;
	return thresholds.includes(count);
}

/**
 * Get the notification message for a milestone
 * @param {string} recipeTitle - Title of the recipe
 * @param {string} metricType - 'likes', 'saves', or 'shares'
 * @param {number} count - The milestone count
 * @returns {object} - { title, body } for the notification
 */
function getMilestoneMessage(recipeTitle, metricType, count) {
	const truncatedTitle = recipeTitle.length > 30 
		? recipeTitle.substring(0, 27) + '...' 
		: recipeTitle;

	switch (metricType) {
		case 'likes':
			return {
				title: '🎉 Your recipe is getting love!',
				body: `Your "${truncatedTitle}" recipe just hit ${count} likes!`,
			};
		case 'saves':
			return {
				title: '📥 People are saving your recipe!',
				body: `${count} people saved your "${truncatedTitle}" recipe!`,
			};
		case 'shares':
			return {
				title: '🔗 Your recipe is being shared!',
				body: `Your "${truncatedTitle}" recipe was shared ${count} times!`,
			};
		default:
			return {
				title: '🎉 Recipe milestone reached!',
				body: `Your "${truncatedTitle}" recipe reached ${count} ${metricType}!`,
			};
	}
}

/**
 * Check if a milestone was reached and send a push notification to the recipe owner
 * @param {string} recipeOwnerId - The user ID of the recipe owner
 * @param {string} recipeId - The recipe ID
 * @param {string} recipeTitle - The recipe title
 * @param {string} metricType - 'likes', 'saves', or 'shares'
 * @param {number} newCount - The new count after increment
 */
async function checkAndSendMilestoneNotification(
	recipeOwnerId,
	recipeId,
	recipeTitle,
	metricType,
	newCount
) {
	try {
		// Check if this count is a milestone
		if (!isMilestone(newCount, metricType)) {
			return;
		}

		console.log(`🎯 Milestone reached: ${recipeTitle} hit ${newCount} ${metricType}`);

		// Get the recipe owner's FCM token
		const userDoc = await db.collection("users").doc(recipeOwnerId).get();
		if (!userDoc.exists) {
			console.log(`⚠️ User ${recipeOwnerId} not found, skipping notification`);
			return;
		}

		const userData = userDoc.data();
		const fcmToken = userData.fcmToken;

		if (!fcmToken) {
			console.log(`⚠️ No FCM token for user ${recipeOwnerId}, skipping notification`);
			return;
		}

		// Get the notification message
		const { title, body } = getMilestoneMessage(recipeTitle, metricType, newCount);

		// Send the push notification
		const message = {
			token: fcmToken,
			notification: {
				title,
				body,
			},
			data: {
				route: '/recipeDetail',
				recipeId: recipeId,
				type: 'milestone',
				metricType: metricType,
				count: String(newCount),
			},
			android: {
				notification: {
					channelId: 'recipe_milestones',
					priority: 'high',
					icon: 'ic_notification',
				},
			},
			apns: {
				payload: {
					aps: {
						badge: 1,
						sound: 'default',
					},
				},
			},
		};

		const response = await getMessaging().send(message);
		console.log(`✅ Milestone notification sent: ${response}`);

	} catch (error) {
		// Log error but don't throw - notification failures shouldn't break the main flow
		console.error(`❌ Error sending milestone notification:`, error.message || error);
	}
}

module.exports = {
	checkAndSendMilestoneNotification,
	isMilestone,
	getMilestoneMessage,
	MILESTONES,
};

