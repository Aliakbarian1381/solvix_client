// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'message_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class MessageModelAdapter extends TypeAdapter<MessageModel> {
  @override
  final int typeId = 0;

  @override
  MessageModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return MessageModel(
      id: fields[0] as int,
      content: fields[1] as String,
      sentAt: fields[2] as DateTime,
      senderId: fields[3] as int,
      senderName: fields[4] as String,
      chatId: fields[5] as String,
      isRead: fields[6] as bool,
      readAt: fields[7] as DateTime?,
      isEdited: fields[8] as bool,
      editedAt: fields[9] as DateTime?,
      isDeleted: fields[10] as bool,
      correlationId: fields[11] as String?,
      clientStatus: fields[12] as ClientMessageStatus?,
    );
  }

  @override
  void write(BinaryWriter writer, MessageModel obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.content)
      ..writeByte(2)
      ..write(obj.sentAt)
      ..writeByte(3)
      ..write(obj.senderId)
      ..writeByte(4)
      ..write(obj.senderName)
      ..writeByte(5)
      ..write(obj.chatId)
      ..writeByte(6)
      ..write(obj.isRead)
      ..writeByte(7)
      ..write(obj.readAt)
      ..writeByte(8)
      ..write(obj.isEdited)
      ..writeByte(9)
      ..write(obj.editedAt)
      ..writeByte(10)
      ..write(obj.isDeleted)
      ..writeByte(11)
      ..write(obj.correlationId)
      ..writeByte(12)
      ..write(obj.clientStatus);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is MessageModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
