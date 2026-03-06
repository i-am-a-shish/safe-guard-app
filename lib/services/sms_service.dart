import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants.dart';
import '../services/storage_service.dart';
import '../models/emergency_contact.dart';

/// SMS service for sending emergency alerts to contacts.
/// Uses native Android SmsManager via MethodChannel (SmsPlugin.kt) which
/// is registered in GeneratedPluginRegistrant and therefore works from
/// BOTH the main Flutter engine and the background service engine.
class SmsService {
  static const MethodChannel _channel =
      MethodChannel('com.safeguardher.womens_safety_app/sms');

  /// Sanitize phone number – keep only digits and leading +
  static String _sanitizeNumber(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[^\d+]'), '');
    return cleaned;
  }

  /// Send SMS distress message to every emergency contact with GPS location
  static Future<bool> sendDistressMessages({
    required double latitude,
    required double longitude,
    String? userName,
  }) async {
    final contacts = StorageService.getContacts();
    if (contacts.isEmpty) {
      debugPrint('SmsService: No emergency contacts configured.');
      return false;
    }

    final name = userName ?? StorageService.getUserName();
    final message = AppConstants.smsTemplate
        .replaceAll('{name}', name)
        .replaceAll('{lat}', latitude.toStringAsFixed(6))
        .replaceAll('{lng}', longitude.toStringAsFixed(6));

    debugPrint('SmsService: Sending to ${contacts.length} contact(s)...');
    debugPrint('SmsService: Message = $message');

    bool anySent = false;

    for (final contact in contacts) {
      try {
        final sent = await _sendSms(contact, message);
        if (sent) {
          anySent = true;
          debugPrint('SmsService: SMS sent to ${contact.name} (${contact.phoneNumber})');
        } else {
          debugPrint('SmsService: SMS failed for ${contact.name}');
        }
      } catch (e) {
        debugPrint('SmsService: Exception for ${contact.name}: $e');
      }
    }

    return anySent;
  }

  /// Send SMS to a single contact
  static Future<bool> _sendSms(EmergencyContact contact, String message) async {
    final cleanNumber = _sanitizeNumber(contact.phoneNumber);
    if (cleanNumber.isEmpty) {
      debugPrint('SmsService: Empty phone number after sanitization for ${contact.name}');
      return false;
    }

    if (Platform.isAndroid) {
      return await _sendViaNativeChannel(cleanNumber, contact.name, message);
    } else if (Platform.isIOS) {
      return await _sendViaUrlLauncher(cleanNumber, message);
    }
    return false;
  }

  /// Primary: use native SmsPlugin (works from foreground + background service)
  static Future<bool> _sendViaNativeChannel(
      String phoneNumber, String contactName, String message) async {
    try {
      final result = await _channel.invokeMethod<bool>('sendSms', {
        'phoneNumber': phoneNumber,
        'message': message,
      });
      debugPrint('SmsService: Native channel result for $contactName = $result');
      return result == true;
    } on PlatformException catch (e) {
      debugPrint(
          'SmsService: Native channel PlatformException for $contactName: ${e.code} - ${e.message}');
      // Fallback to url_launcher
      return await _sendViaUrlLauncher(phoneNumber, message);
    } catch (e) {
      debugPrint('SmsService: Native channel error for $contactName: $e');
      return await _sendViaUrlLauncher(phoneNumber, message);
    }
  }

  /// Fallback: open the SMS app with pre-filled message (iOS + Android fallback)
  static Future<bool> _sendViaUrlLauncher(String phone, String message) async {
    try {
      final uri = Uri(
        scheme: 'sms',
        path: phone,
        queryParameters: {'body': message},
      );
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        return true;
      }
      debugPrint('SmsService: Cannot launch sms URI on this device.');
      return false;
    } catch (e) {
      debugPrint('SmsService: url_launcher fallback error: $e');
      return false;
    }
  }
}
