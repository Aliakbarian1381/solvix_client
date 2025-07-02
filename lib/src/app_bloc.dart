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

  late final StreamSubscription<auth_states.AuthState> _authSubscription;
  late final StreamSubscription<MessageModel> _newMessageSubscription;

  AppBloc(
    this._storageService,
    this._authBloc,
    this._signalRService,
    this._chatListBloc,
    this._notificationService,
  ) : super(AppInitial()) {
    on<AppStarted>(_onAppStarted);
    on<AppLoggedOut>(_onAppLoggedOut);

    _authSubscription = _authBloc.stream.listen(_onAuthStateChanged);

    _newMessageSubscription = _signalRService.onNewMessageReceived.listen((
      message,
    ) {
      _logger.info(
        'AppBloc: New message received via stream, refreshing chat list.',
      );
      _chatListBloc.add(FetchChatList());
    });
  }

  Future<void> _onAuthStateChanged(auth_states.AuthState state) async {
    if (state is auth_states.AuthSuccess) {
      try {
        _logger.info(
          "AppBloc: AuthSuccess detected. Updating token and connecting services...",
        );
        await _signalRService.connect();
        _logger.info("AppBloc: Services connected. Emitting AppAuthenticated.");
        emit(AppAuthenticated());
      } catch (e) {
        _logger.severe(
          "AppBloc: Critical setup failed after auth: $e. Logging out.",
        );
        add(AppLoggedOut());
      }
    } else if (state is auth_states.AuthFailure ||
        state is auth_states.AuthInitial) {
      if (this.state is AppAuthenticated) {
        _logger.info("AppBloc: AuthFailure/AuthInitial detected. Logging out.");
        add(AppLoggedOut());
      }
    }
  }

  Future<void> _onAppStarted(AppStarted event, Emitter<AppState> emit) async {
    final token = await _storageService.getToken();
    if (token != null && token.isNotEmpty) {
      _logger.info("AppBloc: Token found. Fetching current user.");
      _authBloc.add(auth_events.FetchCurrentUser());
    } else {
      _logger.info("AppBloc: No token found. Emitting AppUnauthenticated.");
      emit(AppUnauthenticated());
    }
  }

  Future<void> _onAppLoggedOut(
    AppLoggedOut event,
    Emitter<AppState> emit,
  ) async {
    _logger.info("AppBloc: Processing AppLoggedOut event.");
    await _storageService.deleteToken();
    await _signalRService.disconnect();
    _chatListBloc.add(ResetChatListState());
    _authBloc.add(auth_events.AuthReset());
    emit(AppUnauthenticated());
  }

  @override
  Future<void> close() {
    _authSubscription.cancel();
    _newMessageSubscription.cancel();
    return super.close();
  }
}
