// lib/src/core/network/signalr_service.dart
import 'dart:async';
import 'package:logging/logging.dart';
import 'package:signalr_core/signalr_core.dart';
import 'package:solvix/src/core/models/message_model.dart';
import 'package:solvix/src/core/services/storage_service.dart';
import '../models/client_message_status.dart';

// ✅ Constants centralized
class SignalRConstants {
  static const String hubUrl = "https://api.solvix.ir/chathub";
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration heartbeatInterval = Duration(seconds: 30);
  static const int maxReconnectAttempts = 5;
  static const List<int> reconnectDelays = [0, 2000, 4000, 6000, 8000, 10000];
}

enum SignalRConnectionStatus {
  disconnected,
  connecting,
  connected,
  reconnecting,
}

class MessageConfirmation {
  final String correlationId;
  final MessageModel confirmedMessage;

  MessageConfirmation({
    required this.correlationId,
    required this.confirmedMessage,
  });

  @override
  String toString() =>
      'MessageConfirmation(correlationId: $correlationId, messageId: ${confirmedMessage.id})';
}

class SignalRService {
  HubConnection? _hubConnection;
  final StorageService _storageService;
  final Logger _logger = Logger('SignalRService');

  // ✅ Fix 1: Connection state management
  SignalRConnectionStatus _connectionStatus =
      SignalRConnectionStatus.disconnected;
  int _reconnectAttempts = 0;
  Timer? _heartbeatTimer;
  Timer? _reconnectTimer;
  Completer<void>? _connectionCompleter;

  // ✅ Fix 2: Stream controllers با proper error handling
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

  SignalRService(this._storageService);

  // ✅ Getters
  Stream<SignalRConnectionStatus> get connectionStatus =>
      _connectionStatusController.stream;

  Stream<SignalRConnectionStatus> get connectionStatusStream =>
      _connectionStatusController.stream;

  Stream<MessageModel> get onNewMessageReceived =>
      _newMessageReceivedController.stream;

  Stream<MessageModel> get onMessageUpdated => _messageUpdatedController.stream;

  Stream<MessageConfirmation> get onMessageConfirmation =>
      _messageConfirmationController.stream;

  Stream<MessageConfirmation> get onMessageConfirmationReceived =>
      _messageConfirmationController.stream;

  Stream<Map<String, dynamic>> get onUserStatusChanged =>
      _userStatusChangedController.stream;

  Stream<Map<String, dynamic>> get onMessageStatusChanged =>
      _messageStatusChangedController.stream;

  Stream<Map<String, dynamic>> get onUserTyping => _userTypingController.stream;

  bool get isConnected =>
      _hubConnection?.state == HubConnectionState.connected &&
      _connectionStatus == SignalRConnectionStatus.connected;

  SignalRConnectionStatus get currentStatus => _connectionStatus;

  // ✅ Fix 3: بهبود connection method با retry logic
  Future<void> connect() async {
    if (isConnected) {
      _logger.info('SignalR already connected');
      return;
    }

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _logger.info('Connection already in progress, waiting...');
      return _connectionCompleter!.future;
    }

    _connectionCompleter = Completer<void>();

    try {
      final token = await _storageService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('Auth token not found for SignalR');
      }

      await _establishConnection(token);
      _connectionCompleter!.complete();
    } catch (e) {
      _logger.severe('Failed to connect to SignalR: $e');
      if (!_connectionCompleter!.isCompleted) {
        _connectionCompleter!.completeError(e);
      }
      rethrow;
    }
  }

  // ✅ Fix 4: بهبود connection establishment
  Future<void> _establishConnection(String token) async {
    _setConnectionStatus(SignalRConnectionStatus.connecting);

    try {
      _logger.info(
        'Establishing SignalR connection to ${SignalRConstants.hubUrl}',
      );

      _hubConnection = HubConnectionBuilder()
          .withUrl(
            '${SignalRConstants.hubUrl}?access_token=$token',
            HttpConnectionOptions(
              logging: (level, message) =>
                  _logger.fine('SignalR Internal Log: $message'),
              transport: HttpTransportType.webSockets,
              skipNegotiation: true,
            ),
          )
          .withAutomaticReconnect(SignalRConstants.reconnectDelays)
          .build();

      _setupConnectionEventHandlers();

      if (_hubConnection != null) {
        final startFuture = _hubConnection!.start();
        if (startFuture != null) {
          await startFuture.timeout(SignalRConstants.connectionTimeout);
        }
      } else {
        throw Exception('HubConnection is null');
      }

      _setConnectionStatus(SignalRConnectionStatus.connected);
      _reconnectAttempts = 0;
      _registerServerToClientEventHandlers();
      _startHeartbeat();

      _logger.info('SignalR connection established successfully');
    } catch (e) {
      _setConnectionStatus(SignalRConnectionStatus.disconnected);
      await _cleanup();
      throw Exception('Failed to establish SignalR connection: $e');
    }
  }

  // ✅ Fix 5: بهبود connection event handlers
  void _setupConnectionEventHandlers() {
    if (_hubConnection == null) return;

    _hubConnection!.onclose((error) {
      _logger.warning('SignalR connection closed. Error: $error');
      _setConnectionStatus(SignalRConnectionStatus.disconnected);
      _stopHeartbeat();

      // اگر خطا غیرمنتظره بود، تلاش برای reconnect کن
      if (error != null &&
          _reconnectAttempts < SignalRConstants.maxReconnectAttempts) {
        _scheduleReconnect();
      }
    });

    _hubConnection!.onreconnecting((error) {
      _logger.info('SignalR is reconnecting... Error: $error');
      _setConnectionStatus(SignalRConnectionStatus.reconnecting);
      _stopHeartbeat();
    });

    _hubConnection!.onreconnected((connectionId) {
      _logger.info(
        'SignalR has reconnected successfully. Connection ID: $connectionId',
      );
      _setConnectionStatus(SignalRConnectionStatus.connected);
      _reconnectAttempts = 0;
      _startHeartbeat();
    });
  }

  // ✅ Fix 6: بهبود server event handlers
  void _registerServerToClientEventHandlers() {
    if (!isConnected || _hubConnection == null) {
      _logger.warning('Cannot register server events: SignalR not connected.');
      return;
    }

    _logger.info('Registering server-to-client event handlers...');

    // ✅ ReceiveMessage handler
    _hubConnection!.on('ReceiveMessage', (List<Object?>? arguments) {
      try {
        if (arguments != null && arguments.isNotEmpty) {
          final messageData = arguments[0] as Map<String, dynamic>?;
          if (messageData != null) {
            _logger.info('Message received via SignalR: ${messageData['id']}');
            final message = MessageModel.fromJson(messageData);
            _newMessageReceivedController.add(message);
          }
        }
      } catch (e, stack) {
        _logger.severe('Error parsing received message: $e', e, stack);
      }
    });

    // ✅ MessageUpdated handler
    _hubConnection!.on('MessageUpdated', (List<Object?>? arguments) {
      try {
        if (arguments != null && arguments.isNotEmpty) {
          final messageData = arguments[0] as Map<String, dynamic>?;
          if (messageData != null) {
            _logger.info('Message updated via SignalR: ${messageData['id']}');
            final message = MessageModel.fromJson(messageData);
            _messageUpdatedController.add(message);
          }
        }
      } catch (e, stack) {
        _logger.severe('Error parsing updated message: $e', e, stack);
      }
    });

    // ✅ MessageCorrelationConfirmation handler
    _hubConnection!.on('MessageCorrelationConfirmation', (
      List<Object?>? arguments,
    ) {
      try {
        if (arguments != null && arguments.length >= 2) {
          final correlationId = arguments[0] as String?;
          final confirmedMessageData = arguments[1] as Map<String, dynamic>?;

          if (correlationId != null && confirmedMessageData != null) {
            _logger.info('Message confirmation received: $correlationId');
            final confirmedMessage = MessageModel.fromJson(
              confirmedMessageData,
            );
            final confirmation = MessageConfirmation(
              correlationId: correlationId,
              confirmedMessage: confirmedMessage,
            );
            _messageConfirmationController.add(confirmation);
          }
        }
      } catch (e, stack) {
        _logger.severe('Error parsing message confirmation: $e', e, stack);
      }
    });

    // ✅ UserStatusChanged handler
    _hubConnection!.on('UserStatusChanged', (List<Object?>? arguments) {
      try {
        if (arguments != null && arguments.isNotEmpty) {
          final statusData = arguments[0] as Map<String, dynamic>?;
          if (statusData != null) {
            _logger.fine('User status changed: ${statusData['userId']}');
            _userStatusChangedController.add(statusData);
          }
        }
      } catch (e, stack) {
        _logger.severe('Error parsing user status change: $e', e, stack);
      }
    });

    // ✅ MessageStatusChanged handler
    _hubConnection!.on('MessageStatusChanged', (List<Object?>? arguments) {
      try {
        if (arguments != null && arguments.isNotEmpty) {
          final statusData = arguments[0] as Map<String, dynamic>?;
          if (statusData != null) {
            _logger.fine('Message status changed: ${statusData['messageId']}');
            _messageStatusChangedController.add(statusData);
          }
        }
      } catch (e, stack) {
        _logger.severe('Error parsing message status change: $e', e, stack);
      }
    });

    // ✅ UserTyping handler
    _hubConnection!.on('UserTyping', (List<Object?>? arguments) {
      try {
        if (arguments != null && arguments.isNotEmpty) {
          final typingData = arguments[0] as Map<String, dynamic>?;
          if (typingData != null) {
            _logger.fine('User typing notification: ${typingData['userId']}');
            _userTypingController.add(typingData);
          }
        }
      } catch (e, stack) {
        _logger.severe('Error parsing user typing notification: $e', e, stack);
      }
    });

    _logger.info('All SignalR event handlers registered successfully');
  }

  // ✅ Fix 7: Heartbeat mechanism
  void _startHeartbeat() {
    _stopHeartbeat();
    _heartbeatTimer = Timer.periodic(SignalRConstants.heartbeatInterval, (
      timer,
    ) {
      _checkConnection();
    });
    _logger.fine('Heartbeat started');
  }

  void _stopHeartbeat() {
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _logger.fine('Heartbeat stopped');
  }

  void _checkConnection() async {
    if (!isConnected) {
      _logger.warning('Connection lost during heartbeat check');
      _stopHeartbeat();
      if (_reconnectAttempts < SignalRConstants.maxReconnectAttempts) {
        _scheduleReconnect();
      }
    }
  }

  // ✅ Fix 8: بهبود reconnection logic
  void _scheduleReconnect() {
    if (_reconnectTimer != null) return; // Already scheduled

    _reconnectAttempts++;
    final delay = Duration(
      milliseconds:
          SignalRConstants.reconnectDelays[(_reconnectAttempts - 1).clamp(
            0,
            SignalRConstants.reconnectDelays.length - 1,
          )],
    );

    _logger.info(
      'Scheduling reconnect attempt $_reconnectAttempts in ${delay.inMilliseconds}ms',
    );

    _reconnectTimer = Timer(delay, () async {
      _reconnectTimer = null;

      if (_reconnectAttempts <= SignalRConstants.maxReconnectAttempts) {
        try {
          await connect();
        } catch (e) {
          _logger.warning('Reconnect attempt $_reconnectAttempts failed: $e');
          if (_reconnectAttempts < SignalRConstants.maxReconnectAttempts) {
            _scheduleReconnect();
          } else {
            _logger.severe('Max reconnection attempts reached. Giving up.');
            _setConnectionStatus(SignalRConnectionStatus.disconnected);
          }
        }
      }
    });
  }

  // ✅ Fix 9: بهبود disconnect method
  Future<void> disconnect() async {
    _logger.info('Disconnecting SignalR...');

    _stopHeartbeat();
    _reconnectTimer?.cancel();
    _reconnectTimer = null;

    if (_connectionCompleter != null && !_connectionCompleter!.isCompleted) {
      _connectionCompleter!.completeError(
        Exception("Connection explicitly disconnected."),
      );
    }

    await _cleanup();
    _setConnectionStatus(SignalRConnectionStatus.disconnected);
    _logger.info('SignalR disconnected successfully');
  }

  Future<void> _cleanup() async {
    try {
      if (_hubConnection != null) {
        await _hubConnection!.stop();
        _hubConnection = null;
      }
    } catch (e) {
      _logger.warning('Error during connection cleanup: $e');
    }

    _connectionCompleter = null;
    _reconnectAttempts = 0;
  }

  void _setConnectionStatus(SignalRConnectionStatus status) {
    if (_connectionStatus != status) {
      _connectionStatus = status;
      _connectionStatusController.add(status);
      _logger.info('SignalR connection status changed to: $status');
    }
  }

  // ✅ Fix 10: بهبود client methods با proper error handling

  Future<void> sendChatMessage(
    String chatId,
    String content,
    String correlationId,
  ) async {
    if (!isConnected || _hubConnection == null) {
      throw Exception('SignalR not connected');
    }

    try {
      await _hubConnection!
          .invoke('SendMessage', args: [chatId, content, correlationId])
          .timeout(Duration(seconds: 10));

      _logger.info('Message sent successfully: $correlationId');
    } catch (e) {
      _logger.severe('Error sending message: $e');
      throw Exception('Failed to send message: $e');
    }
  }

  Future<void> editMessage(int messageId, String newContent) async {
    if (!isConnected || _hubConnection == null) {
      throw Exception('SignalR not connected');
    }

    try {
      await _hubConnection!
          .invoke('EditMessage', args: [messageId, newContent])
          .timeout(Duration(seconds: 10));

      _logger.info('Message edit request sent: $messageId');
    } catch (e) {
      _logger.severe('Error editing message: $e');
      throw Exception('Failed to edit message: $e');
    }
  }

  Future<void> deleteMessage(int messageId) async {
    if (!isConnected || _hubConnection == null) {
      throw Exception('SignalR not connected');
    }

    try {
      await _hubConnection!
          .invoke('DeleteMessage', args: [messageId])
          .timeout(Duration(seconds: 10));

      _logger.info('Message delete request sent: $messageId');
    } catch (e) {
      _logger.severe('Error deleting message: $e');
      throw Exception('Failed to delete message: $e');
    }
  }

  Future<void> joinGroup(String chatId) async {
    if (!isConnected || _hubConnection == null) {
      throw Exception('SignalR not connected');
    }

    try {
      await _hubConnection!
          .invoke('JoinGroup', args: [chatId])
          .timeout(Duration(seconds: 10));

      _logger.info('Joined chat group: $chatId');
    } catch (e) {
      _logger.severe('Error joining group: $e');
      throw Exception('Failed to join chat group: $e');
    }
  }

  Future<void> leaveGroup(String chatId) async {
    if (!isConnected || _hubConnection == null) {
      throw Exception('SignalR not connected');
    }

    try {
      await _hubConnection!
          .invoke('LeaveGroup', args: [chatId])
          .timeout(Duration(seconds: 10));

      _logger.info('Left chat group: $chatId');
    } catch (e) {
      _logger.severe('Error leaving group: $e');
      throw Exception('Failed to leave chat group: $e');
    }
  }

  Future<void> leaveGroupChat(String chatId) async {
    if (!isConnected || _hubConnection == null) {
      throw Exception('SignalR not connected');
    }

    try {
      await _hubConnection!
          .invoke('LeaveGroupChat', args: [chatId])
          .timeout(Duration(seconds: 10));

      _logger.info('Left group chat: $chatId');
    } catch (e) {
      _logger.severe('Error leaving group chat: $e');
      throw Exception('Failed to leave group chat: $e');
    }
  }

  Future<void> markMultipleMessagesAsRead(
    String chatId,
    List<int> messageIds,
  ) async {
    if (!isConnected || _hubConnection == null) {
      throw Exception('SignalR not connected');
    }

    if (messageIds.isEmpty) return;

    try {
      await _hubConnection!
          .invoke('MarkMultipleMessagesAsRead', args: [chatId, messageIds])
          .timeout(Duration(seconds: 10));

      _logger.info(
        'Marked ${messageIds.length} messages as read in chat $chatId',
      );
    } catch (e) {
      _logger.severe('Error marking messages as read: $e');
      throw Exception('Failed to mark messages as read: $e');
    }
  }

  Future<void> notifyTyping(String chatId, bool isTyping) async {
    if (!isConnected || _hubConnection == null) {
      _logger.fine('Cannot notify typing: SignalR not connected');
      return;
    }

    try {
      await _hubConnection!
          .invoke('NotifyTyping', args: [chatId, isTyping])
          .timeout(Duration(seconds: 5));

      _logger.fine('Typing notification sent: $isTyping for chat $chatId');
    } catch (e) {
      _logger.fine('Error notifying typing (non-critical): $e');
      // این خطا critical نیست، پس exception نمی‌اندازیم
    }
  }

  // ✅ Fix 11: بهبود dispose method
  Future<void> dispose() async {
    _logger.info('Disposing SignalRService...');

    await disconnect();

    // Close all stream controllers
    await _connectionStatusController.close();
    await _newMessageReceivedController.close();
    await _messageUpdatedController.close();
    await _messageConfirmationController.close();
    await _userStatusChangedController.close();
    await _messageStatusChangedController.close();
    await _userTypingController.close();

    _logger.info('SignalRService disposed successfully');
  }

  // ✅ Debug and monitoring methods
  Map<String, dynamic> getConnectionInfo() {
    return {
      'status': _connectionStatus.toString(),
      'isConnected': isConnected,
      'reconnectAttempts': _reconnectAttempts,
      'hubConnectionState': _hubConnection?.state.toString() ?? 'null',
      'hasHeartbeat': _heartbeatTimer != null,
    };
  }

  void logConnectionInfo() {
    final info = getConnectionInfo();
    _logger.info('SignalR Connection Info: $info');
  }
}
