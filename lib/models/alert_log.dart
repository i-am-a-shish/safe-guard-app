import 'package:hive/hive.dart';

part 'alert_log.g.dart';

@HiveType(typeId: 1)
class AlertLog extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  DateTime timestamp;

  @HiveField(2)
  double latitude;

  @HiveField(3)
  double longitude;

  @HiveField(4)
  double confidence;

  @HiveField(5)
  String type; // 'auto' or 'manual'

  @HiveField(6)
  bool smsSent;

  @HiveField(7)
  List<String> contactsNotified;

  @HiveField(8)
  String? recordingPath; // Path to video/audio recording file

  AlertLog({
    required this.id,
    required this.timestamp,
    required this.latitude,
    required this.longitude,
    required this.confidence,
    required this.type,
    this.smsSent = false,
    this.contactsNotified = const [],
    this.recordingPath,
  });

  bool get hasRecording => recordingPath != null && recordingPath!.isNotEmpty;

  String get locationUrl =>
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude';

  String get formattedTime {
    final hour = timestamp.hour.toString().padLeft(2, '0');
    final minute = timestamp.minute.toString().padLeft(2, '0');
    return '$hour:$minute';
  }

  String get formattedDate {
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    return '${months[timestamp.month - 1]} ${timestamp.day}, ${timestamp.year}';
  }

  @override
  String toString() =>
      'AlertLog(id: $id, type: $type, confidence: $confidence, time: $formattedTime, recording: $hasRecording)';
}
