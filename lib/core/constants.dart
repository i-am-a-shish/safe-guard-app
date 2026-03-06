class AppConstants {
  // App Info
  static const String appName = 'SafeGuardHer';
  static const String appTagline = 'Your Silent Guardian';

  // Model
  static const String modelPath = 'assets/models/cnn_model.tflite';
  // Training used sr=16000 Hz — must match exactly or inference is garbage
  static const int sampleRate = 16000;
  static const int melBands = 128;
  static const int melFrames = 94;

  // Global z-score normalization stats from training (normalization_stats.npz)
  // mel = (mel - normMean) / normStd  — replaces min-max normalization
  static const double normMean = -49.602452774109494;
  static const double normStd = 20.54078017353221;

  // Threshold: model was trained with threshold 0.5 (binary)
  // Using 0.45 gives slight leniency while staying close to training
  static const double defaultThreshold = 0.45;
  static const double minThreshold = 0.10;
  static const double maxThreshold = 0.80;

  // Audio
  static const int audioChunkDurationMs = 2000; // 2 seconds
  static const int audioBufferSize = 32000; // 2 seconds at 16000 Hz

  // Alert
  static const int alertCooldownSeconds = 60;
  static const int maxEmergencyContacts = 5;
  static const int minEmergencyContacts = 1;
  static const int recordingDurationSeconds = 30; // Video recording length

  // SMS Template
  static const String smsTemplate =
      '⚠️ EMERGENCY ALERT: {name} needs help! Location: https://www.google.com/maps/search/?api=1&query={lat},{lng} — Auto-sent by SafeGuardHer';

  // Hive Boxes
  static const String contactsBoxName = 'emergency_contacts';
  static const String settingsBoxName = 'app_settings';
  static const String alertsBoxName = 'alert_logs';

  // Settings Keys
  static const String keyUserName = 'user_name';
  static const String keyThreshold = 'threshold';
  static const String keySmsEnabled = 'sms_enabled';
  static const String keySoundAlertEnabled = 'sound_alert_enabled';
  static const String keyOnboardingComplete = 'onboarding_complete';
  static const String keyProtectionEnabled = 'protection_enabled';
  static const String keyVideoRecordingEnabled = 'video_recording_enabled';

  // Notification
  static const String notificationChannelId = 'safeguard_her_service';
  static const String notificationChannelName = 'Safety Monitor';
  static const String notificationTitle = 'SafeGuardHer Active';
  static const String notificationBody = 'Safety monitoring is running in the background';
}
