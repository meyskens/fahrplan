// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'calendar.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FahrplanCalendarAdapter extends TypeAdapter<FahrplanCalendar> {
  @override
  final int typeId = 2;

  @override
  FahrplanCalendar read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FahrplanCalendar(
      id: fields[0] as String,
      enabled: fields[1] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, FahrplanCalendar obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.enabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FahrplanCalendarAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
