import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:solvix/src/core/models/user_model.dart';

part 'chat_model.g.dart';

@HiveType(typeId: 1)
class ChatModel extends Equatable {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final bool isGroup;

  @HiveField(2)
  final String? title;

  @HiveField(3)
  final DateTime createdAt;

  @HiveField(4)
  final String? lastMessage;

  @HiveField(5)
  final DateTime? lastMessageTime;

  @HiveField(6)
  final int unreadCount;

  @HiveField(7)
  final List<UserModel> participants;

  const ChatModel({
    required this.id,
    required this.isGroup,
    this.title,
    required this.createdAt,
    this.lastMessage,
    this.lastMessageTime,
    required this.unreadCount,
    required this.participants,
  });

  factory ChatModel.fromJson(Map<String, dynamic> json) {
    return ChatModel(
      id: json['id'] as String,
      isGroup: json['isGroup'] as bool,
      title: json['title'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'] as String).toLocal()
          : null,
      unreadCount: json['unreadCount'] as int,
      participants: (json['participants'] as List<dynamic>)
          .map(
            (participantJson) =>
                UserModel.fromJson(participantJson as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'isGroup': isGroup,
      'title': title,
      'createdAt': createdAt.toIso8601String(),
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'unreadCount': unreadCount,
      'participants': participants.map((p) => p.toJson()).toList(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    isGroup,
    title,
    createdAt,
    lastMessage,
    lastMessageTime,
    unreadCount,
    participants,
  ];
}
