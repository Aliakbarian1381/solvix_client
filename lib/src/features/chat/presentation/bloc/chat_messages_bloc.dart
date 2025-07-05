import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:solvix/src/core/api/chat/chat_service.dart';
import 'package:solvix/src/core/models/message_model.dart';
import 'package:solvix/src/core/network/signalr_service.dart';
import '../../../../core/models/client_message_status.dart';

part 'chat_messages_event.dart';

part 'chat_messages_state.dart';

class ChatMessagesBloc extends Bloc<ChatMessagesEvent, ChatMessagesState> {
  final ChatService _chatService;
  final SignalRService _signalRService;
  final String chatId;
  final int currentUserId;
  int _tempIdCounter = 0;

  final Box<MessageModel> _messagesBox = Hive.box<MessageModel>('messages');

  StreamSubscription? _messageReceivedSubscription;
  StreamSubscription? _messageConfirmationSubscription;
  StreamSubscription? _messageStatusSubscription;
  StreamSubscription? _messageUpdatedSubscription;

  ChatMessagesBloc(
    this._chatService,
    this._signalRService, {
    required this.chatId,
    required this.currentUserId,
  }) : super(ChatMessagesLoading()) {
    on<FetchChatMessages>(_onFetchChatMessages);
    on<SendNewMessage>(_onSendNewMessage);
    on<MessageSuccessfullySent>(_onMessageSuccessfullySent);
    on<NewMessageReceivedFromSignalR>(_onNewMessageReceivedFromSignalR);
    on<MarkMessagesAsRead>(_onMarkMessagesAsRead);
    on<MessageStatusUpdated>(_onMessageStatusUpdated);
    on<EditMessageRequested>(_onEditMessageRequested);
    on<DeleteMessageRequested>(_onDeleteMessageRequested);
    on<MessageUpdatedReceived>(_onMessageUpdatedReceived);

    _listenToSignalREvents();
  }

  void _listenToSignalREvents() {
    _messageReceivedSubscription = _signalRService.onNewMessageReceived.listen((
      message,
    ) {
      if (message.chatId == chatId && message.senderId != currentUserId) {
        add(NewMessageReceivedFromSignalR(message));
      }
    }, onError: (error) {});

    _messageConfirmationSubscription = _signalRService
        .onMessageConfirmationReceived
        .listen((confirmation) {
          add(
            MessageSuccessfullySent(
              correlationId: confirmation.correlationId,
              confirmedMessage: confirmation.confirmedMessage,
            ),
          );
        }, onError: (error) {});

    _messageStatusSubscription = _signalRService.onMessageStatusChanged.listen((
      statusUpdate,
    ) {
      if (statusUpdate['chatId'] == chatId) {
        final bool isRead = statusUpdate['status'] == 3;
        add(
          MessageStatusUpdated(
            messageId: statusUpdate['messageId'],
            isRead: isRead,
          ),
        );
      }
    }, onError: (error) {});

    _messageUpdatedSubscription = _signalRService.onMessageUpdated.listen((
      updatedMessage,
    ) {
      if (updatedMessage.chatId == chatId) {
        add(MessageUpdatedReceived(updatedMessage));
      }
    });
  }

  Future<void> _onFetchChatMessages(
    FetchChatMessages event,
    Emitter<ChatMessagesState> emit,
  ) async {
    if (event.chatId != chatId) return;

    final cachedMessages = _messagesBox.values
        .where((msg) => msg.chatId == chatId)
        .toList();
    cachedMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    emit(ChatMessagesLoaded(cachedMessages));

    try {
      final messagesFromServer = await _chatService.getChatMessages(
        chatId,
        skip: 0,
        take: 50,
      );
      await _messagesBox.putAll({
        for (var msg in messagesFromServer) msg.id: msg,
      });

      final allMessages = _messagesBox.values
          .where((msg) => msg.chatId == chatId)
          .toList();
      allMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
      emit(ChatMessagesLoaded(allMessages));
    } catch (e) {
      if (cachedMessages.isEmpty) {
        emit(ChatMessagesError(e.toString().replaceFirst("Exception: ", "")));
      }
    }
  }

  Future<void> _onSendNewMessage(
    SendNewMessage event,
    Emitter<ChatMessagesState> emit,
  ) async {
    final currentState = state;
    if (currentState is ChatMessagesLoaded) {
      final tempId = 0xFFFFFFFF - _tempIdCounter;
      _tempIdCounter++;
      final tempMessage = MessageModel(
        id: tempId,
        content: event.content,
        sentAt: DateTime.now(),
        senderId: currentUserId,
        senderName: "شما",
        chatId: chatId,
        isRead: false,
        isEdited: false,
        isDeleted: false,
        correlationId: event.correlationId,
        clientStatus: ClientMessageStatus.sending,
      );

      await _messagesBox.put(tempMessage.id, tempMessage);

      final updatedMessages = List<MessageModel>.from(currentState.messages)
        ..add(tempMessage);
      emit(ChatMessagesLoaded(updatedMessages));

      _signalRService
          .sendChatMessage(chatId, event.content, event.correlationId)
          .catchError((e) async {
            final failedMessage = tempMessage.copyWith(
              clientStatus: ClientMessageStatus.failed,
            );
            await _messagesBox.put(tempMessage.id, failedMessage);

            if (!isClosed) {
              final messagesAfterFailure = (state as ChatMessagesLoaded)
                  .messages
                  .map(
                    (m) => m.correlationId == event.correlationId
                        ? failedMessage
                        : m,
                  )
                  .toList();
              emit(ChatMessagesLoaded(messagesAfterFailure));
            }
          });
    }
  }

  Future<void> _onMessageSuccessfullySent(
    MessageSuccessfullySent event,
    Emitter<ChatMessagesState> emit,
  ) async {
    final currentState = state;
    if (currentState is ChatMessagesLoaded) {
      final correlationId = event.correlationId;
      final confirmedMessage = event.confirmedMessage.copyWith(
        clientStatus: ClientMessageStatus.sent,
      );

      // ۱. پیام موقت را با correlationId در state فعلی پیدا کن
      MessageModel? tempMessage;
      try {
        tempMessage = currentState.messages.firstWhere(
          (m) => m.correlationId == correlationId,
        );
      } catch (e) {
        tempMessage = null;
      }

      // ۲. اگر پیام موقت پیدا شد، آن را از Hive پاک کن
      if (tempMessage != null) {
        await _messagesBox.delete(tempMessage.id);
      }

      // ۳. پیام نهایی و تایید شده را در Hive ذخیره کن
      await _messagesBox.put(confirmedMessage.id, confirmedMessage);

      // ۴. لیست پیام‌ها را برای نمایش در UI به‌روز کن
      // ابتدا همه پیام‌های بدون correlationId مورد نظر را نگه دار
      final updatedMessages = currentState.messages
          .where((msg) => msg.correlationId != correlationId)
          .toList();

      // سپس پیام تایید شده را به لیست اضافه کن
      updatedMessages.add(confirmedMessage);

      // لیست را مجددا مرتب کن تا پیام‌ها به ترتیب زمان باشند
      updatedMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

      emit(ChatMessagesLoaded(updatedMessages));
    }
  }

  Future<void> _onNewMessageReceivedFromSignalR(
    NewMessageReceivedFromSignalR event,
    Emitter<ChatMessagesState> emit,
  ) async {
    final currentState = state;
    if (currentState is ChatMessagesLoaded) {
      if (currentState.messages.any((m) => m.id == event.message.id)) return;

      await _messagesBox.put(event.message.id, event.message);

      final updatedMessages = List<MessageModel>.from(currentState.messages)
        ..add(event.message);
      emit(ChatMessagesLoaded(updatedMessages));
    }
  }

  Future<void> _onMessageUpdatedReceived(
    MessageUpdatedReceived event,
    Emitter<ChatMessagesState> emit,
  ) async {
    // <-- async
    final currentState = state;
    if (currentState is ChatMessagesLoaded) {
      List<MessageModel> updatedMessages;

      if (event.updatedMessage.isDeleted) {
        await _messagesBox.delete(event.updatedMessage.id);
        updatedMessages = currentState.messages
            .where((msg) => msg.id != event.updatedMessage.id)
            .toList();
      } else {
        await _messagesBox.put(event.updatedMessage.id, event.updatedMessage);
        updatedMessages = currentState.messages.map((msg) {
          return msg.id == event.updatedMessage.id ? event.updatedMessage : msg;
        }).toList();
      }

      emit(ChatMessagesLoaded(updatedMessages));
    }
  }

  @override
  Future<void> close() {
    _messageReceivedSubscription?.cancel();
    _messageConfirmationSubscription?.cancel();
    _messageStatusSubscription?.cancel();
    _messageUpdatedSubscription?.cancel();
    return super.close();
  }

  Future<void> _onEditMessageRequested(
    EditMessageRequested event,
    Emitter<ChatMessagesState> emit,
  ) async {
    try {
      await _chatService.editMessage(event.messageId, event.newContent);
    } catch (e) {
      emit(ChatMessagesError("خطا در ویرایش پیام: ${e.toString()}"));
    }
  }

  Future<void> _onDeleteMessageRequested(
    DeleteMessageRequested event,
    Emitter<ChatMessagesState> emit,
  ) async {
    try {
      await _chatService.deleteMessage(event.messageId);
    } catch (e) {
      emit(ChatMessagesError("خطا در حذف پیام: ${e.toString()}"));
    }
  }

  Future<void> _onMessageStatusUpdated(
    MessageStatusUpdated event,
    Emitter<ChatMessagesState> emit,
  ) async {
    final currentState = state;
    if (currentState is ChatMessagesLoaded) {
      final updatedMessages = currentState.messages.map((msg) {
        if (msg.id == event.messageId) {
          final updatedMsg = msg.copyWith(isRead: event.isRead);
          _messagesBox.put(updatedMsg.id, updatedMsg);
          return updatedMsg;
        }
        return msg;
      }).toList();
      emit(ChatMessagesLoaded(updatedMessages));
    }
  }

  Future<void> _onMarkMessagesAsRead(
    MarkMessagesAsRead event,
    Emitter<ChatMessagesState> emit,
  ) async {
    final currentState = state;
    if (currentState is ChatMessagesLoaded) {
      final unreadMessageIds = currentState.messages
          .where((m) => !m.isRead && m.senderId != currentUserId)
          .map((m) => m.id)
          .toList();

      if (unreadMessageIds.isNotEmpty) {
        try {
          await _signalRService.markMultipleMessagesAsRead(unreadMessageIds);
          final updatedMessages = currentState.messages.map((m) {
            if (unreadMessageIds.contains(m.id)) {
              final updatedMsg = m.copyWith(isRead: true);
              _messagesBox.put(updatedMsg.id, updatedMsg);
              return updatedMsg;
            }
            return m;
          }).toList();
          emit(ChatMessagesLoaded(updatedMessages));
        } catch (e) {}
      }
    }
  }
}
