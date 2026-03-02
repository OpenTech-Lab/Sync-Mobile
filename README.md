# Sync Mobile

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Repo](https://img.shields.io/badge/GitHub-sync--mobile-blue?logo=github)](https://github.com/OpenTech-Lab/sync-mobile)

Sync Mobile is the client-side component of the open-source, privacy-focused Sync chat application. It provides a seamless, cross-platform mobile experience for secure messaging on iOS and Android. Built with Flutter, the app connects to self-hosted Sync servers ("planets") via a secure API, emphasizing local data storage with encryption. Chats are stored encrypted on your device by default (no plain text), with optional encrypted backups to the chosen server for multi-device sync—secure like Signal.

This repo focuses on the mobile app: Flutter code for UI, local storage, real-time chat features, and server integration. For the backend/server, see the companion repo: [sync-server](https://github.com/OpenTech-Lab/sync-server).

## Features

- **Cross-Platform Support**: Single codebase for iOS and Android with native performance.
- **Secure Local Storage**: Chat data encrypted on-device using platform-secure storage (e.g., Flutter Secure Storage with AES-256).
- **Real-Time Chat**: Supports typing indicators, smooth scrolling, image/video previews, reactions, unread badges, and more.
- **Server Selection**: On first launch, enter a custom server URL or choose from official/public planets. Servers enforce user limits based on hardware specs.
- **Federated Messaging**: Connect to any Sync planet; supports ActivityPub for cross-server communication.
- **Privacy Controls**: Data stays local unless you opt-in for encrypted server backups. End-to-end encryption for all messages.
- **Notifications**: Push notifications for new messages via FCM (Android) and APNS (iOS).
- **User-Friendly UI**: Modern chat interface with themes, media sharing, and search.

## Architecture

- **Frontend**: Flutter (Dart) for UI and logic.
- **Data Flow**:
  - Connects to server API for message sending/receiving (secure HTTPS endpoints).
  - Local storage: Encrypted SQLite or key-value store for chats; no plain text.
  - Real-time: WebSockets or long-polling for updates like typing and new messages.
  - Federation: Handles ActivityPub discovery for cross-planet users.
- **Security**: App enforces encryption; server backups are user-initiated and encrypted.

## Tech Stack

- **Framework**: Flutter (Dart) for mobile app development.
- **State Management**: Provider, Riverpod, or Bloc for reactive UI.
- **Networking**: http or dio for API calls; web_socket_channel for real-time.
- **Storage/Encryption**: flutter_secure_storage or hive with encryption; sqflite for local DB.
- **Chat UI**: flutter_chat_ui or custom (e.g., gifted_chat alternative).
- **Notifications**: firebase_messaging for FCM/APNS integration.
- **Other Packages**:
  - intl for localization.
  - image_picker for media sharing.
  - cached_network_image for previews.
  - encrypt or cryptography for additional crypto layers.
  - url_launcher for server URL handling.
- **Build Tools**: Flutter CLI for building APKs/IPAs.

## Getting Started

### Prerequisites

- Flutter SDK (version 3.x or later).
- Android Studio (for Android emulation/builds).
- Xcode (for iOS emulation/builds on macOS).
- Git and basic CLI knowledge.
- Optional: Firebase project for push notifications (add google-services.json/plist).

### Installation

1. **Clone the Repo**:
   ```
   git clone https://github.com/OpenTech-Lab/sync-mobile.git
   cd sync-mobile
   ```

2. **Install Dependencies**:
   ```
   flutter pub get
   ```

3. **Configure Environment**:
   - Copy `lib/config.example.dart` to `lib/config.dart` and add defaults (e.g., official planets list, API keys for notifications).
   - For notifications: Setup Firebase and add configs to android/ios directories.

4. **Run in Development**:
   ```
   flutter run
   ```
   - On first run: Enter a server URL (e.g., `https://your-planet.com`) or select from presets.
   - Create/login to an account via the server API.
   - Test chats: Data saves locally encrypted; enable backups if needed.

5. **Build for Production**:
   - Android: `flutter build apk --release`
   - iOS: `flutter build ipa --release` (requires Apple Developer account).
   - Distribute via app stores or sideloading.

6. **Testing**:
   - Use Flutter test: `flutter test`
   - Emulate different devices for iOS/Android consistency.
   - Test server connection: Ensure API endpoints match the sync server setup.

### Customization

- **Server Onboarding**: Modify the initial screen to add more official planets or QR code scanning for URLs.
- **Notifications**: Integrate with server webhooks; handle device tokens in app settings.
- **Themes/UI**: Easily customize with Flutter's theming system.
- **Encryption**: Default is device-key protected; extend with user passphrases if desired.

## Usage

- **As a User**:
  - Install the app (from releases or build).
  - On launch: Choose/connect to a planet (respects max user limits).
  - Start chatting: Messages are E2E encrypted, stored locally.
  - Enable backups: Opt-in for server-side encrypted sync across devices.
  
- **As a Developer**:
  - Integrate with custom servers: Point to your sync instance.
  - Extend features: Add voice calls, groups, or bots via Flutter plugins.

## Contributing

Contributions welcome! See [CONTRIBUTING.md](CONTRIBUTING.md) for details.

- Report issues on GitHub.
- PRs for Flutter code, UI improvements, or new features.
- Focus on performance: Test on low-end devices for smooth scrolling.

## License

MIT License - see [LICENSE](LICENSE).

## Acknowledgments

- Powered by Flutter for beautiful, fast apps.
- Inspired by secure chat apps like Signal, with federation from Mastodon/Matrix.
