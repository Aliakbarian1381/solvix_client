// lib/src/app.dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solvix/src/app_bloc.dart';
import 'package:solvix/src/app_state.dart';
import 'package:solvix/src/core/api/chat/chat_service.dart';
import 'package:solvix/src/core/api/search_service.dart';
import 'package:solvix/src/core/api/user/user_service.dart';
import 'package:solvix/src/core/navigation/navigation_service.dart';
import 'package:solvix/src/core/network/notification_service.dart';
import 'package:solvix/src/core/network/signalr_service.dart';
import 'package:solvix/src/core/theme/theme_cubit.dart';
import 'package:solvix/src/features/auth/presentation/screens/auth_screen.dart';
import 'package:solvix/src/features/home/presentation/screens/home_screen.dart';

class App extends StatelessWidget {
  final UserService userService;
  final ChatService chatService;
  final SearchService searchService;
  final SignalRService signalRService;
  final NotificationService notificationService;

  const App({
    super.key,
    required this.userService,
    required this.chatService,
    required this.searchService,
    required this.signalRService,
    required this.notificationService,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeData>(
      builder: (context, theme) {
        return MaterialApp(
          navigatorKey: NavigationService.navigatorKey,
          debugShowCheckedModeBanner: false,
          title: 'Solvix Messenger',
          theme: theme,
          home: BlocBuilder<AppBloc, AppState>(
            builder: (context, state) {
              if (state is AppAuthenticated) {
                return MultiRepositoryProvider(
                  providers: [
                    RepositoryProvider.value(value: userService),
                    RepositoryProvider.value(value: chatService),
                    RepositoryProvider.value(value: searchService),
                    RepositoryProvider.value(value: signalRService),
                    RepositoryProvider.value(value: notificationService),
                  ],
                  child: const HomeScreen(),
                );
              }
              if (state is AppUnauthenticated) {
                return const AuthScreen();
              }
              return const Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(),
                      SizedBox(height: 16),
                      Text('در حال بارگذاری...'),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}
