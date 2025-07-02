part of 'chat_list_bloc.dart';

abstract class ChatListEvent extends Equatable {
  const ChatListEvent();

  @override
  List<Object> get props => [];
}

class FetchChatList extends ChatListEvent {}

class ResetChatListState extends ChatListEvent {}

class UpdateChatReceived extends ChatListEvent {
  final ChatModel updatedChat;

  const UpdateChatReceived(this.updatedChat);

  @override
  List<Object> get props => [updatedChat];
}

// TODO: Event های دیگر مثل RefreshChatList یا NewChatReceivedFromSignalR بعداً اضافه می‌شوند
