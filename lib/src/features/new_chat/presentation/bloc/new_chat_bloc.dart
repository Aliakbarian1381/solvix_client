import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solvix/src/core/api/user/user_service.dart';
import 'new_chat_event.dart';
import 'new_chat_state.dart';
import 'package:rxdart/rxdart.dart'; // برای debounce کردن جستجو

class NewChatBloc extends Bloc<NewChatEvent, NewChatState> {
  final UserService _userService;

  NewChatBloc(this._userService) : super(const NewChatState()) {
    on<LoadOnlineUsers>(_onLoadOnlineUsers);
    on<SearchUsersQueryChanged>(
      _onSearchUsersQueryChanged,
      // از debounce استفاده می‌کنیم تا با هر تغییر حرف در جستجو، فوراً API صدا زده نشود
      // بلکه پس از یک وقفه کوتاه (مثلا 500 میلی‌ثانیه) اگر کاربر تایپ جدیدی نکرد، جستجو انجام شود.
      transformer: (events, mapper) => events
          .debounceTime(const Duration(milliseconds: 500))
          .asyncExpand(mapper),
    );
  }

  Future<void> _onLoadOnlineUsers(
    LoadOnlineUsers event,
    Emitter<NewChatState> emit,
  ) async {
    emit(
      state.copyWith(status: NewChatStatus.loading, currentQuery: ''),
    ); // کوئری را خالی می‌کنیم
    try {
      final users = await _userService.getOnlineUsers();
      emit(state.copyWith(status: NewChatStatus.success, users: users));
    } catch (e) {
      emit(
        state.copyWith(
          status: NewChatStatus.failure,
          errorMessage: e.toString().replaceFirst("Exception: ", ""),
        ),
      );
    }
  }

  Future<void> _onSearchUsersQueryChanged(
    SearchUsersQueryChanged event,
    Emitter<NewChatState> emit,
  ) async {
    emit(
      state.copyWith(status: NewChatStatus.loading, currentQuery: event.query),
    );
    if (event.query.isEmpty) {
      // اگر جستجو خالی شد، دوباره کاربران آنلاین را نشان بده (یا لیست خالی اگر نمی‌خواهیم)
      add(
        LoadOnlineUsers(),
      ); // یا emit(state.copyWith(status: NewChatStatus.success, users: []));
      return;
    }
    try {
      final users = await _userService.searchUsers(event.query);
      emit(state.copyWith(status: NewChatStatus.success, users: users));
    } catch (e) {
      emit(
        state.copyWith(
          status: NewChatStatus.failure,
          errorMessage: e.toString().replaceFirst("Exception: ", ""),
        ),
      );
    }
  }
}
