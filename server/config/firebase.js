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
		// Try reading the local service account file first (developer-friendly)
		const serviceAccountPath = path.join(
			__dirname,
			"firebase-service-account.json"
		);

		let serviceAccount;
		if (fs.existsSync(serviceAccountPath)) {
			serviceAccount = JSON.parse(fs.readFileSync(serviceAccountPath, "utf8"));
		} else if (process.env.FIREBASE_SERVICE_ACCOUNT) {
			// Fallback to environment variable (base64 or JSON)
			const raw = process.env.FIREBASE_SERVICE_ACCOUNT;
			try {
				// Support either raw JSON or base64-encoded JSON
				const decoded = Buffer.from(raw, "base64").toString("utf8");
				serviceAccount = JSON.parse(decoded);
			} catch (_) {
				serviceAccount = JSON.parse(raw);
			}
		} else {
			throw new Error(
				"Firebase service account not provided. Place firebase-service-account.json in server/config/ or set FIREBASE_SERVICE_ACCOUNT env var."
			);
		}

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
