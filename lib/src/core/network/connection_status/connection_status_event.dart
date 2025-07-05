part of 'connection_status_bloc.dart';

abstract class ConnectionStatusEvent extends Equatable {
  const ConnectionStatusEvent();

  @override
  List<Object> get props => [];
}

class SignalRStatusUpdated extends ConnectionStatusEvent {
  final SignalRConnectionStatus status;

  const SignalRStatusUpdated(this.status);

  @override
  List<Object> get props => [status];
}

class ConnectivityStatusUpdated extends ConnectionStatusEvent {
  final ConnectivityResult status;

  const ConnectivityStatusUpdated(this.status);

  @override
  List<Object> get props => [status];
}
