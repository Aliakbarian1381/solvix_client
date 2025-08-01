// lib/src/app_bloc.dart
import 'dart:async';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:solvix/src/core/models/message_model.dart';
import 'package:solvix/src/core/network/notification_service.dart';
import 'package:solvix/src/core/network/signalr_service.dart';
import 'package:solvix/src/core/services/storage_service.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_event.dart'
    as auth_events;
import 'package:solvix/src/features/auth/presentation/bloc/auth_state.dart'
    as auth_states;
import 'package:solvix/src/features/home/presentation/bloc/chat_list_bloc.dart';
import 'app_event.dart';
import 'app_state.dart';

class AppBloc extends Bloc<AppEvent, AppState> {
  final StorageService _storageService;
  final AuthBloc _authBloc;
  final SignalRService _signalRService;
  final ChatListBloc _chatListBloc;
  final NotificationService _notificationService;
  final Logger _logger = Logger('AppBloc');

  // ✅ Fix 1: بهتر مدیریت subscriptions
  StreamSubscription<auth_states.AuthState>? _authSubscription;
  StreamSubscription<MessageModel>? _newMessageSubscription;
  StreamSubscription<SignalRConnectionStatus>? _connectionStatusSubscription;

  // ✅ Fix 2: اضافه کردن state tracking
  bool _isInitializing = false;
  bool _isAuthenticating = false;
  Timer? _authTimeoutTimer;

  static const Duration _authTimeout = Duration(seconds: 30);

  AppBloc(
    this._storageService,
    this._authBloc,
    this._signalRService,
    this._chatListBloc,
    this._notificationService,
  ) : super(AppInitial()) {
    // Event handlers
    on<AppStarted>(_onAppStarted);
    on<AppLoggedOut>(_onAppLoggedOut);
    on<AppForceLogout>(_onAppForceLogout);
    on<AppRetryConnection>(_onAppRetryConnection);

    _setupSubscriptions();
    _logger.info('AppBloc initialized');
  }

  // ✅ Fix 3: بهتر setup subscriptions
  void _setupSubscriptions() {
    try {
      // Auth state changes
      _authSubscription = _authBloc.stream.listen(
        _onAuthStateChanged,
        onError: (error, stack) {
          _logger.severe('Error in auth subscription: $error', error, stack);
          add(AppForceLogout(reason: 'Auth stream error: $error'));
        },
        cancelOnError: false,
      );

      // New messages
      _newMessageSubscription = _signalRService.onNewMessageReceived.listen(
        (message) {
          _logger.info('New message received, refreshing chat list');
          _chatListBloc.add(FetchChatList());
        },
        onError: (error, stack) {
          _logger.warning(
            'Error in new message subscription: $error',
            error,
            stack,
          );
        },
        cancelOnError: false,
      );

      // SignalR connection status
      _connectionStatusSubscription = _signalRService.connectionStatus.listen(
        _onSignalRConnectionStatusChanged,
        onError: (error, stack) {
          _logger.warning(
            'Error in SignalR status subscription: $error',
            error,
            stack,
          );
        },
        cancelOnError: false,
      );

      _logger.info('All subscriptions setup successfully');
    } catch (e, stack) {
      _logger.severe('Error setting up subscriptions: $e', e, stack);
    }
  }

  // ✅ Fix 4: بهتر auth state handling
  Future<void> _onAuthStateChanged(auth_states.AuthState authState) async {
    if (isClosed) return;

    _logger.info('Auth state changed: ${authState.runtimeType}');

    try {
      if (authState is auth_states.AuthSuccess) {
        await _handleAuthSuccess(authState);
      } else if (authState is auth_states.AuthFailure) {
        await _handleAuthFailure(authState);
      } else if (authState is auth_states.AuthInitial) {
        await _handleAuthInitial();
      } else if (authState is auth_states.AuthLoading) {
        _handleAuthLoading();
      }
    } catch (e, stack) {
      _logger.severe('Error handling auth state change: $e', e, stack);
      add(AppForceLogout(reason: 'Auth state handling error: $e'));
    }
  }

  // ✅ Fix 5: بهتر SignalR status handling
  void _onSignalRConnectionStatusChanged(SignalRConnectionStatus status) {
    if (isClosed) return;

    _logger.info('SignalR connection status: $status');

    // اگر authenticated هستیم ولی SignalR disconnect شده، سعی کن دوباره وصل شو
    if (state is AppAuthenticated &&
        status == SignalRConnectionStatus.disconnected &&
        !_isAuthenticating) {
      _logger.warning(
        'SignalR disconnected while authenticated, attempting reconnect',
      );
      add(AppRetryConnection());
    }
  }

  // ✅ Fix 6: بهبود app started
  Future<void> _onAppStarted(AppStarted event, Emitter<AppState> emit) async {
    if (_isInitializing) {
      _logger.warning('App already initializing, ignoring start event');
      return;
    }

    _isInitializing = true;
    _logger.info('App starting...');

    try {
      // بررسی وجود token
      final token = await _storageService.getToken();

      if (token != null && token.isNotEmpty) {
        _logger.info('Token found, attempting authentication');
        _startAuthTimeout();
        _authBloc.add(auth_events.FetchCurrentUser());
      } else {
        _logger.info('No token found, showing login');
        emit(AppUnauthenticated());
      }
    } catch (e, stack) {
      _logger.severe('Error during app start: $e', e, stack);
      emit(AppUnauthenticated());
    } finally {
      _isInitializing = false;
    }
  }

  // ✅ Fix 7: بهبود logout
  Future<void> _onAppLoggedOut(
    AppLoggedOut event,
    Emitter<AppState> emit,
  ) async {
    await _performLogout(emit, reason: event.reason);
  }

  Future<void> _onAppForceLogout(
    AppForceLogout event,
    Emitter<AppState> emit,
  ) async {
    _logger.warning('Force logout requested: ${event.reason}');
    await _performLogout(emit, reason: event.reason, isForced: true);
  }

  // ✅ Fix 8: اضافه کردن retry connection
  Future<void> _onAppRetryConnection(
    AppRetryConnection event,
    Emitter<AppState> emit,
  ) async {
    if (state is! AppAuthenticated) {
      _logger.warning('Cannot retry connection: not authenticated');
      return;
    }

    try {
      _logger.info('Retrying SignalR connection...');

      // اول disconnect کن
      await _signalRService.disconnect();

      // کمی صبر کن
      await Future.delayed(Duration(seconds: 1));

      // دوباره وصل شو
      await _signalRService.connect();

      _logger.info('SignalR reconnection successful');
    } catch (e, stack) {
      _logger.severe('Error retrying connection: $e', e, stack);
      // اگر connection retry نشد، لاگ کن ولی logout نکن
    }
  }

  // ✅ Helper methods

  Future<void> _handleAuthSuccess(auth_states.AuthSuccess authState) async {
    _cancelAuthTimeout();
    _isAuthenticating = true;

    try {
      _logger.info('Authentication successful, setting up services...');

      // اتصال به SignalR
      await _signalRService.connect();

      // Initialize notifications
      await _notificationService.initialize();

      // Fetch initial data
      _chatListBloc.add(FetchChatList());

      _logger.info('All services initialized successfully');
      emit(AppAuthenticated());
    } catch (e, stack) {
      _logger.severe('Critical setup failed after auth: $e', e, stack);
      add(AppForceLogout(reason: 'Service setup failed: $e'));
    } finally {
      _isAuthenticating = false;
    }
  }

  Future<void> _handleAuthFailure(auth_states.AuthFailure authState) async {
    _cancelAuthTimeout();
    _isAuthenticating = false;

    if (state is AppAuthenticated) {
      _logger.info('Auth failure detected while authenticated, logging out');
      add(AppLoggedOut(reason: 'Authentication failed: ${authState.error}'));
    } else {
      _logger.info('Auth failure during login attempt');
      emit(AppUnauthenticated());
    }
  }

  Future<void> _handleAuthInitial() async {
    _cancelAuthTimeout();
    _isAuthenticating = false;

    if (state is AppAuthenticated) {
      _logger.info('Auth reset detected while authenticated, logging out');
      add(AppLoggedOut(reason: 'Authentication reset'));
    }
  }

  void _handleAuthLoading() {
    _isAuthenticating = true;
    _logger.fine('Authentication in progress...');
  }

  Future<void> _performLogout(
    Emitter<AppState> emit, {
    String? reason,
    bool isForced = false,
  }) async {
    _logger.info(
      'Performing logout${reason != null ? ' - Reason: $reason' : ''}',
    );

    _cancelAuthTimeout();
    _isAuthenticating = false;

    try {
      // 1. Clear storage
      await _storageService.deleteToken();
      _logger.fine('Token cleared from storage');

      // 2. Disconnect SignalR
      await _signalRService.disconnect();
      _logger.fine('SignalR disconnected');

      // 3. Reset chat list
      _chatListBloc.add(ResetChatListState());
      _logger.fine('Chat list reset');

      // 4. Reset auth bloc (only if not forced to avoid loops)
      if (!isForced) {
        _authBloc.add(auth_events.AuthReset());
        _logger.fine('Auth bloc reset');
      }

      // 5. Emit unauthenticated state
      emit(AppUnauthenticated());
      _logger.info('Logout completed successfully');
    } catch (e, stack) {
      _logger.severe('Error during logout: $e', e, stack);
      // حتی در صورت خطا، state رو unauthenticated کن
      emit(AppUnauthenticated());
    }
  }

  void _startAuthTimeout() {
    _cancelAuthTimeout();
    _authTimeoutTimer = Timer(_authTimeout, () {
      if (_isAuthenticating || _isInitializing) {
        _logger.warning('Authentication timeout reached');
        add(AppForceLogout(reason: 'Authentication timeout'));
      }
    });
  }

  void _cancelAuthTimeout() {
    _authTimeoutTimer?.cancel();
    _authTimeoutTimer = null;
  }

  // ✅ Fix 9: بهبود close method
  @override
  Future<void> close() async {
    _logger.info('Closing AppBloc...');

    // Cancel timers
    _cancelAuthTimeout();

    // Cancel subscriptions
    await _authSubscription?.cancel();
    await _newMessageSubscription?.cancel();
    await _connectionStatusSubscription?.cancel();

    // Clear references
    _authSubscription = null;
    _newMessageSubscription = null;
    _connectionStatusSubscription = null;

    _logger.info('AppBloc closed successfully');
    return super.close();
  }

  // ✅ Debug and monitoring methods
  Map<String, dynamic> getDebugInfo() {
    return {
      'currentState': state.runtimeType.toString(),
      'isInitializing': _isInitializing,
      'isAuthenticating': _isAuthenticating,
      'hasAuthTimeout': _authTimeoutTimer != null,
      'subscriptionsActive': {
        'auth': _authSubscription != null,
        'messages': _newMessageSubscription != null,
        'signalr': _connectionStatusSubscription != null,
      },
      'signalrStatus': _signalRService.currentStatus.toString(),
      'signalrConnected': _signalRService.isConnected,
    };
  }

  void logDebugInfo() {
    final info = getDebugInfo();
    _logger.info('AppBloc Debug Info: $info');
  }

  // ✅ Public methods for manual control
  void forceLogout([String? reason]) {
    add(AppForceLogout(reason: reason ?? 'Manual logout'));
  }

  void retryConnection() {
    add(AppRetryConnection());
  }

  bool get isAuthenticated => state is AppAuthenticated;

  bool get isInitializing => _isInitializing;

  bool get isAuthenticating => _isAuthenticating;
}
