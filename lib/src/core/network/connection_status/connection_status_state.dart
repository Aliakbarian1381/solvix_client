part of 'connection_status_bloc.dart';

class ConnectionStatusState extends Equatable {
  final SignalRConnectionStatus signalRStatus;
  final ConnectivityResult connectivityStatus;

  const ConnectionStatusState({
    this.signalRStatus = SignalRConnectionStatus.Disconnected,
    this.connectivityStatus = ConnectivityResult.none,
  });

  // متد copyWith برای راحتی کار
  ConnectionStatusState copyWith({
    SignalRConnectionStatus? signalRStatus,
    ConnectivityResult? connectivityStatus,
  }) {
    return ConnectionStatusState(
      signalRStatus: signalRStatus ?? this.signalRStatus,
      connectivityStatus: connectivityStatus ?? this.connectivityStatus,
    );
  }

  @override
  List<Object> get props => [signalRStatus, connectivityStatus];
}
