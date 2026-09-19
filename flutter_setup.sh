# Create the project
flutter create fanta_app
cd fanta_app

# Add dependencies
flutter pub add firebase_core firebase_auth firebase_database geolocator url_launcher
flutter pub add lottie  # optional for splash animation

# Generate firebase_options.dart
dart pub global activate flutterfire_cli
flutterfire configure