import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solvix/src/app_bloc.dart';
import 'package:solvix/src/app_state.dart';
import 'package:solvix/src/core/navigation/navigation_service.dart'; // <-- این خط را اضافه کنید
import 'package:solvix/src/core/theme/theme_cubit.dart';
import 'package:solvix/src/features/auth/presentation/screens/auth_screen.dart';
import 'package:solvix/src/features/home/presentation/screens/home_screen.dart';

class App extends StatelessWidget {
  const App({super.key});

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
                return const HomeScreen();
              }
              if (state is AppUnauthenticated) {
                return const AuthScreen();
              }
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            },
          ),
        );
      },
    );
  }
}
