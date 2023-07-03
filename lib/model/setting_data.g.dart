// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'setting_data.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class SettingDataAdapter extends TypeAdapter<SettingData> {
  @override
  final int typeId = 1;

  @override
  SettingData read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SettingData(
      fields[0] as AndroidAudioBackend,
    );
  }

  @override
  void write(BinaryWriter writer, SettingData obj) {
    writer
      ..writeByte(1)
      ..writeByte(0)
      ..write(obj.androidAudioBackend);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SettingDataAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class AndroidAudioBackendAdapter extends TypeAdapter<AndroidAudioBackend> {
  @override
  final int typeId = 2;

  @override
  AndroidAudioBackend read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return AndroidAudioBackend.aaudio;
      case 1:
        return AndroidAudioBackend.opensl;
      default:
        return AndroidAudioBackend.aaudio;
    }
  }

  @override
  void write(BinaryWriter writer, AndroidAudioBackend obj) {
    switch (obj) {
      case AndroidAudioBackend.aaudio:
        writer.writeByte(0);
        break;
      case AndroidAudioBackend.opensl:
        writer.writeByte(1);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AndroidAudioBackendAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
