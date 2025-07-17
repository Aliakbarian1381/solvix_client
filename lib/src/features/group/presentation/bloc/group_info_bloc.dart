import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:solvix/src/core/api/group_service.dart';
import 'package:solvix/src/core/models/group_info_model.dart';

// Events
abstract class GroupInfoEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadGroupInfo extends GroupInfoEvent {
  final String chatId;

  LoadGroupInfo(this.chatId);

  @override
  List<Object> get props => [chatId];
}

class UpdateGroupInfo extends GroupInfoEvent {
  final String chatId;
  final String? title;
  final String? description;

  UpdateGroupInfo({required this.chatId, this.title, this.description});

  @override
  List<Object?> get props => [chatId, title, description];
}

class UpdateGroupSettings extends GroupInfoEvent {
  final String chatId;
  final GroupSettingsModel settings;

  UpdateGroupSettings({required this.chatId, required this.settings});

  @override
  List<Object> get props => [chatId, settings];
}

class LeaveGroup extends GroupInfoEvent {
  final String chatId;

  LeaveGroup(this.chatId);

  @override
  List<Object> get props => [chatId];
}

class DeleteGroup extends GroupInfoEvent {
  final String chatId;

  DeleteGroup(this.chatId);

  @override
  List<Object> get props => [chatId];
}

// States
abstract class GroupInfoState extends Equatable {
  @override
  List<Object?> get props => [];
}

class GroupInfoInitial extends GroupInfoState {}

class GroupInfoLoading extends GroupInfoState {}

class GroupInfoLoaded extends GroupInfoState {
  final GroupInfoModel groupInfo;

  GroupInfoLoaded(this.groupInfo);

  @override
  List<Object> get props => [groupInfo];
}

class GroupInfoError extends GroupInfoState {
  final String message;

  GroupInfoError(this.message);

  @override
  List<Object> get props => [message];
}

class GroupInfoUpdated extends GroupInfoState {
  final String message;

  GroupInfoUpdated(this.message);

  @override
  List<Object> get props => [message];
}

class GroupLeft extends GroupInfoState {}

class GroupDeleted extends GroupInfoState {}

// BLoC
class GroupInfoBloc extends Bloc<GroupInfoEvent, GroupInfoState> {
  final GroupService _groupService;

  GroupInfoBloc(this._groupService) : super(GroupInfoInitial()) {
    on<LoadGroupInfo>(_onLoadGroupInfo);
    on<UpdateGroupInfo>(_onUpdateGroupInfo);
    on<UpdateGroupSettings>(_onUpdateGroupSettings);
    on<LeaveGroup>(_onLeaveGroup);
    on<DeleteGroup>(_onDeleteGroup);
  }

  Future<void> _onLoadGroupInfo(
    LoadGroupInfo event,
    Emitter<GroupInfoState> emit,
  ) async {
    emit(GroupInfoLoading());
    try {
      final groupInfo = await _groupService.getGroupInfo(event.chatId);
      if (groupInfo != null) {
        emit(GroupInfoLoaded(groupInfo));
      } else {
        emit(GroupInfoError('گروه یافت نشد'));
      }
    } catch (e) {
      emit(GroupInfoError('خطا در دریافت اطلاعات گروه: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateGroupInfo(
    UpdateGroupInfo event,
    Emitter<GroupInfoState> emit,
  ) async {
    emit(GroupInfoLoading());
    try {
      final success = await _groupService.updateGroupInfo(
        event.chatId,
        event.title,
        event.description,
      );
      if (success) {
        emit(GroupInfoUpdated('اطلاعات گروه با موفقیت به‌روزرسانی شد'));
        // بارگذاری مجدد اطلاعات
        add(LoadGroupInfo(event.chatId));
      } else {
        emit(GroupInfoError('خطا در به‌روزرسانی اطلاعات گروه'));
      }
    } catch (e) {
      emit(GroupInfoError('خطا در به‌روزرسانی: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateGroupSettings(
    UpdateGroupSettings event,
    Emitter<GroupInfoState> emit,
  ) async {
    emit(GroupInfoLoading());
    try {
      final success = await _groupService.updateGroupSettings(
        event.chatId,
        event.settings,
      );
      if (success) {
        emit(GroupInfoUpdated('تنظیمات گروه با موفقیت به‌روزرسانی شد'));
        add(LoadGroupInfo(event.chatId));
      } else {
        emit(GroupInfoError('خطا در به‌روزرسانی تنظیمات'));
      }
    } catch (e) {
      emit(GroupInfoError('خطا در به‌روزرسانی تنظیمات: ${e.toString()}'));
    }
  }

  Future<void> _onLeaveGroup(
    LeaveGroup event,
    Emitter<GroupInfoState> emit,
  ) async {
    emit(GroupInfoLoading());
    try {
      final success = await _groupService.leaveGroup(event.chatId);
      if (success) {
        emit(GroupLeft());
      } else {
        emit(GroupInfoError('خطا در خروج از گروه'));
      }
    } catch (e) {
      emit(GroupInfoError('خطا در خروج از گروه: ${e.toString()}'));
    }
  }

  Future<void> _onDeleteGroup(
    DeleteGroup event,
    Emitter<GroupInfoState> emit,
  ) async {
    emit(GroupInfoLoading());
    try {
      final success = await _groupService.deleteGroup(event.chatId);
      if (success) {
        emit(GroupDeleted());
      } else {
        emit(GroupInfoError('خطا در حذف گروه'));
      }
    } catch (e) {
      emit(GroupInfoError('خطا در حذف گروه: ${e.toString()}'));
    }
  }
}
