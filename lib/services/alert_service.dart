import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:uuid/uuid.dart';
import '../core/constants.dart';
import '../models/alert_log.dart';
import '../services/location_service.dart';
import '../services/sms_service.dart';
import '../services/storage_service.dart';
import '../services/camera_recording_service.dart';

/// Alert service that handles the full distress alert workflow:
/// Detection → GPS Location → SMS → Camera Recording → Cooldown → Log
class AlertService {
  static bool _isInCooldown = false;
  static Timer? _cooldownTimer;
  static final _uuid = const Uuid();

  // Callbacks for UI notification
  static Function(AlertLog)? onAlertTriggered;
  static Function(String)? onStatusChanged;

  /// Trigger a distress alert (called by detection pipeline or manual SOS)
  static Future<AlertLog?> triggerAlert({
    required String type, // 'auto' or 'manual'
    double confidence = 1.0,
  }) async {
    // Check cooldown
    if (_isInCooldown && type == 'auto') {
      debugPrint('AlertService: In cooldown period, skipping auto alert.');
      return null;
    }

    debugPrint('AlertService: ⚠️ ALERT TRIGGERED (type: $type, confidence: ${confidence.toStringAsFixed(3)})');
    onStatusChanged?.call('Alert Triggered!');

    // Start cooldown
    _startCooldown();

    // 1. Fetch GPS location
    final position = await LocationService.getCurrentLocation();
    final double lat = position?.latitude ?? 0.0;
    final double lng = position?.longitude ?? 0.0;

    debugPrint('AlertService: Location: $lat, $lng');

    // 2. Send SMS to emergency contacts
    bool smsSent = false;
    List<String> notifiedContacts = [];

    if (StorageService.isSmsEnabled()) {
      final contacts = StorageService.getContacts();
      if (contacts.isNotEmpty) {
        smsSent = await SmsService.sendDistressMessages(
          latitude: lat,
          longitude: lng,
          userName: StorageService.getUserName(),
        );

        if (smsSent) {
          notifiedContacts = contacts.map((c) => c.name).toList();
        }
        debugPrint('AlertService: SMS sent=$smsSent to contacts: $notifiedContacts');
      } else {
        debugPrint('AlertService: No emergency contacts configured – SMS skipped.');
      }
    } else {
      debugPrint('AlertService: SMS disabled in settings – skipping.');
    }

    // 3. Start camera recording (non-blocking — runs in parallel)
    String? recordingPath;
    try {
      recordingPath = await CameraRecordingService.startRecording();
      if (recordingPath != null) {
        debugPrint('AlertService: 📹 Camera recording started → $recordingPath');
      }
    } catch (e) {
      debugPrint('AlertService: Camera recording failed: $e');
    }

    // 4. Create and store alert log
    final alertLog = AlertLog(
      id: _uuid.v4(),
      timestamp: DateTime.now(),
      latitude: lat,
      longitude: lng,
      confidence: confidence,
      type: type,
      smsSent: smsSent,
      contactsNotified: notifiedContacts,
      recordingPath: recordingPath,
    );

    await StorageService.addAlertLog(alertLog);

    // 5. Notify UI
    onAlertTriggered?.call(alertLog);
    debugPrint('AlertService: Alert logged and saved.');

    return alertLog;
  }

  /// Start cooldown timer
  static void _startCooldown() {
    _isInCooldown = true;
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer(
      const Duration(seconds: AppConstants.alertCooldownSeconds),
      () {
        _isInCooldown = false;
        debugPrint('AlertService: Cooldown period ended.');
        onStatusChanged?.call('Listening');
      },
    );
  }

  /// Manual SOS - bypass cooldown
  static Future<AlertLog?> triggerManualSOS() async {
    _isInCooldown = false; // Override cooldown for manual SOS
    return triggerAlert(type: 'manual', confidence: 1.0);
  }

  /// Reset cooldown
  static void resetCooldown() {
    _isInCooldown = false;
    _cooldownTimer?.cancel();
  }

  static bool get isInCooldown => _isInCooldown;
}
