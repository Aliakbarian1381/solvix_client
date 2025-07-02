import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:solvix/src/core/api/chat/chat_service.dart';
import 'package:solvix/src/core/api/user/user_service.dart';
import 'package:solvix/src/core/models/chat_model.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/core/navigation/navigation_service.dart';
import 'package:solvix/src/core/network/signalr_service.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_state.dart'
    as auth_states;
import 'package:solvix/src/features/chat/presentation/bloc/chat_messages_bloc.dart';
import 'package:solvix/src/features/chat/presentation/screens/chat_screen.dart';
import 'package:solvix/firebase_options.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

class NotificationService {
  final _firebaseMessaging = FirebaseMessaging.instance;
  final _logger = Logger('NotificationService');
  final UserService _userService;

  NotificationService(this._userService);

  Future<void> initialize() async {
    await _firebaseMessaging.requestPermission();

    final String? fcmToken;
    if (kIsWeb) {
      const vapidKey =
          "BH_su7VydHVTH0w1iNDD-W3adkD20Rbhy_6y501E2E9RFaghkSmAv20nsIhombLNtATGmvHzGiRX6CqO5EeHSkc";
      fcmToken = await _firebaseMessaging.getToken(vapidKey: vapidKey);
    } else {
      fcmToken = await _firebaseMessaging.getToken();
    }

    if (fcmToken != null) {
      _logger.info('Firebase Messaging Token: $fcmToken');
      try {
        await _userService.updateFcmToken(fcmToken);
        _logger.info('FCM Token successfully sent to server.');
      } catch (e) {
        _logger.severe('Failed to send FCM token to server: $e');
      }
    } else {
      _logger.warning('Could not get FCM token.');
    }

    _firebaseMessaging.onTokenRefresh.listen((newToken) async {
      _logger.info('FCM Token Refreshed: $newToken');
      try {
        await _userService.updateFcmToken(newToken);
        _logger.info('Refreshed FCM Token successfully sent to server.');
      } catch (e) {
        _logger.severe('Failed to send refreshed FCM token to server: $e');
      }
    });

    _setupInteractions();
  }

  void _setupInteractions() {
    FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
      _logger.info(
        'Notification tapped while app was in background/terminated.',
      );
      _handleMessageNavigation(message.data);
    });

    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      _logger.info('Got a message whilst in the foreground!');
      _logger.info('Message data: ${message.data}');

      if (message.notification != null) {
        _logger.info(
          'Message also contained a notification: ${message.notification}',
        );
      }
    });

    FirebaseMessaging.instance.getInitialMessage().then((
      RemoteMessage? message,
    ) {
      if (message != null) {
        _logger.info('App opened from terminated state via notification.');
        _handleMessageNavigation(message.data);
      }
    });
  }

  void _handleMessageNavigation(Map<String, dynamic> data) async {
    _logger.info('Handling navigation for data: $data');
    final type = data['type'];

    if (type == 'new_message') {
      final chatId = data['chatId'];
      if (chatId == null) {
        _logger.warning('Received new_message notification without a chatId.');
        return;
      }

      final context = NavigationService.navigatorKey.currentContext;
      if (context == null) {
        _logger.severe("Navigator context is null, cannot navigate.");
        return;
      }

      final authBloc = context.read<AuthBloc>();
      final currentUser = (authBloc.state is auth_states.AuthSuccess)
          ? (authBloc.state as auth_states.AuthSuccess).user
          : null;

      if (currentUser == null) {
        _logger.warning("Current user is null, cannot open chat.");
        return;
      }

      try {
        final chatService = context.read<ChatService>();
        final chats = await chatService.getUserChats();
        final ChatModel targetChat = chats.firstWhere((c) => c.id == chatId);

        NavigationService.navigatorKey.currentState?.push(
          MaterialPageRoute(
            builder: (ctx) => BlocProvider<ChatMessagesBloc>(
              create: (blocContext) => ChatMessagesBloc(
                blocContext.read<ChatService>(),
                blocContext.read<SignalRService>(),
                chatId: chatId,
                currentUserId: currentUser.id,
              ),
              child: ChatScreen(
                chatModel: targetChat,
                currentUser: currentUser,
              ),
            ),
          ),
        );
      } catch (e) {
        _logger.severe("Failed to fetch chat details for navigation: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('خطا در باز کردن چت: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }
}
