# SafeGuardHer — Implementation Report

## 📋 Project Overview
**SafeGuardHer** is a Flutter-based women's safety app that uses AI-powered distress detection via a pre-trained TFLite CNN model. The app continuously monitors audio in the background, processes it with a CNN model to detect distress sounds, and automatically triggers SOS alerts with GPS location sharing via SMS to emergency contacts.

**Build Status:** ✅ APK Built Successfully (debug mode)  
**Dart Analyzer:** ✅ Zero Issues  
**Target Platforms:** Android (primary), iOS (secondary)  

---

## 🏗️ Architecture

### Project Structure
```
lib/
├── main.dart                          # App entry point, Hive init, Provider setup
├── core/
│   ├── app_theme.dart                 # AppColors, AppTheme (dark-first design system)
│   └── constants.dart                 # AppConstants (thresholds, limits, labels)
├── models/
│   ├── emergency_contact.dart         # EmergencyContact Hive model
│   ├── emergency_contact.g.dart       # Hive TypeAdapter (hand-written)
│   ├── alert_log.dart                 # AlertLog Hive model
│   └── alert_log.g.dart              # Hive TypeAdapter (hand-written)
├── providers/
│   ├── protection_provider.dart       # Protection toggle, status, alert history
│   ├── contacts_provider.dart         # CRUD for emergency contacts (Hive-backed)
│   └── settings_provider.dart         # Sensitivity, toggles, user name
├── screens/
│   ├── onboarding/
│   │   └── onboarding_screen.dart     # Multi-step permissions + contact setup
│   ├── home/
│   │   └── home_screen.dart           # Dashboard with shield toggle, SOS, alerts
│   ├── contacts/
│   │   └── contacts_screen.dart       # Emergency contacts management
│   └── settings/
│       └── settings_screen.dart       # Sensitivity slider, toggles, user name
├── services/
│   ├── storage_service.dart           # Hive initialization & box management
│   ├── location_service.dart          # GPS location fetching (geolocator)
│   ├── sms_service.dart               # SMS sending via telephony package
│   ├── audio_processing_service.dart  # Mel spectrogram extraction (FFT/Dart)
│   ├── tflite_service.dart            # TFLite model load & inference
│   ├── alert_service.dart             # Alert orchestration (detect → locate → SMS)
│   └── background_service.dart        # Background audio monitoring pipeline
└── widgets/
    ├── shield_button.dart             # Animated shield toggle widget
    ├── sos_button.dart                # Manual SOS emergency button
    ├── status_card.dart               # Real-time status display card
    └── alert_list_tile.dart           # Alert history list item
```

### Design Patterns
- **State Management:** Provider (ChangeNotifier pattern)
- **Local Storage:** Hive (NoSQL, fast, structured)
- **Service Architecture:** Singleton services (lazy initialization)
- **Background Processing:** flutter_background_service (foreground service on Android)

---

## ✅ Milestones Completed

### Milestone 1: Project Setup ✅
- Created Flutter project with `flutter create --org com.safeguardher --project-name womens_safety_app`
- Configured `pubspec.yaml` with all required dependencies:
  - `tflite_flutter: ^0.11.0` — TFLite inference
  - `record: ^5.2.1` — Audio capture
  - `flutter_background_service: ^5.0.12` — Background processing
  - `geolocator: ^13.0.2` — GPS location
  - `telephony: ^0.2.0` — SMS sending (Android)
  - `hive: ^2.2.3` / `hive_flutter: ^1.1.0` — Local storage
  - `provider: ^6.1.2` — State management
  - `permission_handler: ^11.3.1` — Runtime permissions
  - `google_fonts: ^6.2.1` — Typography (Outfit font family)
  - `vibration: ^2.0.0` — Haptic feedback
  - `uuid: ^4.5.1` — Unique IDs for models
  - `url_launcher: ^6.3.1` — Open external URLs
  - `intl: ^0.19.0` — Date formatting
  - `path_provider: ^2.1.5` — File system paths
- Placed `cnn_model.tflite` in `assets/models/`
- Configured Android platform (minSdkVersion 24, permissions, foreground service)

### Milestone 2: Permissions Onboarding ✅
- **File:** `lib/screens/onboarding/onboarding_screen.dart`
- Multi-page onboarding with PageView:
  1. **Welcome Page** — App introduction with shield animation
  2. **Microphone Permission** — Explanation + request (for distress detection)
  3. **Location Permission** — Explanation + request (for emergency GPS sharing)
  4. **SMS Permission** — Explanation + request (for automated alerts)
  5. **Emergency Contact Setup** — Add first trusted contact
  6. **Ready Page** — Completion with navigation to dashboard
- Permission denial handling with "Open Settings" fallback
- Onboarding completion persisted in Hive

### Milestone 3: Emergency Contacts ✅
- **Files:** `lib/screens/contacts/contacts_screen.dart`, `lib/providers/contacts_provider.dart`
- Full CRUD operations (Add, Edit, Delete contacts)
- Hive-backed persistence with `EmergencyContact` model
- 1–5 contact limit enforcement
- Dialog-based forms with phone number and name fields
- Real-time state updates via ContactsProvider

### Milestone 4: TFLite Integration ✅
- **File:** `lib/services/tflite_service.dart`
- Loads `cnn_model.tflite` via `Interpreter.fromAsset()`
- Input: `[1, 128, 94, 1]` Float32 mel spectrogram
- Output: Single Float32 sigmoid value (0.0–1.0)
- Configurable threshold (default 0.5)
- Proper resource cleanup on dispose

### Milestone 5: Audio Capture & Preprocessing ✅
- **File:** `lib/services/audio_processing_service.dart`
- Pure Dart mel spectrogram extraction pipeline:
  1. Raw PCM audio capture at 22050 Hz (16-bit mono)
  2. Pre-emphasis filter (coefficient 0.97)
  3. Frame windowing with Hanning window (2048 samples, 512 hop)
  4. FFT computation (radix-2 Cooley-Tukey algorithm)
  5. Power spectrum → Mel filterbank (128 mel bands, 94 frames)
  6. Log-mel spectrogram with normalization to [0.0, 1.0]
  7. Reshape to [1, 128, 94, 1] for model input
- Helper functions: `_hzToMel()`, `_melToHz()`, `_fft()`, `_createMelFilterbank()`

### Milestone 6: Background Service ✅
- **File:** `lib/services/background_service.dart`
- Android foreground service with persistent notification ("Safety Monitor Active")
- Continuous 2-second audio chunk recording cycle
- Audio → Mel Spectrogram → TFLite Inference pipeline in service isolate
- 60-second cooldown after alert trigger
- Auto-restart on boot (BootReceiver configured)
- Communication between service and UI via `FlutterBackgroundService`

### Milestone 7: Alert System ✅
- **File:** `lib/services/alert_service.dart`
- Alert orchestration flow:
  1. Distress detection triggers alert
  2. GPS location fetched (with last-known fallback)
  3. SMS sent to all emergency contacts
  4. Alert logged with timestamp, location, probability
- SMS format: `⚠️ EMERGENCY ALERT: [Name] needs help! Location: [Google Maps Link] — Auto-sent by SafeGuardHer`
- 60-second cooldown to prevent alert spam
- Manual SOS bypass (skips model, triggers instantly)

### Milestone 8: UI Construction ✅
- **Dashboard (home_screen.dart):**
  - Animated shield toggle button (gradient, glow effects)
  - Real-time status card (Idle/Listening/Alert Triggered)
  - Manual SOS button (3-second long-press safety)
  - Recent alerts list with timestamps and locations
  - Bottom navigation (Home, Contacts, Settings)

- **Contacts (contacts_screen.dart):**
  - Contact cards with initials avatar
  - Add/Edit/Delete dialogs
  - Info card explaining SMS alerts
  - Empty state with call-to-action

- **Settings (settings_screen.dart):**
  - Sensitivity slider (0.3–0.8 range)
  - SMS alerts toggle
  - Sound alerts toggle
  - User name input for SMS personalization
  - Permission status indicators
  - About section with app version

- **Design System (app_theme.dart):**
  - Dark-first color palette with deep indigo/purple tones
  - Primary gradient: `#7C3AED` → `#4F46E5`
  - Glass morphism effects on cards
  - Google Fonts Outfit typography
  - Consistent border radius, shadows, and spacing

---

## 🔧 Build Fixes Applied

### 1. Telephony Namespace Fix (AGP 8+ Compatibility)
**Problem:** `telephony:0.2.0` doesn't declare `namespace` in its `build.gradle`, which AGP 8+ requires.  
**Fix:** Directly patched `%LOCALAPPDATA%\Pub\Cache\hosted\pub.dev\telephony-0.2.0\android\build.gradle` to add `namespace 'com.shounakmulay.telephony'` inside the `android {}` block.  
**Note:** This is a cached-package patch. If `flutter pub get` re-downloads the package, the patch needs reapplication.

### 2. Record Linux Version Incompatibility
**Problem:** `record_linux:0.7.2` was resolved by pub but is incompatible with `record_platform_interface:1.5.0` (missing `startStream` method signature).  
**Fix:** Added `dependency_overrides` in `pubspec.yaml`: `record_linux: ^1.3.0`

### 3. AndroidManifest Merge Conflict
**Problem:** Our manifest declared `android:exported="false"` for `BackgroundService` and `BootReceiver`, but `flutter_background_service_android` plugin declared them as `"true"`.  
**Fix:** Added `xmlns:tools` namespace and `tools:replace="android:exported"` attributes to the conflicting `<service>` and `<receiver>` elements.

### 4. Dart Analyzer Fixes
- Removed deprecated `withOpacity()` calls → replaced with `withValues(alpha: ...)`
- Fixed `default` clauses covering already-handled enum values in switch statements
- Fixed `activeColor` → `activeTrackColor` on Switch widgets
- Renamed `_2` variable to `i` (no leading underscores for local identifiers)
- Removed unnecessary imports

---

## 📁 Model Details

| Property | Value |
|----------|-------|
| **File** | `assets/models/cnn_model.tflite` |
| **Input Name** | `conv2d_input` |
| **Input Shape** | `[1, 128, 94, 1]` (Batch, Height, Width, Channels) |
| **Input Type** | Float32 mel spectrogram (normalized 0.0–1.0) |
| **Output** | Single float32 value (0–1, sigmoid) |
| **Threshold** | `> 0.5` → Distress Detected (configurable 0.3–0.8) |
| **Audio** | 22050 Hz, 16-bit PCM, ~2 second chunks |

---

## 🔄 End-to-End Flow

```
User Enables Protection
        ↓
Background Service Starts (Foreground Notification)
        ↓
Record 2-sec Audio Chunk (22050 Hz PCM)
        ↓
Extract Mel Spectrogram [128 × 94]
        ↓
Normalize [0.0–1.0] → Reshape to [1, 128, 94, 1]
        ↓
TFLite CNN Inference
        ↓
Output > 0.5? ──→ NO ──→ Record next chunk (loop)
        │
        ↓ YES
Trigger Alert
        ↓
Fetch GPS Location (geolocator)
        ↓
Send SMS to All Emergency Contacts
        ↓
Log Alert (Hive) + 60s Cooldown
        ↓
Resume Listening
```

---

## 📱 Android Configuration

### Permissions (AndroidManifest.xml)
- `RECORD_AUDIO` — Microphone for distress audio capture
- `SEND_SMS` / `READ_SMS` / `READ_PHONE_STATE` — SMS alert sending
- `ACCESS_FINE_LOCATION` / `ACCESS_COARSE_LOCATION` / `ACCESS_BACKGROUND_LOCATION` — GPS for emergency location
- `FOREGROUND_SERVICE` / `FOREGROUND_SERVICE_MICROPHONE` — Background audio monitoring
- `WAKE_LOCK` — Keep service alive
- `RECEIVE_BOOT_COMPLETED` — Auto-restart on device reboot
- `VIBRATE` — Haptic feedback on alerts
- `POST_NOTIFICATIONS` — Foreground service notification
- `INTERNET` — Google Fonts loading

### Build Configuration
- **minSdkVersion:** 24
- **compileSdk:** (default from Flutter SDK)
- **Kotlin:** 2.2.20
- **AGP:** 8.11.1

---

## 🚀 How to Run

```bash
# Install dependencies
flutter pub get

# Run on connected device/emulator
flutter run

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release
```

---

## 📝 Notes & Future Improvements

1. **iOS Support:** SMS sending requires fallback (url_launcher to prefill Messages app or Twilio backend)
2. **Battery Optimization:** Consider adaptive audio chunks (3-5 sec) to reduce processing  
3. **False Positive Tuning:** Sensitivity slider allows users to adjust (0.3 = more sensitive, 0.8 = less)
4. **Audio Recording on Alert:** Future feature — record video/audio evidence during distress events
5. **Notification Channels:** Could add distinct channels for monitoring vs. alert notifications
6. **Widget Testing:** Basic test scaffold created in `test/widget_test.dart`
7. **Telephony Patch:** Consider migrating to a maintained fork of telephony or writing a platform channel for SMS
