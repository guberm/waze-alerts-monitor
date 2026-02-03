# 🚨 Waze Alerts Monitor

Real-time Waze alert notifications with voice alerts, customizable filtering, and dark mode support.

[![Flutter](https://img.shields.io/badge/Flutter-3.38.8-blue.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-3.10.7-blue.svg)](https://dart.dev)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Android](https://img.shields.io/badge/Android-16+-green.svg)](https://www.android.com)

## Features

- 📍 **Real-time GPS Tracking** - Automatic location detection with fallback accuracy levels
- 🔊 **Voice Alerts** - Text-to-speech notifications for incoming alerts
- 📱 **Persistent Monitoring** - Continuous background monitoring with customizable intervals
- 🚔 **Multiple Alert Types** - Support for:
  - 🚔 Police presence
  - ⚠️ Road hazards
  - 🚨 Accidents
  - 📸 Speed cameras
  - 🚦 Red light cameras
- ✅ **Selective Filtering** - Choose which alert types to receive notifications for
- 🌍 **Multi-Region Support** - North America, Israel, Rest of World
- 🎯 **Radius Control** - Search radius presets: 0.3, 0.5, 1, 2, 3, 4, 5 km
- ⏱️ **Refresh Interval** - Configurable monitoring interval (1-10 minutes)
- 🌙 **Dark Mode** - Full dark theme support with persistent preference
- 📍 **Closest Alert Display** - Notification bar shows the nearest alert with distance
- 🗺️ **Deep Link Integration** - Open alerts directly in Waze app
- 🎨 **Material 3 Design** - Modern, clean interface

## Getting Started

### Prerequisites

- Flutter 3.38.8 or higher
- Dart 3.10.7 or higher
- Android SDK (API 21+)
- Device with GPS enabled

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/waze-alerts-monitor.git
   cd waze-alerts-monitor
   ```

2. **Install dependencies**
   ```bash
   flutter pub get
   ```

3. **Build the APK**
   ```bash
   flutter build apk --release
   ```

4. **Install on device**
   ```bash
   adb install -r build/app/outputs/flutter-apk/app-release.apk
   ```

## Usage

1. **Grant Permissions** - Allow location access when prompted
2. **App Starts Automatically** - Monitoring begins once permissions are granted
3. **Configure Settings** - Tap menu → Settings to customize:
   - Alert types to receive
   - Search radius (0.3-5 km presets)
   - Refresh interval (1-10 minutes)
   - Region (auto-detected by GPS)
   - Dark mode toggle
4. **Voice Alerts** - Listen for notifications as alerts appear
5. **Tap Alert** - View closest alert in notification bar

## Configuration

### Alert Types
All alert types can be toggled independently:
- 🚔 **Police** - Police presence on roads
- ⚠️ **Hazard** - Road hazards (debris, weather, etc.)
- 🚨 **Accident** - Reported accidents
- 📸 **Speed Camera** - Speed enforcement cameras
- 🚦 **Red Light Camera** - Traffic light cameras

### Search Radius
Quick-select buttons for common distances:
- **0.3 km** - Very close monitoring
- **0.5 km** - Close area
- **1 km** - Default radius
- **2 km** - Extended area
- **3-5 km** - Wide radius coverage

### Refresh Interval
Monitor how frequently alerts are fetched:
- **1 min** - High frequency (more battery usage)
- **5 min** - Balanced (recommended)
- **10 min** - Low frequency (saves battery)

## Project Structure

```
lib/
├── main.dart                 # App entry point, theme management
├── screens/
│   └── home_screen.dart     # Main UI and monitoring logic
├── services/
│   └── waze_service.dart    # Waze API integration
└── models/
    └── alert_model.dart     # Data model for alerts

android/
└── app/src/main/
    └── AndroidManifest.xml  # App permissions and configuration
```

## Key Technologies

- **Geolocator** - GPS location services with accuracy fallbacks
- **Flutter TTS** - Text-to-speech voice notifications
- **flutter_local_notifications** - Persistent notification bar
- **permission_handler** - Runtime permission management
- **shared_preferences** - Local settings storage
- **http** - REST API client
- **url_launcher** - Deep linking to Waze

## Waze API Integration

- **Endpoint**: `https://www.waze.com/live-map/api/georss`
- **Features**: Real-time alert data with bounding box filtering
- **Reverse Geocoding**: Nominatim OpenStreetMap API

## Permissions

The app requires the following Android permissions:

```xml
- ACCESS_FINE_LOCATION      - High-precision GPS
- ACCESS_COARSE_LOCATION    - Network-based location
- ACCESS_BACKGROUND_LOCATION - Background monitoring
- INTERNET                  - API requests
- FOREGROUND_SERVICE        - Persistent notification
- WAKE_LOCK                 - Prevent device sleep
```

## Settings Storage

All user preferences are stored locally using SharedPreferences:

- `searchRadius` - Search radius in kilometers
- `region` - Geographic region (na/il/row)
- `refreshInterval` - Monitoring interval in minutes
- `isDarkMode` - Dark mode enabled/disabled
- `showPolice` - Police alerts enabled
- `showHazard` - Hazard alerts enabled
- `showAccident` - Accident alerts enabled
- `showSpeedCamera` - Speed camera alerts enabled
- `showRedLightCamera` - Red light camera alerts enabled

## Troubleshooting

### Location Not Found
- Ensure location services are enabled
- Check GPS signal strength
- Grant location permission when prompted
- Try pulling down to refresh location

### No Alerts Appearing
- Verify you're in an area with Waze data
- Check that alert types are enabled in settings
- Ensure search radius is appropriate
- Check internet connection

### Voice Not Working
- Verify device volume is not muted
- Check device text-to-speech is working
- Ensure app has required audio permissions

## Building from Source

```bash
# Get dependencies
flutter pub get

# Run analyzer
flutter analyze

# Build release APK
flutter build apk --release --no-shrink

# Output: build/app/outputs/flutter-apk/app-release.apk
```

## Versioning

- **Current Version**: 1.0.0
- **Flutter**: 3.38.8
- **Dart**: 3.10.7
- **Minimum Android**: API 21 (Android 5.0)
- **Target Android**: API 36 (Android 16)

## License

MIT License - see LICENSE file for details

## Disclaimer

This is an unofficial Waze application. Waze is a trademark of Google Inc. This app is not affiliated with or endorsed by Google/Waze.

**⚠️ Safety Notice**: This app provides alert information for driving awareness only. Always drive safely and follow traffic laws.

## Author

Made with ❤️ using Flutter

---

**Built with Flutter** 🚀 | **Powered by Dart** ⚡ | **Google Maps Integration** 🗺️
