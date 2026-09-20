# Google Play Console: Data Safety & Policy Compliance Guide

---

## 1. Data Safety Section Responses

When completing the **Data Safety** questionnaire in Google Play Console, use the exact answers below:

### Does your app collect or share any of the required user data types?
- Select: **Yes** (Location only, for astronomical calculation and Qibla).

### Data Type 1: Location -> Approximate Location & Precise Location
1. **Is this data collected, shared, or both?**
   - Select: **Collected**
2. **Is this data processed ephemerally?**
   - Select: **Yes** (The data is processed in memory on-device to compute solar angles and Qibla heading, and not permanently stored or tied to user identity).
3. **Is this data required for your app, or can users choose whether it's collected?**
   - Select: **Data collection is required** (or user can opt out and enter coordinates/city manually).
4. **Why is this user data collected?**
   - Select: **App functionality**
   - Description: *Used strictly to calculate astronomical prayer times tailored to the user's geographical position and determine Qibla compass bearing to Mecca.*
5. **Is this data shared with third parties?**
   - Select: **No** (Coordinates are not shared with data brokers or advertisers).

### Other Data Categories:
- **Personal info (Name, Email, Address, Phone):** No
- **Financial info:** No
- **Health & Fitness:** No
- **Messages / SMS:** No
- **Photos and videos:** No
- **Audio files:** No
- **Files and docs:** No
- **Calendar:** No
- **Contacts:** No
- **App activity / Page views:** No
- **Web browsing history:** No
- **App info and performance (Diagnostics/Crash logs):** No
- **Device or other IDs (Advertising ID):** No

---

## 2. Security Practices
- **Is data encrypted in transit?** -> **Yes** (All API communication uses TLS 1.3 / HTTPS).
- **Do you provide a way for users to request that their data be deleted?** -> **Yes** (Users can reset app data in system settings or unsubscribe from push notifications).

---

## 3. Policy Declarations in Google Play Console

### A. Alarms & Reminders (`USE_EXACT_ALARM` / `SCHEDULE_EXACT_ALARM`)
- **Category:** **Alarms and reminders**
- **Rationale / Justification Text:**
  > *Sirr is an Islamic prayer companion app that provides punctual prayer time reminders. Islamic prayer times shift daily by 1 to 2 minutes based on solar declination. Delivering alerts at the exact calculated astronomical minute is the core functionality of the application, requiring exact alarms to wake the device from idle mode.*

### B. App Access
- Select: **All functionality is available without special access** (No login or credentials needed).

### C. Ads
- Select: **No, my app does not contain ads**.

### D. Content Rating (IARC)
- **Email:** `adilrahman3063@gmail.com`
- **Category:** **Utility, Productivity, Communication, or Other**
- Violence: No
- Sexuality: No
- Language / Profanity: No
- Controlled Substances: No
- Location Sharing with other users: No
- Digital Goods Purchase: No
- Resulting Rating: **PEGI 3 / Everyone (3+)**

### E. Target Audience & Content
- Target age groups: **13-15, 16-17, 18 and over**
- Could your store listing appeal to children? **No**

### F. Privacy Policy URL
- Enter: `https://sirr.pages.dev/privacy.html`
