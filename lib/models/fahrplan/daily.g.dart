// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'daily.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FahrplanDailyItemAdapter extends TypeAdapter<FahrplanDailyItem> {
  @override
  final int typeId = 0;

  @override
  FahrplanDailyItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FahrplanDailyItem(
      title: fields[0] as String,
      hour: fields[1] as int?,
      minute: fields[2] as int?,
    );
  }

  @override
  void write(BinaryWriter writer, FahrplanDailyItem obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.hour)
      ..writeByte(2)
      ..write(obj.minute);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FahrplanDailyItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
