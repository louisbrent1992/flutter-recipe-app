const express = require("express");
const cors = require("cors");
const bodyParser = require("body-parser");
require("dotenv").config(); // Load environment variables from .env file

const recipesRouter = require("./routes/recipes");
const usersRouter = require("./routes/users");

const app = express();
const port = process.env.PORT || 8000;

app.use(cors());
app.use(bodyParser.urlencoded({ extended: true }));

// Middleware to parse JSON data
app.use(bodyParser.json());

// Routes
app.use("/recipes", recipesRouter);
app.use("/users", usersRouter);

app.get("/", (req, res) => {
	res.send("AI Recipe App Backend");
});

app.listen(port, () => {
	console.log(`Server running on http://localhost:${port}🍜`);
});
