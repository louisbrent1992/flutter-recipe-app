# Flutter Recipe App 🍽️

A mobile application that allows users to generate unique recipes using AI, manage personal recipe collections, and easily import recipe details from shared social media posts.

## Table of Contents

- [Project Overview](#project-overview)
- [Core Features](#core-features)
- [Technology Stack](#technology-stack)
- [Getting Started](#getting-started)
- [Screenshots](#screenshots)
- [License](#license)

## Project Overview

**Purpose:** This app is designed for home cooks, food enthusiasts, and anyone looking for culinary inspiration. It leverages AI to create personalized recipes based on user inputs and provides a platform for managing and sharing recipes.

## Core Features

### A. AI-Generated Recipe Creation

- Users can specify ingredients, dietary restrictions, and cuisine types.
- If no inputs are provided, the app will use default random values for ingredients, dietary restrictions, and cuisine types.
- Integration with an AI service to generate recipes based on user inputs.
- Customization options for cooking time, difficulty level, and nutritional information.

### B. Recipe Management

- CRUD operations for personal recipe collections.
- Categorization and tagging of recipes.
- Favorites and bookmarks for quick access.
- Search and filter functionality.

### C. Social Media Recipe Import

- Deep linking to handle shared social media content.
- Parsing engine to extract recipe details from social media posts.
- Validation and editing of imported data.

## Technology Stack

- **Frontend:** Flutter (Dart)
- **Backend:** Node.js with Express
- **Database:** In-memory storage (for demo purposes)
- **AI Integration:** External AI service (e.g., OpenAI)
- **State Management:** Provider

## Getting Started

To get started with the Flutter Recipe App, follow these steps:

1. Clone the repository:

   ```bash
   git clone https://github.com/yourusername/flutter-recipe-app.git
   cd flutter-recipe-app
   ```

2. Navigate to the client directory and install dependencies:

   ```bash
   cd client
   flutter pub get
   ```

3. Run the app:

   ```bash
   flutter run
   ```

4. For the backend, navigate to the server directory and install dependencies:

   ```bash
   cd server
   npm install
   ```

5. Start the server:

   ```bash
   npm run dev
   ```

## Screenshots

![Home Screen](assets/screenshots/home_screen.png)
![AI Recipe Screen](assets/screenshots/ai_recipe_screen.png)
![Recipe List Screen](assets/screenshots/recipe_list_screen.png)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
