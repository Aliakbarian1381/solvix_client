// lib/src/features/contacts/presentation/bloc/contacts_event.dart

part of 'contacts_bloc.dart';

abstract class ContactsEvent extends Equatable {
  const ContactsEvent();

  @override
  List<Object> get props => [];
}

class ContactsProcessStarted extends ContactsEvent {}

class StartChatWithContact extends ContactsEvent {
  final UserModel recipient;
  final UserModel currentUser;

  const StartChatWithContact({
    required this.recipient,
    required this.currentUser,
  });

  @override
  List<Object> get props => [recipient, currentUser];
}

class ResetChatToOpen extends ContactsEvent {}

class BackgroundSyncCompleted extends ContactsEvent {}

class RefreshContacts extends ContactsEvent {}

class LoadContactChats extends ContactsEvent {
  final List<UserModel> contacts;

  const LoadContactChats({required this.contacts});

  @override
  List<Object> get props => [contacts];
}