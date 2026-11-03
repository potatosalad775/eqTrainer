// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'legacy_audio_clip.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LegacyAudioClipAdapter extends TypeAdapter<LegacyAudioClip> {
  @override
  final typeId = 0;

  @override
  LegacyAudioClip read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LegacyAudioClip(
      fields[0] as String,
      fields[1] as String,
      (fields[2] as num).toDouble(),
      fields[3] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, LegacyAudioClip obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.fileName)
      ..writeByte(1)
      ..write(obj.ogAudioName)
      ..writeByte(2)
      ..write(obj.duration)
      ..writeByte(3)
      ..write(obj.isEnabled);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LegacyAudioClipAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
