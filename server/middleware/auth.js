/**
 * Authentication Middleware
 *
 * Verifies Firebase authentication tokens and attaches the user to the request object.
 */

const { getAuth } = require("firebase-admin/auth");
const errorHandler = require("../utils/errorHandler");

/**
 * Middleware to authenticate requests using Firebase Auth
 * Expects an Authorization header with format: 'Bearer <TOKEN>'
 */
module.exports = async (req, res, next) => {
	try {
		// Check if the Authorization header exists
		const authHeader = req.headers.authorization;
		if (!authHeader || !authHeader.startsWith("Bearer ")) {
			return errorHandler.unauthorized(
				res,
				"No valid authentication token provided"
			);
		}

		// Extract the token
		const idToken = authHeader.split("Bearer ")[1];

		// Verify the token with Firebase
		const decodedToken = await getAuth().verifyIdToken(idToken);

		// Attach the user information to the request
		req.user = {
			uid: decodedToken.uid,
			email: decodedToken.email,
			emailVerified: decodedToken.email_verified,
			displayName: decodedToken.name,
			photoURL: decodedToken.picture,
		};

		next();
	} catch (error) {
		console.error("Authentication error:", error);

		// Handle specific auth errors
		if (error.code === "auth/id-token-expired") {
			return errorHandler.unauthorized(res, "Authentication token has expired");
		} else if (error.code === "auth/id-token-revoked") {
			return errorHandler.unauthorized(
				res,
				"Authentication token has been revoked"
			);
		} else if (error.code === "auth/invalid-id-token") {
			return errorHandler.unauthorized(res, "Invalid authentication token");
		}

		// General auth error
		return errorHandler.unauthorized(
			res,
			"Authentication failed",
			process.env.NODE_ENV === "development" ? error.message : null
		);
	}
};
