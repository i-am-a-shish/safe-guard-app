import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../services/storage_service.dart';

class SettingsProvider extends ChangeNotifier {
  String _userName = 'User';
  double _threshold = AppConstants.defaultThreshold;
  bool _smsEnabled = true;
  bool _soundAlertEnabled = true;
  bool _videoRecordingEnabled = true;

  String get userName => _userName;
  double get threshold => _threshold;
  bool get smsEnabled => _smsEnabled;
  bool get soundAlertEnabled => _soundAlertEnabled;
  bool get videoRecordingEnabled => _videoRecordingEnabled;

  SettingsProvider() {
    _loadSettings();
  }

  void _loadSettings() {
    _userName = StorageService.getUserName();
    _threshold = StorageService.getThreshold();
    _smsEnabled = StorageService.isSmsEnabled();
    _soundAlertEnabled = StorageService.isSoundAlertEnabled();
    _videoRecordingEnabled = StorageService.isVideoRecordingEnabled();
    notifyListeners();
  }

  Future<void> setUserName(String name) async {
    _userName = name.trim();
    await StorageService.setSetting(AppConstants.keyUserName, _userName);
    notifyListeners();
  }

  Future<void> setThreshold(double value) async {
    _threshold = value.clamp(AppConstants.minThreshold, AppConstants.maxThreshold);
    await StorageService.setSetting(AppConstants.keyThreshold, _threshold);
    notifyListeners();
  }

  Future<void> setSmsEnabled(bool enabled) async {
    _smsEnabled = enabled;
    await StorageService.setSetting(AppConstants.keySmsEnabled, _smsEnabled);
    notifyListeners();
  }

  Future<void> setSoundAlertEnabled(bool enabled) async {
    _soundAlertEnabled = enabled;
    await StorageService.setSetting(AppConstants.keySoundAlertEnabled, _soundAlertEnabled);
    notifyListeners();
  }

  Future<void> setVideoRecordingEnabled(bool enabled) async {
    _videoRecordingEnabled = enabled;
    await StorageService.setSetting(AppConstants.keyVideoRecordingEnabled, _videoRecordingEnabled);
    notifyListeners();
  }

  void refresh() {
    _loadSettings();
  }
}
