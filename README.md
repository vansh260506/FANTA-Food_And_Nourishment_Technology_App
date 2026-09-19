# FANTA-Food_And_Nourishment_Technology_App
Fanta x Savethe#MotherEarth
About the Project
Fanta App is a cross-platform mobile application built with Flutter that bridges the gap between food donors and recipients in need. It provides a simple, reliable way for individuals and organizations to donate surplus food, request food based on real needs, and coordinate deliveries through a dedicated driver dashboard.

The app is designed for real-world impact — reducing food waste while feeding communities. Every donation is tagged with a live location, and every delivery is routed through Google Maps for accurate navigation.

Developed during a 24-hour Intra-Institutional Internship at MS Ramaiah Institute of Technology, Bangalore.

Features
For Donors
Register and login as a Donor

Submit surplus food with quantity and auto-fetched location

Track donation history with live status

View personal impact — total donations completed

For Receivers
Register and login as a Receiver

Submit food requests with number of people and location

Track request history with live status

View personal impact — total requests fulfilled and people served

For Drivers
Browse all pending donations and requests

Sort by distance from current location

Accept jobs with atomic transactions (prevents double-booking)

Open Google Maps with a one-tap driving route from donor to receiver

Mark deliveries as completed and notify both parties

Common Features
Email/password authentication via Firebase

Editable user profile (name, phone)

Role-based navigation drawer

Smooth fade transitions between screens

Floating snackbars for feedback

Status chips for tracking (Pending, In Progress, Completed, Cancelled)

Tech Stack
Layer	Technology
Framework	Flutter 3.x
Language	Dart 3.x
Authentication	Firebase Authentication
Database	Firebase Realtime Database
Location	Geolocator plugin
Maps	URL Launcher (Google Maps deep link)
State Management	StatefulWidget + StreamBuilder
How It Works
User registers as either a Donor or Receiver

Donor submits a food donation — name, phone, quantity, and location

Receiver submits a food request — name, phone, people count, and location

Driver opens the dashboard and sees both pending lists

Driver accepts a job — the app pairs one donor with one receiver

Driver taps "Open in Maps" — Google Maps opens with a live driving route

Driver completes the delivery — both donor and receiver are notified

Users view their history and personal impact at any time

Screens
The application contains 19 unique screens, including:

Auth Flow — Welcome, Login, Register Choice, Register Form

Home & Navigation — Home, Drawer Menu

Forms — Donor Form, Receiver Form

Driver Dashboard — Job Selection, Active Delivery

History & Impact — My History, My Impact (role-specific)

Profile — Editable user details

System UI — Snackbars, Dialogs, Permission Prompts

Each screen is designed with a clean Material Design language — teal app bars, amber action buttons, rounded cards, and clear status indicators.

Getting Started
Prerequisites
Before running the app, ensure you have:

Flutter SDK 3.0 or higher

Dart SDK 3.0 or higher

Android Studio or Visual Studio Code with Flutter extension

Firebase account (free tier is sufficient)

A physical device or emulator with GPS support

Verify Your Environment
Run flutter doctor -v and make sure all required items are marked with a green checkmark before proceeding.

Firebase Setup
1. Create a Firebase Project
Go to the Firebase Console

Create a new project named Fanta App

Skip Google Analytics (optional)

2. Enable Required Services
Authentication → Sign-in method → Enable Email/Password

Realtime Database → Create database → Start in Test Mode

3. Register Your App
Add an Android app with package name com.example.fanta_app

Add an iOS app with bundle ID com.example.fantaApp

Download the config files and place them in the correct directories

4. Generate Flutter Firebase Options
Run the FlutterFire CLI from your project root to generate the required configuration file. Select your Firebase project and the platforms you're targeting.

5. Set Database Rules (Development)
For development, allow any authenticated user to read and write. Before production, tighten these rules to validate ownership per user.

Data Structure
The app uses Firebase Realtime Database with four main nodes:

users
Stores each registered user's name, phone, and role (donor or receiver).

donors
Stores each donation with name, phone, quantity, location, status, and assignment fields when a driver accepts the job.

receivers
Stores each request with name, phone, people count, location, status, and the linked donor key when assigned.

messages
Stores delivery notifications per phone number. When a driver completes a job, both the donor and receiver receive a message here.

Status Lifecycle
Every record moves through a defined lifecycle:

PENDING — waiting for a driver to accept

IN PROGRESS — assigned to a driver and being delivered

COMPLETED — successfully delivered

CANCELLED — cancelled by donor, receiver, or driver

User Flows
Donor Flow
Register → Login → Open Drawer → Donor Form → Fill Details → Fetch Location → Submit → Track in History & Impact

Receiver Flow
Register → Login → Open Drawer → Receiver Form → Fill Details → Fetch Location → Submit → Track in History & Impact

Driver Flow
Login → Open Drawer → Driver Dashboard → Fetch My Location → Select Donor → Select Receiver → Accept Job → Open in Maps → Mark Completed

Permissions Required
Android
Fine Location — for precise GPS coordinates

Coarse Location — for approximate location fallback

Internet — for Firebase and Google Maps

iOS
Location When In Use — required for tagging donations

Location Always and When In Use — required for driver navigation

The app requests location permission only when the user taps "Fetch My Location" — never on launch.

Troubleshooting
Location permission dialog never appears
Ensure both ACCESS_FINE_LOCATION and ACCESS_COARSE_LOCATION permissions are declared in the Android manifest.

"Cannot open maps" appears in a snackbar
The app's manifest is missing the required <queries> block for Android 11 and above. Without it, the system blocks the app from launching Google Maps.

Firebase PERMISSION_DENIED
The Realtime Database rules are still in locked mode. Update them to allow reads and writes for authenticated users.

Geolocator plugin exception
Run flutter clean and flutter pub get, then do a full restart of the app. Plugin registration does not work through hot reload.

Blank screen on launch
Firebase is likely not initialized. Check that the Firebase configuration files are correctly placed and that the generated options file exists.

Team
Name	USN	Role
Gaurav Durge	1MS24IS045	Developer
Tushar Harihar	1MS24EC138	Developer
Institution: MS Ramaiah Institute of Technology, Bangalore
Department: Computer Science & Engineering
Internship: INT410 — Intra Institutional Internship
Duration: 05 August 2025 – 12 August 2025 (24 Hours)
Domain: Mobile Application Development

Acknowledgements
We sincerely thank:

The Department of Computer Science & Engineering at MS Ramaiah Institute of Technology for organizing this internship

Our Faculty Co-Ordinator for continuous guidance throughout the program

The Flutter, Firebase, and Google Maps teams for providing powerful, free developer tools

The open-source community for the plugins that made this app possible

License
This project is released under the MIT License.

You are free to use, modify, and distribute this software for personal or commercial purposes, provided the original copyright notice is retained.

<div align="center">
🌟 Fanta App
Reducing food waste. Feeding communities. One delivery at a time.

Made with ❤️ in Bangalore, India

</div>
