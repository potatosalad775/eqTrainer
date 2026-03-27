// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BackendDataAdapter extends TypeAdapter<BackendData> {
  @override
  final typeId = 1;

  @override
  BackendData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BackendData(
      fields[0] == null ? [] : (fields[0] as List).cast<String>(),
    );
  }

  @override
  void write(BinaryWriter writer, BackendData obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.backendList);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BackendDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class MiscSettingsAdapter extends TypeAdapter<MiscSettings> {
  @override
  final typeId = 2;

  @override
  MiscSettings read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MiscSettings(
      fields[0] == null ? false : fields[0] as bool,
      fields[1] == null ? 0 : (fields[1] as num).toInt(),
    );
  }

  @override
  void write(BinaryWriter writer, MiscSettings obj) {
    writer
      ..writeByte(2)
      ..writeByte(0)
      ..write(obj.frequencyToolTip)
      ..writeByte(1)
      ..write(obj.importFormat);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MiscSettingsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
