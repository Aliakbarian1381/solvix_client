import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:solvix/src/app.dart';
import 'package:solvix/src/app_bloc.dart';
import 'package:solvix/src/app_event.dart';
import 'package:solvix/src/core/api/auth_service.dart';
import 'package:solvix/src/core/api/chat/chat_service.dart';
import 'package:solvix/src/core/api/search_service.dart';
import 'package:solvix/src/core/api/user/user_service.dart';
import 'package:solvix/src/core/models/chat_model.dart';
import 'package:solvix/src/core/models/client_message_status.dart';
import 'package:solvix/src/core/models/message_model.dart';
import 'package:dio/dio.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/core/network/connection_status/connection_status_bloc.dart';
import 'package:solvix/src/core/network/notification_service.dart';
import 'package:solvix/src/core/network/signalr_service.dart';
import 'package:solvix/src/core/services/storage_service.dart';
import 'package:solvix/src/core/theme/theme_cubit.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:solvix/src/features/contacts/presentation/bloc/contacts_bloc.dart';
import 'package:solvix/src/features/home/presentation/bloc/chat_list_bloc.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'firebase_options.dart';
import 'package:hive_flutter/hive_flutter.dart';

@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print("Handling a background message: ${message.messageId}");
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  Hive.registerAdapter(MessageModelAdapter());
  Hive.registerAdapter(ChatModelAdapter());
  Hive.registerAdapter(UserModelAdapter());
  Hive.registerAdapter(ClientMessageStatusAdapter());

  await Hive.openBox<ChatModel>('chats');
  await Hive.openBox<MessageModel>('messages');

  await Hive.openBox<UserModel>('users');
  await Hive.openBox<UserModel>('synced_contacts');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  tz.initializeTimeZones();
  final tehranLocation = tz.getLocation('Asia/Tehran');
  tz.setLocalLocation(tehranLocation);

  await initializeDateFormatting('fa_IR', null);

  final storageService = StorageService();
  final authService = AuthService();
  final signalRService = SignalRService();
  final chatService = ChatService();
  final dio = Dio();
  final userService = UserService(dio, storageService);
  final searchService = SearchService();
  final notificationService = NotificationService(userService);

  final authBloc = AuthBloc(authService, storageService);
  final chatListBloc = ChatListBloc(chatService);
  final contactsBloc = ContactsBloc(userService, chatService);

  runApp(
    MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: storageService),
        RepositoryProvider.value(value: authService),
        RepositoryProvider.value(value: signalRService),
        RepositoryProvider.value(value: chatService),
        RepositoryProvider.value(value: userService),
        RepositoryProvider.value(value: searchService),
        RepositoryProvider.value(value: notificationService),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider.value(value: authBloc),
          BlocProvider.value(value: chatListBloc),
          BlocProvider.value(value: contactsBloc),
          BlocProvider<ThemeCubit>(create: (context) => ThemeCubit()),
          BlocProvider<ConnectionStatusBloc>(
            create: (context) =>
                ConnectionStatusBloc(context.read<SignalRService>()),
            lazy: false,
          ),
          BlocProvider<AppBloc>(
            create: (context) => AppBloc(
              context.read<StorageService>(),
              context.read<AuthBloc>(),
              context.read<SignalRService>(),
              context.read<ChatListBloc>(),
              context.read<NotificationService>(),
            )..add(AppStarted()),
          ),
        ],
        child: const App(),
      ),
    ),
  );
}
