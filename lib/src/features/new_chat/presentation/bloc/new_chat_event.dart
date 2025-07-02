import 'package:equatable/equatable.dart';

abstract class NewChatEvent extends Equatable {
  const NewChatEvent();

  @override
  List<Object> get props => [];
}

// برای بارگذاری اولیه کاربران آنلاین
class LoadOnlineUsers extends NewChatEvent {}

// برای جستجوی کاربران
class SearchUsersQueryChanged extends NewChatEvent {
  final String query;

  const SearchUsersQueryChanged(this.query);

  @override
  List<Object> get props => [query];
}
