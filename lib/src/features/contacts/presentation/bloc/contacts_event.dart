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
