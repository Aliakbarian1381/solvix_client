import 'package:equatable/equatable.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/chat_model.dart';

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
  final List<UserModel> searchResults;
  final List<UserModel> favoriteContacts;
  final List<UserModel> recentContacts;
  final List<UserModel> filteredContacts;
  final int totalContacts;
  final int syncedCount;
  final DateTime? lastSyncTime;
  final String? errorMessage;
  final bool isStartingChat;
  final bool isSearching;
  final bool isLoadingFavorites;
  final bool isLoadingRecent;
  final bool isFiltering;
  final ChatModel? chatToOpen;

  const ContactsState({
    this.status = ContactsStatus.initial,
    this.syncedContacts = const [],
    this.searchResults = const [],
    this.favoriteContacts = const [],
    this.recentContacts = const [],
    this.filteredContacts = const [],
    this.totalContacts = 0,
    this.syncedCount = 0,
    this.lastSyncTime,
    this.errorMessage,
    this.isStartingChat = false,
    this.isSearching = false,
    this.isLoadingFavorites = false,
    this.isLoadingRecent = false,
    this.isFiltering = false,
    this.chatToOpen,
  });

  ContactsState copyWith({
    ContactsStatus? status,
    List<UserModel>? syncedContacts,
    List<UserModel>? searchResults,
    List<UserModel>? favoriteContacts,
    List<UserModel>? recentContacts,
    List<UserModel>? filteredContacts,
    int? totalContacts,
    int? syncedCount,
    DateTime? lastSyncTime,
    String? errorMessage,
    bool? isStartingChat,
    bool? isSearching,
    bool? isLoadingFavorites,
    bool? isLoadingRecent,
    bool? isFiltering,
    ChatModel? chatToOpen,
    bool clearChatToOpen = false,
  }) {
    return ContactsState(
      status: status ?? this.status,
      syncedContacts: syncedContacts ?? this.syncedContacts,
      searchResults: searchResults ?? this.searchResults,
      favoriteContacts: favoriteContacts ?? this.favoriteContacts,
      recentContacts: recentContacts ?? this.recentContacts,
      filteredContacts: filteredContacts ?? this.filteredContacts,
      totalContacts: totalContacts ?? this.totalContacts,
      syncedCount: syncedCount ?? this.syncedCount,
      lastSyncTime: lastSyncTime ?? this.lastSyncTime,
      errorMessage: errorMessage,
      isStartingChat: isStartingChat ?? this.isStartingChat,
      isSearching: isSearching ?? this.isSearching,
      isLoadingFavorites: isLoadingFavorites ?? this.isLoadingFavorites,
      isLoadingRecent: isLoadingRecent ?? this.isLoadingRecent,
      isFiltering: isFiltering ?? this.isFiltering,
      chatToOpen: clearChatToOpen ? null : (chatToOpen ?? this.chatToOpen),
    );
  }

  @override
  List<Object?> get props => [
    status,
    syncedContacts,
    searchResults,
    favoriteContacts,
    recentContacts,
    filteredContacts,
    totalContacts,
    syncedCount,
    lastSyncTime,
    errorMessage,
    isStartingChat,
    isSearching,
    isLoadingFavorites,
    isLoadingRecent,
    isFiltering,
    chatToOpen,
  ];

  // Computed properties
  List<UserModel> get nonBlockedContacts => syncedContacts.where((c) => !c.isBlocked).toList();
  List<UserModel> get blockedContacts => syncedContacts.where((c) => c.isBlocked).toList();
  List<UserModel> get favoriteNonBlockedContacts => syncedContacts.where((c) => c.isFavorite && !c.isBlocked).toList();

  int get totalNonBlockedContacts => nonBlockedContacts.length;
  int get totalFavoriteContacts => favoriteNonBlockedContacts.length;
  int get totalBlockedContacts => blockedContacts.length;

  bool get hasContacts => syncedContacts.isNotEmpty;
  bool get hasSearchResults => searchResults.isNotEmpty;
  bool get hasFavorites => favoriteContacts.isNotEmpty;
  bool get hasRecent => recentContacts.isNotEmpty;

  bool get isLoading => status == ContactsStatus.loading;
  bool get isSyncing => status == ContactsStatus.syncing;
  bool get isRefreshing => status == ContactsStatus.refreshing;
  bool get isBackgroundSyncing => status == ContactsStatus.backgroundSyncing;
  bool get isSuccess => status == ContactsStatus.success;
  bool get isFailure => status == ContactsStatus.failure;
  bool get isPermissionDenied => status == ContactsStatus.permissionDenied;
  bool get isPermissionPermanentlyDenied => status == ContactsStatus.permissionPermanentlyDenied;

  double get syncProgress => totalContacts > 0 ? syncedCount / totalContacts : 0.0;
}