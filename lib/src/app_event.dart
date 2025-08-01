// lib/src/app_event.dart
import 'package:equatable/equatable.dart';

abstract class AppEvent extends Equatable {
  const AppEvent();

  @override
  List<Object?> get props => [];
}

class AppStarted extends AppEvent {
  const AppStarted();

  @override
  String toString() => 'AppStarted';
}

class AppLoggedOut extends AppEvent {
  final String? reason;

  const AppLoggedOut({this.reason});

  @override
  List<Object?> get props => [reason];

  @override
  String toString() =>
      'AppLoggedOut${reason != null ? '(reason: $reason)' : ''}';
}

// ✅ Fix 1: اضافه کردن Force Logout برای حالات اضطراری
class AppForceLogout extends AppEvent {
  final String reason;

  const AppForceLogout({required this.reason});

  @override
  List<Object> get props => [reason];

  @override
  String toString() => 'AppForceLogout(reason: $reason)';
}

// ✅ Fix 2: اضافه کردن Retry Connection
class AppRetryConnection extends AppEvent {
  const AppRetryConnection();

  @override
  String toString() => 'AppRetryConnection';
}

// ✅ Fix 3: اضافه کردن App Pause/Resume برای lifecycle management
class AppPaused extends AppEvent {
  const AppPaused();

  @override
  String toString() => 'AppPaused';
}

class AppResumed extends AppEvent {
  const AppResumed();

  @override
  String toString() => 'AppResumed';
}

// ✅ Fix 4: اضافه کردن Network Status Change
class AppNetworkStatusChanged extends AppEvent {
  final bool isConnected;

  const AppNetworkStatusChanged({required this.isConnected});

  @override
  List<Object> get props => [isConnected];

  @override
  String toString() => 'AppNetworkStatusChanged(isConnected: $isConnected)';
}
