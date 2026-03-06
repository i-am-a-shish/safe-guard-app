import 'package:hive/hive.dart';

part 'emergency_contact.g.dart';

@HiveType(typeId: 0)
class EmergencyContact extends HiveObject {
  @HiveField(0)
  String id;

  @HiveField(1)
  String name;

  @HiveField(2)
  String phoneNumber;

  @HiveField(3)
  DateTime createdAt;

  EmergencyContact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  EmergencyContact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
  }) {
    return EmergencyContact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      createdAt: createdAt,
    );
  }

  @override
  String toString() => 'EmergencyContact(id: $id, name: $name, phone: $phoneNumber)';
}
