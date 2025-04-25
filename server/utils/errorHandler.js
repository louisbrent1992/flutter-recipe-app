/**
 * Error Handling Utilities
 *
 * Centralizes error handling for consistent API responses
 */

/**
 * Standard API error response
 * @param {Object} res - Express response object
 * @param {number} statusCode - HTTP status code
 * @param {string} message - Error message
 * @param {Object} details - Optional additional error details
 */
function sendError(res, statusCode, message, details = null) {
	const response = {
		error: true,
		message,
		...(details && { details }),
		timestamp: new Date().toISOString(),
	};

	res.status(statusCode).json(response);
}

/**
 * Handle common error scenarios with appropriate status codes
 */
const errorHandler = {
	// 400 - Bad Request
	badRequest: (res, message = "Invalid request parameters", details = null) =>
		sendError(res, 400, message, details),

	// 401 - Unauthorized
	unauthorized: (res, message = "Authentication required", details = null) =>
		sendError(res, 401, message, details),

	// 403 - Forbidden
	forbidden: (
		res,
		message = "You do not have permission to access this resource",
		details = null
	) => sendError(res, 403, message, details),

	// 404 - Not Found
	notFound: (res, message = "Resource not found", details = null) =>
		sendError(res, 404, message, details),

	// 409 - Conflict
	conflict: (
		res,
		message = "Request conflicts with current state",
		details = null
	) => sendError(res, 409, message, details),

	// 500 - Internal Server Error
	serverError: (res, message = "Internal server error", details = null) => {
		console.error("Server error:", message, details);
		sendError(
			res,
			500,
			message,
			process.env.NODE_ENV === "development" ? details : null
		);
	},

	/**
	 * Express middleware for global error handling
	 */
	globalHandler: (err, req, res, next) => {
		console.error("Unhandled error:", err);

		// Handle specific error types
		if (err.name === "ValidationError") {
			return sendError(
				res,
				400,
				"Validation error",
				process.env.NODE_ENV === "development" ? err.details : null
			);
		}

		// Default to 500 for unhandled errors
		sendError(
			res,
			500,
			"An unexpected error occurred",
			process.env.NODE_ENV === "development" ? err.message : null
		);
	},
};

module.exports = errorHandler;
