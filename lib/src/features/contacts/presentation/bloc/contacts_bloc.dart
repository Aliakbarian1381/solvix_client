import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:solvix/src/core/api/user/user_service.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import '../../../../core/models/chat_model.dart';
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
      final List<Contact> contacts = await FlutterContacts.getContacts(
        withProperties: true,
      );
      final List<String> phoneNumbers = contacts
          .where((c) => c.phones.isNotEmpty)
          .map((c) => c.phones.first.number) // TODO: نرمال‌سازی شماره‌ها
          .toSet() // حذف شماره‌های تکراری
          .toList();

      if (phoneNumbers.isEmpty) {
        emit(
          state.copyWith(status: ContactsStatus.success, syncedContacts: []),
        );
        return;
      }

      // ۱. وضعیت را به "در حال همگام‌سازی" تغییر می‌دهیم و تعداد کل را مشخص می‌کنیم
      emit(
        state.copyWith(
          status: ContactsStatus.syncing,
          totalContacts: phoneNumbers.length,
          syncedCount: 0,
        ),
      );

      const batchSize = 100; // هر بار ۱۰۰ شماره را به سرور می‌فرستیم
      final List<UserModel> allSyncedUsers = [];
      int currentSyncedCount = 0;

      // ۲. لیست شماره‌ها را به دسته‌های ۱۰۰تایی تقسیم می‌کنیم
      for (int i = 0; i < phoneNumbers.length; i += batchSize) {
        final end = (i + batchSize < phoneNumbers.length)
            ? i + batchSize
            : phoneNumbers.length;
        final batch = phoneNumbers.sublist(i, end);

        // ۳. هر دسته را به سرور ارسال می‌کنیم
        final syncedUsersInBatch = await _userService.syncContacts(batch);
        allSyncedUsers.addAll(syncedUsersInBatch);

        currentSyncedCount += batch.length;

        // ۴. وضعیت پیشرفت را به UI اطلاع می‌دهیم
        emit(
          state.copyWith(
            status: ContactsStatus.syncing,
            syncedCount: currentSyncedCount,
            syncedContacts: allSyncedUsers, // لیست را به مرور تکمیل می‌کنیم
          ),
        );
      }

      // ۵. پس از اتمام همه دسته‌ها، وضعیت نهایی را success اعلام می‌کنیم
      emit(
        state.copyWith(
          status: ContactsStatus.success,
          syncedContacts: allSyncedUsers,
          syncedCount: phoneNumbers.length,
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
