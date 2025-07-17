import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:solvix/src/core/api/group_service.dart';
import 'package:solvix/src/core/models/group_info_model.dart';

// Events
abstract class GroupMembersEvent extends Equatable {
  @override
  List<Object?> get props => [];
}

class LoadGroupMembers extends GroupMembersEvent {
  final String chatId;

  LoadGroupMembers(this.chatId);

  @override
  List<Object> get props => [chatId];
}

class AddMembers extends GroupMembersEvent {
  final String chatId;
  final List<int> userIds;

  AddMembers({required this.chatId, required this.userIds});

  @override
  List<Object> get props => [chatId, userIds];
}

class RemoveMember extends GroupMembersEvent {
  final String chatId;
  final int memberId;

  RemoveMember({required this.chatId, required this.memberId});

  @override
  List<Object> get props => [chatId, memberId];
}

class UpdateMemberRole extends GroupMembersEvent {
  final String chatId;
  final int memberId;
  final GroupRole newRole;

  UpdateMemberRole({
    required this.chatId,
    required this.memberId,
    required this.newRole,
  });

  @override
  List<Object> get props => [chatId, memberId, newRole];
}

class TransferOwnership extends GroupMembersEvent {
  final String chatId;
  final int newOwnerId;

  TransferOwnership({required this.chatId, required this.newOwnerId});

  @override
  List<Object> get props => [chatId, newOwnerId];
}

// States
abstract class GroupMembersState extends Equatable {
  @override
  List<Object?> get props => [];
}

class GroupMembersInitial extends GroupMembersState {}

class GroupMembersLoading extends GroupMembersState {}

class GroupMembersLoaded extends GroupMembersState {
  final List<GroupMemberModel> members;

  GroupMembersLoaded(this.members);

  @override
  List<Object> get props => [members];
}

class GroupMembersError extends GroupMembersState {
  final String message;

  GroupMembersError(this.message);

  @override
  List<Object> get props => [message];
}

class GroupMembersUpdated extends GroupMembersState {
  final String message;

  GroupMembersUpdated(this.message);

  @override
  List<Object> get props => [message];
}

// BLoC
class GroupMembersBloc extends Bloc<GroupMembersEvent, GroupMembersState> {
  final GroupService _groupService;

  GroupMembersBloc(this._groupService) : super(GroupMembersInitial()) {
    on<LoadGroupMembers>(_onLoadGroupMembers);
    on<AddMembers>(_onAddMembers);
    on<RemoveMember>(_onRemoveMember);
    on<UpdateMemberRole>(_onUpdateMemberRole);
    on<TransferOwnership>(_onTransferOwnership);
  }

  Future<void> _onLoadGroupMembers(
    LoadGroupMembers event,
    Emitter<GroupMembersState> emit,
  ) async {
    emit(GroupMembersLoading());
    try {
      final members = await _groupService.getGroupMembers(event.chatId);
      emit(GroupMembersLoaded(members));
    } catch (e) {
      emit(GroupMembersError('خطا در دریافت لیست اعضا: ${e.toString()}'));
    }
  }

  Future<void> _onAddMembers(
    AddMembers event,
    Emitter<GroupMembersState> emit,
  ) async {
    emit(GroupMembersLoading());
    try {
      final success = await _groupService.addMembers(
        event.chatId,
        event.userIds,
      );
      if (success) {
        emit(GroupMembersUpdated('اعضای جدید با موفقیت اضافه شدند'));
        add(LoadGroupMembers(event.chatId));
      } else {
        emit(GroupMembersError('خطا در اضافه کردن اعضای جدید'));
      }
    } catch (e) {
      emit(GroupMembersError('خطا در اضافه کردن اعضا: ${e.toString()}'));
    }
  }

  Future<void> _onRemoveMember(
    RemoveMember event,
    Emitter<GroupMembersState> emit,
  ) async {
    emit(GroupMembersLoading());
    try {
      final success = await _groupService.removeMember(
        event.chatId,
        event.memberId,
      );
      if (success) {
        emit(GroupMembersUpdated('عضو با موفقیت حذف شد'));
        add(LoadGroupMembers(event.chatId));
      } else {
        emit(GroupMembersError('خطا در حذف عضو'));
      }
    } catch (e) {
      emit(GroupMembersError('خطا در حذف عضو: ${e.toString()}'));
    }
  }

  Future<void> _onUpdateMemberRole(
    UpdateMemberRole event,
    Emitter<GroupMembersState> emit,
  ) async {
    emit(GroupMembersLoading());
    try {
      final success = await _groupService.updateMemberRole(
        event.chatId,
        event.memberId,
        event.newRole,
      );
      if (success) {
        emit(GroupMembersUpdated('نقش عضو با موفقیت تغییر کرد'));
        add(LoadGroupMembers(event.chatId));
      } else {
        emit(GroupMembersError('خطا در تغییر نقش عضو'));
      }
    } catch (e) {
      emit(GroupMembersError('خطا در تغییر نقش: ${e.toString()}'));
    }
  }

  Future<void> _onTransferOwnership(
    TransferOwnership event,
    Emitter<GroupMembersState> emit,
  ) async {
    emit(GroupMembersLoading());
    try {
      final success = await _groupService.transferOwnership(
        event.chatId,
        event.newOwnerId,
      );
      if (success) {
        emit(GroupMembersUpdated('مالکیت گروه با موفقیت منتقل شد'));
        add(LoadGroupMembers(event.chatId));
      } else {
        emit(GroupMembersError('خطا در انتقال مالکیت'));
      }
    } catch (e) {
      emit(GroupMembersError('خطا در انتقال مالکیت: ${e.toString()}'));
    }
  }
}
