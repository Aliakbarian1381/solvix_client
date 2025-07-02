import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:solvix/src/core/api/user/user_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/models/user_model.dart';

part 'contacts_event.dart';

part 'contacts_state.dart';

class ContactsBloc extends Bloc<ContactsEvent, ContactsState> {
  final UserService _userService;

  ContactsBloc(this._userService) : super(const ContactsState()) {
    on<ContactsProcessStarted>(_onContactsProcessStarted);
  }

  Future<void> _onContactsProcessStarted(
    ContactsProcessStarted event,
    Emitter<ContactsState> emit,
  ) async {
    emit(state.copyWith(status: ContactsStatus.loading));

    if (kIsWeb) {
      try {
       //todo اینجا باید سیستم گرفتم مخاطبین از دیتابیس برای نمایش در وب رو اضافه کنیم
      } catch (e) {
        emit(
          state.copyWith(
            status: ContactsStatus.failure,
            errorMessage: 'خطا در دریافت مخاطبین از سرور: ${e.toString()}',
          ),
        );
      }
    } else {
      final permission = await Permission.contacts.request();

      if (permission.isGranted) {
        await _syncDeviceContacts(emit);
      } else {
        emit(state.copyWith(status: ContactsStatus.permissionDenied));
      }
    }
  }

  Future<void> _syncDeviceContacts(Emitter<ContactsState> emit) async {
    try {
      List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );

      if (contacts.isEmpty) {
        emit(
          state.copyWith(status: ContactsStatus.success, syncedContacts: []),
        );
        return;
      }

      final List<String> phoneNumbers = contacts
          .where((c) => c.phones.isNotEmpty)
          .map((c) => c.phones.first.number)
          .toList();

      if (phoneNumbers.isEmpty) {
        emit(
          state.copyWith(status: ContactsStatus.success, syncedContacts: []),
        );
        return;
      }

      final syncedUsers = await _userService.syncContacts(
        phoneNumbers.toSet().toList(),
      );
      emit(
        state.copyWith(
          status: ContactsStatus.success,
          syncedContacts: syncedUsers,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ContactsStatus.failure,
          errorMessage: 'خطا در همگام‌سازی مخاطبین: ${e.toString()}',
        ),
      );
    }
  }
}
