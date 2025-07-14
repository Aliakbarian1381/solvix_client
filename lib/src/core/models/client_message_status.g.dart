// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'client_message_status.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class ClientMessageStatusAdapter extends TypeAdapter<ClientMessageStatus> {
  @override
  final int typeId = 3;

  @override
  ClientMessageStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return ClientMessageStatus.sending;
      case 1:
        return ClientMessageStatus.sent;
      case 2:
        return ClientMessageStatus.failed;
      default:
        return ClientMessageStatus.sending;
    }
  }

  @override
  void write(BinaryWriter writer, ClientMessageStatus obj) {
    switch (obj) {
      case ClientMessageStatus.sending:
        writer.writeByte(0);
        break;
      case ClientMessageStatus.sent:
        writer.writeByte(1);
        break;
      case ClientMessageStatus.failed:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClientMessageStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
