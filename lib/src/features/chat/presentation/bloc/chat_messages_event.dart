part of "chat_messages_bloc.dart";

abstract class ChatMessagesEvent extends Equatable {
  const ChatMessagesEvent();

  @override
  List<Object?> get props => [];
}

class FetchChatMessages extends ChatMessagesEvent {
  final String chatId;

  const FetchChatMessages(this.chatId);

  @override
  List<Object> get props => [chatId];
}

// Event برای ارسال پیام جدید
class SendNewMessage extends ChatMessagesEvent {
  final String content;
  final String correlationId; // برای پیگیری پیام ارسالی

  const SendNewMessage({required this.content, required this.correlationId});

  @override
  List<Object> get props => [content, correlationId];
}

// Event برای زمانی که تاییدیه ارسال پیام از سرور می‌آید
class MessageSuccessfullySent extends ChatMessagesEvent {
  final String correlationId;
  final MessageModel confirmedMessage; // پیام تایید شده با ID واقعی از سرور

  const MessageSuccessfullySent({
    required this.correlationId,
    required this.confirmedMessage,
  });

  @override
  List<Object> get props => [correlationId, confirmedMessage];
}

// Event برای زمانی که پیام جدیدی از SignalR دریافت می‌شود (از دیگران)
class NewMessageReceivedFromSignalR extends ChatMessagesEvent {
  final MessageModel message;

  const NewMessageReceivedFromSignalR(this.message);

  @override
  List<Object> get props => [message];
}

class MarkMessagesAsRead extends ChatMessagesEvent {
  const MarkMessagesAsRead();

  @override
  List<Object> get props => [];
}

class MessageStatusUpdated extends ChatMessagesEvent {
  final int messageId;
  final bool isRead;

  const MessageStatusUpdated({required this.messageId, required this.isRead});

  @override
  List<Object> get props => [messageId, isRead];
}

class EditMessageRequested extends ChatMessagesEvent {
  final int messageId;
  final String newContent;

  const EditMessageRequested({
    required this.messageId,
    required this.newContent,
  });
}

class DeleteMessageRequested extends ChatMessagesEvent {
  final int messageId;

  const DeleteMessageRequested({required this.messageId});
}

class MessageUpdatedReceived extends ChatMessagesEvent {
  final MessageModel updatedMessage;

  const MessageUpdatedReceived(this.updatedMessage);
}
