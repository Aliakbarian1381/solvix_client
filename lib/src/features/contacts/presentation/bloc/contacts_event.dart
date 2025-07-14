import 'package:equatable/equatable.dart';
import '../../../../core/models/user_model.dart';

abstract class ContactsEvent extends Equatable {
  const ContactsEvent();

  @override
  List<Object?> get props => [];
}

// ===== Events موجود =====

class ContactsProcessStarted extends ContactsEvent {
  const ContactsProcessStarted();
}

class RefreshContacts extends ContactsEvent {
  const RefreshContacts();
}

class BackgroundSyncCompleted extends ContactsEvent {
  const BackgroundSyncCompleted();
}

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

class ResetChatToOpen extends ContactsEvent {
  const ResetChatToOpen();
}

// ===== Events جدید =====

class SearchContacts extends ContactsEvent {
  final String query;

  const SearchContacts({required this.query});

  @override
  List<Object> get props => [query];
}

class ClearSearchContacts extends ContactsEvent {
  const ClearSearchContacts();
}

class ToggleFavoriteContact extends ContactsEvent {
  final int contactId;
  final bool isFavorite;

  const ToggleFavoriteContact({
    required this.contactId,
    required this.isFavorite,
  });

  @override
  List<Object> get props => [contactId, isFavorite];
}

class ToggleBlockContact extends ContactsEvent {
  final int contactId;
  final bool isBlocked;

  const ToggleBlockContact({
    required this.contactId,
    required this.isBlocked,
  });

  @override
  List<Object> get props => [contactId, isBlocked];
}

class UpdateContactDisplayName extends ContactsEvent {
  final int contactId;
  final String? displayName;

  const UpdateContactDisplayName({
    required this.contactId,
    this.displayName,
  });

  @override
  List<Object?> get props => [contactId, displayName];
}

class RemoveContact extends ContactsEvent {
  final int contactId;

  const RemoveContact({required this.contactId});

  @override
  List<Object> get props => [contactId];
}

class LoadFavoriteContacts extends ContactsEvent {
  const LoadFavoriteContacts();
}

class LoadRecentContacts extends ContactsEvent {
  const LoadRecentContacts();
}

class FilterContacts extends ContactsEvent {
  final bool? isFavorite;
  final bool? isBlocked;
  final bool? hasChat;
  final String sortBy;
  final String sortDirection;

  const FilterContacts({
    this.isFavorite,
    this.isBlocked,
    this.hasChat,
    this.sortBy = 'name',
    this.sortDirection = 'asc',
  });

  @override
  List<Object?> get props => [isFavorite, isBlocked, hasChat, sortBy, sortDirection];
}