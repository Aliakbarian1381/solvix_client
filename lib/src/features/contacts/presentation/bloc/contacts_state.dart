part of 'contacts_bloc.dart';

enum ContactsStatus { initial, loading, syncing, success, failure, permissionDenied, permissionPermanentlyDenied }

class ContactsState extends Equatable {
  final ContactsStatus status;
  final List<UserModel> syncedContacts;
  final String errorMessage;
  final int totalContacts;
  final int syncedCount;
  final ChatModel? chatToOpen;

  const ContactsState({
    this.status = ContactsStatus.initial,
    this.syncedContacts = const [],
    this.errorMessage = '',
    this.totalContacts = 0,
    this.syncedCount = 0,
    this.chatToOpen,
  });

  ContactsState copyWith({
    ContactsStatus? status,
    List<UserModel>? syncedContacts,
    String? errorMessage,
    int? totalContacts,
    int? syncedCount,
    ChatModel? chatToOpen,
    bool clearChatToOpen = false,
  }) {
    return ContactsState(
      status: status ?? this.status,
      syncedContacts: syncedContacts ?? this.syncedContacts,
      errorMessage: errorMessage ?? this.errorMessage,
      totalContacts: totalContacts ?? this.totalContacts,
      syncedCount: syncedCount ?? this.syncedCount,
      chatToOpen: clearChatToOpen ? null : chatToOpen ?? this.chatToOpen,
    );
  }

  @override
  List<Object> get props => [status, syncedContacts, errorMessage, totalContacts, syncedCount];
}
