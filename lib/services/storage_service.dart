import 'package:hive_flutter/hive_flutter.dart';
import '../models/emergency_contact.dart';
import '../models/alert_log.dart';
import '../core/constants.dart';

class StorageService {
  static late Box<EmergencyContact> _contactsBox;
  static late Box<AlertLog> _alertsBox;
  static late Box _settingsBox;
  static bool _initialized = false;

  static Future<void> init() async {
    if (_initialized) return;

    await Hive.initFlutter();

    // Register adapters (only if not already registered)
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(EmergencyContactAdapter());
    }
    if (!Hive.isAdapterRegistered(1)) {
      Hive.registerAdapter(AlertLogAdapter());
    }

    // Open boxes
    _contactsBox = await Hive.openBox<EmergencyContact>(AppConstants.contactsBoxName);
    _alertsBox = await Hive.openBox<AlertLog>(AppConstants.alertsBoxName);
    _settingsBox = await Hive.openBox(AppConstants.settingsBoxName);

    _initialized = true;
  }

  // ---- Emergency Contacts ----
  static Box<EmergencyContact> get contactsBox => _contactsBox;

  static List<EmergencyContact> getContacts() {
    return _contactsBox.values.toList();
  }

  static Future<void> addContact(EmergencyContact contact) async {
    await _contactsBox.put(contact.id, contact);
  }

  static Future<void> updateContact(EmergencyContact contact) async {
    await _contactsBox.put(contact.id, contact);
  }

  static Future<void> deleteContact(String id) async {
    await _contactsBox.delete(id);
  }

  static int get contactCount => _contactsBox.length;

  // ---- Alert Logs ----
  static Box<AlertLog> get alertsBox => _alertsBox;

  static List<AlertLog> getAlertLogs() {
    final logs = _alertsBox.values.toList();
    logs.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return logs;
  }

  static Future<void> addAlertLog(AlertLog log) async {
    await _alertsBox.put(log.id, log);
  }

  static Future<void> clearAlertLogs() async {
    await _alertsBox.clear();
  }

  // ---- Settings ----
  static T? getSetting<T>(String key, {T? defaultValue}) {
    return _settingsBox.get(key, defaultValue: defaultValue) as T?;
  }

  static Future<void> setSetting<T>(String key, T value) async {
    await _settingsBox.put(key, value);
  }

  static String getUserName() {
    return _settingsBox.get(AppConstants.keyUserName, defaultValue: 'User') as String;
  }

  static double getThreshold() {
    return _settingsBox.get(AppConstants.keyThreshold,
        defaultValue: AppConstants.defaultThreshold) as double;
  }

  static bool isSmsEnabled() {
    return _settingsBox.get(AppConstants.keySmsEnabled, defaultValue: true) as bool;
  }

  static bool isSoundAlertEnabled() {
    return _settingsBox.get(AppConstants.keySoundAlertEnabled, defaultValue: true) as bool;
  }

  static bool isOnboardingComplete() {
    return _settingsBox.get(AppConstants.keyOnboardingComplete, defaultValue: false) as bool;
  }

  static bool isProtectionEnabled() {
    return _settingsBox.get(AppConstants.keyProtectionEnabled, defaultValue: false) as bool;
  }

  static bool isVideoRecordingEnabled() {
    return _settingsBox.get(AppConstants.keyVideoRecordingEnabled, defaultValue: true) as bool;
  }
}
