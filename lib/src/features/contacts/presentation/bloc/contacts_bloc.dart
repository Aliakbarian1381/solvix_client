import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:solvix/src/core/api/chat/chat_service.dart';
import 'package:solvix/src/core/api/user/user_service.dart';
import '../../../../core/models/chat_model.dart';
import '../../../../core/models/user_model.dart';
import 'contacts_event.dart';
import 'contacts_state.dart';

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

    // متدهای جدید
    on<SearchContacts>(_onSearchContacts);
    on<ClearSearchContacts>(_onClearSearchContacts);
    on<ToggleFavoriteContact>(_onToggleFavoriteContact);
    on<ToggleBlockContact>(_onToggleBlockContact);
    on<UpdateContactDisplayName>(_onUpdateContactDisplayName);
    on<RemoveContact>(_onRemoveContact);
    on<LoadFavoriteContacts>(_onLoadFavoriteContacts);
    on<LoadRecentContacts>(_onLoadRecentContacts);
    on<FilterContacts>(_onFilterContacts);
  }

  // ===== متدهای موجود =====

  void _onResetChatToOpen(ResetChatToOpen event, Emitter<ContactsState> emit) {
    emit(state.copyWith(clearChatToOpen: true));
  }

  Future<void> _onContactsProcessStarted(
    ContactsProcessStarted event,
    Emitter<ContactsState> emit,
  ) async {
    // نمایش فوری کش موجود
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
    // فقط در Mobile اجرا میشه
    if (kIsWeb) return;

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
      // خواندن مخاطبین device
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

      // ارسال batch به سرور و ذخیره در دیتابیس
      const batchSize = 100;
      final List<UserModel> allSyncedUsers = [];

      for (int i = 0; i < phoneNumbers.length; i += batchSize) {
        final end = (i + batchSize < phoneNumbers.length)
            ? i + batchSize
            : phoneNumbers.length;
        final batch = phoneNumbers.sublist(i, end);

        // این API کال باعث میشه روابط در دیتابیس ذخیره بشن
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

      // کش کردن local
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

  Future<void> _refreshWebContacts(Emitter<ContactsState> emit) async {
    try {
      emit(state.copyWith(status: ContactsStatus.refreshing));

      // در Web فقط از سرور refresh کن
      final refreshedContacts = await _userService.getSavedContactsWithChat();

      // بروزرسانی کش
      await _contactsBox.clear();
      final contactsMap = {for (var user in refreshedContacts) user.id: user};
      await _contactsBox.putAll(contactsMap);

      emit(
        state.copyWith(
          status: ContactsStatus.success,
          syncedContacts: refreshedContacts,
          lastSyncTime: DateTime.now(),
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          status: ContactsStatus.failure,
          errorMessage: 'خطا در بروزرسانی: ${e.toString()}',
        ),
      );
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

      final savedContacts = await _userService.getSavedContactsWithChat();

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

      // به‌روزرسانی آخرین تعامل
      await _userService.updateLastInteraction(event.recipient.id);

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

  // ===== متدهای جدید =====

  Future<void> _onSearchContacts(
    SearchContacts event,
    Emitter<ContactsState> emit,
  ) async {
    if (event.query.isEmpty) {
      emit(state.copyWith(searchResults: [], isSearching: false));
      return;
    }

    emit(state.copyWith(isSearching: true));

    try {
      final results = await _userService.searchContacts(event.query);
      emit(state.copyWith(searchResults: results, isSearching: false));
    } catch (e) {
      emit(
        state.copyWith(
          isSearching: false,
          errorMessage: 'خطا در جستجو: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _onClearSearchContacts(
    ClearSearchContacts event,
    Emitter<ContactsState> emit,
  ) async {
    emit(state.copyWith(searchResults: [], isSearching: false));
  }

  Future<void> _onToggleFavoriteContact(
    ToggleFavoriteContact event,
    Emitter<ContactsState> emit,
  ) async {
    try {
      final success = await _userService.toggleFavoriteContact(
        event.contactId,
        event.isFavorite,
      );

      if (success) {
        // به‌روزرسانی لیست مخاطبین
        final updatedContacts = state.syncedContacts.map((contact) {
          if (contact.id == event.contactId) {
            return contact.copyWith(isFavorite: event.isFavorite);
          }
          return contact;
        }).toList();

        // بروزرسانی کش
        await _contactsBox.clear();
        final contactsMap = {for (var user in updatedContacts) user.id: user};
        await _contactsBox.putAll(contactsMap);

        emit(state.copyWith(syncedContacts: updatedContacts));
      }
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: 'خطا در تغییر وضعیت علاقه‌مندی: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _onToggleBlockContact(
    ToggleBlockContact event,
    Emitter<ContactsState> emit,
  ) async {
    try {
      final success = await _userService.toggleBlockContact(
        event.contactId,
        event.isBlocked,
      );

      if (success) {
        // به‌روزرسانی لیست مخاطبین
        final updatedContacts = state.syncedContacts.map((contact) {
          if (contact.id == event.contactId) {
            return contact.copyWith(isBlocked: event.isBlocked);
          }
          return contact;
        }).toList();

        // بروزرسانی کش
        await _contactsBox.clear();
        final contactsMap = {for (var user in updatedContacts) user.id: user};
        await _contactsBox.putAll(contactsMap);

        emit(state.copyWith(syncedContacts: updatedContacts));
      }
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: 'خطا در تغییر وضعیت مسدودیت: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _onUpdateContactDisplayName(
    UpdateContactDisplayName event,
    Emitter<ContactsState> emit,
  ) async {
    try {
      final success = await _userService.updateContactDisplayName(
        event.contactId,
        event.displayName,
      );

      if (success) {
        // به‌روزرسانی لیست مخاطبین
        final updatedContacts = state.syncedContacts.map((contact) {
          if (contact.id == event.contactId) {
            return contact.copyWith(displayName: event.displayName);
          }
          return contact;
        }).toList();

        // بروزرسانی کش
        await _contactsBox.clear();
        final contactsMap = {for (var user in updatedContacts) user.id: user};
        await _contactsBox.putAll(contactsMap);

        emit(state.copyWith(syncedContacts: updatedContacts));
      }
    } catch (e) {
      emit(
        state.copyWith(
          errorMessage: 'خطا در به‌روزرسانی نام نمایشی: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _onRemoveContact(
    RemoveContact event,
    Emitter<ContactsState> emit,
  ) async {
    try {
      final success = await _userService.removeContact(event.contactId);

      if (success) {
        // حذف از لیست مخاطبین
        final updatedContacts = state.syncedContacts
            .where((contact) => contact.id != event.contactId)
            .toList();

        // بروزرسانی کش
        await _contactsBox.clear();
        final contactsMap = {for (var user in updatedContacts) user.id: user};
        await _contactsBox.putAll(contactsMap);

        emit(state.copyWith(syncedContacts: updatedContacts));
      }
    } catch (e) {
      emit(state.copyWith(errorMessage: 'خطا در حذف مخاطب: ${e.toString()}'));
    }
  }

  Future<void> _onLoadFavoriteContacts(
    LoadFavoriteContacts event,
    Emitter<ContactsState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoadingFavorites: true));
      final favorites = await _userService.getFavoriteContacts();
      emit(
        state.copyWith(favoriteContacts: favorites, isLoadingFavorites: false),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingFavorites: false,
          errorMessage: 'خطا در دریافت مخاطبین مورد علاقه: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _onLoadRecentContacts(
    LoadRecentContacts event,
    Emitter<ContactsState> emit,
  ) async {
    try {
      emit(state.copyWith(isLoadingRecent: true));
      final recent = await _userService.getRecentContacts();
      emit(state.copyWith(recentContacts: recent, isLoadingRecent: false));
    } catch (e) {
      emit(
        state.copyWith(
          isLoadingRecent: false,
          errorMessage: 'خطا در دریافت مخاطبین اخیر: ${e.toString()}',
        ),
      );
    }
  }

  Future<void> _onFilterContacts(
    FilterContacts event,
    Emitter<ContactsState> emit,
  ) async {
    try {
      emit(state.copyWith(isFiltering: true));
      final filtered = await _userService.getFilteredContacts(
        isFavorite: event.isFavorite,
        isBlocked: event.isBlocked,
        hasChat: event.hasChat,
        sortBy: event.sortBy,
        sortDirection: event.sortDirection,
      );
      emit(state.copyWith(filteredContacts: filtered, isFiltering: false));
    } catch (e) {
      emit(
        state.copyWith(
          isFiltering: false,
          errorMessage: 'خطا در فیلتر کردن مخاطبین: ${e.toString()}',
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
