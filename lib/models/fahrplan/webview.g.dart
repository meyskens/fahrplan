// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'webview.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class FahrplanWebViewAdapter extends TypeAdapter<FahrplanWebView> {
  @override
  final int typeId = 5;

  @override
  FahrplanWebView read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FahrplanWebView(
      name: fields[1] as String,
      url: fields[2] as String,
      refreshIntervalSeconds: fields[3] as int,
      isShown: fields[4] as bool,
      cachedContent: fields[5] as String?,
      lastFetched: fields[6] as DateTime?,
      customTitle: fields[7] as String?,
      uuid: fields[0] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, FahrplanWebView obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.uuid)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.url)
      ..writeByte(3)
      ..write(obj.refreshIntervalSeconds)
      ..writeByte(4)
      ..write(obj.isShown)
      ..writeByte(5)
      ..write(obj.cachedContent)
      ..writeByte(6)
      ..write(obj.lastFetched)
      ..writeByte(7)
      ..write(obj.customTitle);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FahrplanWebViewAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
