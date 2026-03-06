import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import '../core/constants.dart';
import '../models/alert_log.dart';
import '../services/storage_service.dart';
import '../services/background_service.dart';
import '../services/alert_service.dart';

enum ProtectionStatus {
  idle,
  listening,
  alertTriggered,
  cooldown,
}

class ProtectionProvider extends ChangeNotifier {
  bool _isProtectionEnabled = false;
  ProtectionStatus _status = ProtectionStatus.idle;
  double _lastProbability = 0.0;
  List<AlertLog> _alertLogs = [];
  StreamSubscription? _serviceSubscription;

  bool get isProtectionEnabled => _isProtectionEnabled;
  ProtectionStatus get status => _status;
  double get lastProbability => _lastProbability;
  List<AlertLog> get alertLogs => _alertLogs;

  String get statusText {
    switch (_status) {
      case ProtectionStatus.idle:
        return 'Idle';
      case ProtectionStatus.listening:
        return 'Listening';
      case ProtectionStatus.alertTriggered:
        return 'Alert Triggered!';
      case ProtectionStatus.cooldown:
        return 'Cooldown';
    }
  }

  ProtectionProvider() {
    _loadState();
    _listenToBackgroundService();
  }

  void _loadState() {
    _isProtectionEnabled = StorageService.isProtectionEnabled();
    _alertLogs = StorageService.getAlertLogs();
    if (_isProtectionEnabled) {
      _status = ProtectionStatus.listening;
      // Service may have already been started in main.dart; calling startService
      // again is idempotent – flutter_background_service handles duplicate calls.
      BackgroundServiceManager.startService().catchError((e) {
        debugPrint('ProtectionProvider: Failed to start service: $e');
      });
    }
    notifyListeners();
  }

  void _listenToBackgroundService() {
    final service = FlutterBackgroundService();

    // Listen for detection updates
    service.on('detectionUpdate').listen((event) {
      if (event != null) {
        _lastProbability = (event['probability'] as num?)?.toDouble() ?? 0.0;
        final isDistress = event['isDistress'] as bool? ?? false;

        if (isDistress) {
          _status = ProtectionStatus.alertTriggered;
          // Revert after cooldown
          Future.delayed(const Duration(seconds: 5), () {
            if (_isProtectionEnabled) {
              _status = ProtectionStatus.listening;
              notifyListeners();
            }
          });
        }
        notifyListeners();
      }
    });

    // Listen for alert events
    service.on('alertTriggered').listen((event) {
      _refreshAlertLogs();
    });

    // Set alert service callback
    AlertService.onAlertTriggered = (alertLog) {
      _alertLogs.insert(0, alertLog);
      notifyListeners();
    };
  }

  /// Toggle protection on/off
  Future<void> toggleProtection() async {
    _isProtectionEnabled = !_isProtectionEnabled;
    await StorageService.setSetting(AppConstants.keyProtectionEnabled, _isProtectionEnabled);

    if (_isProtectionEnabled) {
      await BackgroundServiceManager.startService();
      _status = ProtectionStatus.listening;
    } else {
      await BackgroundServiceManager.stopService();
      _status = ProtectionStatus.idle;
      _lastProbability = 0.0;
    }

    notifyListeners();
  }

  /// Trigger manual SOS
  Future<void> triggerManualSOS() async {
    _status = ProtectionStatus.alertTriggered;
    notifyListeners();

    final alertLog = await AlertService.triggerManualSOS();

    if (alertLog != null) {
      _alertLogs.insert(0, alertLog);
    }

    // Revert status after 5 seconds
    Future.delayed(const Duration(seconds: 5), () {
      if (_isProtectionEnabled) {
        _status = ProtectionStatus.listening;
      } else {
        _status = ProtectionStatus.idle;
      }
      notifyListeners();
    });

    notifyListeners();
  }

  void _refreshAlertLogs() {
    _alertLogs = StorageService.getAlertLogs();
    notifyListeners();
  }

  Future<void> clearAlertLogs() async {
    await StorageService.clearAlertLogs();
    _alertLogs.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _serviceSubscription?.cancel();
    super.dispose();
  }
}
