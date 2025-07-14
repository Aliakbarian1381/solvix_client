import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:solvix/src/core/api/chat/chat_service.dart';
import 'package:solvix/src/core/api/user/user_service.dart';
import '../../../../core/models/chat_model.dart';
import '../../../../core/models/user_model.dart';

part 'contacts_event.dart';

part 'contacts_state.dart';

class ContactsBloc extends Bloc<ContactsEvent, ContactsState> {
  final UserService _userService;
  final ChatService _chatService;
  final Box<UserModel> _contactsBox = Hive.box<UserModel>('synced_contacts');
  Timer? _backgroundSyncTimer;

  ContactsBloc(this._userService, this._chatService)
    : super(const ContactsState()) {
    on<ContactsProcessStarted>(_onContactsProcessStarted);
    on<StartChatWithContact>(_onStartChatWithContact);
    on<ResetChatToOpen>(_onResetChatToOpen);
    on<BackgroundSyncCompleted>(_onBackgroundSyncCompleted);
    on<RefreshContacts>(_onRefreshContacts);
  }

  void _onResetChatToOpen(ResetChatToOpen event, Emitter<ContactsState> emit) {
    emit(state.copyWith(clearChatToOpen: true));
  }

  Future<void> _onContactsProcessStarted(
    ContactsProcessStarted event,
    Emitter<ContactsState> emit,
  ) async {
    // 1. نمایش فوری کش موجود
    final cachedContacts = _contactsBox.values.toList();
    if (cachedContacts.isNotEmpty) {
      emit(
        state.copyWith(
          status: ContactsStatus.success,
          syncedContacts: cachedContacts,
          lastSyncTime: DateTime.now(),
        ),
      );

      // شروع sync در پس‌زمینه
      _startBackgroundSync(emit);
    } else {
      emit(state.copyWith(status: ContactsStatus.loading));
      await _performInitialSync(emit);
    }
  }

  Future<void> _onRefreshContacts(
    RefreshContacts event,
    Emitter<ContactsState> emit,
  ) async {
    emit(state.copyWith(status: ContactsStatus.refreshing));
    await _performInitialSync(emit);
  }

  void _startBackgroundSync(Emitter<ContactsState> emit) {
    _backgroundSyncTimer?.cancel();
    _backgroundSyncTimer = Timer(const Duration(milliseconds: 500), () {
      add(BackgroundSyncCompleted());
    });

    if (kIsWeb) {
      _fetchSavedContactsForWeb(emit, isBackground: true);
    } else {
      _checkPermissionAndSync(emit, isBackground: true);
    }
  }

  Future<void> _onBackgroundSyncCompleted(
    BackgroundSyncCompleted event,
    Emitter<ContactsState> emit,
  ) async {
    // Background sync کامل شد - اختیاری می‌توان loading indicator حذف کرد
    if (state.status == ContactsStatus.backgroundSyncing) {
      emit(state.copyWith(status: ContactsStatus.success));
    }
  }

  Future<void> _performInitialSync(Emitter<ContactsState> emit) async {
    if (kIsWeb) {
      await _fetchSavedContactsForWeb(emit);
    } else {
      await _checkPermissionAndSync(emit);
    }
  }

  Future<void> _checkPermissionAndSync(
    Emitter<ContactsState> emit, {
    bool isBackground = false,
  }) async {
    var status = await Permission.contacts.status;

    if (status.isGranted) {
      await _syncDeviceContacts(emit, isBackgroundSync: isBackground);
    } else if (status.isPermanentlyDenied) {
      if (!isBackground) {
        emit(
          state.copyWith(status: ContactsStatus.permissionPermanentlyDenied),
        );
      }
    } else {
      if (!isBackground) {
        final requestedStatus = await Permission.contacts.request();
        if (requestedStatus.isGranted) {
          await _syncDeviceContacts(emit, isBackgroundSync: false);
        } else {
          emit(state.copyWith(status: ContactsStatus.permissionDenied));
        }
      }
    }
  }

  Future<void> _syncDeviceContacts(
    Emitter<ContactsState> emit, {
    required bool isBackgroundSync,
  }) async {
    if (!isBackgroundSync) {
      emit(
        state.copyWith(
          status: ContactsStatus.syncing,
          totalContacts: 0,
          syncedCount: 0,
        ),
      );
    } else {
      emit(state.copyWith(status: ContactsStatus.backgroundSyncing));
    }

    try {
      final contacts = await FlutterContacts.getContacts(withProperties: true);
      final phoneNumbers = contacts
          .where((c) => c.phones.isNotEmpty)
          .map((c) => c.phones.first.number)
          .toSet()
          .toList();

      if (phoneNumbers.isEmpty) {
        if (!isBackgroundSync) {
          emit(
            state.copyWith(
              status: ContactsStatus.success,
              syncedContacts: [],
              lastSyncTime: DateTime.now(),
            ),
          );
        }
        return;
      }

      if (!isBackgroundSync) {
        emit(
          state.copyWith(
            status: ContactsStatus.syncing,
            totalContacts: phoneNumbers.length,
          ),
        );
      }

      const batchSize = 100;
      final List<UserModel> allSyncedUsers = [];

      for (int i = 0; i < phoneNumbers.length; i += batchSize) {
        final end = (i + batchSize < phoneNumbers.length)
            ? i + batchSize
            : phoneNumbers.length;
        final batch = phoneNumbers.sublist(i, end);

        final syncedUsersInBatch = await _userService.syncContacts(batch);
        allSyncedUsers.addAll(syncedUsersInBatch);

        if (!isBackgroundSync) {
          emit(
            state.copyWith(
              status: ContactsStatus.syncing,
              syncedCount: i + batch.length,
            ),
          );
        }
      }

      // بروزرسانی کش
      await _contactsBox.clear();
      final contactsMap = {for (var user in allSyncedUsers) user.id: user};
      await _contactsBox.putAll(contactsMap);

      emit(
        state.copyWith(
          status: ContactsStatus.success,
          syncedContacts: allSyncedUsers,
          lastSyncTime: DateTime.now(),
        ),
      );
    } catch (e) {
      if (!isBackgroundSync) {
        emit(
          state.copyWith(
            status: ContactsStatus.failure,
            errorMessage: 'خطا در همگام‌سازی: ${e.toString()}',
          ),
        );
      }
    }
  }

  Future<void> _fetchSavedContactsForWeb(
    Emitter<ContactsState> emit, {
    bool isBackground = false,
  }) async {
    try {
      if (!isBackground) {
        emit(state.copyWith(status: ContactsStatus.loading));
      }

      final savedContacts = await _userService.getSavedContacts();

      await _contactsBox.clear();
      final contactsMap = {for (var user in savedContacts) user.id: user};
      await _contactsBox.putAll(contactsMap);

      emit(
        state.copyWith(
          status: ContactsStatus.success,
          syncedContacts: savedContacts,
          lastSyncTime: DateTime.now(),
        ),
      );
    } catch (e) {
      if (!isBackground) {
        emit(
          state.copyWith(
            status: ContactsStatus.failure,
            errorMessage: 'خطا در دریافت مخاطبین: ${e.toString()}',
          ),
        );
      }
    }
  }

  Future<void> _onStartChatWithContact(
    StartChatWithContact event,
    Emitter<ContactsState> emit,
  ) async {
    try {
      // نمایش loading state
      emit(state.copyWith(isStartingChat: true));

      final result = await _chatService.startChatWithUser(event.recipient.id);
      final chatId = result['chatId'] as String;

      final chatModel = ChatModel(
        id: chatId,
        isGroup: false,
        title:
            "${event.recipient.firstName ?? ''} ${event.recipient.lastName ?? ''}"
                .trim(),
        createdAt: DateTime.now(),
        participants: [event.currentUser, event.recipient],
        unreadCount: 0,
      );

      emit(state.copyWith(chatToOpen: chatModel, isStartingChat: false));
    } catch (e) {
      emit(
        state.copyWith(
          isStartingChat: false,
          errorMessage: 'خطا در ایجاد چت: ${e.toString()}',
        ),
      );
    }
  }

  @override
  Future<void> close() {
    _backgroundSyncTimer?.cancel();
    return super.close();
  }
}
