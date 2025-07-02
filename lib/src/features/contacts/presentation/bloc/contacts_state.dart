part of 'contacts_bloc.dart';

enum ContactsStatus { initial, loading, success, failure, permissionDenied }

class ContactsState extends Equatable {
  final ContactsStatus status;
  final List<UserModel> syncedContacts;
  final String errorMessage;

  const ContactsState({
    this.status = ContactsStatus.initial,
    this.syncedContacts = const [],
    this.errorMessage = '',
  });

  ContactsState copyWith({
    ContactsStatus? status,
    List<UserModel>? syncedContacts,
    String? errorMessage,
  }) {
    return ContactsState(
      status: status ?? this.status,
      syncedContacts: syncedContacts ?? this.syncedContacts,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object> get props => [status, syncedContacts, errorMessage];
}
