/**
 * Firebase Configuration
 *
 * Initializes Firebase Admin SDK for server-side operations
 */

const { initializeApp, cert } = require("firebase-admin/app");

// Initialize Firebase Admin
const initFirebase = () => {
	try {
		// Check if we have service account credentials in env
		if (!process.env.FIREBASE_SERVICE_ACCOUNT) {
			throw new Error(
				"FIREBASE_SERVICE_ACCOUNT environment variable is not set"
			);
		}

		// Parse the service account JSON
		const serviceAccount = process.env.FIREBASE_SERVICE_ACCOUNT;

		// Initialize the app
		initializeApp({
			credential: cert(serviceAccount),
			databaseURL: process.env.FIREBASE_DATABASE_URL,
		});

		console.log("Firebase Admin initialized successfully");
	} catch (error) {
		console.error("Error initializing Firebase Admin:", error);
		process.exit(1);
	}
};

module.exports = { initFirebase };
