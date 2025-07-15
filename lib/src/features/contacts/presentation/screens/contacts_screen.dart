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
  late TabController _tabController;
  late TextEditingController _searchController;
  late AnimationController _refreshController;
  late AnimationController _fabController;
  bool _isRefreshing = false;
  String _currentSearchQuery = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _searchController = TextEditingController();
    _refreshController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fabController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _searchController.addListener(() {
      if (_searchController.text != _currentSearchQuery) {
        _currentSearchQuery = _searchController.text;
        if (_currentSearchQuery.isNotEmpty) {
          context.read<ContactsBloc>().add(
            SearchContacts(query: _currentSearchQuery),
          );
        } else {
          context.read<ContactsBloc>().add(ClearSearchContacts());
        }
      }
    });

    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ContactsBloc>().add(ContactsProcessStarted());
      _fabController.forward();
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    _refreshController.dispose();
    _fabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return MultiBlocListener(
      listeners: [
        BlocListener<AuthBloc, auth_state.AuthState>(
          listener: (context, state) {
            if (state is auth_state.AuthSuccess ) {
              _currentUser = state.user;
            }
          },
        ),
        BlocListener<ContactsBloc, ContactsState>(
          listener: (context, state) {
            if (state.chatToOpen != null) {
              _navigateToChat(state.chatToOpen!);
            }
            if (state.errorMessage != null) {
              _showErrorSnackBar(state.errorMessage!);
            }
          },
        ),
      ],
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0B1426)
            : const Color(0xFFF7F8FC),
        body: SafeArea(
          child: Column(
            children: [
              _buildModernHeader(context, isDark, isDesktop),
              Expanded(
                child: BlocBuilder<ContactsBloc, ContactsState>(
                  builder: (context, state) {
                    return Column(
                      children: [
                        _buildSearchSection(context, isDark, isDesktop),
                        _buildTabSection(context, state, isDark, isDesktop),
                        Expanded(
                          child: TabBarView(
                            controller: _tabController,
                            children: [
                              _buildAllContactsTab(
                                context,
                                state,
                                isDark,
                                isDesktop,
                              ),
                              _buildFavoritesTab(
                                context,
                                state,
                                isDark,
                                isDesktop,
                              ),
                              _buildRecentTab(
                                context,
                                state,
                                isDark,
                                isDesktop,
                              ),
                              _buildBlockedTab(
                                context,
                                state,
                                isDark,
                                isDesktop,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        floatingActionButton: _buildModernFAB(context, isDark, isDesktop),
      ),
    );
  }

  // ===== Header Section =====
  Widget _buildModernHeader(BuildContext context, bool isDark, bool isDesktop) {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 24,
        isDesktop ? 20 : 16,
        isDesktop ? 32 : 24,
        isDesktop ? 16 : 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: isDesktop ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Back Button
          Container(
            width: isDesktop ? 48 : 44,
            height: isDesktop ? 48 : 44,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.arrow_back_ios_rounded,
                color: primaryColor,
                size: isDesktop ? 20 : 18,
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ).animate().scale(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutBack,
          ),

          SizedBox(width: isDesktop ? 20 : 16),

          // Title Section
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'مخاطبین',
                  style: TextStyle(
                    fontSize: isDesktop ? 28 : 24,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                    height: 1.2,
                  ),
                ).animate().slideX(
                  begin: -0.3,
                  duration: const Duration(milliseconds: 500),
                  curve: Curves.easeOutCubic,
                ),

                SizedBox(height: isDesktop ? 6 : 4),

                BlocBuilder<ContactsBloc, ContactsState>(
                  builder: (context, state) {
                    String subtitle = 'در حال بارگذاری...';
                    Color subtitleColor = isDark
                        ? Colors.white60
                        : Colors.black54;

                    if (state.isSuccess && state.hasContacts) {
                      subtitle = '${state.totalNonBlockedContacts} مخاطب';
                      subtitleColor = primaryColor;
                    } else if (state.isLoading || state.isSyncing) {
                      subtitle = 'در حال همگام‌سازی...';
                      subtitleColor = primaryColor;
                    } else if (state.isFailure) {
                      subtitle = 'خطا در بارگذاری';
                      subtitleColor = Colors.red;
                    } else if (state.isSuccess && !state.hasContacts) {
                      subtitle = 'هیچ مخاطبی یافت نشد';
                    }

                    return Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 14,
                        color: subtitleColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ).animate().fadeIn(
                      delay: const Duration(milliseconds: 200),
                    );
                  },
                ),
              ],
            ),
          ),

          // Action Buttons
          Row(
            children: [
              // Refresh Button
              Container(
                width: isDesktop ? 48 : 44,
                height: isDesktop ? 48 : 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF475569)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: IconButton(
                  icon: RotationTransition(
                    turns: _refreshController,
                    child: Icon(
                      Icons.refresh_rounded,
                      color: isDark ? Colors.white70 : Colors.black54,
                      size: isDesktop ? 20 : 18,
                    ),
                  ),
                  onPressed: _handleRefresh,
                ),
              ).animate().scale(
                delay: const Duration(milliseconds: 100),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
              ),

              SizedBox(width: isDesktop ? 12 : 8),

              // Menu Button
              Container(
                width: isDesktop ? 48 : 44,
                height: isDesktop ? 48 : 44,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF475569)
                        : const Color(0xFFE2E8F0),
                    width: 1,
                  ),
                ),
                child: PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: isDark ? Colors.white70 : Colors.black54,
                    size: isDesktop ? 20 : 18,
                  ),
                  offset: Offset(0, isDesktop ? 56 : 52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                  ),
                  onSelected: (value) {
                    switch (value) {
                      case 'sort_name':
                        context.read<ContactsBloc>().add(
                          FilterContacts(sortBy: 'name'),
                        );
                        break;
                      case 'sort_recent':
                        context.read<ContactsBloc>().add(
                          FilterContacts(sortBy: 'lastInteraction'),
                        );
                        break;
                      case 'sort_added':
                        context.read<ContactsBloc>().add(
                          FilterContacts(sortBy: 'dateAdded'),
                        );
                        break;
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'sort_name',
                      child: Row(
                        children: [
                          Icon(
                            Icons.sort_by_alpha_rounded,
                            size: isDesktop ? 20 : 18,
                          ),
                          SizedBox(width: isDesktop ? 12 : 8),
                          Text('مرتب‌سازی بر اساس نام'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'sort_recent',
                      child: Row(
                        children: [
                          Icon(
                            Icons.access_time_rounded,
                            size: isDesktop ? 20 : 18,
                          ),
                          SizedBox(width: isDesktop ? 12 : 8),
                          Text('مرتب‌سازی بر اساس آخرین تعامل'),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'sort_added',
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today_rounded,
                            size: isDesktop ? 20 : 18,
                          ),
                          SizedBox(width: isDesktop ? 12 : 8),
                          Text('مرتب‌سازی بر اساس تاریخ اضافه'),
                        ],
                      ),
                    ),
                  ],
                ),
              ).animate().scale(
                delay: const Duration(milliseconds: 200),
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOutBack,
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== Search Section =====
  Widget _buildSearchSection(
    BuildContext context,
    bool isDark,
    bool isDesktop,
  ) {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      padding: EdgeInsets.fromLTRB(
        isDesktop ? 32 : 24,
        isDesktop ? 24 : 20,
        isDesktop ? 32 : 24,
        isDesktop ? 20 : 16,
      ),
      child:
          Container(
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
                  blurRadius: isDesktop ? 12 : 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: TextField(
              controller: _searchController,
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: isDark ? Colors.white : Colors.black87,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'جستجو در مخاطبین...',
                hintStyle: TextStyle(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: isDesktop ? 16 : 14,
                  fontWeight: FontWeight.w400,
                ),
                prefixIcon: Container(
                  padding: EdgeInsets.all(isDesktop ? 16 : 14),
                  child: Icon(
                    Icons.search_rounded,
                    color: primaryColor,
                    size: isDesktop ? 22 : 20,
                  ),
                ),
                suffixIcon: _searchController.text.isNotEmpty
                    ? Container(
                        padding: EdgeInsets.all(isDesktop ? 12 : 10),
                        child: GestureDetector(
                          onTap: () {
                            _searchController.clear();
                            context.read<ContactsBloc>().add(
                              ClearSearchContacts(),
                            );
                          },
                          child: Container(
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white12 : Colors.black12,
                              borderRadius: BorderRadius.circular(
                                isDesktop ? 12 : 10,
                              ),
                            ),
                            child: Icon(
                              Icons.clear_rounded,
                              color: isDark ? Colors.white60 : Colors.black54,
                              size: isDesktop ? 18 : 16,
                            ),
                          ),
                        ),
                      )
                    : null,
                border: InputBorder.none,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 20 : 16,
                  vertical: isDesktop ? 20 : 16,
                ),
              ),
            ),
          ).animate().slideY(
            begin: -0.3,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          ),
    );
  }

  // ===== Tab Section =====
  Widget _buildTabSection(
    BuildContext context,
    ContactsState state,
    bool isDark,
    bool isDesktop,
  ) {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      margin: EdgeInsets.symmetric(horizontal: isDesktop ? 32 : 24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: isDesktop ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        child: TabBar(
          controller: _tabController,
          labelColor: primaryColor,
          unselectedLabelColor: isDark ? Colors.white54 : Colors.black54,
          labelStyle: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.w600,
          ),
          unselectedLabelStyle: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            fontWeight: FontWeight.w500,
          ),
          indicator: BoxDecoration(
            color: primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
          ),
          indicatorSize: TabBarIndicatorSize.tab,
          dividerColor: Colors.transparent,
          tabs: [
            Tab(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 8 : 4,
                  vertical: isDesktop ? 12 : 10,
                ),
                child: Text('همه (${state.totalNonBlockedContacts})'),
              ),
            ),
            Tab(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 8 : 4,
                  vertical: isDesktop ? 12 : 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.star_rounded, size: isDesktop ? 16 : 14),
                    SizedBox(width: isDesktop ? 6 : 4),
                    Text('(${state.totalFavoriteContacts})'),
                  ],
                ),
              ),
            ),
            Tab(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 8 : 4,
                  vertical: isDesktop ? 12 : 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.access_time_rounded, size: isDesktop ? 16 : 14),
                    SizedBox(width: isDesktop ? 6 : 4),
                    Text('اخیر'),
                  ],
                ),
              ),
            ),
            Tab(
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 8 : 4,
                  vertical: isDesktop ? 12 : 10,
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.block_rounded, size: isDesktop ? 16 : 14),
                    SizedBox(width: isDesktop ? 6 : 4),
                    Text('(${state.totalBlockedContacts})'),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().slideY(
      begin: -0.2,
      delay: const Duration(milliseconds: 300),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }

  // ===== Tab Content Methods =====
  Widget _buildAllContactsTab(
    BuildContext context,
    ContactsState state,
    bool isDark,
    bool isDesktop,
  ) {
    if (state.isSearching && _searchController.text.isNotEmpty) {
      return _buildSearchResults(context, state, isDark, isDesktop);
    }

    if (state.isLoading) {
      return _buildLoadingState(context, isDark, isDesktop);
    }

    if (state.isSyncing) {
      return _buildSyncingState(context, state, isDark, isDesktop);
    }

    if (state.isPermissionDenied) {
      return _buildPermissionDeniedState(context, isDark, isDesktop);
    }

    if (state.isPermissionPermanentlyDenied) {
      return _buildPermissionPermanentlyDeniedState(context, isDark, isDesktop);
    }

    if (state.isFailure) {
      return _buildErrorState(
        context,
        state.errorMessage ?? 'خطای نامشخص',
        isDark,
        isDesktop,
      );
    }

    if (state.nonBlockedContacts.isEmpty) {
      return _buildEmptyState(context, isDark, isDesktop);
    }

    return _buildContactsList(
      context,
      state.nonBlockedContacts,
      isDark,
      isDesktop,
    );
  }

  Widget _buildFavoritesTab(
    BuildContext context,
    ContactsState state,
    bool isDark,
    bool isDesktop,
  ) {
    if (state.isLoadingFavorites) {
      return _buildLoadingState(context, isDark, isDesktop);
    }

    if (state.favoriteNonBlockedContacts.isEmpty) {
      return _buildEmptyFavoritesState(context, isDark, isDesktop);
    }

    return _buildContactsList(
      context,
      state.favoriteNonBlockedContacts,
      isDark,
      isDesktop,
    );
  }

  Widget _buildRecentTab(
    BuildContext context,
    ContactsState state,
    bool isDark,
    bool isDesktop,
  ) {
    if (state.isLoadingRecent) {
      return _buildLoadingState(context, isDark, isDesktop);
    }

    if (state.recentContacts.isEmpty) {
      return _buildEmptyRecentState(context, isDark, isDesktop);
    }

    return _buildContactsList(context, state.recentContacts, isDark, isDesktop);
  }

  Widget _buildBlockedTab(
    BuildContext context,
    ContactsState state,
    bool isDark,
    bool isDesktop,
  ) {
    if (state.blockedContacts.isEmpty) {
      return _buildEmptyBlockedState(context, isDark, isDesktop);
    }

    return _buildContactsList(
      context,
      state.blockedContacts,
      isDark,
      isDesktop,
      showBlockedOptions: true,
    );
  }

  Widget _buildSearchResults(
    BuildContext context,
    ContactsState state,
    bool isDark,
    bool isDesktop,
  ) {
    if (state.isSearching) {
      return _buildLoadingState(context, isDark, isDesktop);
    }

    if (state.searchResults.isEmpty) {
      return _buildEmptySearchState(context, isDark, isDesktop);
    }

    return _buildContactsList(context, state.searchResults, isDark, isDesktop);
  }

  // ===== Contact List =====
  Widget _buildContactsList(
    BuildContext context,
    List<UserModel> contacts,
    bool isDark,
    bool isDesktop, {
    bool showBlockedOptions = false,
  }) {
    return RefreshIndicator(
      onRefresh: _handleRefresh,
      color: Theme.of(context).primaryColor,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      child: ListView.separated(
        padding: EdgeInsets.fromLTRB(
          isDesktop ? 32 : 24,
          isDesktop ? 24 : 20,
          isDesktop ? 32 : 24,
          isDesktop ? 100 : 80, // Extra padding for FAB
        ),
        itemCount: contacts.length,
        separatorBuilder: (context, index) =>
            SizedBox(height: isDesktop ? 12 : 8),
        itemBuilder: (context, index) {
          final contact = contacts[index];
          return _ModernContactTile(
                contact: contact,
                isDesktop: isDesktop,
                isDark: isDark,
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
              )
              .animate(delay: Duration(milliseconds: index * 50))
              .slideX(
                begin: 0.3,
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutCubic,
              )
              .fadeIn();
        },
      ),
    );
  }

  // ===== State Widgets =====
  Widget _buildLoadingState(BuildContext context, bool isDark, bool isDesktop) {
    final primaryColor = Theme.of(context).primaryColor;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isDesktop ? 80 : 64,
            height: isDesktop ? 80 : 64,
            decoration: BoxDecoration(
              color: primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
              border: Border.all(
                color: primaryColor.withOpacity(0.2),
                width: 2,
              ),
            ),
            child: Center(
              child: SizedBox(
                width: isDesktop ? 32 : 24,
                height: isDesktop ? 32 : 24,
                child: CircularProgressIndicator(
                  color: primaryColor,
                  strokeWidth: 3,
                ),
              ),
            ),
          ).animate().scale(
            duration: const Duration(milliseconds: 800),
            curve: Curves.elasticOut,
          ),

          SizedBox(height: isDesktop ? 32 : 24),

          Text(
            'در حال بارگذاری مخاطبین...',
            style: TextStyle(
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 400)),

          SizedBox(height: isDesktop ? 12 : 8),

          Text(
            'لطفاً صبر کنید',
            style: TextStyle(
              fontSize: isDesktop ? 14 : 12,
              color: isDark ? Colors.white60 : Colors.black54,
              fontWeight: FontWeight.w400,
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 600)),
        ],
      ),
    );
  }

  Widget _buildSyncingState(
    BuildContext context,
    ContactsState state,
    bool isDark,
    bool isDesktop,
  ) {
    final primaryColor = Theme.of(context).primaryColor;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
                width: isDesktop ? 100 : 80,
                height: isDesktop ? 100 : 80,
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.2),
                    width: 2,
                  ),
                ),
                child: Center(
                  child: Icon(
                    Icons.sync_rounded,
                    color: primaryColor,
                    size: isDesktop ? 40 : 32,
                  ),
                ),
              )
              .animate()
              .rotate(duration: const Duration(seconds: 2))
              .then()
              .scale(duration: const Duration(milliseconds: 500)),

          SizedBox(height: isDesktop ? 32 : 24),

          Text(
            'در حال همگام‌سازی مخاطبین...',
            style: TextStyle(
              fontSize: isDesktop ? 20 : 18,
              fontWeight: FontWeight.w700,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ).animate().slideY(
            begin: 0.3,
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          ),

          SizedBox(height: isDesktop ? 16 : 12),

          Text(
            '${state.syncedCount} از ${state.totalContacts}',
            style: TextStyle(
              fontSize: isDesktop ? 16 : 14,
              color: primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 300)),

          SizedBox(height: isDesktop ? 24 : 20),

          Container(
            width: isDesktop ? 300 : 250,
            height: isDesktop ? 8 : 6,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(isDesktop ? 4 : 3),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(isDesktop ? 4 : 3),
              child: LinearProgressIndicator(
                value: state.syncProgress,
                backgroundColor: Colors.transparent,
                valueColor: AlwaysStoppedAnimation<Color>(primaryColor),
              ),
            ),
          ).animate().slideX(
            begin: -0.5,
            delay: const Duration(milliseconds: 500),
            duration: const Duration(milliseconds: 800),
            curve: Curves.easeOutCubic,
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedState(
    BuildContext context,
    bool isDark,
    bool isDesktop,
  ) {
    final primaryColor = Theme.of(context).primaryColor;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 48 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 120 : 100,
              height: isDesktop ? 120 : 100,
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                border: Border.all(
                  color: Colors.orange.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.contact_page_outlined,
                color: Colors.orange,
                size: isDesktop ? 60 : 50,
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
            ),

            SizedBox(height: isDesktop ? 32 : 24),

            Text(
              'دسترسی به مخاطبین',
              style: TextStyle(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ).animate().slideY(
              begin: 0.3,
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),

            SizedBox(height: isDesktop ? 16 : 12),

            Text(
              'برای نمایش مخاطبین و امکان چت با آن‌ها،\nنیاز به دسترسی به مخاطبین دستگاه شما داریم.',
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: const Duration(milliseconds: 400)),

            SizedBox(height: isDesktop ? 32 : 24),

            SizedBox(
              width: double.infinity,
              height: isDesktop ? 56 : 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.read<ContactsBloc>().add(ContactsProcessStarted());
                },
                icon: Icon(Icons.security_rounded, size: isDesktop ? 20 : 18),
                label: Text(
                  'اجازه دسترسی',
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                  ),
                ),
              ),
            ).animate().slideY(
              begin: 0.3,
              delay: const Duration(milliseconds: 600),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionPermanentlyDeniedState(
    BuildContext context,
    bool isDark,
    bool isDesktop,
  ) {
    final primaryColor = Theme.of(context).primaryColor;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 48 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 120 : 100,
              height: isDesktop ? 120 : 100,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.error_outline_rounded,
                color: Colors.red,
                size: isDesktop ? 60 : 50,
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
            ),

            SizedBox(height: isDesktop ? 32 : 24),

            Text(
              'دسترسی رد شده',
              style: TextStyle(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ).animate().slideY(
              begin: 0.3,
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),

            SizedBox(height: isDesktop ? 16 : 12),

            Text(
              'دسترسی به مخاطبین به طور دائمی رد شده است.\nلطفاً از تنظیمات دستگاه، دسترسی را فعال کنید.',
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: const Duration(milliseconds: 400)),

            SizedBox(height: isDesktop ? 32 : 24),

            SizedBox(
              width: double.infinity,
              height: isDesktop ? 56 : 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  openAppSettings();
                },
                icon: Icon(Icons.settings_rounded, size: isDesktop ? 20 : 18),
                label: Text(
                  'باز کردن تنظیمات',
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                  ),
                ),
              ),
            ).animate().slideY(
              begin: 0.3,
              delay: const Duration(milliseconds: 600),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(
    BuildContext context,
    String message,
    bool isDark,
    bool isDesktop,
  ) {
    final primaryColor = Theme.of(context).primaryColor;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 48 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 120 : 100,
              height: isDesktop ? 120 : 100,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.cloud_off_rounded,
                color: Colors.red,
                size: isDesktop ? 60 : 50,
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
            ),

            SizedBox(height: isDesktop ? 32 : 24),

            Text(
              'خطا در بارگذاری',
              style: TextStyle(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ).animate().slideY(
              begin: 0.3,
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),

            SizedBox(height: isDesktop ? 16 : 12),

            Text(
              message,
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: const Duration(milliseconds: 400)),

            SizedBox(height: isDesktop ? 32 : 24),

            SizedBox(
              width: double.infinity,
              height: isDesktop ? 56 : 52,
              child: ElevatedButton.icon(
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.read<ContactsBloc>().add(RefreshContacts());
                },
                icon: Icon(Icons.refresh_rounded, size: isDesktop ? 20 : 18),
                label: Text(
                  'تلاش مجدد',
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                  ),
                ),
              ),
            ).animate().slideY(
              begin: 0.3,
              delay: const Duration(milliseconds: 600),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),
          ],
        ),
      ),
    );
  }

  // ===== Empty State Widgets =====
  Widget _buildEmptyState(BuildContext context, bool isDark, bool isDesktop) {
    final primaryColor = Theme.of(context).primaryColor;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 48 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 120 : 100,
              height: isDesktop ? 120 : 100,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                border: Border.all(
                  color: primaryColor.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.people_outline_rounded,
                color: primaryColor,
                size: isDesktop ? 60 : 50,
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
            ),

            SizedBox(height: isDesktop ? 32 : 24),

            Text(
              'هیچ مخاطبی یافت نشد',
              style: TextStyle(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ).animate().slideY(
              begin: 0.3,
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),

            SizedBox(height: isDesktop ? 16 : 12),

            Text(
              'مخاطبین شما در اینجا نمایش داده خواهند شد.\nبا دوستان خود به گفتگو بپردازید!',
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: const Duration(milliseconds: 400)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyFavoritesState(
    BuildContext context,
    bool isDark,
    bool isDesktop,
  ) {
    final primaryColor = Theme.of(context).primaryColor;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 48 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 120 : 100,
              height: isDesktop ? 120 : 100,
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                border: Border.all(
                  color: Colors.amber.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.star_border_rounded,
                color: Colors.amber,
                size: isDesktop ? 60 : 50,
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
            ),

            SizedBox(height: isDesktop ? 32 : 24),

            Text(
              'هیچ مخاطب مورد علاقه‌ای ندارید',
              style: TextStyle(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ).animate().slideY(
              begin: 0.3,
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),

            SizedBox(height: isDesktop ? 16 : 12),

            Text(
              'مخاطبین مورد علاقه‌تان اینجا نمایش داده می‌شوند.\nبرای اضافه کردن، روی ستاره کنار هر مخاطب ضربه بزنید.',
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: const Duration(milliseconds: 400)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyRecentState(
    BuildContext context,
    bool isDark,
    bool isDesktop,
  ) {
    final primaryColor = Theme.of(context).primaryColor;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 48 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 120 : 100,
              height: isDesktop ? 120 : 100,
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                border: Border.all(
                  color: Colors.blue.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.access_time_rounded,
                color: Colors.blue,
                size: isDesktop ? 60 : 50,
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
            ),

            SizedBox(height: isDesktop ? 32 : 24),

            Text(
              'هیچ تعامل اخیری ندارید',
              style: TextStyle(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ).animate().slideY(
              begin: 0.3,
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),

            SizedBox(height: isDesktop ? 16 : 12),

            Text(
              'مخاطبینی که اخیراً با آن‌ها چت داشته‌اید\nاینجا نمایش داده می‌شوند.',
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: const Duration(milliseconds: 400)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyBlockedState(
    BuildContext context,
    bool isDark,
    bool isDesktop,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 48 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 120 : 100,
              height: isDesktop ? 120 : 100,
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                border: Border.all(
                  color: Colors.red.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.block_rounded,
                color: Colors.red,
                size: isDesktop ? 60 : 50,
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
            ),

            SizedBox(height: isDesktop ? 32 : 24),

            Text(
              'هیچ مخاطب مسدودی ندارید',
              style: TextStyle(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ).animate().slideY(
              begin: 0.3,
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),

            SizedBox(height: isDesktop ? 16 : 12),

            Text(
              'مخاطبین مسدود شده اینجا نمایش داده می‌شوند.\nمی‌توانید آن‌ها را از منوی مخاطبین مسدود کنید.',
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: const Duration(milliseconds: 400)),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptySearchState(
    BuildContext context,
    bool isDark,
    bool isDesktop,
  ) {
    return Center(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 48 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 120 : 100,
              height: isDesktop ? 120 : 100,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                border: Border.all(
                  color: Colors.grey.withOpacity(0.3),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.search_off_rounded,
                color: Colors.grey,
                size: isDesktop ? 60 : 50,
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 800),
              curve: Curves.elasticOut,
            ),

            SizedBox(height: isDesktop ? 32 : 24),

            Text(
              'نتیجه‌ای یافت نشد',
              style: TextStyle(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
              textAlign: TextAlign.center,
            ).animate().slideY(
              begin: 0.3,
              delay: const Duration(milliseconds: 200),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
            ),

            SizedBox(height: isDesktop ? 16 : 12),

            Text(
              'مخاطبی با این نام یا شماره پیدا نشد.\nجستجوی دیگری امتحان کنید.',
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ).animate().fadeIn(delay: const Duration(milliseconds: 400)),
          ],
        ),
      ),
    );
  }

  // ===== FAB =====
  Widget _buildModernFAB(BuildContext context, bool isDark, bool isDesktop) {
    final primaryColor = Theme.of(context).primaryColor;

    return ScaleTransition(
      scale: _fabController,
      child: Container(
        width: isDesktop ? 64 : 56,
        height: isDesktop ? 64 : 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [primaryColor, primaryColor.withOpacity(0.8)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
          boxShadow: [
            BoxShadow(
              color: primaryColor.withOpacity(0.4),
              blurRadius: isDesktop ? 20 : 16,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () {
              HapticFeedback.lightImpact();
              // Navigate to add contact or create new chat
            },
            borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
            child: Center(
              child: Icon(
                Icons.person_add_rounded,
                color: Colors.white,
                size: isDesktop ? 28 : 24,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ===== Event Handlers =====
  void _onContactTap(UserModel contact) {
    if (_currentUser != null) {
      HapticFeedback.selectionClick();
      context.read<ContactsBloc>().add(
        StartChatWithContact(recipient: contact, currentUser: _currentUser!),
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
        content: Row(
          children: [
            Icon(Icons.error_outline_rounded, color: Colors.white),
            SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: EdgeInsets.all(16),
      ),
    );
  }
}

// ===== Modern Contact Tile Widget =====
class _ModernContactTile extends StatelessWidget {
  final UserModel contact;
  final bool isDesktop;
  final bool isDark;
  final VoidCallback onTap;
  final Function(bool) onFavorite;
  final Function(bool) onBlock;
  final Function(String?) onEditName;
  final VoidCallback onRemove;
  final bool showBlockedOptions;

  const _ModernContactTile({
    required this.contact,
    required this.isDesktop,
    required this.isDark,
    required this.onTap,
    required this.onFavorite,
    required this.onBlock,
    required this.onEditName,
    required this.onRemove,
    this.showBlockedOptions = false,
  });

  @override
  Widget build(BuildContext context) {
    final primaryColor = Theme.of(context).primaryColor;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.04),
            blurRadius: isDesktop ? 12 : 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 20 : 16),
            child: Row(
              children: [
                // Avatar
                _buildAvatar(context, primaryColor),

                SizedBox(width: isDesktop ? 16 : 12),

                // Contact Info
                Expanded(child: _buildContactInfo(context)),

                // Status & Actions
                _buildTrailingSection(context, primaryColor),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context, Color primaryColor) {
    return Stack(
      children: [
        Container(
          width: isDesktop ? 60 : 52,
          height: isDesktop ? 60 : 52,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: contact.profilePictureUrl != null
                  ? [Colors.transparent, Colors.transparent]
                  : [primaryColor, primaryColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.2),
                blurRadius: isDesktop ? 8 : 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
            child: contact.profilePictureUrl != null
                ? Image.network(
                    contact.profilePictureUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      return _buildAvatarInitials(primaryColor);
                    },
                  )
                : _buildAvatarInitials(primaryColor),
          ),
        ),

        // Online Status Indicator
        if (contact.isOnline && !showBlockedOptions)
          Positioned(
            bottom: 0,
            right: 0,
            child: Container(
              width: isDesktop ? 18 : 16,
              height: isDesktop ? 18 : 16,
              decoration: BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildAvatarInitials(Color primaryColor) {
    return Center(
      child: Text(
        contact.avatarInitials,
        style: TextStyle(
          color: Colors.white,
          fontSize: isDesktop ? 24 : 20,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildContactInfo(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name
        Text(
          contact.fullName,
          style: TextStyle(
            fontSize: isDesktop ? 18 : 16,
            fontWeight: FontWeight.w600,
            color: isDark ? Colors.white : Colors.black87,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        SizedBox(height: isDesktop ? 6 : 4),

        // Phone Number
        Text(
          contact.phoneNumber ?? 'شماره نامشخص',
          style: TextStyle(
            fontSize: isDesktop ? 14 : 12,
            color: isDark ? Colors.white60 : Colors.black54,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),

        // Last Seen
        if (contact.lastSeenText.isNotEmpty) ...[
          SizedBox(height: isDesktop ? 4 : 2),
          Row(
            children: [
              Icon(
                Icons.access_time_rounded,
                size: isDesktop ? 12 : 10,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              SizedBox(width: isDesktop ? 4 : 2),
              Expanded(
                child: Text(
                  contact.lastSeenText,
                  style: TextStyle(
                    fontSize: isDesktop ? 12 : 10,
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],

        // Last Message
        if (contact.lastMessage != null && contact.lastMessage!.isNotEmpty) ...[
          SizedBox(height: isDesktop ? 4 : 2),
          Row(
            children: [
              Icon(
                Icons.chat_bubble_outline_rounded,
                size: isDesktop ? 12 : 10,
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              SizedBox(width: isDesktop ? 4 : 2),
              Expanded(
                child: Text(
                  contact.lastMessage!,
                  style: TextStyle(
                    fontSize: isDesktop ? 12 : 10,
                    color: isDark ? Colors.white38 : Colors.black38,
                    fontWeight: FontWeight.w400,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildTrailingSection(BuildContext context, Color primaryColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // Status Indicators
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Favorite Star
            if (contact.isFavorite)
              Container(
                padding: EdgeInsets.all(isDesktop ? 6 : 4),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isDesktop ? 8 : 6),
                ),
                child: Icon(
                  Icons.star_rounded,
                  color: Colors.amber,
                  size: isDesktop ? 16 : 14,
                ),
              ),

            if (contact.isFavorite) SizedBox(width: isDesktop ? 8 : 6),

            // Unread Count
            if (contact.unreadCount > 0)
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? 8 : 6,
                  vertical: isDesktop ? 4 : 2,
                ),
                decoration: BoxDecoration(
                  color: primaryColor,
                  borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                ),
                child: Text(
                  contact.unreadCount.toString(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: isDesktop ? 12 : 10,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),

            if (contact.unreadCount > 0) SizedBox(width: isDesktop ? 8 : 6),

            // Menu Button
            Container(
              width: isDesktop ? 36 : 32,
              height: isDesktop ? 36 : 32,
              decoration: BoxDecoration(
                color: isDark ? Colors.white12 : Colors.black12,
                borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
              ),
              child: PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert_rounded,
                  size: isDesktop ? 18 : 16,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                offset: Offset(0, isDesktop ? 40 : 36),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
                ),
                onSelected: (value) => _handleMenuAction(context, value),
                itemBuilder: (context) => _buildMenuItems(),
              ),
            ),
          ],
        ),
      ],
    );
  }

  List<PopupMenuEntry<String>> _buildMenuItems() {
    if (showBlockedOptions) {
      return [
        PopupMenuItem(
          value: 'unblock',
          child: Row(
            children: [
              Icon(
                Icons.check_circle_outline_rounded,
                size: isDesktop ? 18 : 16,
              ),
              SizedBox(width: isDesktop ? 12 : 8),
              Text('رفع مسدودیت'),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'remove',
          child: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color: Colors.red,
                size: isDesktop ? 18 : 16,
              ),
              SizedBox(width: isDesktop ? 12 : 8),
              Text('حذف مخاطب', style: TextStyle(color: Colors.red)),
            ],
          ),
        ),
      ];
    }

    return [
      PopupMenuItem(
        value: 'favorite',
        child: Row(
          children: [
            Icon(
              contact.isFavorite
                  ? Icons.star_rounded
                  : Icons.star_border_rounded,
              color: contact.isFavorite ? Colors.amber : null,
              size: isDesktop ? 18 : 16,
            ),
            SizedBox(width: isDesktop ? 12 : 8),
            Text(
              contact.isFavorite
                  ? 'حذف از علاقه‌مندی‌ها'
                  : 'افزودن به علاقه‌مندی‌ها',
            ),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'edit_name',
        child: Row(
          children: [
            Icon(Icons.edit_rounded, size: isDesktop ? 18 : 16),
            SizedBox(width: isDesktop ? 12 : 8),
            Text('ویرایش نام'),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'block',
        child: Row(
          children: [
            Icon(
              Icons.block_rounded,
              color: Colors.orange,
              size: isDesktop ? 18 : 16,
            ),
            SizedBox(width: isDesktop ? 12 : 8),
            Text('مسدود کردن', style: TextStyle(color: Colors.orange)),
          ],
        ),
      ),
      PopupMenuItem(
        value: 'remove',
        child: Row(
          children: [
            Icon(
              Icons.delete_outline_rounded,
              color: Colors.red,
              size: isDesktop ? 18 : 16,
            ),
            SizedBox(width: isDesktop ? 12 : 8),
            Text('حذف مخاطب', style: TextStyle(color: Colors.red)),
          ],
        ),
      ),
    ];
  }

  void _handleMenuAction(BuildContext context, String value) {
    HapticFeedback.lightImpact();

    switch (value) {
      case 'favorite':
        onFavorite(!contact.isFavorite);
        break;
      case 'block':
        _showBlockConfirmation(context);
        break;
      case 'unblock':
        onBlock(false);
        break;
      case 'edit_name':
        _showEditNameDialog(context);
        break;
      case 'remove':
        _showRemoveConfirmation(context);
        break;
    }
  }

  void _showBlockConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        ),
        title: Text('مسدود کردن مخاطب'),
        content: Text(
          'آیا مطمئن هستید که می‌خواهید ${contact.fullName} را مسدود کنید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onBlock(true);
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
            child: Text('مسدود کردن'),
          ),
        ],
      ),
    );
  }

  void _showRemoveConfirmation(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        ),
        title: Text('حذف مخاطب'),
        content: Text(
          'آیا مطمئن هستید که می‌خواهید ${contact.fullName} را حذف کنید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onRemove();
            },
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: Text('حذف'),
          ),
        ],
      ),
    );
  }

  void _showEditNameDialog(BuildContext context) {
    final controller = TextEditingController(text: contact.fullName);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
        ),
        title: Text('ویرایش نام مخاطب'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'نام جدید',
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text('انصراف'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              onEditName(
                controller.text.trim().isEmpty ? null : controller.text.trim(),
              );
            },
            child: Text('ذخیره'),
          ),
        ],
      ),
    );
  }
}
