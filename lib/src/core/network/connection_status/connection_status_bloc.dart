import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solvix/src/core/network/signalr_service.dart';

part 'connection_status_event.dart';

part 'connection_status_state.dart';

class ConnectionStatusBloc
    extends Bloc<ConnectionStatusEvent, ConnectionStatusState> {
  final SignalRService _signalRService;
  StreamSubscription? _signalRSubscription;
  StreamSubscription? _connectivitySubscription;

  ConnectionStatusBloc(this._signalRService)
    : super(const ConnectionStatusState()) {
    _signalRSubscription = _signalRService.connectionStatusStream.listen((
      status,
    ) {
      add(SignalRStatusUpdated(status));
    });

    _connectivitySubscription = Connectivity().onConnectivityChanged.listen((
      results,
    ) {
      if (results.isNotEmpty) {
        add(ConnectivityStatusUpdated(results.first));
      }
    });

    on<SignalRStatusUpdated>((event, emit) {
      emit(state.copyWith(signalRStatus: event.status));
    });

    on<ConnectivityStatusUpdated>((event, emit) {
      emit(state.copyWith(connectivityStatus: event.status));
    });
  }

  @override
  Future<void> close() {
    _signalRSubscription?.cancel();
    _connectivitySubscription?.cancel();
    return super.close();
  }
}
