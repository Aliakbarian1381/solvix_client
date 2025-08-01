// lib/src/features/chat/presentation/bloc/chat_messages_bloc.dart
import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:logging/logging.dart';
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
  final Logger _logger = Logger('ChatMessagesBloc');

  int _tempIdCounter = 0;
  final Box<MessageModel> _messagesBox = Hive.box<MessageModel>('messages');

  // ✅ Fix 1: همه subscriptions رو nullable کردیم و بهتر مدیریت می‌کنیم
  StreamSubscription<MessageModel>? _messageReceivedSubscription;
  StreamSubscription<MessageConfirmation>? _messageConfirmationSubscription;
  StreamSubscription<Map<String, dynamic>>? _messageStatusSubscription;
  StreamSubscription<MessageModel>? _messageUpdatedSubscription;

  // ✅ Fix 2: اضافه کردن timer برای debounce کردن پیام‌های خوندن
  Timer? _markAsReadTimer;
  final Set<int> _pendingReadMessageIds = <int>{};

  ChatMessagesBloc(
    this._chatService,
    this._signalRService, {
    required this.chatId,
    required this.currentUserId,
  }) : super(ChatMessagesLoading()) {
    // Event handlers
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
    _logger.info('ChatMessagesBloc initialized for chat: $chatId');
  }

  // ✅ Fix 3: بهتر کردن SignalR event handling
  void _listenToSignalREvents() {
    try {
      _messageReceivedSubscription = _signalRService.onNewMessageReceived
          .listen(
            (message) {
              if (message.chatId == chatId &&
                  message.senderId != currentUserId) {
                _logger.info('New message received for chat $chatId');
                add(NewMessageReceivedFromSignalR(message));
              }
            },
            onError: (error) {
              _logger.severe('Error in message received stream: $error');
            },
            cancelOnError:
                false, // ✅ مهم: جلوگیری از cancel شدن stream در صورت خطا
          );

      _messageConfirmationSubscription = _signalRService
          .onMessageConfirmationReceived
          .listen(
            (confirmation) {
              _logger.info(
                'Message confirmation received: ${confirmation.correlationId}',
              );
              add(
                MessageSuccessfullySent(
                  correlationId: confirmation.correlationId,
                  confirmedMessage: confirmation.confirmedMessage,
                ),
              );
            },
            onError: (error) {
              _logger.severe('Error in message confirmation stream: $error');
            },
            cancelOnError: false,
          );

      _messageStatusSubscription = _signalRService.onMessageStatusChanged.listen(
        (statusUpdate) {
          if (statusUpdate['chatId'] == chatId) {
            final bool isRead = statusUpdate['status'] == 3;
            _logger.fine(
              'Message status updated: ${statusUpdate['messageId']} -> read: $isRead',
            );
            add(
              MessageStatusUpdated(
                messageId: statusUpdate['messageId'],
                isRead: isRead,
              ),
            );
          }
        },
        onError: (error) {
          _logger.severe('Error in message status stream: $error');
        },
        cancelOnError: false,
      );

      _messageUpdatedSubscription = _signalRService.onMessageUpdated.listen(
        (updatedMessage) {
          if (updatedMessage.chatId == chatId) {
            _logger.info(
              'Message updated for chat $chatId: ${updatedMessage.id}',
            );
            add(MessageUpdatedReceived(updatedMessage));
          }
        },
        onError: (error) {
          _logger.severe('Error in message updated stream: $error');
        },
        cancelOnError: false,
      );

      _logger.info('SignalR event listeners registered successfully');
    } catch (e) {
      _logger.severe('Error setting up SignalR listeners: $e');
    }
  }

  // ✅ Fix 4: بهبود fetch messages با بهتر error handling
  Future<void> _onFetchChatMessages(
    FetchChatMessages event,
    Emitter<ChatMessagesState> emit,
  ) async {
    if (event.chatId != chatId) {
      _logger.warning(
        'Received fetch request for different chat: ${event.chatId}',
      );
      return;
    }

    try {
      // اول cache رو نشون بده
      final cachedMessages = _getCachedMessages();
      if (cachedMessages.isNotEmpty) {
        emit(ChatMessagesLoaded(cachedMessages));
        _logger.info('Loaded ${cachedMessages.length} cached messages');
      }

      // بعد از سرور بگیر
      final messagesFromServer = await _chatService.getChatMessages(
        chatId,
        skip: 0,
        take: 50,
      );

      // کش رو آپدیت کن
      await _updateMessagesCache(messagesFromServer);

      // state جدید رو emit کن
      final allMessages = _getCachedMessages();
      emit(ChatMessagesLoaded(allMessages));

      _logger.info('Loaded ${messagesFromServer.length} messages from server');
    } catch (e) {
      _logger.severe('Error fetching messages: $e');

      // اگر کش خالیه، خطا نشون بده
      final cachedMessages = _getCachedMessages();
      if (cachedMessages.isEmpty) {
        emit(ChatMessagesError(_formatErrorMessage(e)));
      }
      // وگرنه همون کش رو نگه دار
    }
  }

  // ✅ Fix 5: بهبود send message با retry mechanism
  Future<void> _onSendNewMessage(
    SendNewMessage event,
    Emitter<ChatMessagesState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatMessagesLoaded) {
      _logger.warning('Cannot send message: chat not loaded');
      return;
    }

    try {
      // ساخت پیام موقت
      final tempMessage = _createTempMessage(event);

      // اضافه کردن به کش و UI
      await _messagesBox.put(tempMessage.id, tempMessage);
      final updatedMessages = [...currentState.messages, tempMessage];
      emit(ChatMessagesLoaded(updatedMessages));

      _logger.info(
        'Sending message with correlation ID: ${event.correlationId}',
      );

      // ارسال به سرور
      await _signalRService.sendChatMessage(
        chatId,
        event.content,
        event.correlationId,
      );
    } catch (e) {
      _logger.severe('Error sending message: $e');

      // تغییر وضعیت پیام به failed
      await _markMessageAsFailed(event.correlationId, currentState);
      emit(ChatMessagesLoaded(_getCachedMessages()));
    }
  }

  // ✅ Fix 6: بهبود message confirmation handling
  Future<void> _onMessageSuccessfullySent(
    MessageSuccessfullySent event,
    Emitter<ChatMessagesState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatMessagesLoaded) return;

    try {
      // پیدا کردن پیام موقت و جایگزینی با پیام تایید شده
      final updatedMessages = currentState.messages.map((msg) {
        if (msg.correlationId == event.correlationId) {
          final confirmedMsg = event.confirmedMessage.copyWith(
            clientStatus: ClientMessageStatus.sent,
          );

          // آپدیت کش
          _messagesBox.delete(msg.id); // حذف پیام موقت
          _messagesBox.put(
            confirmedMsg.id,
            confirmedMsg,
          ); // اضافه کردن پیام تایید شده

          return confirmedMsg;
        }
        return msg;
      }).toList();

      emit(ChatMessagesLoaded(updatedMessages));
      _logger.info(
        'Message confirmed: ${event.correlationId} -> ${event.confirmedMessage.id}',
      );
    } catch (e) {
      _logger.severe('Error handling message confirmation: $e');
    }
  }

  // ✅ Fix 7: بهبود new message handling
  Future<void> _onNewMessageReceivedFromSignalR(
    NewMessageReceivedFromSignalR event,
    Emitter<ChatMessagesState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatMessagesLoaded) return;

    try {
      // بررسی اینکه پیام قبلاً وجود داره یا نه (جلوگیری از duplicate)
      final existingMessageIndex = currentState.messages.indexWhere(
        (msg) => msg.id == event.message.id,
      );

      if (existingMessageIndex != -1) {
        _logger.fine('Message already exists: ${event.message.id}');
        return;
      }

      // اضافه کردن پیام جدید
      await _messagesBox.put(event.message.id, event.message);
      final updatedMessages = [...currentState.messages, event.message];

      // مرتب کردن بر اساس زمان
      updatedMessages.sort((a, b) => a.sentAt.compareTo(b.sentAt));

      emit(ChatMessagesLoaded(updatedMessages));
      _logger.info('New message added: ${event.message.id}');
    } catch (e) {
      _logger.severe('Error handling new message: $e');
    }
  }

  // ✅ Fix 8: بهبود mark as read با debouncing
  Future<void> _onMarkMessagesAsRead(
    MarkMessagesAsRead event,
    Emitter<ChatMessagesState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatMessagesLoaded) return;

    try {
      // پیدا کردن پیام‌های خوانده نشده
      final unreadMessages = currentState.messages
          .where((m) => !m.isRead && m.senderId != currentUserId)
          .toList();

      if (unreadMessages.isEmpty) return;

      // اضافه کردن به لیست pending
      _pendingReadMessageIds.addAll(unreadMessages.map((m) => m.id));

      // Cancel کردن timer قبلی و شروع جدید (debouncing)
      _markAsReadTimer?.cancel();
      _markAsReadTimer = Timer(const Duration(milliseconds: 500), () {
        _processPendingReadMessages();
      });

      // فوراً UI رو آپدیت کن
      final updatedMessages = currentState.messages.map((m) {
        if (unreadMessages.any((unread) => unread.id == m.id)) {
          final updatedMsg = m.copyWith(isRead: true);
          _messagesBox.put(updatedMsg.id, updatedMsg);
          return updatedMsg;
        }
        return m;
      }).toList();

      emit(ChatMessagesLoaded(updatedMessages));
      _logger.info('Marked ${unreadMessages.length} messages as read locally');
    } catch (e) {
      _logger.severe('Error marking messages as read: $e');
    }
  }

  // ✅ Fix 9: پردازش batch messages برای خوندن
  Future<void> _processPendingReadMessages() async {
    if (_pendingReadMessageIds.isEmpty) return;

    try {
      final messageIds = _pendingReadMessageIds.toList();
      _pendingReadMessageIds.clear();

      await _signalRService.markMultipleMessagesAsRead(chatId, messageIds);
      _logger.info(
        'Sent read confirmation for ${messageIds.length} messages to server',
      );
    } catch (e) {
      _logger.warning('Failed to send read confirmation to server: $e');
      // در صورت خطا، پیام‌ها رو دوباره به pending اضافه نمی‌کنیم چون UI آپدیت شده
    }
  }

  // ✅ Fix 10: بهبود message editing
  Future<void> _onEditMessageRequested(
    EditMessageRequested event,
    Emitter<ChatMessagesState> emit,
  ) async {
    try {
      _logger.info('Editing message ${event.messageId}');
      await _chatService.editMessage(event.messageId, event.newContent);
      // پیام آپدیت شده از طریق SignalR دریافت خواهد شد
    } catch (e) {
      _logger.severe('Error editing message: $e');
      emit(ChatMessagesError(_formatErrorMessage(e)));
    }
  }

  // ✅ Fix 11: بهبود message deletion
  Future<void> _onDeleteMessageRequested(
    DeleteMessageRequested event,
    Emitter<ChatMessagesState> emit,
  ) async {
    try {
      _logger.info('Deleting message ${event.messageId}');
      await _chatService.deleteMessage(event.messageId);
      // پیام حذف شده از طریق SignalR اطلاع داده خواهد شد
    } catch (e) {
      _logger.severe('Error deleting message: $e');
      emit(ChatMessagesError(_formatErrorMessage(e)));
    }
  }

  // ✅ Fix 12: بهبود message status update
  Future<void> _onMessageStatusUpdated(
    MessageStatusUpdated event,
    Emitter<ChatMessagesState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatMessagesLoaded) return;

    try {
      final updatedMessages = currentState.messages.map((msg) {
        if (msg.id == event.messageId) {
          final updatedMsg = msg.copyWith(isRead: event.isRead);
          _messagesBox.put(updatedMsg.id, updatedMsg);
          return updatedMsg;
        }
        return msg;
      }).toList();

      emit(ChatMessagesLoaded(updatedMessages));
      _logger.fine(
        'Message status updated: ${event.messageId} -> read: ${event.isRead}',
      );
    } catch (e) {
      _logger.severe('Error updating message status: $e');
    }
  }

  // ✅ Fix 13: بهبود message update handling
  Future<void> _onMessageUpdatedReceived(
    MessageUpdatedReceived event,
    Emitter<ChatMessagesState> emit,
  ) async {
    final currentState = state;
    if (currentState is! ChatMessagesLoaded) return;

    try {
      final updatedMessages = currentState.messages.map((msg) {
        if (msg.id == event.updatedMessage.id) {
          _messagesBox.put(event.updatedMessage.id, event.updatedMessage);
          return event.updatedMessage;
        }
        return msg;
      }).toList();

      emit(ChatMessagesLoaded(updatedMessages));
      _logger.info('Message updated: ${event.updatedMessage.id}');
    } catch (e) {
      _logger.severe('Error handling message update: $e');
    }
  }

  // ✅ Helper Methods

  List<MessageModel> _getCachedMessages() {
    final messages = _messagesBox.values
        .where((msg) => msg.chatId == chatId)
        .toList();
    messages.sort((a, b) => a.sentAt.compareTo(b.sentAt));
    return messages;
  }

  Future<void> _updateMessagesCache(List<MessageModel> messages) async {
    final batch = <int, MessageModel>{};
    for (var msg in messages) {
      batch[msg.id] = msg;
    }
    await _messagesBox.putAll(batch);
  }

  MessageModel _createTempMessage(SendNewMessage event) {
    final tempId = 0xFFFFFFFF - _tempIdCounter;
    _tempIdCounter++;

    return MessageModel(
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
  }

  Future<void> _markMessageAsFailed(
    String correlationId,
    ChatMessagesLoaded currentState,
  ) async {
    try {
      final messageToUpdate = currentState.messages.firstWhere(
        (m) => m.correlationId == correlationId,
      );

      final failedMessage = messageToUpdate.copyWith(
        clientStatus: ClientMessageStatus.failed,
      );

      await _messagesBox.put(messageToUpdate.id, failedMessage);
      _logger.warning('Message marked as failed: $correlationId');
    } catch (e) {
      _logger.severe('Error marking message as failed: $e');
    }
  }

  String _formatErrorMessage(dynamic error) {
    String message = error.toString();
    if (message.startsWith('Exception: ')) {
      message = message.replaceFirst('Exception: ', '');
    }
    return message;
  }

  // ✅ Fix 14: بهبود cleanup در close
  @override
  Future<void> close() async {
    _logger.info('Closing ChatMessagesBloc for chat: $chatId');

    // Cancel همه subscriptions
    await _messageReceivedSubscription?.cancel();
    await _messageConfirmationSubscription?.cancel();
    await _messageStatusSubscription?.cancel();
    await _messageUpdatedSubscription?.cancel();

    // Cancel timers
    _markAsReadTimer?.cancel();

    // Clear pending operations
    _pendingReadMessageIds.clear();

    _logger.info('ChatMessagesBloc cleanup completed');
    return super.close();
  }
}
