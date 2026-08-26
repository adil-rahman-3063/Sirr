# Sirr: Your Personal Prayer Companion

Sirr is a modern, cross-platform prayer tracking and Islamic calendar application built with Flutter. Designed with a sleek glassmorphism UI, it helps Muslims manage their daily prayers, track their spiritual journey, and stay updated with important Hijri dates.

## ✨ Features

- **Accurate Prayer Times**: Automatically calculates prayer times based on your current location (GPS) or defaults to Mecca. Shows countdown to next prayer.
- **Hijri Calendar & Events**: Stay informed about the current Hijri date and upcoming Islamic events (Ramadan, Eid, etc.) with a built-in countdown.
- **Prayer Tracking**: Easily mark prayers as completed with a simple swipe gesture. Visual feedback includes time of completion and daily progress rings.
- **Activity Heatmap**: Visualize your prayer consistency over time with a GitHub-style contribution heatmap.
- **Glassmorphism Design**: Experience a beautiful, modern interface with semi-transparent elements and dynamic backgrounds.
- **Cross-Platform**: Seamlessly runs on Android, Windows, and Web.

## 🛠️ Tech Stack

- **Framework**: [Flutter](https://flutter.dev) (Dart)
- **State Management**: [Provider](https://pub.dev/packages/provider) (Used implicitly or planned) / `setState` based for now.
- **Database**: [SQFlite](https://pub.dev/packages/sqflite) (Local data persistence)
- **Geolocation**: [Geolocator](https://pub.dev/packages/geolocator) & [Geocoding](https://pub.dev/packages/geocoding)
- **Visualization**: [Flutter Heatmap Calendar](https://pub.dev/packages/flutter_heatmap_calendar)
- **UI Components**: Custom Glass Containers, Material 3 Theming.

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (Latest Stable)
- Dart SDK
- Android Studio / VS Code with Flutter extensions

### Installation

1.  **Clone the repository:**
    ```bash
    git clone https://github.com/adil-rahman-3063/Sirr.git
    cd sirr
    ```

2.  **Install dependencies:**
    ```bash
    flutter pub get
    ```

3.  **Run the app:**
    ```bash
    # For Android
    flutter run

    # For Web
    flutter run -d chrome

    # For Windows
    flutter run -d windows
    ```

## 📸 Screenshots

*(To be added)*

## 🤝 Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
