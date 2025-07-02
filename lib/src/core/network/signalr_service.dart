import 'dart:async';
import 'package:logging/logging.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:solvix/src/core/models/message_model.dart';
import 'package:solvix/src/core/services/storage_service.dart';

import '../models/client_message_status.dart';

const String _hubUrl = "https://api.solvix.ir/chathub";

class MessageConfirmation {
  final String correlationId;
  final MessageModel confirmedMessage;

  MessageConfirmation({
    required this.correlationId,
    required this.confirmedMessage,
  });
}

class SignalRService {
  HubConnection? _hubConnection;
  final StorageService _storageService = StorageService();
  final Logger _logger = Logger('SignalRService');
  Completer<void>? _connectionCompleter;

  final _newMessageReceivedController =
      StreamController<MessageModel>.broadcast();

  final _messageUpdatedController = StreamController<MessageModel>.broadcast();

  Stream<MessageModel> get onMessageUpdated => _messageUpdatedController.stream;

  Stream<MessageModel> get onNewMessageReceived =>
      _newMessageReceivedController.stream;

  final _messageConfirmationController =
      StreamController<MessageConfirmation>.broadcast();

  Stream<MessageConfirmation> get onMessageConfirmationReceived =>
      _messageConfirmationController.stream;

  final _userStatusChangedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onUserStatusChanged =>
      _userStatusChangedController.stream;

  final _userTypingController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;

  final _messageStatusChangedController =
      StreamController<Map<String, dynamic>>.broadcast();

  Stream<Map<String, dynamic>> get onMessageStatusChanged =>
      _messageStatusChangedController.stream;

  bool get isConnected => _hubConnection?.state == HubConnectionState.connected;

  SignalRService() {
    Logger.root.level = Level.INFO; // یا Level.FINE برای جزئیات بیشتر
    Logger.root.onRecord.listen((LogRecord rec) {
      if (rec.loggerName == 'SignalRService' ||
          rec.loggerName.startsWith('SignalRClientInternal')) {
        print(
          '[${rec.level.name}] ${rec.time.toIso8601String().substring(11, 23)} | ${rec.loggerName} | ${rec.message}',
        );
      }
    });
  }

  Future<void> connect() async {
    if (isConnected) {
      _logger.info('SignalR connection already established.');
      return;
    }

    final token = await _storageService.getToken();
    if (token == null) {
      _logger.warning('Auth token is null. Cannot connect to SignalR.');
      throw Exception('Auth token not found for SignalR');
    }

    try {
      _hubConnection = HubConnectionBuilder()
          .withUrl(
            '$_hubUrl?access_token=$token',
            HttpConnectionOptions(
              logging: (level, message) =>
                  _logger.fine('SignalR Internal Log: $message'),
            ),
          )
          .withAutomaticReconnect()
          .build();

      _hubConnection!.onclose((error) {
        _logger.warning('SignalR connection closed. Error: $error');
      });

      await _hubConnection!.start();

      _logger.info('SignalR connection established successfully.');

      _registerServerToClientEventHandlers();
    } catch (e) {
      _logger.severe('Failed to connect to SignalR: $e');
      await disconnect();
      throw Exception('Failed to establish SignalR connection: $e');
    }
  }

  Future<void> disconnect() async {
    _logger.info('Disconnecting SignalR...');
    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.completeError(
        Exception("Connection explicitly disconnected."),
      );
    }
    if (_hubConnection != null) {
      await _hubConnection!.stop();
      _hubConnection = null;
    }
    _connectionCompleter = null; // همیشه ریست شود
    _logger.info('SignalR connection has been disconnected.');
  }

  void _registerServerToClientEventHandlers() {
    if (!isConnected || _hubConnection == null) {
      _logger.warning('Cannot register server events: SignalR not connected.');
      return;
    }
    _logger.info('Registering server-to-client event handlers...');

    _hubConnection!.on('ReceiveMessage', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final messageData = arguments[0] as Map<String, dynamic>?;
        if (messageData != null) {
          _logger.info('SignalR: Message received: $messageData');
          try {
            final message = MessageModel.fromJson(messageData);
            _newMessageReceivedController.add(message);
          } catch (e) {
            _logger.severe(
              'SignalR: Error parsing received message: $e \nData: $messageData',
            );
          }
        }
      }
    });

    _hubConnection!.on('MessageUpdated', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final messageData = arguments[0] as Map<String, dynamic>?;
        if (messageData != null) {
          _logger.info('SignalR: Message updated: $messageData');
          try {
            final message = MessageModel.fromJson(messageData);
            _messageUpdatedController.add(message);
          } catch (e) {
            _logger.severe('SignalR: Error parsing updated message: $e');
          }
        }
      }
    });

    _hubConnection!.on('MessageCorrelationConfirmation', (
      List<Object?>? arguments,
    ) {
      if (arguments != null && arguments.length >= 2) {
        final correlationId = arguments[0] as String?;
        final confirmedMessageData = arguments[1] as Map<String, dynamic>?;

        if (correlationId != null && confirmedMessageData != null) {
          _logger.info(
            'SignalR: Message correlation confirmation: CorrelationID: $correlationId, ServerMessageData: $confirmedMessageData',
          );
          try {
            final confirmedMessage = MessageModel.fromJson(
              confirmedMessageData,
              correlationId: correlationId,
              clientStatus: ClientMessageStatus.sent,
            );
            _messageConfirmationController.add(
              MessageConfirmation(
                correlationId: correlationId,
                confirmedMessage: confirmedMessage,
              ),
            );
          } catch (e) {
            _logger.severe(
              'SignalR: Error parsing confirmed message for correlation $correlationId: $e',
            );
          }
        } else {
          _logger.warning(
            'SignalR: MessageCorrelationConfirmation received with missing data. CorrelationID: $correlationId, MessageData: $confirmedMessageData',
          );
        }
      }
    });

    _hubConnection!.on('UserStatusChanged', (List<Object?>? arguments) {
      if (arguments != null && arguments.length >= 2) {
        final userId = arguments[0] as int?;
        final isOnline = arguments[1] as bool?;
        final lastActiveRaw = arguments.length > 2 ? arguments[2] : null;
        _logger.info(
          'SignalR: User status changed: UserID: $userId, IsOnline: $isOnline, LastActive: $lastActiveRaw',
        );
        _userStatusChangedController.add({
          'userId': userId,
          'isOnline': isOnline,
          'lastActive': lastActiveRaw is String
              ? DateTime.tryParse(lastActiveRaw)
              : null,
        });
      }
    });

    _hubConnection!.on('MessageStatusChanged', (List<Object?>? arguments) {
      if (arguments != null && arguments.length >= 3) {
        final chatId = arguments[0] as String?;
        final messageId = arguments[1] as int?;
        final status = arguments[2] as int?;
        _logger.info(
          'SignalR: Message status changed: ChatID: $chatId, MessageID: $messageId, Status: $status',
        );
        _messageStatusChangedController.add({
          'chatId': chatId,
          'messageId': messageId,
          'status': status,
        });
      }
    });

    _hubConnection!.on('UserTyping', (List<Object?>? arguments) {
      if (arguments != null && arguments.length >= 3) {
        final chatId = arguments[0] as String?;
        final userId = arguments[1] as int?;
        final isTyping = arguments[2] as bool?;
        _logger.info(
          'SignalR: User typing status: ChatID: $chatId, UserID: $userId, IsTyping: $isTyping',
        );
        _userTypingController.add({
          'chatId': chatId,
          'userId': userId,
          'isTyping': isTyping,
        });
      }
    });

    _hubConnection!.on('ReceiveError', (List<Object?>? arguments) {
      if (arguments != null && arguments.isNotEmpty) {
        final errorMessage = arguments[0] as String?;
        _logger.warning('SignalR: Received error from Hub: $errorMessage');
      }
    });
    _logger.info('SignalR: Server-to-client event handlers registered.');
  }

  Future<void> sendChatMessage(
    String chatIdGuid,
    String content,
    String correlationId,
  ) async {
    if (!isConnected || _hubConnection == null) {
      _logger.warning('SignalR: Cannot send message: Not connected.');
      throw Exception('SignalR not connected');
    }
    try {
      _logger.info(
        'SignalR: Invoking SendToChat: ChatID=$chatIdGuid, CorrelationID=$correlationId',
      );
      await _hubConnection!.invoke(
        'SendToChat',
        args: [chatIdGuid, content, correlationId],
      );
      _logger.info('SignalR: Message invocation sent for chat $chatIdGuid.');
    } catch (e) {
      _logger.severe('SignalR: Error invoking SendToChat: $e');
      rethrow;
    }
  }

  Future<void> markMessageAsRead(int messageId) async {
    if (!isConnected || _hubConnection == null) return;
    try {
      await _hubConnection!.invoke('MarkMessageAsRead', args: [messageId]);
    } catch (e) {
      _logger.severe('SignalR: Error invoking MarkMessageAsRead: $e');
    }
  }

  Future<void> markMultipleMessagesAsRead(List<int> messageIds) async {
    if (!isConnected || _hubConnection == null) return;
    try {
      await _hubConnection!.invoke(
        'MarkMultipleMessagesAsRead',
        args: [messageIds],
      );
    } catch (e) {
      _logger.severe('SignalR: Error invoking MarkMultipleMessagesAsRead: $e');
    }
  }

  Future<void> notifyUserTyping(String chatIdGuid, bool isTyping) async {
    if (!isConnected || _hubConnection == null) return;
    try {
      await _hubConnection!.invoke('UserTyping', args: [chatIdGuid, isTyping]);
    } catch (e) {
      _logger.severe('SignalR: Error invoking UserTyping: $e');
    }
  }

  void dispose() {
    _logger.info('SignalRService disposing...');
    _newMessageReceivedController.close();
    _messageConfirmationController.close();
    _userStatusChangedController.close();
    _userTypingController.close();
    _messageStatusChangedController.close();
    _messageUpdatedController.close();
    disconnect();
  }
}
