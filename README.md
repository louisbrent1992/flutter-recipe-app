# Flutter Recipe App 🍽️

A mobile application that allows users to generate unique recipes using AI, manage personal recipe collections, and easily import recipe details from shared social media posts.

## Table of Contents

- [Project Overview](#project-overview)
- [Core Features](#core-features)
- [Technology Stack](#technology-stack)
- [Getting Started](#getting-started)
- [Instagram Integration](#instagram-integration)
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
- Direct integration with Instagram to retrieve captions and images.

## Technology Stack

- **Frontend:** Flutter (Dart)
- **Backend:** Node.js with Express
- **Database:** In-memory storage (for demo purposes)
- **AI Integration:** External AI service (e.g., OpenAI)
- **State Management:** Provider
- **External APIs:** RocketAPI for Instagram content

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

5. Set up environment variables:

   Copy `.env.example` to `.env` and fill in the required API keys.

6. Start the server:

   ```bash
   npm run dev
   ```

## Instagram Integration

This app integrates with Instagram posts to extract recipe information from captions. To set up the Instagram integration:

1. Sign up for a RapidAPI key at [RapidAPI](https://rapidapi.com/)
2. Subscribe to the [RocketAPI for Developers](https://rapidapi.com/rocketapi-rocketapi-default/api/rocketapi-for-developers/)
3. Add your API key to the `.env` file as `RAPID_API_KEY`

To test the Instagram integration:

```bash
cd server
node test-instagram.js https://www.instagram.com/p/SHORTCODE/
```

The integration allows the app to:

- Extract captions from Instagram posts
- Retrieve the image from the post
- Process the caption with AI to identify recipe details
- Create a recipe entry with metadata from Instagram

## Screenshots

![Home Screen](assets/screenshots/home_screen.png)
![AI Recipe Screen](assets/screenshots/ai_recipe_screen.png)
![Recipe List Screen](assets/screenshots/recipe_list_screen.png)

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Recipe App

A Flutter application for managing recipes, with features to generate and import recipes.

### Development Setup

1. Clone this repository
2. Install Flutter SDK
3. Run `flutter pub get` in the client directory
4. Set up the server environment:
   - Navigate to the server directory
   - Run `npm install`
   - Create a `.env` file with the required environment variables

### Running the App

1. Start the server: `npm run dev` in the server directory
2. Run the Flutter app: `flutter run` in the client directory

### Firebase Setup

The app uses Firebase for authentication and Firestore for data storage. To configure Firebase:

1. Create a new Firebase project at https://console.firebase.google.com/
2. Enable Authentication (Email/Password and Google sign-in)
3. Enable Cloud Firestore
4. Deploy the Firestore security rules:

   ```
   # Install Firebase CLI if you haven't already
   npm install -g firebase-tools

   # Login to your Firebase account
   firebase login

   # Initialize Firebase in your project directory (if not already done)
   firebase init

   # Deploy the Firestore security rules
   firebase deploy --only firestore
   ```

### Fixing Firestore Permissions Issues

If you encounter a "Missing or insufficient permissions" error:

1. Make sure you've deployed the Firestore security rules
2. Check that the collection paths in your code match the paths in the security rules
3. Verify that the user is properly authenticated before accessing protected data

### License

MIT
