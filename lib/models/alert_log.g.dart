// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'alert_log.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AlertLogAdapter extends TypeAdapter<AlertLog> {
  @override
  final int typeId = 1;

  @override
  AlertLog read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AlertLog(
      id: fields[0] as String,
      timestamp: fields[1] as DateTime,
      latitude: fields[2] as double,
      longitude: fields[3] as double,
      confidence: fields[4] as double,
      type: fields[5] as String,
      smsSent: fields[6] as bool,
      contactsNotified: (fields[7] as List).cast<String>(),
      recordingPath: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, AlertLog obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.timestamp)
      ..writeByte(2)
      ..write(obj.latitude)
      ..writeByte(3)
      ..write(obj.longitude)
      ..writeByte(4)
      ..write(obj.confidence)
      ..writeByte(5)
      ..write(obj.type)
      ..writeByte(6)
      ..write(obj.smsSent)
      ..writeByte(7)
      ..write(obj.contactsNotified)
      ..writeByte(8)
      ..write(obj.recordingPath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AlertLogAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
