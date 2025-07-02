/**
 * Firebase Configuration
 *
 * Initializes Firebase Admin SDK for server-side operations
 */

const { initializeApp, cert } = require("firebase-admin/app");
const fs = require("fs");
const path = require("path");

// Initialize Firebase Admin
const initFirebase = () => {
	try {
		// Check if we have service account credentials in env
		if (!process.env.FIREBASE_SERVICE_ACCOUNT) {
			throw new Error(
				"FIREBASE_SERVICE_ACCOUNT environment variable is not set"
			);
		}

		const serviceAccountPath = path.join(
			__dirname,
			"firebase-service-account.json"
		);

		const serviceAccount = JSON.parse(
			fs.readFileSync(serviceAccountPath, "utf8")
		);

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
