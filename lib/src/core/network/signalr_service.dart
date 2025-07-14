// lib/src/core/network/signalr_service.dart
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:solvix/src/core/models/message_model.dart';
import 'package:solvix/src/core/services/storage_service.dart';
import '../models/client_message_status.dart';

// اضافه کردن URL ثابت مثل سایر service ها
const String _signalRHubUrl = "https://api.solvix.ir/chathub";

enum SignalRConnectionStatus {
  Disconnected,
  Connecting,
  Connected,
  Reconnecting,
}

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
  final StorageService _storageService;
  final Logger _logger = Logger('SignalRService');

  final StreamController<SignalRConnectionStatus> _connectionStatusController =
      StreamController<SignalRConnectionStatus>.broadcast();
  final StreamController<MessageModel> _newMessageReceivedController =
      StreamController<MessageModel>.broadcast();
  final StreamController<MessageModel> _messageUpdatedController =
      StreamController<MessageModel>.broadcast();
  final StreamController<MessageConfirmation> _messageConfirmationController =
      StreamController<MessageConfirmation>.broadcast();
  final StreamController<Map<String, dynamic>> _userStatusChangedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _messageStatusChangedController =
      StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<Map<String, dynamic>> _userTypingController =
      StreamController<Map<String, dynamic>>.broadcast();

  Completer<void>? _connectionCompleter;

  SignalRService(this._storageService);

  // ✅ Fix 1: اضافه کردن getter برای connectionStatusStream
  Stream<SignalRConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  Stream<SignalRConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  Stream<MessageModel> get onNewMessageReceived =>
      _newMessageReceivedController.stream;

  Stream<MessageModel> get onMessageUpdated => _messageUpdatedController.stream;

  Stream<MessageConfirmation> get onMessageConfirmation =>
      _messageConfirmationController.stream;

  // ✅ Fix 2: اضافه کردن getter برای onMessageConfirmationReceived
  Stream<MessageConfirmation> get onMessageConfirmationReceived =>
      _messageConfirmationController.stream;

  Stream<Map<String, dynamic>> get onUserStatusChanged =>
      _userStatusChangedController.stream;

  Stream<Map<String, dynamic>> get onMessageStatusChanged =>
      _messageStatusChangedController.stream;

  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;

  bool get isConnected => _hubConnection?.state == HubConnectionState.connected;

  Future<void> connect() async {
    if (isConnected) {
      _logger.info('SignalR already connected');
      _connectionStatusController.add(SignalRConnectionStatus.Connected);
      return;
    }

    final token = await _storageService.getToken();
    if (token == null) {
      _logger.warning('Auth token is null. Cannot connect to SignalR.');
      throw Exception('Auth token not found for SignalR');
    }

    try {
      _logger.info(
        'SignalR: Connecting to $_signalRHubUrl',
      ); // استفاده از URL ثابت

      _hubConnection = HubConnectionBuilder()
          .withUrl(
            '$_signalRHubUrl?access_token=$token', // استفاده از URL ثابت
            HttpConnectionOptions(
              logging: (level, message) =>
                  _logger.fine('SignalR Internal Log: $message'),
            ),
          )
          .withAutomaticReconnect([0, 2000, 4000, 6000, 8000, 10000])
          .build();

      _hubConnection!.onclose((error) {
        _logger.warning('SignalR connection closed. Error: $error');
        _connectionStatusController.add(SignalRConnectionStatus.Disconnected);
      });

      _hubConnection!.onreconnecting((error) {
        _logger.info('SignalR is reconnecting...');
        _connectionStatusController.add(SignalRConnectionStatus.Reconnecting);
      });

      _hubConnection!.onreconnected((connectionId) {
        _logger.info('SignalR has reconnected successfully.');
        _connectionStatusController.add(SignalRConnectionStatus.Connected);
      });

      _connectionStatusController.add(SignalRConnectionStatus.Reconnecting);
      await _hubConnection!.start();

      _logger.info('SignalR connection established successfully.');
      _connectionStatusController.add(SignalRConnectionStatus.Connected);

      _registerServerToClientEventHandlers();
    } catch (e) {
      _logger.severe('Failed to connect to SignalR: $e');
      _connectionStatusController.add(SignalRConnectionStatus.Disconnected);
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
    _connectionStatusController.add(SignalRConnectionStatus.Disconnected);
    _connectionCompleter = null;
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
      _logger.severe('SignalR: Error sending message: $e');
      throw Exception('Failed to send message via SignalR: $e');
    }
  }

  Future<void> joinChatGroup(String chatId) async {
    if (!isConnected || _hubConnection == null) {
      _logger.warning('SignalR: Cannot join group: Not connected.');
      throw Exception('SignalR not connected');
    }
    try {
      await _hubConnection!.invoke('JoinGroup', args: [chatId]);
      _logger.info('SignalR: Joined chat group: $chatId');
    } catch (e) {
      _logger.severe('SignalR: Error joining group: $e');
      throw Exception('Failed to join chat group: $e');
    }
  }

  Future<void> leaveChatGroup(String chatId) async {
    if (!isConnected || _hubConnection == null) {
      _logger.warning('SignalR: Cannot leave group: Not connected.');
      throw Exception('SignalR not connected');
    }
    try {
      await _hubConnection!.invoke('LeaveGroup', args: [chatId]);
      _logger.info('SignalR: Left chat group: $chatId');
    } catch (e) {
      _logger.severe('SignalR: Error leaving group: $e');
      throw Exception('Failed to leave chat group: $e');
    }
  }

  // ✅ Fix 3: اضافه کردن method markMultipleMessagesAsRead
  Future<void> markMultipleMessagesAsRead(
    String chatId,
    List<int> messageIds,
  ) async {
    if (!isConnected || _hubConnection == null) {
      _logger.warning('SignalR: Cannot mark messages as read: Not connected.');
      throw Exception('SignalR not connected');
    }
    try {
      await _hubConnection!.invoke(
        'MarkMultipleMessagesAsRead',
        args: [chatId, messageIds],
      );
      _logger.info(
        'SignalR: Marked ${messageIds.length} messages as read in chat $chatId',
      );
    } catch (e) {
      _logger.severe('SignalR: Error marking messages as read: $e');
      throw Exception('Failed to mark messages as read: $e');
    }
  }

  Future<void> notifyTyping(String chatId, bool isTyping) async {
    if (!isConnected || _hubConnection == null) {
      _logger.warning('SignalR: Cannot notify typing: Not connected.');
      return;
    }
    try {
      await _hubConnection!.invoke('NotifyTyping', args: [chatId, isTyping]);
      _logger.fine('SignalR: Typing notification sent: $isTyping');
    } catch (e) {
      _logger.warning('SignalR: Error notifying typing: $e');
    }
  }

  void dispose() {
    _logger.info('Disposing SignalRService...');
    _connectionStatusController.close();
    _newMessageReceivedController.close();
    _messageUpdatedController.close();
    _messageConfirmationController.close();
    _userStatusChangedController.close();
    _messageStatusChangedController.close();
    _userTypingController.close();
    disconnect();
  }
}
