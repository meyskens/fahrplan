// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'checklist.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FahrplanChecklistAdapter extends TypeAdapter<FahrplanChecklist> {
  @override
  final int typeId = 3;

  @override
  FahrplanChecklist read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FahrplanChecklist(
      name: fields[1] as String,
      duration: fields[2] as int,
      showUntil: fields[4] as DateTime?,
      uuid: fields[0] as String?,
    )..items = (fields[5] as List).cast<FahrplanCheckListItem>();
  }

  @override
  void write(BinaryWriter writer, FahrplanChecklist obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.uuid)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.duration)
      ..writeByte(4)
      ..write(obj.showUntil)
      ..writeByte(5)
      ..write(obj.items);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FahrplanChecklistAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FahrplanCheckListItemAdapter extends TypeAdapter<FahrplanCheckListItem> {
  @override
  final int typeId = 4;

  @override
  FahrplanCheckListItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FahrplanCheckListItem(
      title: fields[0] as String,
    );
  }

  @override
  void write(BinaryWriter writer, FahrplanCheckListItem obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.title);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FahrplanCheckListItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
