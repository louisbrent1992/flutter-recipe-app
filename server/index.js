/**
 * Recipe App Server
 *
 * Main server entrypoint that configures Express and registers routes
 */

const express = require("express");
const cors = require("cors");
require("dotenv").config();
const errorHandler = require("./utils/errorHandler");

// Initialize Firebase
require("./config/firebase").initFirebase();

// Import routes
const aiRoutes = require("./routes/generatedRecipes");
const userRecipesRoutes = require("./routes/userRecipes");
const userRoutes = require("./routes/users");

const app = express();
const port = process.env.PORT || 3001;

// Middleware
app.use(express.json());
app.use(express.urlencoded({ extended: true }));
app.use(cors());

// Add request logger in development
if (process.env.NODE_ENV !== "production") {
	app.use((req, res, next) => {
		console.log(`${req.method} ${req.url}`);
		next();
	});
}

// API Routes with clean naming structure
app.use("/api/ai/recipes", aiRoutes);
app.use("/api/user/recipes", userRecipesRoutes);
app.use("/api/users", userRoutes);

// Health check endpoint
app.get("/health", (req, res) => {
	res.json({ status: "ok", timestamp: new Date().toISOString() });
});

// 404 handler for undefined routes
app.use((req, res) => {
	errorHandler.notFound(res, `Route not found: ${req.method} ${req.url}`);
});

// Global error handler
app.use(errorHandler.globalHandler);

// Start server
app.listen(port, () => {
	console.log(`🚀 Server running on port ${port}`);
	console.log(`🔗 API available at http://localhost:${port}/api`);
});
