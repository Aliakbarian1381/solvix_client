// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserModelAdapter extends TypeAdapter<UserModel> {
  @override
  final int typeId = 2;

  @override
  UserModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserModel(
      id: fields[0] as int,
      username: fields[1] as String,
      firstName: fields[2] as String?,
      lastName: fields[3] as String?,
      phoneNumber: fields[4] as String?,
      token: fields[5] as String?,
      isOnline: fields[6] as bool,
      lastActive: fields[7] as DateTime?,
      isContact: fields[8] as bool?,
      hasChat: fields[9] as bool,
      lastMessage: fields[10] as String?,
      lastMessageTime: fields[11] as DateTime?,
      unreadCount: fields[12] as int,
      isFavorite: fields[13] as bool,
      isBlocked: fields[14] as bool,
      displayName: fields[15] as String?,
      contactCreatedAt: fields[16] as DateTime?,
      lastInteractionAt: fields[17] as DateTime?,
      profilePictureUrl: fields[18] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, UserModel obj) {
    writer
      ..writeByte(19)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.username)
      ..writeByte(2)
      ..write(obj.firstName)
      ..writeByte(3)
      ..write(obj.lastName)
      ..writeByte(4)
      ..write(obj.phoneNumber)
      ..writeByte(5)
      ..write(obj.token)
      ..writeByte(6)
      ..write(obj.isOnline)
      ..writeByte(7)
      ..write(obj.lastActive)
      ..writeByte(8)
      ..write(obj.isContact)
      ..writeByte(9)
      ..write(obj.hasChat)
      ..writeByte(10)
      ..write(obj.lastMessage)
      ..writeByte(11)
      ..write(obj.lastMessageTime)
      ..writeByte(12)
      ..write(obj.unreadCount)
      ..writeByte(13)
      ..write(obj.isFavorite)
      ..writeByte(14)
      ..write(obj.isBlocked)
      ..writeByte(15)
      ..write(obj.displayName)
      ..writeByte(16)
      ..write(obj.contactCreatedAt)
      ..writeByte(17)
      ..write(obj.lastInteractionAt)
      ..writeByte(18)
      ..write(obj.profilePictureUrl);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
