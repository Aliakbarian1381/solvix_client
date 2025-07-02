import 'package:equatable/equatable.dart';
import 'package:solvix/src/core/models/user_model.dart';

enum NewChatStatus { initial, loading, success, failure }

class NewChatState extends Equatable {
  final NewChatStatus status;
  final List<UserModel> users; // می‌تواند کاربران آنلاین یا نتایج جستجو باشد
  final String errorMessage;
  final String currentQuery; // برای نگهداری متن جستجوی فعلی

  const NewChatState({
    this.status = NewChatStatus.initial,
    this.users = const <UserModel>[],
    this.errorMessage = '',
    this.currentQuery = '',
  });

  NewChatState copyWith({
    NewChatStatus? status,
    List<UserModel>? users,
    String? errorMessage,
    String? currentQuery,
  }) {
    return NewChatState(
      status: status ?? this.status,
      users: users ?? this.users,
      errorMessage: errorMessage ?? this.errorMessage,
      currentQuery: currentQuery ?? this.currentQuery,
    );
  }

  @override
  List<Object> get props => [status, users, errorMessage, currentQuery];
}
