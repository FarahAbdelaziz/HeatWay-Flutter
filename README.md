# HeatWay

HeatWay is a Flutter application that helps users compare routes using environmental and thermal data and select a cooler route.

## Features

- Select a starting point using GPS or manual location selection.
- Search for a destination address.
- Generate and display thermal heatmap data.
- Compare ranked route alternatives.
- Display route temperature, distance, duration, and thermal coverage.
- View environmental indicators and recommendations.
- Supports Android and Flutter Web.

## Backend

The application communicates with the deployed HeatWay FastAPI backend.

The API base URL is configured in:

```text
lib/config/api_config.dart
```

A different backend URL can be provided at build or run time:

```bash
flutter run --dart-define=HEATWAY_API_URL=http://YOUR_SERVER_IP:8000
```

Backend repository:

https://github.com/omaratef-ahmed/smart-thermal-routing

## Requirements

- Flutter SDK compatible with Dart SDK `^3.7.2`
- Android SDK for Android builds
- An accessible HeatWay backend server
- Location permission on Android

## Installation

Install project dependencies:

```bash
flutter pub get
```

Check the project:

```bash
flutter analyze
```

Run the application:

```bash
flutter run --dart-define=HEATWAY_API_URL=http://YOUR_SERVER_IP:8000
```

## Build Android APK

Build a release APK:

```bash
flutter build apk --release --dart-define=HEATWAY_API_URL=http://YOUR_SERVER_IP:8000
```

The generated APK will be available at:

```text
build/app/outputs/flutter-apk/app-release.apk
```

The APK is distributed through GitHub Releases and is not committed directly to the repository.

## Project Structure

```text
├── android/
├── assets/
├── ios/
├── lib/
├── web/
├── analysis_options.yaml
├── pubspec.lock
├── pubspec.yaml
└── README.md
```

## Version

Current version: `1.0.0+1`

## Disclaimer

Environmental guidance provided by HeatWay is informational and should not be treated as medical advice.
