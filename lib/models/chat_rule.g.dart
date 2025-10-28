// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_rule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ChatRuleAdapter extends TypeAdapter<ChatRule> {
  @override
  final int typeId = 0;

  @override
  ChatRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ChatRule(
      id: fields[0] as String,
      text: fields[1] as String,
      isPositive: fields[2] as bool,
      createdAt: fields[3] as DateTime,
      updatedAt: fields[4] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, ChatRule obj) {
    writer
      ..writeByte(5)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.text)
      ..writeByte(2)
      ..write(obj.isPositive)
      ..writeByte(3)
      ..write(obj.createdAt)
      ..writeByte(4)
      ..write(obj.updatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ChatRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
