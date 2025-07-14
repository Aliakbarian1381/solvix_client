// lib/src/features/contacts/presentation/bloc/contacts_state.dart

part of 'contacts_bloc.dart';

enum ContactsStatus {
  initial,
  loading,
  syncing,
  backgroundSyncing,
  refreshing,
  success,
  failure,
  permissionDenied,
  permissionPermanentlyDenied,
}

class ContactsState extends Equatable {
  final ContactsStatus status;
  final List<UserModel> syncedContacts;
  final String errorMessage;
  final int totalContacts;
  final int syncedCount;
  final ChatModel? chatToOpen;
  final bool isStartingChat;
  final DateTime? lastSyncTime;
  final Map<int, ChatModel> contactChats;

  const ContactsState({
    this.status = ContactsStatus.initial,
    this.syncedContacts = const [],
    this.errorMessage = '',
    this.totalContacts = 0,
    this.syncedCount = 0,
    this.chatToOpen,
    this.isStartingChat = false,
    this.lastSyncTime,
    this.contactChats = const {},
  });

  ContactsState copyWith({
    ContactsStatus? status,
    List<UserModel>? syncedContacts,
    String? errorMessage,
    int? totalContacts,
    int? syncedCount,
    ChatModel? chatToOpen,
    bool? isStartingChat,
    DateTime? lastSyncTime,
    Map<int, ChatModel>? contactChats,
    bool clearChatToOpen = false,
  }) {
    return ContactsState(
      status: status ?? this.status,
      syncedContacts: syncedContacts ?? this.syncedContacts,
      errorMessage: errorMessage ?? this.errorMessage,
      totalContacts: totalContacts ?? this.totalContacts,
      syncedCount: syncedCount ?? this.syncedCount,
      chatToOpen: clearChatToOpen ? null : chatToOpen ?? this.chatToOpen,
      isStartingChat: isStartingChat ?? this.isStartingChat,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      contactChats: contactChats ?? this.contactChats,
    );
  }

  @override
  List<Object?> get props => [
    status,
    syncedContacts,
    errorMessage,
    totalContacts,
    syncedCount,
    chatToOpen,
    isStartingChat,
    lastSyncTime,
    contactChats,
  ];
}
