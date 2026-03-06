# Project Completion Summary

## 📋 Overview
SafeGuardHer is a Flutter-based women's safety app that continuously monitors audio for distress sounds, processes them with a TFLite CNN model, and triggers SOS alerts with location via SMS to emergency contacts.

## ✅ Milestones Completed
- **Milestone 1: Project Setup** – Flutter project created, dependencies added, assets configured.
- **Milestone 2: Permissions Onboarding** – Multi‑page onboarding flow with microphone, location, SMS permissions and emergency contact setup.
- **Milestone 3: Emergency Contacts** – CRUD UI and Hive‑backed persistence for contacts.
- **Milestone 4: TFLite Integration** – Model loading, inference, configurable threshold.
- **Milestone 5: Audio Capture & Pre‑processing** – Pure‑Dart mel‑spectrogram pipeline.
- **Milestone 6: Background Service** – Foreground Android service with 2‑second audio cycles, cooldown handling, auto‑restart.
- **Milestone 7: Alert System** – GPS fetch, SMS dispatch, alert logging, manual SOS bypass.
- **Milestone 8: UI Construction** – Home dashboard, contacts screen, settings screen, design system with dark‑first palette, glass‑morphism, Outfit font.

## 🛠️ Build Fixes Applied
1. **Telephony namespace fix** for AGP 8+ compatibility.
2. **Record Linux version override** to resolve incompatibility.
3. **AndroidManifest merge conflict** resolved with `tools:replace`.
4. Various Dart analyzer fixes (opacity, switch cases, imports, etc.).

## 📁 Model Details
| Property | Value |
|---|---|
| File | `assets/models/cnn_model.tflite` |
| Input Name | `conv2d_input` |
| Input Shape | `[1, 128, 94, 1]` |
| Input Type | Float32 mel spectrogram (0.0‑1.0) |
| Output | Single float32 (0‑1) |
| Threshold | `> 0.5` (configurable 0.3‑0.8) |
| Audio | 22050 Hz, 16‑bit PCM, ~2 s chunks |

## 🔄 End‑to‑End Flow
```
User Enables Protection
    ↓
Background Service Starts (Foreground Notification)
    ↓
Record 2‑sec Audio Chunk
    ↓
Extract Mel Spectrogram [128 × 94]
    ↓
Normalize → Reshape to [1, 128, 94, 1]
    ↓
TFLite CNN Inference
    ↓
Output > 0.5? ──→ NO → Record next chunk (loop)
    │
    ↓ YES
Trigger Alert → Fetch GPS → Send SMS → Log Alert + 60 s cooldown → Resume Listening
```

## 📱 Android Configuration
- **Permissions**: RECORD_AUDIO, SEND_SMS, ACCESS_FINE_LOCATION, FOREGROUND_SERVICE, WAKE_LOCK, etc.
- **Build**: minSdkVersion 24, compileSdk from Flutter, Kotlin 2.2.20, AGP 8.11.1.

## 🚀 How to Run
```bash
# Install dependencies
flutter pub get

# Run on device/emulator
flutter run

# Build debug APK
flutter build apk --debug

# Build release APK
flutter build apk --release
```

## 📝 Notes & Future Improvements
1. iOS SMS fallback (url_launcher or Twilio).
2. Battery optimization with adaptive audio chunks.
3. False‑positive tuning via sensitivity slider.
4. Record video/audio evidence on alert.
5. Separate notification channels.
6. Expand widget testing.
7. Consider migrating from the unmaintained `telephony` plugin.
