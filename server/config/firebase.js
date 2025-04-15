const admin = require("firebase-admin");
require("dotenv").config();
const serviceAccount = require("./recipe-app-c2fcc-firebase-adminsdk-fsjis-7641d9672e.json");

// Initialize Firebase Admin
admin.initializeApp({
	credential: admin.credential.cert(serviceAccount),
});

// Get Firestore instance
const db = admin.firestore();

module.exports = { admin, db };
