// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'waypoint.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FahrplanWaypointAdapter extends TypeAdapter<FahrplanWaypoint> {
  @override
  final int typeId = 6;

  @override
  FahrplanWaypoint read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FahrplanWaypoint(
      description: fields[0] as String,
      startTime: fields[1] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, FahrplanWaypoint obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.description)
      ..writeByte(1)
      ..write(obj.startTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FahrplanWaypointAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
