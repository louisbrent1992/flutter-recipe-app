# App Configuration

This directory contains configuration constants for the Recipease app.

## AppConfig

The `AppConfig` class contains various timing and behavior constants that can be easily adjusted:

### Splash Screen Configuration
- `splashMinDurationMs`: Minimum time (in milliseconds) to show the splash screen (default: 2000ms = 2 seconds)
- `splashTransitionDelayMs`: Additional delay for smooth transition after initialization (default: 500ms)

### Import Screen Configuration  
- `importDelayMs`: Delay for provider initialization in import screen (default: 100ms)
- `importNavigationDelayMs`: Delay for cold start navigation when importing from external apps (default: 1000ms)

### Other Configuration
- `enableDebugLogs`: Enable/disable debug logging (default: true)
- `enablePerformanceOverlay`: Enable/disable Flutter performance overlay (default: false)

## Usage

To adjust the splash screen duration, simply modify the values in `app_config.dart`:

```dart
// Make splash screen show for 3 seconds minimum
static const int splashMinDurationMs = 3000;

// Add 1 second transition delay
static const int splashTransitionDelayMs = 1000;
```

## Benefits

- **Centralized Configuration**: All timing constants in one place
- **Easy Adjustment**: Change durations without hunting through code
- **Consistent Behavior**: Same timing values used across the app
- **Better UX**: Ensures app is fully loaded before showing main interface
