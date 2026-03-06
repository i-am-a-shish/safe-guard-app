# Flutter Women's Safety App - Comprehensive Project Plan

## Project Overview
This comprehensive plan outlines the step-by-step development process for building a Flutter-based women's safety app. The app utilizes background audio listening, machine learning-based distress detection via a pre-trained TFLite CNN model, and automated alerts with GPS location sharing via SMS. It emphasizes user privacy, minimal battery usage, and an intuitive UI. The plan integrates details from the initial specifications and refined prompt, following the build order with additional tasks, dependencies, testing, and challenges. 

Development assumes:
- Flutter SDK 3.0+ and Dart 2.18+.
- Primary focus on Android; secondary on iOS due to platform limitations (e.g., background audio and SMS).
- Git for version control; commit after each milestone.
- Estimated timeline: 2-4 weeks for a solo developer.
- Tools: VS Code or Android Studio as IDE; physical devices/emulators for testing.

## Key Assumptions
- Model file (`cnn_model.tflite`) is provided and trained on 22050 Hz audio (confirm; fallback to 16000 Hz if mismatched).
- No external APIs unless necessary (e.g., Twilio for iOS SMS fallback).
- Emphasize security: No unnecessary data collection; local storage only.
- Target audience: Women seeking proactive safety features.

## Model Specifications
| Property          | Value                                                                 |
|-------------------|-----------------------------------------------------------------------|
| File              | `cnn_model.tflite` (place in `assets/models/`)                        |
| Input Name        | `conv2d_input`                                                        |
| Input Shape       | [1, 128, 94, 1] (Batch, Height, Width, Channels)                     |
| Input Type        | Float32 mel spectrogram (normalized 0.0–1.0)                          |
| Output            | Single float32 value between 0–1 (sigmoid)                            |
| Threshold         | Output > 0.5 → Distress Detected (configurable via settings)          |
| Architecture      | 1. Conv2D → BatchNorm → ReLU → MaxPooling<br>2. Conv2D → BatchNorm → ReLU → MaxPooling<br>3. Conv2D → BatchNorm → ReLU → MaxPooling<br>4. GlobalAveragePooling2D<br>5. Dense (ReLU)<br>6. Dense (Output) |

The 128×94 single-channel input represents a mel spectrogram from ~1–2 seconds of audio.

## End-to-End Flow
```
Microphone (Background Listener)
↓
Raw PCM Audio (~1–2 sec chunk, 22050 Hz)
↓
Mel Spectrogram Extraction [128 × 94]
↓
Normalize [0.0–1.0] → Reshape to [1, 128, 94, 1] Float32
↓
TFLite CNN Model Inference
↓
Output Value (0.0 – 1.0)
↓
If > Threshold (default 0.5) → Trigger Alert
↓
Fetch GPS Location (geolocator, background-enabled)
↓
Send SMS to Emergency Contacts with Location Link
↓
Cooldown (60 sec) + Log Alert
```

## Core Features
1. **Background Audio Monitoring**  
   - Continuously capture microphone audio in 1–2 second sliding windows.  
   - Package: `flutter_background_service` or `flutter_foreground_task` for persistence.  
   - Android: Foreground Service with persistent notification ("Safety Monitor Active").  
   - iOS: Background Audio mode via entitlements; handle app suspension.  
   - Audio: PCM format via `flutter_sound` or `record`.

2. **Audio Preprocessing (Mel Spectrogram)**  
   - Sample rate: 22050 Hz (match model training).  
   - Convert PCM to mel spectrogram [128, 94].  
   - Normalize to [0.0, 1.0] float32; reshape to [1, 128, 94, 1].  
   - Package: `fftea` (Dart) for FFT, or native channels (Kotlin: TarsosDSP; Swift: Accelerate).  
   - Verify shape before inference.

3. **TFLite Model Inference**  
   - Package: `tflite_flutter`.  
   - Load from assets; run per spectrogram.  
   - Extract single float32 output.  
   - Configurable threshold (0.3–0.8, default 0.5).

4. **Alert Mechanism**  
   - On detection: Fetch GPS (use last known if unavailable).  
   - SMS Format: "⚠️ EMERGENCY ALERT: [User's Name] needs help! Location: https://www.google.com/maps/search/?api=1&query=[LAT],[LNG] — Auto-sent by Safety App".  
   - Send via `telephony` (Android) or `flutter_sms`; iOS fallback: `url_launcher` to prefill Messages app.  
   - Cooldown: 60 seconds (Timer).  
   - Foreground: Play alarm sound (`flutter_sound`), flash screen.  
   - Log alerts with timestamps/locations.

5. **Emergency Contacts Management**  
   - UI screen for add/edit/delete (name + phone).  
   - Limit: 1–5 contacts.  
   - Storage: `hive` (structured) or `shared_preferences`.  
   - Validation: Phone number format.

6. **Onboarding and Permissions**  
   - First launch: Request Microphone, Location (always), SMS via `permission_handler`.  
   - Educational dialogs explaining each (e.g., "Microphone for distress detection").  
   - Denial: Guide to settings (`url_launcher`).

7. **Home/Dashboard Screen**  
   - Toggle: "Enable Protection" (start/stop service).  
   - Status: "Listening", "Idle", "Alert Triggered".  
   - Manual SOS button: Bypass model for instant alert.  
   - Recent alerts: ListView with timestamps/locations.

8. **Settings Screen**  
   - Sensitivity slider (0.3–0.8).  
   - Toggles: SMS, sound alerts.  
   - User name input (for SMS personalization).

## Tech Stack
| Layer              | Package/Tool                  |
|--------------------|-------------------------------|
| TFLite Inference   | `tflite_flutter`              |
| Audio Capture      | `flutter_sound` or `record`   |
| Background Service | `flutter_background_service`  |
| Mel Spectrogram    | `fftea` or native channel     |
| GPS Location       | `geolocator`                  |
| SMS Sending        | `telephony` (Android) / `flutter_sms` |
| Local Storage      | `hive`                        |
| State Management   | `riverpod` or `bloc`          |
| Permissions        | `permission_handler`          |
| Other              | `url_launcher`                |

## Platform-Specific Configurations
### Android (`AndroidManifest.xml`)
```xml
<uses-permission android:name="android.permission.RECORD_AUDIO"/>
<uses-permission android:name="android.permission.SEND_SMS"/>
<uses-permission android:name="android.permission.ACCESS_FINE_LOCATION"/>
<uses-permission android:name="android.permission.FOREGROUND_SERVICE"/>
```

### iOS (`Info.plist`)
```xml
<key>NSMicrophoneUsageDescription</key>
<string>Used to detect distress sounds for your safety</string>
<key>NSLocationAlwaysUsageDescription</key>
<string>Used to share your location in an emergency</string>
```
- Enable Background Audio mode in Xcode capabilities.  
- SMS: Limited; use fallback or backend API (e.g., Twilio).

## Milestones and Tasks (Build Order)
### Milestone 1: Project Setup (1-2 days)
- Create project: `flutter create womens_safety_app`.  
- Add dependencies to `pubspec.yaml` (as in Tech Stack); run `flutter pub get`.  
- Assets: Add `cnn_model.tflite` to `assets/models/`.  
- Platform configs: Update AndroidManifest and Info.plist.  
- **Testing**: Run `flutter doctor`; verify no errors.  
- **Challenges**: Resolve dependency conflicts via pub.dev.

### Milestone 2: Permissions Onboarding (1 day)
- Request permissions sequentially on launch.  
- Build UI: Scaffold with explanatory ListView/Dialogs.  
- Store status in local storage.  
- **Testing**: Simulate denials; ensure graceful handling.  
- **Challenges**: iOS "always" location restrictions.

### Milestone 3: Emergency Contacts (1-2 days)
- Build screen: StatefulWidget with ListView/TextFields.  
- Initialize Hive Box; enforce 1-5 limit.  
- Integrate state management for updates.  
- **Testing**: CRUD operations; persistence check.  
- **Challenges**: International phone validation.

### Milestone 4: TFLite Integration (1-2 days)
- Load model: `Interpreter.fromAsset()`.  
- Test with hardcoded spectrogram array.  
- Add threshold config.  
- **Testing**: Console logs; shape error handling.  
- **Challenges**: Tensor compatibility.

### Milestone 5: Audio Capture & Preprocessing (2-3 days)
- Capture chunks: 22050 Hz PCM.  
- Extract mel spectrogram; normalize/reshape.  
- Connect to TFLite.  
- **Testing**: Log shapes; sample audio tests.  
- **Challenges**: Real-time processing without lag.

### Milestone 6: Background Service (2-3 days)
- Setup service; start/stop via UI toggle.  
- Android: Notification; iOS: Background mode.  
- Run audio pipeline in isolate.  
- **Testing**: Background persistence; app kill simulation.  
- **Challenges**: Battery optimization.

### Milestone 7: Alert System (1-2 days)
- Trigger on detection: GPS fetch, SMS send.  
- Implement cooldown and logging.  
- Foreground extras.  
- **Testing**: Manual triggers; real SMS verification.  
- **Challenges**: iOS SMS fallback.

### Milestone 8: UI Construction (1 day)
- Dashboard: Toggle, status, SOS, alerts list.  
- Settings: Slider, toggles, name input.  
- Use state management.  
- **Testing**: Responsiveness; theme consistency (Material/Cupertino).  
- **Challenges**: Cross-platform UI.

### Milestone 9: End-to-End Testing (2-3 days)
- Full flow on Android device.  
- Edge cases: Low battery, no GPS, revokes.  
- Performance monitoring.  
- **Testing**: Debug logs; distress simulations.  
- **Challenges**: Tune for false positives.

### Milestone 10: iOS Adaptation (2-3 days)
- Adjust for background/SMS limits.  
- Test on simulator/device.  
- **Testing**: Consistency across platforms.  
- **Challenges**: App Store guidelines.

## Risk Management
- **Technical**: Latency → Use isolates; battery drain → Optimize chunks.  
- **Legal/Privacy**: No cloud; clear privacy policy.  
- **Dependencies**: Monitor updates.  
- **Scalability**: Android MVP; iOS extension.

## Best Practices
- **Testing**: Physical devices; unit tests for key pipelines.  
- **Error Handling**: Fallbacks (e.g., last known GPS).  
- **Optimization**: Isolates for heavy tasks; monitor resources.  
- **Verification**: Always validate spectrogram shape.  
- **Security**: Local-only data; user-friendly notifications.

## Next Steps
- Start with Milestone 1.  
- Track in Trello/Notion.  
- Post-completion: Add icons, descriptions for app store submission.  
- Reference this plan iteratively during development for consistency.

