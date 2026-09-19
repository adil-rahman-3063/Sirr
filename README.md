# سِرّ • Sirr: Islamic Prayer Companion

<p align="center">
  <h2 align="center">سِرّ • Sirr</h2>
  <p align="center">
    <strong>A modern, privacy-first Islamic prayer companion with dynamic glassmorphism and serverless push notifications.</strong>
  </p>
  <p align="center">
    <img src="https://img.shields.io/badge/version-3.0.0-blue.svg?style=flat-square" alt="Version 3.0.0" />
    <img src="https://img.shields.io/badge/Flutter-3.x-02569B?style=flat-square&logo=flutter&logoColor=white" alt="Flutter" />
    <img src="https://img.shields.io/badge/Cloudflare_Workers-Serverless-F38020?style=flat-square&logo=cloudflare&logoColor=white" alt="Cloudflare Workers" />
    <img src="https://img.shields.io/badge/Cloudflare_D1-SQL_Database-F38020?style=flat-square&logo=sqlite&logoColor=white" alt="Cloudflare D1" />
    <img src="https://img.shields.io/badge/License-MIT-green.svg?style=flat-square" alt="License: MIT" />
  </p>
</p>

---

## ✨ Features

- 🕋 **Accurate Astronomical Prayer Times**: Computes daily prayer timings (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha) tailored to exact GPS coordinates via Aladhan API with countdown timer to the next prayer.
- 🔔 **100% Anonymous Web Push System**:
  - Cloudflare-native Web Push architecture (RFC 8291/8292) without Firebase or Google Play Services dependencies.
  - 1-minute serverless cron dispatcher running on Cloudflare Workers & Cloudflare D1 SQL.
  - Zero personal data or emails required—completely private and encrypted end-to-end.
- 🎨 **Dynamic Time-of-Day Glassmorphism Engine**:
  - Automatically shifts through 5 tailored prayer period color palettes (Fajr, Morning/Dhuhr, Asr, Maghrib, Isha).
  - Instant time-of-day detection on app launch eliminates theme flashing during loading.
  - Adaptive frosted glass cards, soft glow highlights, and period-matched Shimmer skeleton screens.
- 🪄 **Glassmorphic Floating SnackBars**:
  - Frosted blur (`BackdropFilter`) with pill capsule rounded edges (`BorderRadius.circular(24)`).
  - Dynamic glowing status badges and responsive centering matching the active prayer theme.
- 🕌 **Calligraphic Splash Screen**:
  - Frosted illuminated emblem showcasing **"سِرّ"** in authentic Arabic calligraphy (*Aref Ruqaa*).
  - Sleek capsule `LinearProgressIndicator` loading bar and smooth fade-in transitions.
- 🧭 **Interactive Qibla Compass**:
  - Real-time magnetic heading calculation, smooth compass rotation, Kaaba alignment indicators, and one-tap calibration.
- 📅 **Hijri Calendar & Habit Heatmap**:
  - Real-time Hijri date conversion, upcoming Islamic event countdowns (Ramadan, Eid, etc.).
  - Daily prayer habit tracking with swipe-to-complete actions and a GitHub-style consistency heatmap.

---

## 🛠️ Architecture & Tech Stack

### Client (Flutter Web & Mobile)
- **Framework**: [Flutter](https://flutter.dev) (Dart SDK `^3.9.2`)
- **State & Theming**: [Provider](https://pub.dev/packages/provider) + Dynamic `ThemeProvider` with 5 prayer periods
- **Typography**: [Google Fonts](https://pub.dev/packages/google_fonts) (*Amiri*, *Aref Ruqaa*, *Outfit*)
- **Storage**: [SharedPreferences](https://pub.dev/packages/shared_preferences) & [sqflite](https://pub.dev/packages/sqflite) / [sqflite_common_ffi_web](https://pub.dev/packages/sqflite_common_ffi_web)
- **Sensor & Geo**: [Geolocator](https://pub.dev/packages/geolocator), [Geocoding](https://pub.dev/packages/geocoding), [Flutter Compass](https://pub.dev/packages/flutter_compass)
- **Native Notifications**: [flutter_local_notifications](https://pub.dev/packages/flutter_local_notifications) (Android/iOS offline alerts)

### Backend (Cloudflare Serverless)
- **Compute**: [Cloudflare Workers](https://workers.cloudflare.com/) (TypeScript / Edge runtime)
- **Database**: [Cloudflare D1](https://developers.cloudflare.com/d1/) (Serverless distributed SQLite database)
- **Trigger**: 1-minute Cron Trigger (`* * * * *`) for automated prayer time matching & dispatch
- **Web Push Protocol**: RFC 8291 / RFC 8292 VAPID encryption with AES-128-GCM payload encryption

---

## 🚀 Getting Started

### Prerequisites
- [Flutter SDK](https://docs.flutter.dev/get-started/install) (3.27+ recommended)
- [Node.js](https://nodejs.org/) & [Wrangler CLI](https://developers.cloudflare.com/workers/wrangler/) (for backend deployment)

### 1. Clone the Repository
```bash
git clone https://github.com/adil-rahman-3063/Sirr.git
cd Sirr
```

### 2. Install Dependencies
```bash
flutter pub get
```

### 3. Run Locally
```bash
# Run on Web (Chrome)
flutter run -d chrome

# Run on Android Device / Emulator
flutter run -d android

# Run on Windows Desktop
flutter run -d windows
```

### 4. Cloudflare Worker Deployment (Optional)
```bash
cd cloudflare_worker
npm install
npx wrangler d1 execute sirr-push-db --remote --file=./schema.sql
npx wrangler deploy
```

---

## 📋 Release Notes

### What's New in v3.0.0 🎉

#### 🔔 Anonymous Cloudflare Web Push Engine
- **No Firebase Needed**: 100% serverless, zero-dependency Web Push notification pipeline running on Cloudflare Workers and Cloudflare D1.
- **Automated Cron Delivery**: Minute-accurate prayer dispatch with automatic daily Aladhan cache management and timezone sanitization.
- **Privacy-First**: Anonymous device push subscriptions without user accounts or tracking.

#### 🎨 Dynamic Glassmorphism & UI Refresh
- **Calligraphic Splash Screen**: Illuminated emblem featuring **"سِرّ"** calligraphy (*Aref Ruqaa*) with a sleek capsule loading bar.
- **Glassmorphic Floating SnackBars**: Custom frosted pill SnackBars with rounded edges, dynamic accent glow, and status badges.
- **Zero-Flash Dynamic Theme Loading**: Time-of-day dynamic initialization renders skeleton loading instantly in the appropriate theme (Fajr, Morning, Asr, Maghrib, Isha).
- **Sanitized Console Logging**: Cleared all verbose raw endpoints and payload logging from client consoles.

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome! Feel free to check the [issues page](https://github.com/adil-rahman-3063/Sirr/issues).

---

## 📄 License

This project is open-source and licensed under the [MIT License](LICENSE).
