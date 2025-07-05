import 'package:connectivity_plus/connectivity_plus.dart';
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
import '../../../../core/network/connection_status/connection_status_bloc.dart';
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
  late AnimationController _connectionController;

  bool _isSearching = false;
  final _searchController = TextEditingController();
  late final SearchBloc _searchBloc;

  // Connection states
  bool _isConnected = true;
  bool _isUpdating = false;

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
    _connectionController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );

    // Start animations
    _appBarAnimationController.forward();
    _fabAnimationController.forward();

    // Simulate connection states (you can replace with real SignalR connection status)
    _simulateConnectionStates();
  }

  void _simulateConnectionStates() {
    // This is just for demonstration - replace with real connection monitoring
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        setState(() {
          _isConnected = false;
        });
        _connectionController.repeat();
      }
    });

    Future.delayed(const Duration(seconds: 5), () {
      if (mounted) {
        setState(() {
          _isConnected = true;
          _isUpdating = true;
        });
        _connectionController.stop();
        _connectionController.reset();
      }
    });

    Future.delayed(const Duration(seconds: 8), () {
      if (mounted) {
        setState(() {
          _isUpdating = false;
        });
      }
    });
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
    _connectionController.dispose();
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
        if (!_isConnected) return 'درحال اتصال...';
        if (_isUpdating) return 'درحال بروزرسانی...';
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
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
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
              padding: const EdgeInsets.all(6),
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
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
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

  void _showSuccessToast(String message) {
    // استفاده از toast سفارشی با styling درست
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(
                Icons.check_circle_outline_rounded,
                color: Colors.white,
                size: 16,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: const Color(0xFF22C55E),
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
    final isDesktop = screenWidth > 800; // افزایش threshold برای desktop

    // اگر desktop است، layout متفاوت نمایش بده
    if (isDesktop) {
      return _buildDesktopLayout();
    }

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: isDark
          ? const Color(0xFF0B1426)
          : const Color(0xFFF7F8FC),
      appBar: _isSearching
          ? _buildSearchAppBar(context, isDesktop)
          : _buildDefaultAppBar(context, isDesktop),
      body: _isSearching
          ? _buildSearchResults(isDesktop)
          : _buildPrimaryContent(context, isDesktop),
      bottomNavigationBar: _isSearching
          ? null
          : _buildModernBottomNavBar(context, isDesktop),
      floatingActionButton: (_isSearching || _selectedIndex != 0)
          ? null
          : _buildModernFAB(context, isDesktop),
      floatingActionButtonLocation: FloatingActionButtonLocation.endFloat,
    );
  }

  Widget _buildDesktopLayout() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B1426)
          : const Color(0xFFF7F8FC),
      body: Row(
        children: [
          // Side Panel
          Container(
            width: 320,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              border: Border(
                left: BorderSide(
                  color: isDark
                      ? const Color(0xFF334155)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
            ),
            child: Column(
              children: [
                // Header
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                  ),
                  child: Row(
                    children: [
                      // Profile Avatar
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [
                              Theme.of(context).primaryColor.withOpacity(0.2),
                              Theme.of(context).primaryColor.withOpacity(0.1),
                            ],
                          ),
                        ),
                        child: Center(
                          child: Text(
                            _currentUser?.firstName
                                    ?.substring(0, 1)
                                    .toUpperCase() ??
                                'U',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 20,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _getAppBarTitle(),
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 16,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (!_isConnected || _isUpdating)
                              Text(
                                !_isConnected
                                    ? 'درحال اتصال...'
                                    : 'درحال بروزرسانی...',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: !_isConnected
                                      ? Colors.orange
                                      : Theme.of(context).primaryColor,
                                ),
                              ),
                          ],
                        ),
                      ),
                      // Search button
                      _buildDesktopSearchButton(),
                    ],
                  ),
                ),
                // Navigation
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      _buildDesktopNavItem(
                        0,
                        Icons.chat_bubble_rounded,
                        'چت‌ها',
                      ),
                      const SizedBox(width: 8),
                      _buildDesktopNavItem(1, Icons.people_rounded, 'مخاطبین'),
                      const SizedBox(width: 8),
                      _buildDesktopNavItem(
                        2,
                        Icons.settings_rounded,
                        'تنظیمات',
                      ),
                    ],
                  ),
                ),
                // Content
                Expanded(
                  child: _isSearching
                      ? _buildSearchResults(true)
                      : _buildPrimaryContent(context, true),
                ),
              ],
            ),
          ),
          // Main Content Area
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A)
                    : const Color(0xFFF8FAFC),
              ),
              child: Column(
                children: [
                  // Top bar
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      border: Border(
                        bottom: BorderSide(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Text(
                          'انتخاب چت برای شروع مکالمه',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: isDark ? Colors.white70 : Colors.black54,
                          ),
                        ),
                        const Spacer(),
                        if (_selectedIndex == 0) _buildDesktopNewChatButton(),
                      ],
                    ),
                  ),
                  // Welcome message
                  Expanded(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            width: 120,
                            height: 120,
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(30),
                            ),
                            child: Icon(
                              Icons.chat_bubble_outline_rounded,
                              size: 60,
                              color: Theme.of(context).primaryColor,
                            ),
                          ),
                          const SizedBox(height: 24),
                          Text(
                            'از چپ یک چت انتخاب کنید',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w600,
                              color: isDark ? Colors.white70 : Colors.black54,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'یا گفتگوی جدید شروع کنید',
                            style: TextStyle(
                              fontSize: 16,
                              color: isDark ? Colors.white54 : Colors.black45,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDesktopSearchButton() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.search, color: Colors.white, size: 20),
        onPressed: _toggleSearch,
      ),
    );
  }

  Widget _buildDesktopNavItem(int index, IconData icon, String label) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isSelected = _selectedIndex == index;

    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onItemTapped(index),
          borderRadius: BorderRadius.circular(10),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: isSelected
                  ? Border.all(
                      color: Theme.of(context).primaryColor.withOpacity(0.2),
                    )
                  : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 16,
                  color: isSelected
                      ? Theme.of(context).primaryColor
                      : (isDark ? Colors.white54 : Colors.black54),
                ),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                    color: isSelected
                        ? Theme.of(context).primaryColor
                        : (isDark ? Colors.white54 : Colors.black54),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDesktopNewChatButton() {
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).primaryColor,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).primaryColor.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: const Icon(Icons.edit_rounded, color: Colors.white, size: 20),
        onPressed: () {
          if (_currentUser == null) return;
          _showNewConversationModal(context, true);
        },
      ),
    );
  }

  Widget _buildLoadingScreen() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B1426)
          : const Color(0xFFF7F8FC),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 80 : 64,
              height: isDesktop ? 80 : 64,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.25),
                    blurRadius: isDesktop ? 20 : 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.chat_bubble_rounded,
                color: Colors.white,
                size: isDesktop ? 40 : 32,
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
            ),
            SizedBox(height: isDesktop ? 32 : 24),
            Text(
              'در حال بارگذاری...',
              style: TextStyle(
                color: isDark ? Colors.white70 : Colors.black54,
                fontSize: isDesktop ? 18 : 16,
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
      duration: const Duration(milliseconds: 350),
      transitionBuilder: (Widget child, Animation<double> animation) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position:
                Tween<Offset>(
                  begin: const Offset(0.0, 0.1),
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
    final userName =
        _currentUser?.firstName ?? _currentUser?.username ?? 'Solvix';

    return AppBar(
      title: BlocBuilder<ConnectionStatusBloc, ConnectionStatusState>(
        builder: (context, state) {
          String titleText = userName;
          Color titleColor = isDark ? Colors.white : Colors.black87;
          IconData? titleIcon;

          if (state.signalRStatus != SignalRConnectionStatus.Connected) {
            if (state.connectivityStatus == ConnectivityResult.none) {
              titleText = "آفلاین";
              titleColor = Colors.grey.shade500;
              titleIcon = Icons.cloud_off_rounded;
            } else {
              titleText = "در حال اتصال...";
              titleColor = Colors.orange.shade600;
              titleIcon = Icons.sync_rounded;
            }
          }

          return AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            transitionBuilder: (child, animation) {
              return FadeTransition(
                opacity: animation,
                child: SlideTransition(
                  position: Tween<Offset>(
                    begin: const Offset(0, -0.2),
                    end: Offset.zero,
                  ).animate(animation),
                  child: child,
                ),
              );
            },
            child: Row(
              key: ValueKey<String>(titleText),
              children: [
                if (titleIcon != null)
                  Icon(titleIcon, color: titleColor, size: isDesktop ? 20 : 18),
                if (titleIcon != null) const SizedBox(width: 8),
                Text(
                  titleText,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isDesktop ? 22 : 19,
                    color: titleColor,
                  ),
                ),
              ],
            ),
          );
        },
      ),
      backgroundColor: isDark
          ? const Color(0xFF0B1426)
          : const Color(0xFFF7F8FC),
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
                      child: Container(
                        decoration: BoxDecoration(
                          color: Theme.of(context).primaryColor,
                          borderRadius: BorderRadius.circular(
                            isDesktop ? 16 : 14,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.3),
                              blurRadius: isDesktop ? 12 : 8,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: IconButton(
                          icon: Icon(
                            Icons.search,
                            color: Colors.white,
                            size: isDesktop ? 22 : 20,
                          ),
                          tooltip: 'جستجو',
                          onPressed: _toggleSearch,
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
          ? const Color(0xFF0B1426)
          : const Color(0xFFF7F8FC),
      elevation: 0,
      scrolledUnderElevation: 0,
      leading: Container(
        margin: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: isDark
              ? const Color(0xFF1E293B).withOpacity(0.6)
              : Colors.white.withOpacity(0.8),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
        ),
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white : Colors.black87,
            size: isDesktop ? 22 : 20,
          ),
          onPressed: _toggleSearch,
        ),
      ).animate().slideX(begin: -0.2, curve: Curves.easeOutCubic),
      title: Container(
        height: isDesktop ? 48 : 44,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
          border: Border.all(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDesktop ? 0.06 : 0.04),
              blurRadius: isDesktop ? 8 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: TextField(
          controller: _searchController,
          autofocus: true,
          style: TextStyle(
            fontSize: isDesktop ? 16 : 15,
            fontWeight: FontWeight.w500,
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
            prefixIcon: Container(
              margin: EdgeInsets.all(isDesktop ? 12 : 10),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                Icons.search,
                color: Theme.of(context).primaryColor,
                size: isDesktop ? 18 : 16,
              ),
            ),
          ),
        ),
      ).animate().slideY(begin: -0.2, curve: Curves.easeOutCubic),
      actions: [
        if (_searchController.text.isNotEmpty)
          Container(
            margin: EdgeInsets.only(left: isDesktop ? 16 : 12, right: 8),
            decoration: BoxDecoration(
              color: isDark
                  ? const Color(0xFF1E293B).withOpacity(0.6)
                  : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
              ),
            ),
            child: IconButton(
              icon: Icon(
                Icons.clear_rounded,
                color: isDark ? Colors.white54 : Colors.black45,
                size: isDesktop ? 18 : 16,
              ),
              onPressed: () {
                HapticFeedback.lightImpact();
                _searchController.clear();
              },
            ),
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
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                blurRadius: 20,
                offset: const Offset(0, -5),
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 32 : 24),
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
                          ? const Color(0xFF334155)
                          : const Color(0xFFE2E8F0),
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
                    fontSize: isDesktop ? 22 : 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ).animate().slideX(
                  begin: -0.1,
                  delay: const Duration(milliseconds: 100),
                  curve: Curves.easeOutCubic,
                ),
                SizedBox(height: isDesktop ? 24 : 20),
                _buildModernModalOption(
                  context,
                  icon: Icons.person_add_alt_1_rounded,
                  title: 'پیام خصوصی جدید',
                  subtitle: 'چت شخصی با یک فرد',
                  isDesktop: isDesktop,
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ContactsScreen()),
                    );
                  },
                ).animate().slideX(
                  begin: -0.2,
                  delay: const Duration(milliseconds: 100),
                  curve: Curves.easeOutCubic,
                ),
                SizedBox(height: isDesktop ? 16 : 12),
                _buildModernModalOption(
                  context,
                  icon: Icons.group_add_rounded,
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
                SizedBox(height: isDesktop ? 16 : 12),
                _buildModernModalOption(
                  context,
                  icon: Icons.campaign_rounded,
                  title: 'کانال جدید',
                  subtitle: 'اطلاع‌رسانی به مخاطبین',
                  isDesktop: isDesktop,
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSuccessToast("کانال جدید به زودی اضافه می‌شود!");
                  },
                ).animate().slideX(
                  begin: -0.2,
                  delay: const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                ),
                SizedBox(height: isDesktop ? 24 : 20),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernModalOption(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool isDesktop,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
          child: Padding(
            padding: EdgeInsets.all(isDesktop ? 20 : 16),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isDesktop ? 14 : 12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
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
                          fontWeight: FontWeight.w600,
                          fontSize: isDesktop ? 16 : 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
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
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isDark ? Colors.white38 : Colors.black38,
                  size: isDesktop ? 16 : 14,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSearchResults(bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      color: isDark ? const Color(0xFF0B1426) : const Color(0xFFF7F8FC),
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
                padding: EdgeInsets.symmetric(vertical: isDesktop ? 20 : 16),
                children: [
                  if (chatResults.isNotEmpty)
                    _buildSearchResultHeader("گفتگوها", isDesktop),
                  ...chatResults.asMap().entries.map(
                    (entry) =>
                        _ModernSearchResultItem(
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
                        _ModernSearchResultItem(
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
        padding: EdgeInsets.all(isDesktop ? 48 : 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 96 : 80,
              height: isDesktop ? 96 : 80,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
                boxShadow: [
                  BoxShadow(
                    color: Theme.of(context).primaryColor.withOpacity(0.25),
                    blurRadius: isDesktop ? 20 : 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.search_rounded,
                size: isDesktop ? 48 : 40,
                color: Colors.white,
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
            ),
            SizedBox(height: isDesktop ? 32 : 24),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDesktop ? 18 : 16,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w500,
                height: 1.4,
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
            width: isDesktop ? 64 : 56,
            height: isDesktop ? 64 : 56,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.25),
                  blurRadius: isDesktop ? 16 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                width: isDesktop ? 28 : 24,
                height: isDesktop ? 28 : 24,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2.5,
                ),
              ),
            ),
          ).animate().scale(
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
          ),
          SizedBox(height: isDesktop ? 24 : 20),
          Text(
            'در حال جستجو...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: isDesktop ? 16 : 15,
              fontWeight: FontWeight.w500,
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
        right: isDesktop ? 24 : 20,
        top: isDesktop ? 20 : 16,
        bottom: isDesktop ? 12 : 8,
      ),
      child: Text(
        title,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: isDesktop ? 16 : 15,
          color: isDark ? Colors.white70 : Colors.black54,
        ),
      ),
    );
  }

  Widget _buildModernFAB(BuildContext context, bool isDesktop) {
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
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  blurRadius: isDesktop ? 16 : 12,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: FloatingActionButton(
              onPressed: () {
                HapticFeedback.selectionClick();
                if (_currentUser == null) return;
                _showNewConversationModal(context, isDesktop);
              },
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
              ),
              child: Icon(Icons.edit_rounded, size: isDesktop ? 26 : 24),
            ),
          ),
        );
      },
    );
  }

  Widget _buildModernBottomNavBar(BuildContext context, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1426) : const Color(0xFFF7F8FC),
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: SafeArea(
        child: Container(
          height: isDesktop ? 80 : 70, // کاهش ارتفاع برای جلوگیری از overflow
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 16,
            vertical: isDesktop ? 8 : 6, // کاهش padding عمودی
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildModernNavBarItem(
                context,
                0,
                Icons.chat_bubble_outline_rounded,
                Icons.chat_bubble_rounded,
                'چت‌ها',
                isDesktop,
              ),
              _buildModernNavBarItem(
                context,
                1,
                Icons.people_outline_rounded,
                Icons.people_rounded,
                'مخاطبین',
                isDesktop,
              ),
              _buildModernNavBarItem(
                context,
                2,
                Icons.settings_outlined,
                Icons.settings_rounded,
                'تنظیمات',
                isDesktop,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModernNavBarItem(
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
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              vertical: isDesktop ? 6 : 4, // کاهش padding عمودی
              horizontal: isDesktop ? 6 : 4,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? primaryColor.withOpacity(0.1)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.all(isDesktop ? 4 : 3), // کاهش padding
                  decoration: BoxDecoration(
                    color: isSelected
                        ? primaryColor.withOpacity(0.15)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(isDesktop ? 8 : 6),
                  ),
                  child: Icon(
                    isSelected ? activeIcon : inactiveIcon,
                    color: isSelected
                        ? primaryColor
                        : (isDark ? Colors.white54 : Colors.black45),
                    size: isDesktop ? 20 : 18, // کاهش سایز آیکون
                  ),
                ),
                SizedBox(height: isDesktop ? 2 : 1), // کاهش فاصله
                Flexible(
                  child: Text(
                    label,
                    style: TextStyle(
                      color: isSelected
                          ? primaryColor
                          : (isDark ? Colors.white54 : Colors.black45),
                      fontSize: isDesktop ? 10 : 9, // کاهش سایز متن
                      fontWeight: isSelected
                          ? FontWeight.w600
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
    final isDesktop = screenWidth > 800;

    if (_currentUser == null) {
      return Center(
        child: Container(
          padding: EdgeInsets.all(isDesktop ? 48 : 40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: isDesktop ? 96 : 80,
                height: isDesktop ? 96 : 80,
                decoration: BoxDecoration(
                  color: Colors.red.shade400,
                  borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.red.shade400.withOpacity(0.25),
                      blurRadius: isDesktop ? 20 : 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.error_outline_rounded,
                  size: isDesktop ? 48 : 40,
                  color: Colors.white,
                ),
              ).animate().scale(
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
              ),
              SizedBox(height: isDesktop ? 32 : 24),
              Text(
                "خطا: اطلاعات کاربر برای نمایش چت‌ها در دسترس نیست.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: isDesktop ? 18 : 16,
                  color: isDark ? Colors.white60 : Colors.black54,
                  fontWeight: FontWeight.w500,
                  height: 1.4,
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
                  width: isDesktop ? 64 : 56,
                  height: isDesktop ? 64 : 56,
                  decoration: BoxDecoration(
                    color: Theme.of(context).primaryColor,
                    borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
                    boxShadow: [
                      BoxShadow(
                        color: Theme.of(context).primaryColor.withOpacity(0.25),
                        blurRadius: isDesktop ? 16 : 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: SizedBox(
                      width: isDesktop ? 28 : 24,
                      height: isDesktop ? 28 : 24,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.5,
                      ),
                    ),
                  ),
                ).animate().scale(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                ),
                SizedBox(height: isDesktop ? 24 : 20),
                Text(
                  'در حال بارگذاری چت‌ها...',
                  style: TextStyle(
                    color: isDark ? Colors.white70 : Colors.black54,
                    fontSize: isDesktop ? 16 : 15,
                    fontWeight: FontWeight.w500,
                  ),
                ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
              ],
            ),
          );
        }

        if (chatListState is ChatListLoaded) {
          _isChatListFetchInitiated = true;
          if (chatListState.chats.isEmpty) {
            return _buildModernEmptyChatState(context, isDesktop);
          }
          return RefreshIndicator(
            color: Theme.of(context).primaryColor,
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            strokeWidth: 2.5,
            onRefresh: () async {
              if (_currentUser != null) {
                context.read<ChatListBloc>().add(FetchChatList());
              }
            },
            child: ListView.separated(
              itemCount: chatListState.chats.length,
              separatorBuilder: (context, index) => Container(
                margin: EdgeInsets.only(right: isDesktop ? 88 : 80),
                child: Divider(
                  height: 1,
                  thickness: 0.5,
                  color: isDark
                      ? const Color(0xFF1E293B)
                      : const Color(0xFFE2E8F0),
                ),
              ),
              itemBuilder: (context, index) {
                final chat = chatListState.chats[index];
                return _ModernChatListItem(
                  chat: chat,
                  currentUser: _currentUser,
                  isDesktop: isDesktop,
                  onTap: () async {
                    if (_currentUser == null) return;
                    HapticFeedback.selectionClick();
                    final chatListBlocInstance = context.read<ChatListBloc>();
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
                  delay: Duration(milliseconds: index * 50),
                  curve: Curves.easeOutCubic,
                );
              },
            ),
          );
        }

        if (chatListState is ChatListError) {
          _isChatListFetchInitiated = true;
          return Center(
            child: Container(
              padding: EdgeInsets.all(isDesktop ? 48 : 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: isDesktop ? 96 : 80,
                    height: isDesktop ? 96 : 80,
                    decoration: BoxDecoration(
                      color: Colors.red.shade400,
                      borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.red.shade400.withOpacity(0.25),
                          blurRadius: isDesktop ? 20 : 16,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Icon(
                      Icons.error_outline_rounded,
                      size: isDesktop ? 48 : 40,
                      color: Colors.white,
                    ),
                  ).animate().scale(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                  ),
                  SizedBox(height: isDesktop ? 32 : 24),
                  Text(
                    'خطا در دریافت لیست گفتگوها',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isDesktop ? 20 : 18,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white : Colors.black87,
                    ),
                  ).animate().fadeIn(delay: const Duration(milliseconds: 150)),
                  SizedBox(height: isDesktop ? 12 : 8),
                  Text(
                    chatListState.message,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isDesktop ? 16 : 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                      height: 1.4,
                    ),
                  ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
                  SizedBox(height: isDesktop ? 32 : 24),
                  SizedBox(
                    width: double.infinity,
                    height: isDesktop ? 56 : 52,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            isDesktop ? 16 : 14,
                          ),
                        ),
                      ),
                      icon: Icon(
                        Icons.refresh_rounded,
                        size: isDesktop ? 22 : 20,
                      ),
                      label: Text(
                        'تلاش مجدد',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isDesktop ? 16 : 15,
                        ),
                      ),
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        if (_currentUser != null) {
                          context.read<ChatListBloc>().add(FetchChatList());
                        }
                      },
                    ),
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
              padding: EdgeInsets.all(isDesktop ? 48 : 40),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: isDesktop ? 96 : 80,
                    height: isDesktop ? 96 : 80,
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B)
                          : const Color(0xFFF1F5F9),
                      borderRadius: BorderRadius.circular(isDesktop ? 24 : 20),
                    ),
                    child: Icon(
                      Icons.person_off_outlined,
                      size: isDesktop ? 48 : 40,
                      color: isDark ? Colors.white24 : Colors.black26,
                    ),
                  ).animate().scale(
                    duration: const Duration(milliseconds: 600),
                    curve: Curves.elasticOut,
                  ),
                  SizedBox(height: isDesktop ? 32 : 24),
                  Text(
                    "اطلاعات کاربر برای نمایش لیست گفتگوها در دسترس نیست.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isDesktop ? 18 : 16,
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontWeight: FontWeight.w500,
                      height: 1.4,
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
                width: isDesktop ? 64 : 56,
                height: isDesktop ? 64 : 56,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.25),
                      blurRadius: isDesktop ? 16 : 12,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Center(
                  child: SizedBox(
                    width: isDesktop ? 28 : 24,
                    height: isDesktop ? 28 : 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2.5,
                    ),
                  ),
                ),
              ).animate().scale(
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
              ),
              SizedBox(height: isDesktop ? 24 : 20),
              Text(
                'در حال بارگذاری...',
                style: TextStyle(
                  color: isDark ? Colors.white70 : Colors.black54,
                  fontSize: isDesktop ? 16 : 15,
                  fontWeight: FontWeight.w500,
                ),
              ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildModernEmptyChatState(BuildContext context, bool isDesktop) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return RefreshIndicator(
      color: Theme.of(context).primaryColor,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      strokeWidth: 2.5,
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
                padding: EdgeInsets.all(isDesktop ? 48 : 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: isDesktop ? 140 : 120,
                      height: isDesktop ? 140 : 120,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor,
                        borderRadius: BorderRadius.circular(
                          isDesktop ? 35 : 30,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.25),
                            blurRadius: isDesktop ? 30 : 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.forum_rounded,
                        size: isDesktop ? 70 : 60,
                        color: Colors.white,
                      ),
                    ).animate().scale(
                      duration: const Duration(milliseconds: 800),
                      curve: Curves.elasticOut,
                    ),
                    SizedBox(height: isDesktop ? 40 : 32),
                    Text(
                      'هنوز هیچ گفتگویی نداری!',
                      style: TextStyle(
                        fontSize: isDesktop ? 24 : 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ).animate().slideY(
                      begin: 0.2,
                      delay: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                    ),
                    SizedBox(height: isDesktop ? 16 : 12),
                    Text(
                      'برای شروع، روی دکمه + در پایین صفحه ضربه بزن\nو با دوستان خود به گفتگو بپردازید.',
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 16,
                        color: isDark ? Colors.white60 : Colors.black54,
                        fontWeight: FontWeight.w400,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ).animate().fadeIn(
                      delay: const Duration(milliseconds: 300),
                    ),
                    SizedBox(height: isDesktop ? 40 : 32),
                    Container(
                      padding: EdgeInsets.all(isDesktop ? 20 : 16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(
                          isDesktop ? 20 : 16,
                        ),
                        border: Border.all(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: EdgeInsets.all(isDesktop ? 8 : 6),
                            decoration: BoxDecoration(
                              color: Theme.of(
                                context,
                              ).primaryColor.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(
                                isDesktop ? 10 : 8,
                              ),
                            ),
                            child: Icon(
                              Icons.lightbulb_outline_rounded,
                              color: Theme.of(context).primaryColor,
                              size: isDesktop ? 20 : 18,
                            ),
                          ),
                          SizedBox(width: isDesktop ? 12 : 10),
                          Text(
                            'با دوستان خود به گفتگو بپردازید',
                            style: TextStyle(
                              color: Theme.of(context).primaryColor,
                              fontWeight: FontWeight.w600,
                              fontSize: isDesktop ? 16 : 14,
                            ),
                          ),
                        ],
                      ),
                    ).animate().slideY(
                      begin: 0.2,
                      delay: const Duration(milliseconds: 400),
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

class _ModernChatListItem extends StatelessWidget {
  final ChatModel chat;
  final UserModel? currentUser;
  final bool isDesktop;
  final VoidCallback onTap;

  const _ModernChatListItem({
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

  bool _isLastMessageFromMe() {
    // This would normally check the last message sender ID
    // For now, we'll simulate it randomly
    return chat.id.hashCode % 2 == 0;
  }

  Widget _buildMessageStatus() {
    if (!_isLastMessageFromMe()) return const SizedBox.shrink();

    // Simulate message status (you would get this from your message model)
    final isDelivered = chat.id.hashCode % 3 != 0;
    final isRead = chat.id.hashCode % 4 == 0;

    if (isRead) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all_rounded, size: 16, color: Colors.blue.shade400),
        ],
      );
    } else if (isDelivered) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_all_rounded, size: 16, color: Colors.grey.shade400),
        ],
      );
    } else {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.done_rounded, size: 16, color: Colors.grey.shade400),
        ],
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final otherParticipant = _getOtherParticipant();

    return Material(
      color: isDark ? const Color(0xFF0B1426) : const Color(0xFFF7F8FC),
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: isDesktop ? 24 : 20,
            vertical: isDesktop ? 16 : 14,
          ),
          child: Row(
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: isDesktop ? 64 : 56,
                    height: isDesktop ? 64 : 56,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [
                          theme.primaryColor.withOpacity(0.2),
                          theme.primaryColor.withOpacity(0.1),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: theme.primaryColor.withOpacity(0.1),
                          blurRadius: isDesktop ? 8 : 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(
                        _getAvatarInitials(),
                        style: TextStyle(
                          color: theme.primaryColor,
                          fontWeight: FontWeight.w700,
                          fontSize: isDesktop ? 20 : 18,
                        ),
                      ),
                    ),
                  ),
                  if (otherParticipant != null && otherParticipant.isOnline)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: isDesktop ? 18 : 16,
                        height: isDesktop ? 18 : 16,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.shade400,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF0B1426)
                                : const Color(0xFFF7F8FC),
                            width: 3,
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
                        fontWeight: FontWeight.w600,
                        fontSize: isDesktop ? 17 : 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isDesktop ? 6 : 4),
                    Row(
                      children: [
                        if (_isLastMessageFromMe()) ...[
                          _buildMessageStatus(),
                          const SizedBox(width: 4),
                        ],
                        Expanded(
                          child: Text(
                            chat.lastMessage?.replaceAll('\n', ' ') ??
                                'بدون پیام',
                            style: TextStyle(
                              color: isDark ? Colors.white60 : Colors.black54,
                              fontSize: isDesktop ? 15 : 14,
                              fontWeight: FontWeight.w400,
                              height: 1.3,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
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
                        fontSize: isDesktop ? 13 : 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  SizedBox(height: isDesktop ? 8 : 6),
                  if (chat.unreadCount > 0)
                    Container(
                      constraints: BoxConstraints(
                        minWidth: isDesktop ? 24 : 20,
                        minHeight: isDesktop ? 24 : 20,
                      ),
                      padding: EdgeInsets.symmetric(
                        horizontal: isDesktop ? 8 : 6,
                        vertical: isDesktop ? 4 : 2,
                      ),
                      decoration: BoxDecoration(
                        color: theme.primaryColor,
                        borderRadius: BorderRadius.circular(
                          isDesktop ? 12 : 10,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: theme.primaryColor.withOpacity(0.3),
                            blurRadius: 4,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Text(
                        chat.unreadCount > 99
                            ? '99+'
                            : chat.unreadCount.toString(),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isDesktop ? 12 : 11,
                          fontWeight: FontWeight.w700,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    )
                  else
                    SizedBox(height: isDesktop ? 24 : 20),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ModernSearchResultItem extends StatelessWidget {
  final SearchResultModel result;
  final bool isDesktop;
  final VoidCallback onTap;

  const _ModernSearchResultItem({
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

    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: isDesktop ? 20 : 16,
        vertical: isDesktop ? 4 : 2,
      ),
      decoration: BoxDecoration(
        color: isDark
            ? const Color(0xFF1E293B).withOpacity(0.3)
            : Colors.white.withOpacity(0.7),
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
        border: Border.all(
          color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
          width: 0.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            HapticFeedback.selectionClick();
            onTap();
          },
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
          child: Container(
            padding: EdgeInsets.all(isDesktop ? 16 : 14),
            child: Row(
              children: [
                Container(
                  width: isDesktop ? 52 : 48,
                  height: isDesktop ? 52 : 48,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        primaryColor.withOpacity(0.2),
                        primaryColor.withOpacity(0.1),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.1),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Text(
                      _getAvatarInitials(),
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w700,
                        fontSize: isDesktop ? 18 : 16,
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
                          fontWeight: FontWeight.w600,
                          fontSize: isDesktop ? 16 : 15,
                          color: isDark ? Colors.white : Colors.black87,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (result.subtitle != null &&
                          result.subtitle!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
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
                Container(
                  padding: EdgeInsets.all(isDesktop ? 8 : 6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isDesktop ? 10 : 8),
                  ),
                  child: Icon(
                    result.type == 'chat'
                        ? Icons.chat_bubble_outline_rounded
                        : Icons.person_add_alt_1_outlined,
                    color: primaryColor,
                    size: isDesktop ? 18 : 16,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
