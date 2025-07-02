import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';
import 'package:solvix/src/core/models/client_message_status.dart';

part 'message_model.g.dart';

@HiveType(typeId: 0)
class MessageModel extends Equatable {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String content;

  @HiveField(2)
  final DateTime sentAt;

  @HiveField(3)
  final int senderId;

  @HiveField(4)
  final String senderName;

  @HiveField(5)
  final String chatId;

  @HiveField(6)
  final bool isRead;

  @HiveField(7)
  final DateTime? readAt;

  @HiveField(8)
  final bool isEdited;

  @HiveField(9)
  final DateTime? editedAt;

  @HiveField(10)
  final bool isDeleted;

  @HiveField(11)
  final String? correlationId;

  @HiveField(12)
  final ClientMessageStatus? clientStatus;

  const MessageModel({
    required this.id,
    required this.content,
    required this.sentAt,
    required this.senderId,
    required this.senderName,
    required this.chatId,
    required this.isRead,
    this.readAt,
    required this.isEdited,
    this.editedAt,
    required this.isDeleted,
    this.correlationId,
    this.clientStatus,
  });

  factory MessageModel.fromJson(
    Map<String, dynamic> json, {
    String? correlationId,
    ClientMessageStatus? clientStatus,
  }) {
    return MessageModel(
      id: json['id'] as int,
      content: json['content'] as String,
      sentAt: DateTime.parse(json['sentAt'] as String).toLocal(),
      senderId: json['senderId'] as int,
      senderName: json['senderName'] as String,
      chatId: json['chatId'] as String,
      isRead: json['isRead'] as bool,
      readAt: json['readAt'] != null
          ? DateTime.parse(json['readAt'] as String).toLocal()
          : null,
      isEdited: json['isEdited'] as bool? ?? false,
      editedAt: json['editedAt'] != null
          ? DateTime.parse(json['editedAt'] as String).toLocal()
          : null,
      isDeleted: json['isDeleted'] as bool? ?? false,
      correlationId: correlationId,
      clientStatus: clientStatus,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'content': content,
      'sentAt': sentAt.toIso8601String(),
      'senderId': senderId,
      'senderName': senderName,
      'chatId': chatId,
      'isRead': isRead,
      'readAt': readAt?.toIso8601String(),
      'isEdited': isEdited,
      'editedAt': editedAt?.toIso8601String(),
      'isDeleted': isDeleted,
    };
  }

  MessageModel copyWith({
    int? id,
    String? content,
    DateTime? sentAt,
    int? senderId,
    String? senderName,
    String? chatId,
    bool? isRead,
    DateTime? readAt,
    bool? isEdited,
    DateTime? editedAt,
    bool? isDeleted,
    String? correlationId,
    ClientMessageStatus? clientStatus,
  }) {
    return MessageModel(
      id: id ?? this.id,
      content: content ?? this.content,
      sentAt: sentAt ?? this.sentAt,
      senderId: senderId ?? this.senderId,
      senderName: senderName ?? this.senderName,
      chatId: chatId ?? this.chatId,
      isRead: isRead ?? this.isRead,
      readAt: readAt ?? this.readAt,
      isEdited: isEdited ?? this.isEdited,
      editedAt: editedAt ?? this.editedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      correlationId: correlationId ?? this.correlationId,
      clientStatus: clientStatus ?? this.clientStatus,
    );
  }

  @override
  List<Object?> get props => [
    id,
    content,
    sentAt,
    senderId,
    senderName,
    chatId,
    isRead,
    readAt,
    isEdited,
    editedAt,
    isDeleted,
    correlationId,
    clientStatus,
  ];
}
