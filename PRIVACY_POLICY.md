# Exhaustive Privacy Policy for سِرّ • Sirr

**Effective Date:** September 21, 2026  
**Last Updated:** September 21, 2026  
**Application Name:** سِرّ • Sirr (Islamic Prayer Companion & Qibla Direction)  
**Package Identifier:** `com.adilrahman.sirr`  
**Developer:** AR Creations  
**Website:** [https://sirr.pages.dev](https://sirr.pages.dev)  
**Contact Email:** [adilrahman3063@gmail.com](mailto:adilrahman3063@gmail.com)  

---

## 1. Introduction and Philosophy

Welcome to **سِرّ • Sirr** ("we", "us", "our", or the "Application"). We are profoundly committed to honoring, respecting, and safeguarding the digital privacy and civil liberties of every individual who uses our mobile and web applications.

Sirr was engineered from its very foundation upon a strict **Privacy-by-Design and Zero-Knowledge architecture**. Unlike conventional utility applications, Sirr operates under the firm principle that religious practice, daily spiritual habits, and prayer times are deeply personal and private. We believe you should never be required to sacrifice your personal data, privacy, or anonymity in order to access accurate Islamic prayer schedules, Qibla compass navigation, and spiritual habit tools.

This Privacy Policy constitutes a legally binding document explaining the exact nature of data interactions within Sirr across all supported platforms (Android, iOS, and Web/PWA), in full alignment with international privacy regulations including the **General Data Protection Regulation (GDPR - Regulation (EU) 2016/679)**, the **California Consumer Privacy Act as amended by the California Privacy Rights Act (CCPA/CPRA)**, the **Children's Online Privacy Protection Act (COPPA)**, the **Personal Data Protection Act (PDPA)**, and the **Google Play Developer Program Policies**.

---

## 2. Summary of Core Commitments

- **No Personal Identifiable Information (PII) Collected:** We do not collect, request, or store your name, email address, physical address, phone number, contacts, biometric identifiers, or government-issued IDs.
- **No User Account Requirement:** You can access 100% of Sirr’s features without registering, creating an account, or logging in.
- **No Commercial Advertising or Tracking:** Sirr contains **zero** third-party advertising SDKs, zero behavioral tracking pixels, and zero data broker partnerships.
- **No Sale or Monetization of User Data:** We do not sell, rent, license, monetize, trade, or share your data with advertisers, marketing networks, or data brokers. Ever.
- **Ephemeral & Localized Processing:** Geographic coordinates requested for astronomical prayer time calculations and Qibla heading determination are processed ephemerally on-device or handled via privacy-preserving anonymous tokens.

---

## 3. Categories of Data & Permissions Used

To deliver its core features, Sirr interacts with specific hardware sensors and operating system permissions. Below is an exhaustive breakdown of every category of data, the technical permission requested, the explicit purpose, and the retention timeframe.

### 3.1 Geographical Location Data
- **Android Permissions:** `android.permission.ACCESS_FINE_LOCATION`, `android.permission.ACCESS_COARSE_LOCATION`
- **Web / iOS API:** `navigator.geolocation.getCurrentPosition()`, `CoreLocation`
- **Why It Is Needed:**
  1. *Astronomical Prayer Calculations:* Daily Islamic prayer timings (Fajr, Sunrise, Dhuhr, Asr, Maghrib, Isha) are strictly determined by the exact position of the Sun relative to the user's specific latitude, longitude, and elevation on Earth.
  2. *Qibla Direction:* The true bearing towards the Kaaba in Mecca, Saudi Arabia ($21.4225^\circ\text{ N}, 39.8262^\circ\text{ E}$) requires knowing the user's current geographic coordinate to calculate the great-circle course angle.
- **Processing and Storage:**
  - **Mobile Native (Android/iOS):** Location coordinates are retrieved locally on your device to query astronomical computation tables (via the open Aladhan API or local astronomical algorithms). Location coordinates are never transmitted to our private servers or logged to any database.
  - **Web Push Notifications (Optional Web Feature):** If a user explicitly opts in to background serverless web push notifications on the Web platform, approximate coordinates rounded to two decimal places ($\approx 1.1\text{ km}$ precision, eliminating exact street-level identification) along with the regional IANA timezone identifier (e.g., `Asia/Kolkata`, `Asia/Dubai`, `Europe/London`) are stored in an encrypted Cloudflare D1 SQL database alongside an anonymous RFC 8291 Web Push endpoint token. This is used solely by the serverless dispatcher to evaluate daily prayer times for that region.
- **Retention Period:** Mobile location coordinates are ephemeral and discarded from memory immediately after calculation. Web push location keys are retained only while the push subscription remains active and are deleted immediately upon user unsubscription.

### 3.2 Sensor & Compass Data
- **Android / iOS Sensor:** Magnetometer (Magnetic Field Sensor) & Accelerometer
- **Purpose:** Used in real-time within the interactive Qibla Compass screen to compute the magnetic azimuth heading of the device and guide the user toward the Kaaba.
- **Processing and Storage:** 100% on-device and real-time. Sensor readings are never stored in persistent memory, cached to disk, or transmitted across the network.

### 3.3 Exact Alarms & Background Scheduling
- **Android Permissions:** `android.permission.SCHEDULE_EXACT_ALARM`, `android.permission.USE_EXACT_ALARM`, `android.permission.WAKE_LOCK`, `android.permission.RECEIVE_BOOT_COMPLETED`
- **Purpose:** In accordance with Google Play's *Alarms & Reminders Policy*, Islamic prayer times shift daily by 1 to 2 minutes due to seasonal solar declination. To ensure the user is notified at the exact calculated minute of each prayer—even when the device is in Deep Sleep / Doze mode—Sirr schedules exact alarm intents via Android's `AlarmManager`.
- **Processing and Storage:** Alarm intents are managed entirely by the operating system on the local device. No telemetry or alarm trigger data is transmitted off the device.

### 3.4 Notifications
- **Android Permission:** `android.permission.POST_NOTIFICATIONS`
- **Purpose:** Delivering foreground and background banners, lock-screen notifications, and audible prayer calls when a prayer time arrives.
- **Control:** Users possess full, granular control to enable or disable alerts for any individual prayer (Fajr, Dhuhr, Asr, Maghrib, Isha) at any time directly in the app settings.

### 3.5 Local Device Preferences & Habit Storage
- **Mechanism:** `SharedPreferences` and local SQLite / IndexedDB
- **Data Stored Locally:**
  - User's selected prayer calculation method (e.g., Muslim World League, Umm Al-Qura, Egyptian General Authority of Survey, University of Islamic Sciences Karachi, etc.).
  - Notification toggle states per prayer.
  - Dynamic UI theme preferences (Light, Dark, Period-matched glassmorphic theme).
  - Habit completion checkmarks for the daily prayer consistency tracker.
- **Retention:** Stored exclusively within the application's private sandboxed local storage on your device. Cleared automatically if you clear app storage or uninstall the application.

---

## 4. Third-Party Services and Sub-Processors

Sirr relies on a minimal set of highly reputable infrastructure providers solely for computational and content delivery purposes:

| Service Provider | Role / Purpose | Data Transferred | Privacy Policy Link |
|---|---|---|---|
| **Aladhan API** (Community Open API) | Astronomical prayer calculations & calendar conversions | Latitude, Longitude, Date, Calculation Method ID | [Aladhan Privacy](https://aladhan.com/privacy) |
| **OpenStreetMap Nominatim** | Human-readable city/region reverse geocoding | Approximate Latitude & Longitude | [OSM Privacy Policy](https://wiki.osmfoundation.org/wiki/Privacy_Policy) |
| **Cloudflare Workers & D1** (Web Push Backend) | Anonymous serverless cron dispatcher for Web Push (RFC 8291/8292) | Anonymous Push Endpoint Token, Rounded Coordinates, Timezone | [Cloudflare Privacy](https://www.cloudflare.com/privacypolicy/) |
| **Google Fonts** | Typography delivery (*Amiri*, *Outfit*, *Aref Ruqaa*) | Standard HTTP user-agent header during initial font asset cache | [Google Fonts Privacy](https://developers.google.com/fonts/faq/privacy) |

---

## 5. Global Privacy Rights & Compliance

### 5.1 European Union (GDPR) Compliance
If you reside within the European Economic Area (EEA) or United Kingdom (UK), you possess statutory rights under Articles 12–23 of the GDPR:
- **Right of Access (Art. 15):** You have the right to request confirmation of whether your personal data is processed. (Sirr processes zero personal identifiable data).
- **Right to Rectification (Art. 16) & Erasure (Art. 17):** You may delete all locally stored preferences, cached prayer times, and habit data instantly by clearing the app data or uninstalling the app. Web push subscribers can delete their subscription with a single tap on the "Unsubscribe" button.
- **Right to Restrict Processing (Art. 18) & Data Portability (Art. 20):** All local data resides on your physical hardware under your direct dominion.
- **Legal Basis for Processing:** Processing of location data is conducted solely upon your explicit **Consent (Art. 6(1)(a) GDPR)** provided via the operating system permission dialog.

### 5.2 California Privacy Rights (CCPA / CPRA) Compliance
Under the California Consumer Privacy Act (CCPA) and California Privacy Rights Act (CPRA):
- **Right to Know:** We do not collect or sell consumer personal information.
- **Right to Opt-Out of Sale / Sharing:** Sirr **does not sell or share** personal information for cross-context behavioral advertising (California Civil Code § 1798.140(t)).
- **Non-Discrimination:** We will never discriminate against you for exercising your privacy rights.

### 5.3 Children's Online Privacy Protection Act (COPPA)
Sirr does not knowingly collect, request, or solicit information from children under 13 years of age (or under 16 in the EEA). The application is classified as a general-audience spiritual utility and is completely safe, ad-free, and tracker-free for users of all ages.

---

## 6. Data Security and Technical Safeguards

We implement industry-standard cryptographic and technical safeguards to protect all application data flows:
1. **End-to-End HTTPS / TLS 1.3 Encryption:** All network transmissions between the application and external APIs utilize transport-layer encryption with modern cipher suites.
2. **RFC 8291 / 8292 VAPID Web Push Encryption:** Web push notification payloads are encrypted end-to-end using AES-128-GCM with ECDH key exchange (P-256 curve) prior to transmission through browser push gateways.
3. **App Sandboxing:** All local application storage is strictly partitioned within the secure sandbox environment provided by the host mobile operating system (Android / iOS).

---

## 7. Data Retention & Deletion Policy

- **On-Device Data:** All local settings, habit history, and cached prayer schedules remain on your device until manually deleted or until the application is uninstalled.
- **Web Push Subscription Data:** If you enable web push alerts, you can revoke permissions and delete your subscription token from our Cloudflare D1 database at any time by toggling off notifications in the application or revoking notification permissions in your web browser settings.
- **Automatic Stale Record Purging:** Any push subscription endpoints that return HTTP `404 Not Found` or `410 Gone` during notification dispatch are permanently purged from the database immediately.

---

## 8. Changes to This Privacy Policy

We may periodically update this Privacy Policy to reflect enhancements in application functionality, operating system platform requirements, or evolving legal frameworks. Whenever changes are made, the "Last Updated" date at the top of this document will be revised. We encourage users to review this page periodically.

---

## 9. Contact and Data Protection Inquiries

If you have questions, feedback, or concerns regarding this Privacy Policy or our privacy practices, please contact us:

- **Developer / Publisher:** AR Creations
- **Email:** [adilrahman3063@gmail.com](mailto:adilrahman3063@gmail.com)
- **Official Web Portal:** [https://sirr.pages.dev](https://sirr.pages.dev)
- **Postal Correspondence:** AR Creations, Mumbai, Maharashtra, India
