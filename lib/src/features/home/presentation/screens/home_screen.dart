import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:solvix/src/core/api/chat/chat_service.dart';
import 'package:solvix/src/core/api/search_service.dart';
import 'package:solvix/src/core/api/user/user_service.dart';
import 'package:solvix/src/core/models/chat_model.dart';
import 'package:solvix/src/core/models/search_result_model.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/core/network/signalr_service.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_state.dart'
    as auth_bloc_states;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:solvix/src/features/chat/presentation/bloc/chat_messages_bloc.dart';
import 'package:solvix/src/features/chat/presentation/screens/chat_screen.dart';
import 'package:solvix/src/features/home/presentation/bloc/chat_list_bloc.dart';
import 'package:solvix/src/features/home/presentation/bloc/search_bloc.dart';
import 'package:solvix/src/features/home/presentation/bloc/search_event.dart';
import 'package:solvix/src/features/home/presentation/bloc/search_state.dart';
import 'package:solvix/src/features/new_chat/presentation/bloc/new_chat_bloc.dart';
import 'package:solvix/src/features/new_chat/presentation/bloc/new_chat_event.dart';
import 'package:solvix/src/features/new_chat/presentation/screens/new_chat_screen.dart';
import 'package:solvix/src/features/settings/presentation/screens/settings_screen.dart';
import 'package:solvix/src/features/new_chat/presentation/screens/create_group_screen.dart';
import 'package:solvix/src/features/contacts/presentation/screens/contacts_screen.dart';
import 'package:solvix/src/core/network/notification_service.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../contacts/presentation/bloc/contacts_bloc.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin {
  UserModel? _currentUser;
  bool _isChatListFetchInitiated = false;
  bool _isInitDone = false;
  int _selectedIndex = 0;
  late List<Widget> _widgetOptions;
  late AnimationController _appBarAnimationController;
  late AnimationController _fabAnimationController;

  bool _isSearching = false;
  final _searchController = TextEditingController();
  late final SearchBloc _searchBloc;

  @override
  void initState() {
    super.initState();
    _appBarAnimationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );

    // Start animations
    _appBarAnimationController.forward();
    _fabAnimationController.forward();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitDone) {
      context.read<NotificationService>().initialize();
      _searchBloc = SearchBloc(context.read<SearchService>());

      final authState = context.read<AuthBloc>().state;
      if (authState is auth_bloc_states.AuthSuccess) {
        _currentUser = authState.user;
      }

      _searchController.addListener(() {
        _searchBloc.add(SearchQueryChanged(_searchController.text));
      });

      if (_currentUser != null) {
        final currentChatListState = context.read<ChatListBloc>().state;
        if (currentChatListState is! ChatListLoaded &&
            currentChatListState is! ChatListError) {
          context.read<ChatListBloc>().add(FetchChatList());
          _isChatListFetchInitiated = true;
        } else if (currentChatListState is ChatListLoaded) {
          _isChatListFetchInitiated = true;
        }
      }
      _isInitDone = true;
    }
  }

  @override
  void dispose() {
    _appBarAnimationController.dispose();
    _fabAnimationController.dispose();
    _searchController.dispose();
    _searchBloc.close();
    super.dispose();
  }

  void _buildWidgetOptions() {
    _widgetOptions = <Widget>[
      _buildChatListTabContent(),
      const ContactsScreen(),
      SettingsScreen(currentUser: _currentUser),
    ];
  }

  void _onItemTapped(int index) {
    HapticFeedback.selectionClick();
    setState(() {
      _selectedIndex = index;
    });
  }

  String _getAppBarTitle() {
    final userName =
        _currentUser?.firstName ?? _currentUser?.username ?? 'سالویکس';
    switch (_selectedIndex) {
      case 0:
        return userName;
      case 1:
        return 'مخاطبین';
      case 2:
        return 'تنظیمات';
      default:
        return 'سالویکس';
    }
  }

  void _toggleSearch() {
    HapticFeedback.lightImpact();
    setState(() {
      _isSearching = !_isSearching;
    });
    if (!_isSearching) {
      _searchController.clear();
      _searchBloc.add(ClearSearch());
    }
  }

  void _handleSearchResultTap(SearchResultModel result) async {
    if (result.type == 'chat' && result.entity is ChatModel) {
      final chat = result.entity as ChatModel;
      _toggleSearch();
      await Future.delayed(const Duration(milliseconds: 100));

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
        context.read<ChatListBloc>().add(FetchChatList());
      });
    } else if (result.type == 'user' && result.entity is UserModel) {
      final user = result.entity as UserModel;
      _startChatWithUser(user);
    }
  }

  void _startChatWithUser(UserModel recipientUser) async {
    if (_currentUser == null) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => _buildLoadingDialog(),
    );

    try {
      final chatService = context.read<ChatService>();
      final result = await chatService.startChatWithUser(recipientUser.id);
      final chatId = result['chatId'] as String;

      Navigator.of(context, rootNavigator: true).pop();

      _toggleSearch();
      await Future.delayed(const Duration(milliseconds: 100));

      context.read<ChatListBloc>().add(FetchChatList());

      final tempChatModel = ChatModel(
        id: chatId,
        isGroup: false,
        title:
            "${recipientUser.firstName ?? ''} ${recipientUser.lastName ?? ''}"
                .trim(),
        createdAt: DateTime.now(),
        participants: [_currentUser!, recipientUser],
        unreadCount: 0,
      );

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BlocProvider(
            create: (blocContext) => ChatMessagesBloc(
              blocContext.read<ChatService>(),
              blocContext.read<SignalRService>(),
              chatId: tempChatModel.id,
              currentUserId: _currentUser!.id,
            ),
            child: ChatScreen(
              chatModel: tempChatModel,
              currentUser: _currentUser,
            ),
          ),
        ),
      ).then((_) {
        context.read<ChatListBloc>().add(FetchChatList());
      });
    } catch (e) {
      Navigator.of(context, rootNavigator: true).pop();
      if (context.mounted) {
        _showErrorSnackBar(
          'خطا در شروع چت: ${e.toString().replaceFirst("Exception: ", "")}',
        );
      }
    }
  }

  Widget _buildLoadingDialog() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child:
          Container(
            width: 90,
            height: 90,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 28,
                  height: 28,
                  child: CircularProgressIndicator(
                    color: Theme.of(context).primaryColor,
                    strokeWidth: 2.5,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'در حال اتصال...',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ).animate().scale(
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutBack,
          ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.error_outline_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFFE53E3E),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        elevation: 0,
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_currentUser == null &&
        context.read<AuthBloc>().state is! auth_bloc_states.AuthSuccess) {
      return _buildLoadingScreen();
    }
    _buildWidgetOptions();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFFFFFFF),
      appBar: _isSearching
          ? _buildSearchAppBar(context, isDesktop)
          : _buildDefaultAppBar(context, isDesktop),
      body: _isSearching
          ? _buildSearchResults(isDesktop)
          : _buildPrimaryContent(context, isDesktop),
      bottomNavigationBar: _isSearching
          ? null
          : _buildTelegramBottomNavBar(context, isDesktop),
      floatingActionButton: (_isSearching || _selectedIndex != 0)
          ? null
          : _buildTelegramFAB(context, isDesktop),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildLoadingScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFFFFFFF),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 64 : 56,
              height: isDesktop ? 64 : 56,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.2),
                    blurRadius: isDesktop ? 12 : 10,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: SizedBox(
                  width: isDesktop ? 28 : 24,
                  height: isDesktop ? 28 : 24,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: isDesktop ? 2.5 : 2,
                  ),
                ),
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
            ),
            SizedBox(height: isDesktop ? 24 : 20),
            Text(
              'در حال بارگذاری...',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: isDesktop ? 16 : 14,
                fontWeight: FontWeight.w500,
              ),
            ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
          ],
        ),
      ),
    );
  }

  Widget _buildPrimaryContent(BuildContext context, bool isDesktop) {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 250),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.0, 0.02),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: animation,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: child,
          ),
        );
      },
      child: IndexedStack(
        key: ValueKey(_selectedIndex),
        index: _selectedIndex,
        children: _widgetOptions,
      ),
    );
  }

  PreferredSizeWidget _buildDefaultAppBar(
    BuildContext context,
    bool isDesktop,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      title: AnimatedBuilder(
        animation: _appBarAnimationController,
        builder: (context, child) {
          return SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(-0.2, 0),
                  end: Offset.zero,
                ).animate(
                  CurvedAnimation(
                    parent: _appBarAnimationController,
                    curve: Curves.easeOutCubic,
                  ),
                ),
            child: FadeTransition(
              opacity: _appBarAnimationController,
              child: Text(
                _getAppBarTitle(),
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: isDesktop ? 22 : 19,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            ),
          );
        },
      ),
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFFFFFFF),
      elevation: 0,
      scrolledUnderElevation: 0,
      actions: _selectedIndex == 0
          ? [
              Container(
                margin: EdgeInsets.only(left: isDesktop ? 20 : 16),
                child: AnimatedBuilder(
                  animation: _appBarAnimationController,
                  builder: (context, child) {
                    return ScaleTransition(
                      scale: Tween<double>(begin: 0.0, end: 1.0).animate(
                        CurvedAnimation(
                          parent: _appBarAnimationController,
                          curve: const Interval(
                            0.3,
                            1.0,
                            curve: Curves.easeOutBack,
                          ),
                        ),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.search,
                          color: isDark ? Colors.white : Colors.black87,
                          size: isDesktop ? 24 : 22,
                        ),
                        tooltip: 'جستجو',
                        onPressed: _toggleSearch,
                        style: IconButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          foregroundColor: isDark
                              ? Colors.white
                              : Colors.black87,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ]
          : null,
    );
  }

  PreferredSizeWidget _buildSearchAppBar(BuildContext context, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      backgroundColor: isDark
          ? const Color(0xFF0D1117)
          : const Color(0xFFFFFFFF),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: isDark ? Colors.white : Colors.black87,
          size: isDesktop ? 24 : 22,
        ),
        onPressed: _toggleSearch,
      ).animate().slideX(begin: -0.2, curve: Curves.easeOutCubic),
      title: Container(
        height: isDesktop ? 44 : 38,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(
            fontSize: isDesktop ? 16 : 15,
            fontWeight: FontWeight.w400,
            color: isDark ? Colors.white : Colors.black87,
          ),
          decoration: InputDecoration(
            hintText: "جستجوی چت‌ها و کاربران...",
            border: InputBorder.none,
            contentPadding: EdgeInsets.symmetric(
              horizontal: isDesktop ? 16 : 14,
              vertical: isDesktop ? 12 : 10,
            ),
            hintStyle: TextStyle(
              color: isDark ? Colors.white54 : Colors.black45,
              fontWeight: FontWeight.w400,
            ),
            prefixIcon: Icon(
              Icons.search,
              color: isDark ? Colors.white54 : Colors.black45,
              size: isDesktop ? 20 : 18,
            ),
          ),
        ),
      ).animate().slideY(begin: -0.2, curve: Curves.easeOutCubic),
      actions: [
        if (_searchController.text.isNotEmpty)
          IconButton(
            icon: Icon(
              Icons.clear,
              color: isDark ? Colors.white54 : Colors.black45,
              size: isDesktop ? 20 : 18,
            ),
            onPressed: () {
              HapticFeedback.lightImpact();
              _searchController.clear();
            },
          ).animate().scale(curve: Curves.easeOutBack),
      ],
    );
  }

  void _showNewConversationModal(BuildContext context, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.3 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 28 : 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Handle bar
                Center(
                  child: Container(
                    width: isDesktop ? 50 : 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF3A3A3A)
                          : const Color(0xFFE0E0E0),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ).animate().scale(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutBack,
                ),
                SizedBox(height: isDesktop ? 24 : 20),
                Text(
                  'شروع مکالمه جدید',
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ).animate().slideX(
                  begin: -0.1,
                  delay: const Duration(milliseconds: 100),
                  curve: Curves.easeOutCubic,
                ),
                SizedBox(height: isDesktop ? 20 : 16),
                _buildTelegramModalOption(
                  context,
                  icon: Icons.group_add,
                  title: 'گروه جدید',
                  subtitle: 'ایجاد گروه با چندین نفر',
                  isDesktop: isDesktop,
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => BlocProvider.value(
                          value: context.read<ContactsBloc>(),
                          child: const CreateGroupScreen(),
                        ),
                      ),
                    );
                  },
                ).animate().slideX(
                  begin: -0.2,
                  delay: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                ),
                SizedBox(height: isDesktop ? 12 : 8),
                _buildTelegramModalOption(
                  context,
                  icon: Icons.campaign,
                  title: 'کانال جدید',
                  subtitle: 'اطلاع‌رسانی به مخاطبین',
                  isDesktop: isDesktop,
                  onTap: () {
                    Navigator.pop(ctx);
                    Fluttertoast.showToast(
                      msg: "کانال جدید به زودی اضافه می‌شود!",
                      toastLength: Toast.LENGTH_SHORT,
                      gravity: ToastGravity.BOTTOM,
                    );
                  },
                ).animate().slideX(
                  begin: -0.2,
                  delay: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                ),
                SizedBox(height: isDesktop ? 20 : 16),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildTelegramModalOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDesktop,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 16 : 12,
            vertical: isDesktop ? 14 : 12,
          ),
          child: Row(
            children: [
              Container(
                padding: EdgeInsets.all(isDesktop ? 12 : 10),
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).primaryColor,
                  size: isDesktop ? 24 : 22,
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: isDesktop ? 16 : 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: isDesktop ? 14 : 13,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF),
      child: BlocBuilder<SearchBloc, SearchState>(
        bloc: _searchBloc,
        builder: (context, state) {
          switch (state.status) {
            case SearchStatus.initial:
              return _buildSearchEmptyState(
                'برای جستجو، نام یا شماره را وارد کنید.',
                isDesktop,
              );
            case SearchStatus.loading:
              return _buildSearchLoadingState(isDesktop);
            case SearchStatus.failure:
              return _buildSearchEmptyState(
                'خطا: ${state.errorMessage}',
                isDesktop,
              );
            case SearchStatus.success:
              if (state.results.isEmpty && state.query.isNotEmpty) {
                return _buildSearchEmptyState(
                  'نتیجه‌ای برای "${state.query}" یافت نشد.',
                  isDesktop,
                );
              }
              if (state.results.isEmpty && state.query.isEmpty) {
                return _buildSearchEmptyState(
                  'برای جستجو، نام یا شماره را وارد کنید.',
                  isDesktop,
                );
              }

              final chatResults = state.results
                  .where((r) => r.type == 'chat')
                  .toList();
              final userResults = state.results
                  .where((r) => r.type == 'user')
                  .toList();

              return ListView(
                padding: EdgeInsets.symmetric(vertical: isDesktop ? 16 : 12),
                children: [
                  if (chatResults.isNotEmpty)
                    _buildSearchResultHeader("گفتگوها", isDesktop),
                  ...chatResults.asMap().entries.map(
                    (entry) =>
                        _TelegramSearchResultItem(
                          result: entry.value,
                          isDesktop: isDesktop,
                          onTap: () => _handleSearchResultTap(entry.value),
                        ).animate().slideX(
                          begin: -0.1,
                          delay: Duration(milliseconds: entry.key * 50),
                          curve: Curves.easeOutCubic,
                        ),
                  ),
                  if (userResults.isNotEmpty)
                    _buildSearchResultHeader("کاربران", isDesktop),
                  ...userResults.asMap().entries.map(
                    (entry) =>
                        _TelegramSearchResultItem(
                          result: entry.value,
                          isDesktop: isDesktop,
                          onTap: () => _handleSearchResultTap(entry.value),
                        ).animate().slideX(
                          begin: -0.1,
                          delay: Duration(milliseconds: entry.key * 50),
                          curve: Curves.easeOutCubic,
                        ),
                  ),
                ],
              );
          }
        },
      ),
    );
  }

  Widget _buildSearchEmptyState(String message, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(isDesktop ? 40 : 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 80 : 70,
              height: isDesktop ? 80 : 70,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(isDesktop ? 20 : 18),
              ),
              child: Icon(
                Icons.search,
                size: isDesktop ? 40 : 35,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
            ),
            SizedBox(height: isDesktop ? 24 : 20),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDesktop ? 16 : 15,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w400,
                height: 1.3,
              ),
            ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchLoadingState(bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isDesktop ? 56 : 48,
            height: isDesktop ? 56 : 48,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
            ),
            child: Center(
              child: SizedBox(
                width: isDesktop ? 24 : 20,
                height: isDesktop ? 24 : 20,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              ),
            ),
          ).animate().scale(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
          ),
          SizedBox(height: isDesktop ? 20 : 16),
          Text(
            'در حال جستجو...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: isDesktop ? 15 : 14,
              fontWeight: FontWeight.w400,
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
        ],
      ),
    );
  }

  Widget _buildSearchResultHeader(String title, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Padding(
      padding: EdgeInsets.only(
        right: isDesktop ? 20 : 16,
        top: isDesktop ? 16 : 12,
        bottom: isDesktop ? 8 : 6,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: isDesktop ? 16 : 15,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  Widget _buildTelegramFAB(BuildContext context, bool isDesktop) {
    return AnimatedBuilder(
      animation: _fabAnimationController,
      builder: (context, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.0, end: 1.0).animate(
            CurvedAnimation(
              parent: _fabAnimationController,
              curve: const Interval(0.2, 1.0, curve: Curves.easeOutBack),
            ),
          ),
          child: FloatingActionButton(
            onPressed: () {
              HapticFeedback.selectionClick();
              if (_currentUser == null) return;
              _showNewConversationModal(context, isDesktop);
            },
            backgroundColor: Theme.of(context).primaryColor,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(Icons.edit, size: isDesktop ? 24 : 22),
          ),
        );
      },
    );
  }

  Widget _buildTelegramBottomNavBar(BuildContext context, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE1E4E8),
            width: 0.5,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: isDesktop ? 56 : 50,
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20 : 8,
            vertical: 2,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildTelegramNavBarItem(
                context,
                0,
                Icons.chat_bubble_outline,
                Icons.chat_bubble,
                'چت‌ها',
                isDesktop,
              ),
              _buildTelegramNavBarItem(
                context,
                1,
                Icons.people_outline,
                Icons.people,
                'مخاطبین',
                isDesktop,
              ),
              _buildTelegramNavBarItem(
                context,
                2,
                Icons.settings_outlined,
                Icons.settings,
                'تنظیمات',
                isDesktop,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTelegramNavBarItem(
    BuildContext context,
    int index,
    IconData inactiveIcon,
    IconData activeIcon,
    String label,
    bool isDesktop,
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedIndex == index;
    final primaryColor = Theme.of(context).primaryColor;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(8),
          child: Container(
            padding: EdgeInsets.symmetric(
              vertical: isDesktop ? 6 : 4,
              horizontal: isDesktop ? 6 : 2,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isSelected ? activeIcon : inactiveIcon,
                  color: isSelected
                      ? primaryColor
                      : (isDark ? Colors.white54 : Colors.black45),
                  size: isDesktop ? 20 : 18,
                ),
                SizedBox(height: isDesktop ? 2 : 1),
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? primaryColor
                          : (isDark ? Colors.white54 : Colors.black45),
                      fontSize: isDesktop ? 10 : 9,
                      fontWeight: isSelected
                          ? FontWeight.w500
                          : FontWeight.w400,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildChatListTabContent() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600;

    if (_currentUser == null) {
      return Center(
        child: Container(
          padding: EdgeInsets.all(isDesktop ? 40 : 30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isDesktop ? 80 : 70,
                height: isDesktop ? 80 : 70,
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E1E1E)
                      : const Color(0xFFF5F5F5),
                  borderRadius: BorderRadius.circular(isDesktop ? 20 : 18),
                ),
                child: Icon(
                  Icons.error_outline,
                  size: isDesktop ? 40 : 35,
                  color: Colors.red.shade400,
                ),
              ).animate().scale(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
              ),
              SizedBox(height: isDesktop ? 24 : 20),
              Text(
                "خطا: اطلاعات کاربر برای نمایش چت‌ها در دسترس نیست.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isDesktop ? 16 : 15,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w400,
                  height: 1.3,
                ),
              ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
            ],
          ),
        ),
      );
    }

    return BlocBuilder<ChatListBloc, ChatListState>(
      builder: (context, chatListState) {
        if (chatListState is ChatListLoading && !_isChatListFetchInitiated) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: isDesktop ? 56 : 48,
                  height: isDesktop ? 56 : 48,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
                  ),
                  child: Center(
                    child: SizedBox(
                      width: isDesktop ? 24 : 20,
                      height: isDesktop ? 24 : 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2,
                      ),
                    ),
                  ),
                ).animate().scale(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeOutBack,
                ),
                SizedBox(height: isDesktop ? 20 : 16),
                Text(
                  'در حال بارگذاری چت‌ها...',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: isDesktop ? 15 : 14,
                    fontWeight: FontWeight.w400,
                  ),
                ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
              ],
            ),
          );
        }

        if (chatListState is ChatListLoaded) {
          _isChatListFetchInitiated = true;
          if (chatListState.chats.isEmpty) {
            return _buildTelegramEmptyChatState(context, isDesktop);
          }
          return RefreshIndicator(
            color: Theme.of(context).primaryColor,
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            strokeWidth: 2,
            onRefresh: () async {
              if (_currentUser != null) {
                context.read<ChatListBloc>().add(FetchChatList());
              }
            },
            child: ListView.builder(
              itemCount: chatListState.chats.length,
              itemBuilder: (context, index) {
                final chat = chatListState.chats[index];
                return Column(
                  children: [
                    _TelegramChatListItem(
                      chat: chat,
                      currentUser: _currentUser,
                      isDesktop: isDesktop,
                      onTap: () async {
                        if (_currentUser == null) return;
                        HapticFeedback.selectionClick();
                        final chatListBlocInstance = context
                            .read<ChatListBloc>();
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (newNavContext) => BlocProvider(
                              create: (blocContext) => ChatMessagesBloc(
                                blocContext.read<ChatService>(),
                                blocContext.read<SignalRService>(),
                                chatId: chat.id,
                                currentUserId: _currentUser!.id,
                              ),
                              child: ChatScreen(
                                chatModel: chat,
                                currentUser: _currentUser,
                              ),
                            ),
                          ),
                        );
                        chatListBlocInstance.add(FetchChatList());
                      },
                    ).animate().slideX(
                      begin: -0.05,
                      delay: Duration(milliseconds: index * 30),
                      curve: Curves.easeOutCubic,
                    ),
                    if (index < chatListState.chats.length - 1)
                      Container(
                        margin: EdgeInsets.only(right: isDesktop ? 76 : 68),
                        child: Divider(
                          height: 1,
                          thickness: 0.3,
                          color: isDark
                              ? const Color(0xFF30363D)
                              : const Color(0xFFE1E4E8),
                        ),
                      ),
                  ],
                );
              },
            ),
          );
        }

        if (chatListState is ChatListError) {
          _isChatListFetchInitiated = true;
          return Center(
            child: Container(
              padding: EdgeInsets.all(isDesktop ? 40 : 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: isDesktop ? 80 : 70,
                    height: isDesktop ? 80 : 70,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(isDesktop ? 20 : 18),
                    ),
                    child: Icon(
                      Icons.error_outline,
                      size: isDesktop ? 40 : 35,
                      color: Colors.red.shade400,
                    ),
                  ).animate().scale(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                  ),
                  SizedBox(height: isDesktop ? 24 : 20),
                  Text(
                    'خطا در دریافت لیست گفتگوها',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isDesktop ? 18 : 16,
                      fontWeight: FontWeight.w500,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ).animate().fadeIn(delay: const Duration(milliseconds: 150)),
                  SizedBox(height: isDesktop ? 8 : 6),
                  Text(
                    chatListState.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isDesktop ? 14 : 13,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.3,
                    ),
                  ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
                  SizedBox(height: isDesktop ? 24 : 20),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Theme.of(context).primaryColor,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 24 : 20,
                        vertical: isDesktop ? 12 : 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(
                          isDesktop ? 12 : 10,
                        ),
                      ),
                      elevation: 0,
                    ),
                    icon: Icon(Icons.refresh, size: isDesktop ? 20 : 18),
                    label: Text(
                      'تلاش مجدد',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: isDesktop ? 14 : 13,
                      ),
                    ),
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      if (_currentUser != null) {
                        context.read<ChatListBloc>().add(FetchChatList());
                      }
                    },
                  ).animate().scale(
                    delay: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                  ),
                ],
              ),
            ),
          );
        }

        if (_currentUser == null) {
          return Center(
            child: Container(
              padding: EdgeInsets.all(isDesktop ? 40 : 30),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: isDesktop ? 80 : 70,
                    height: isDesktop ? 80 : 70,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E1E1E)
                          : const Color(0xFFF5F5F5),
                      borderRadius: BorderRadius.circular(isDesktop ? 20 : 18),
                    ),
                    child: Icon(
                      Icons.person_off_outlined,
                      size: isDesktop ? 40 : 35,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ).animate().scale(
                    duration: const Duration(milliseconds: 400),
                    curve: Curves.easeOutBack,
                  ),
                  SizedBox(height: isDesktop ? 24 : 20),
                  Text(
                    "اطلاعات کاربر برای نمایش لیست گفتگوها در دسترس نیست.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 15,
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontWeight: FontWeight.w400,
                      height: 1.3,
                    ),
                  ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
                ],
              ),
            ),
          );
        }

        if (context.read<ChatListBloc>().state is! ChatListLoaded &&
            context.read<ChatListBloc>().state is! ChatListError &&
            !_isChatListFetchInitiated) {
          context.read<ChatListBloc>().add(FetchChatList());
          _isChatListFetchInitiated = true;
        }

        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isDesktop ? 56 : 48,
                height: isDesktop ? 56 : 48,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
                ),
                child: Center(
                  child: SizedBox(
                    width: isDesktop ? 24 : 20,
                    height: isDesktop ? 24 : 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  ),
                ),
              ).animate().scale(
                duration: const Duration(milliseconds: 400),
                curve: Curves.easeOutBack,
              ),
              SizedBox(height: isDesktop ? 20 : 16),
              Text(
                'در حال بارگذاری...',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: isDesktop ? 15 : 14,
                  fontWeight: FontWeight.w400,
                ),
              ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildTelegramEmptyChatState(BuildContext context, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      color: Theme.of(context).primaryColor,
      backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
      strokeWidth: 2,
      onRefresh: () async {
        if (_currentUser != null) {
          context.read<ChatListBloc>().add(FetchChatList());
        }
      },
      child: LayoutBuilder(
        builder: (ctx, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Container(
                padding: EdgeInsets.all(isDesktop ? 40 : 30),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: isDesktop ? 120 : 100,
                      height: isDesktop ? 120 : 100,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E1E1E)
                            : const Color(0xFFF5F5F5),
                        borderRadius: BorderRadius.circular(
                          isDesktop ? 30 : 25,
                        ),
                      ),
                      child: Icon(
                        Icons.forum_outlined,
                        size: isDesktop ? 60 : 50,
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                    ).animate().scale(
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutBack,
                    ),
                    SizedBox(height: isDesktop ? 32 : 24),
                    Text(
                      'هنوز هیچ گفتگویی نداری!',
                      style: TextStyle(
                        fontSize: isDesktop ? 20 : 18,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ).animate().slideY(
                      begin: 0.2,
                      delay: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                    ),
                    SizedBox(height: isDesktop ? 12 : 8),
                    Text(
                      'برای شروع، روی دکمه + در پایین صفحه ضربه بزن.',
                      style: TextStyle(
                        fontSize: isDesktop ? 16 : 15,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w400,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(
                      delay: const Duration(milliseconds: 250),
                    ),
                    SizedBox(height: isDesktop ? 32 : 24),
                    Container(
                      padding: EdgeInsets.all(isDesktop ? 16 : 14),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(
                          isDesktop ? 16 : 14,
                        ),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.15),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(isDesktop ? 6 : 5),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(
                                isDesktop ? 8 : 7,
                              ),
                            ),
                            child: Icon(
                              Icons.lightbulb_outline,
                              color: Theme.of(context).primaryColor,
                              size: isDesktop ? 18 : 16,
                            ),
                          ),
                          SizedBox(width: isDesktop ? 10 : 8),
                          Text(
                            'با دوستان خود به گفتگو بپردازید',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w500,
                              fontSize: isDesktop ? 14 : 13,
                            ),
                          ),
                        ],
                      ),
                    ).animate().slideY(
                      begin: 0.2,
                      delay: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TelegramChatListItem extends StatelessWidget {
  final ChatModel chat;
  final UserModel? currentUser;
  final bool isDesktop;
  final VoidCallback onTap;

  const _TelegramChatListItem({
    required this.chat,
    required this.currentUser,
    required this.isDesktop,
    required this.onTap,
  });

  UserModel? _getOtherParticipant() {
    if (chat.isGroup) return null;
    try {
      return chat.participants.firstWhere((p) => p.id != currentUser?.id);
    } catch (e) {
      return null;
    }
  }

  String _getChatTitle() {
    if (chat.title != null && chat.title!.isNotEmpty) {
      return chat.title!;
    }
    final otherParticipant = _getOtherParticipant();
    if (otherParticipant != null) {
      String fullName =
          "${otherParticipant.firstName ?? ''} ${otherParticipant.lastName ?? ''}"
              .trim();
      return fullName.isEmpty ? otherParticipant.username : fullName;
    }
    return chat.isGroup ? "گروه" : "چت";
  }

  String _getAvatarInitials() {
    String title = _getChatTitle();
    if (title.isEmpty || title == "چت" || title == "گروه") return "?";
    List<String> words = title.split(' ').where((s) => s.isNotEmpty).toList();
    if (words.length > 1 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return (words[0][0] + words[1][0]).toUpperCase();
    } else if (words.isNotEmpty && words[0].isNotEmpty) {
      return words[0].length > 1
          ? words[0].substring(0, 1).toUpperCase()
          : words[0][0].toUpperCase();
    }
    return "?";
  }

  String _formatLastMessageTime(DateTime? time, BuildContext context) {
    if (time == null) return "";
    final localTime = toTehran(time);
    final jalaliDate = Jalali.fromDateTime(localTime);
    final nowJalali = Jalali.now();

    if (jalaliDate.year == nowJalali.year &&
        jalaliDate.month == nowJalali.month &&
        jalaliDate.day == nowJalali.day) {
      return DateFormat('HH:mm').format(localTime);
    }
    final yesterdayJalali = nowJalali.addDays(-1);
    if (jalaliDate.year == yesterdayJalali.year &&
        jalaliDate.month == yesterdayJalali.month &&
        jalaliDate.day == yesterdayJalali.day) {
      return "دیروز";
    }
    if (nowJalali.distanceTo(jalaliDate).abs() < 7) {
      return jalaliDate.formatter.wN;
    }
    return '${jalaliDate.formatter.d} ${jalaliDate.formatter.mN}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final otherParticipant = _getOtherParticipant();

    return Material(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20 : 16,
            vertical: isDesktop ? 12 : 10,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: isDesktop ? 60 : 52,
                    height: isDesktop ? 60 : 52,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.primaryColor.withOpacity(0.15),
                          theme.primaryColor.withOpacity(0.08),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        _getAvatarInitials(),
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w600,
                          fontSize: isDesktop ? 18 : 16,
                        ),
                      ),
                    ),
                  ),
                  if (otherParticipant != null && otherParticipant.isOnline)
                    Positioned(
                      bottom: 0,
                      right: 0,
                      child: Container(
                        width: isDesktop ? 16 : 14,
                        height: isDesktop ? 16 : 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.shade400,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF0D1117)
                                : const Color(0xFFFFFFFF),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getChatTitle(),
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: isDesktop ? 16 : 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isDesktop ? 4 : 3),
                    Text(
                      chat.lastMessage?.replaceAll('\n', ' ') ?? 'بدون پیام',
                      style: TextStyle(
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontSize: isDesktop ? 14 : 13,
                        fontWeight: FontWeight.w400,
                        height: 1.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: isDesktop ? 12 : 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (chat.lastMessageTime != null)
                    Text(
                      _formatLastMessageTime(chat.lastMessageTime, context),
                      style: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: isDesktop ? 12 : 11,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  SizedBox(height: isDesktop ? 6 : 4),
                  if (chat.unreadCount > 0)
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 6 : 5,
                        vertical: isDesktop ? 3 : 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
                      ),
                      child: Text(
                        chat.unreadCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isDesktop ? 11 : 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    )
                  else
                    SizedBox(height: isDesktop ? 20 : 16),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TelegramSearchResultItem extends StatelessWidget {
  final SearchResultModel result;
  final bool isDesktop;
  final VoidCallback onTap;

  const _TelegramSearchResultItem({
    required this.result,
    required this.isDesktop,
    required this.onTap,
  });

  String _getAvatarInitials() {
    String title = result.title;
    if (title.isEmpty) return "?";
    List<String> words = title.split(' ').where((s) => s.isNotEmpty).toList();
    if (words.length > 1 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return (words[0][0] + words[1][0]).toUpperCase();
    } else if (words.isNotEmpty && words[0].isNotEmpty) {
      return words[0].length > 1
          ? words[0].substring(0, 1).toUpperCase()
          : words[0][0].toUpperCase();
    }
    return "?";
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Material(
      color: isDark ? const Color(0xFF0D1117) : const Color(0xFFFFFFFF),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 20 : 16,
            vertical: isDesktop ? 12 : 10,
          ),
          child: Row(
            children: [
              Container(
                width: isDesktop ? 48 : 44,
                height: isDesktop ? 48 : 44,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.15),
                      primaryColor.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(isDesktop ? 12 : 11),
                ),
                child: Center(
                  child: Text(
                    _getAvatarInitials(),
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: isDesktop ? 16 : 14,
                    ),
                  ),
                ),
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      result.title,
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        fontSize: isDesktop ? 16 : 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (result.subtitle != null && result.subtitle!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          result.subtitle!,
                          style: TextStyle(
                            fontSize: isDesktop ? 14 : 13,
                            color: isDark ? Colors.white60 : Colors.black54,
                            fontWeight: FontWeight.w400,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: isDesktop ? 12 : 8),
              Icon(
                result.type == 'chat'
                    ? Icons.chat_bubble_outline
                    : Icons.person_add_alt_1_outlined,
                color: isDark ? Colors.white38 : Colors.black38,
                size: isDesktop ? 20 : 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
