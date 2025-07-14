import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:solvix/src/core/api/chat/chat_service.dart';
import 'package:solvix/src/core/models/chat_model.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/core/network/signalr_service.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_state.dart'
as auth_state;
import 'package:solvix/src/features/chat/presentation/bloc/chat_messages_bloc.dart';
import 'package:solvix/src/features/chat/presentation/screens/chat_screen.dart';
import 'package:solvix/src/features/contacts/presentation/bloc/contacts_bloc.dart';
import '../../../../core/utils/date_helper.dart';
import '../bloc/contacts_event.dart';
import '../bloc/contacts_state.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen>
    with TickerProviderStateMixin {
  UserModel? _currentUser;
  late AnimationController _animationController;
  late AnimationController _refreshController;
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  bool _isRefreshing = false;
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    _tabController = TabController(length: 4, vsync: this);

    final authState = context.read<AuthBloc>().state;
    if (authState is auth_state.AuthSuccess) {
      _currentUser = authState.user;
    }

    context.read<ContactsBloc>().add(ContactsProcessStarted());
    context.read<ContactsBloc>().add(LoadFavoriteContacts());
    context.read<ContactsBloc>().add(LoadRecentContacts());
    _animationController.forward();

    _searchController.addListener(() {
      if (_searchController.text.isEmpty) {
        context.read<ContactsBloc>().add(ClearSearchContacts());
      } else {
        context.read<ContactsBloc>().add(SearchContacts(query: _searchController.text));
      }
    });
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshController.dispose();
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ContactsBloc, ContactsState>(
      listener: (context, state) {
        if (state.chatToOpen != null) {
          _navigateToChat(state.chatToOpen!);
        }
        if (state.errorMessage != null) {
          _showErrorSnackBar(state.errorMessage!);
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        appBar: _buildAppBar(),
        body: BlocBuilder<ContactsBloc, ContactsState>(
          builder: (context, state) {
            return Column(
              children: [
                _buildSearchBar(),
                _buildTabBar(),
                Expanded(
                  child: TabBarView(
                    controller: _tabController,
                    children: [
                      _buildAllContactsTab(state),
                      _buildFavoritesTab(state),
                      _buildRecentTab(state),
                      _buildBlockedTab(state),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar() {
    return AppBar(
      title: const Text('مخاطبین'),
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      elevation: 0,
      actions: [
        IconButton(
          icon: const Icon(Icons.refresh_rounded),
          onPressed: _handleRefresh,
        ),
        PopupMenuButton<String>(
          onSelected: (value) {
            switch (value) {
              case 'sort_name':
                context.read<ContactsBloc>().add(FilterContacts(sortBy: 'name'));
                break;
              case 'sort_recent':
                context.read<ContactsBloc>().add(FilterContacts(sortBy: 'lastInteraction'));
                break;
              case 'sort_added':
                context.read<ContactsBloc>().add(FilterContacts(sortBy: 'dateAdded'));
                break;
            }
          },
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'sort_name',
              child: Text('مرتب‌سازی بر اساس نام'),
            ),
            const PopupMenuItem(
              value: 'sort_recent',
              child: Text('مرتب‌سازی بر اساس آخرین تعامل'),
            ),
            const PopupMenuItem(
              value: 'sort_added',
              child: Text('مرتب‌سازی بر اساس تاریخ اضافه'),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.all(16),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: 'جستجو در مخاطبین...',
          prefixIcon: const Icon(Icons.search),
          suffixIcon: _searchController.text.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear),
            onPressed: () {
              _searchController.clear();
              context.read<ContactsBloc>().add(ClearSearchContacts());
            },
          )
              : null,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          filled: true,
          fillColor: Theme.of(context).cardColor,
        ),
        onSubmitted: (value) {
          if (value.isNotEmpty) {
            context.read<ContactsBloc>().add(SearchContacts(query: value));
          }
        },
      ),
    );
  }

  Widget _buildTabBar() {
    return BlocBuilder<ContactsBloc, ContactsState>(
      builder: (context, state) {
        return TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: 'همه (${state.totalNonBlockedContacts})',
            ),
            Tab(
              text: 'علاقه‌مندی‌ها (${state.totalFavoriteContacts})',
            ),
            Tab(
              text: 'اخیر',
            ),
            Tab(
              text: 'مسدود شده (${state.totalBlockedContacts})',
            ),
          ],
        );
      },
    );
  }

  Widget _buildAllContactsTab(ContactsState state) {
    if (state.isSearching && _searchController.text.isNotEmpty) {
      return _buildSearchResults(state);
    }

    if (state.isLoading) {
      return _buildLoadingState();
    }

    if (state.isSyncing) {
      return _buildSyncingState(state);
    }

    if (state.isPermissionDenied) {
      return _buildPermissionDeniedState();
    }

    if (state.isPermissionPermanentlyDenied) {
      return _buildPermissionPermanentlyDeniedState();
    }

    if (state.isFailure) {
      return _buildErrorState(state.errorMessage ?? 'خطای نامشخص');
    }

    if (state.nonBlockedContacts.isEmpty) {
      return _buildEmptyState();
    }

    return _buildContactsList(state.nonBlockedContacts);
  }

  Widget _buildFavoritesTab(ContactsState state) {
    if (state.isLoadingFavorites) {
      return _buildLoadingState();
    }

    if (state.favoriteNonBlockedContacts.isEmpty) {
      return _buildEmptyFavoritesState();
    }

    return _buildContactsList(state.favoriteNonBlockedContacts);
  }

  Widget _buildRecentTab(ContactsState state) {
    if (state.isLoadingRecent) {
      return _buildLoadingState();
    }

    if (state.recentContacts.isEmpty) {
      return _buildEmptyRecentState();
    }

    return _buildContactsList(state.recentContacts);
  }

  Widget _buildBlockedTab(ContactsState state) {
    if (state.blockedContacts.isEmpty) {
      return _buildEmptyBlockedState();
    }

    return _buildContactsList(state.blockedContacts, showBlockedOptions: true);
  }

  Widget _buildSearchResults(ContactsState state) {
    if (state.isSearching) {
      return _buildLoadingState();
    }

    if (state.searchResults.isEmpty) {
      return _buildEmptySearchState();
    }

    return _buildContactsList(state.searchResults);
  }

  Widget _buildContactsList(List<UserModel> contacts, {bool showBlockedOptions = false}) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      child: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: contacts.length,
        separatorBuilder: (context, index) => const Divider(height: 1),
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return _ContactListItem(
            contact: contact,
            onTap: () => _onContactTap(contact),
            onFavorite: (isFavorite) {
              context.read<ContactsBloc>().add(
                ToggleFavoriteContact(
                  contactId: contact.id,
                  isFavorite: isFavorite,
                ),
              );
            },
            onBlock: (isBlocked) {
              context.read<ContactsBloc>().add(
                ToggleBlockContact(
                  contactId: contact.id,
                  isBlocked: isBlocked,
                ),
              );
            },
            onEditName: (displayName) {
              context.read<ContactsBloc>().add(
                UpdateContactDisplayName(
                  contactId: contact.id,
                  displayName: displayName,
                ),
              );
            },
            onRemove: () {
              context.read<ContactsBloc>().add(
                RemoveContact(contactId: contact.id),
              );
            },
            showBlockedOptions: showBlockedOptions,
          );
        },
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildSyncingState(ContactsState state) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'در حال همگام‌سازی مخاطبین...',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            '${state.syncedCount} از ${state.totalContacts}',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          LinearProgressIndicator(
            value: state.syncProgress,
            backgroundColor: Theme.of(context).cardColor,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.contact_page_outlined, size: 64),
          const SizedBox(height: 16),
          Text(
            'دسترسی به مخاطبین',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'برای نمایش مخاطبین، نیاز به دسترسی داریم.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<ContactsBloc>().add(ContactsProcessStarted());
            },
            child: const Text('اجازه دسترسی'),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionPermanentlyDeniedState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'دسترسی رد شده',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            'لطفاً از تنظیمات دسترسی را فعال کنید.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              openAppSettings();
            },
            child: const Text('باز کردن تنظیمات'),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          Text(
            'خطا',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              context.read<ContactsBloc>().add(RefreshContacts());
            },
            child: const Text('تلاش مجدد'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.people_outline, size: 64),
          SizedBox(height: 16),
          Text('هیچ مخاطبی یافت نشد'),
          SizedBox(height: 8),
          Text('مخاطبین شما در اینجا نمایش داده خواهند شد'),
        ],
      ),
    );
  }

  Widget _buildEmptyFavoritesState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.star_border, size: 64),
          SizedBox(height: 16),
          Text('هیچ مخاطب مورد علاقه‌ای ندارید'),
          SizedBox(height: 8),
          Text('مخاطبین مورد علاقه‌تان اینجا نمایش داده می‌شوند'),
        ],
      ),
    );
  }

  Widget _buildEmptyRecentState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.access_time, size: 64),
          SizedBox(height: 16),
          Text('هیچ تعامل اخیری ندارید'),
          SizedBox(height: 8),
          Text('مخاطبین اخیر اینجا نمایش داده می‌شوند'),
        ],
      ),
    );
  }

  Widget _buildEmptyBlockedState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.block, size: 64),
          SizedBox(height: 16),
          Text('هیچ مخاطب مسدودی ندارید'),
          SizedBox(height: 8),
          Text('مخاطبین مسدود شده اینجا نمایش داده می‌شوند'),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64),
          SizedBox(height: 16),
          Text('نتیجه‌ای یافت نشد'),
          SizedBox(height: 8),
          Text('جستجوی دیگری امتحان کنید'),
        ],
      ),
    );
  }

  void _onContactTap(UserModel contact) {
    if (_currentUser != null) {
      HapticFeedback.selectionClick();
      context.read<ContactsBloc>().add(
        StartChatWithContact(
          recipient: contact,
          currentUser: _currentUser!,
        ),
      );
    }
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    HapticFeedback.lightImpact();
    _refreshController.repeat();

    context.read<ContactsBloc>().add(RefreshContacts());

    await Future.delayed(const Duration(milliseconds: 1000));

    setState(() {
      _isRefreshing = false;
    });

    _refreshController.stop();
    _refreshController.reset();
  }

  void _navigateToChat(ChatModel chat) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => BlocProvider(
          create: (blocContext) => ChatMessagesBloc(
            blocContext.read<ChatService>(),
            blocContext.read<SignalRService>(),
            chatId: chat.id,
            currentUserId: _currentUser!.id,
          ),
          child: ChatScreen(chatModel: chat, currentUser: _currentUser),
        ),
      ),
    ).then((_) {
      context.read<ContactsBloc>().add(ResetChatToOpen());
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }
}

// ===== Contact List Item Widget =====

class _ContactListItem extends StatelessWidget {
  final UserModel contact;
  final VoidCallback onTap;
  final Function(bool) onFavorite;
  final Function(bool) onBlock;
  final Function(String?) onEditName;
  final VoidCallback onRemove;
  final bool showBlockedOptions;

  const _ContactListItem({
    required this.contact,
    required this.onTap,
    required this.onFavorite,
    required this.onBlock,
    required this.onEditName,
    required this.onRemove,
    this.showBlockedOptions = false,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: Theme.of(context).primaryColor,
        backgroundImage: contact.profilePictureUrl != null
            ? NetworkImage(contact.profilePictureUrl!)
            : null,
        child: contact.profilePictureUrl == null
            ? Text(
          contact.avatarInitials,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        )
            : null,
      ),
      title: Text(
        contact.fullName,
        style: const TextStyle(fontWeight: FontWeight.w600),
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(contact.lastSeenText),
          if (contact.lastMessage != null)
            Text(
              contact.lastMessage!,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
        ],
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (contact.isFavorite)
            const Icon(Icons.star, color: Colors.amber, size: 20),
          if (contact.unreadCount > 0)
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                shape: BoxShape.circle,
              ),
              child: Text(
                contact.unreadCount.toString(),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          PopupMenuButton<String>(
            onSelected: (value) => _handleMenuAction(context, value),
            itemBuilder: (context) => [
              if (!showBlockedOptions) ...[
                PopupMenuItem(
                  value: 'favorite',
                  child: Row(
                    children: [
                      Icon(contact.isFavorite ? Icons.star : Icons.star_border),
                      const SizedBox(width: 8),
                      Text(contact.isFavorite ? 'حذف از علاقه‌مندی‌ها' : 'افزودن به علاقه‌مندی‌ها'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'edit_name',
                  child: Row(
                    children: [
                      Icon(Icons.edit),
                      SizedBox(width: 8),
                      Text('تغییر نام نمایشی'),
                    ],
                  ),
                ),
                const PopupMenuItem(
                  value: 'block',
                  child: Row(
                    children: [
                      Icon(Icons.block),
                      SizedBox(width: 8),
                      Text('مسدود کردن'),
                    ],
                  ),
                ),
              ] else ...[
                const PopupMenuItem(
                  value: 'unblock',
                  child: Row(
                    children: [
                      Icon(Icons.check_circle),
                      SizedBox(width: 8),
                      Text('رفع مسدودیت'),
                    ],
                  ),
                ),
              ],
              const PopupMenuItem(
                value: 'remove',
                child: Row(
                  children: [
                    Icon(Icons.delete, color: Colors.red),
                    SizedBox(width: 8),
                    Text('حذف مخاطب', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      onTap: contact.isBlocked ? null : onTap,
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'favorite':
        onFavorite(!contact.isFavorite);
        break;
      case 'edit_name':
        _showEditNameDialog(context);
        break;
      case 'block':
        _showBlockConfirmDialog(context);
        break;
      case 'unblock':
        onBlock(false);
        break;
      case 'remove':
        _showRemoveConfirmDialog(context);
        break;
    }
  }

  void _showEditNameDialog(BuildContext context) {
    final controller = TextEditingController(text: contact.displayName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تغییر نام نمایشی'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'نام نمایشی',
            hintText: 'نام دلخواه برای این مخاطب',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              onEditName(controller.text.trim().isEmpty ? null : controller.text.trim());
              Navigator.of(context).pop();
            },
            child: const Text('ذخیره'),
          ),
        ],
      ),
    );
  }

  void _showBlockConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('مسدود کردن مخاطب'),
        content: Text('آیا مطمئن هستید که می‌خواهید ${contact.fullName} را مسدود کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              onBlock(true);
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('مسدود کردن'),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف مخاطب'),
        content: Text('آیا مطمئن هستید که می‌خواهید ${contact.fullName} را از مخاطبین حذف کنید؟'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              onRemove();
              Navigator.of(context).pop();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('حذف'),
          ),
        ],
      ),
    );
  }
}