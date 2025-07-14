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
  bool _isRefreshing = false;

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

    final authState = context.read<AuthBloc>().state;
    if (authState is auth_state.AuthSuccess) {
      _currentUser = authState.user;
    }

    context.read<ContactsBloc>().add(ContactsProcessStarted());
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _refreshController.dispose();
    super.dispose();
  }

  Future<void> _handleRefresh() async {
    if (_isRefreshing) return;

    setState(() {
      _isRefreshing = true;
    });

    HapticFeedback.lightImpact();
    _refreshController.repeat();

    context.read<ContactsBloc>().add(RefreshContacts());

    // حداقل 1 ثانیه صبر کنیم برای UX بهتر
    await Future.delayed(const Duration(milliseconds: 1000));

    setState(() {
      _isRefreshing = false;
    });

    _refreshController.stop();
    _refreshController.reset();
  }

  String _formatLastSeen(DateTime? lastActive) {
    if (lastActive == null) return 'نامشخص';

    final localTime = toTehran(lastActive);
    final now = DateTime.now();
    final difference = now.difference(localTime);

    if (difference.inMinutes < 1) {
      return 'همین الان';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} دقیقه پیش';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} روز پیش';
    } else {
      final jalaliDate = Jalali.fromDateTime(localTime);
      return '${jalaliDate.formatter.d} ${jalaliDate.formatter.mN}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 800;

    return BlocListener<ContactsBloc, ContactsState>(
      listener: (context, state) {
        if (state.chatToOpen != null && _currentUser != null) {
          _navigateToChat(state.chatToOpen!);
        }

        if (state.errorMessage.isNotEmpty) {
          _showErrorSnackBar(state.errorMessage);
        }
      },
      child: Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0B1426)
            : const Color(0xFFF7F8FC),
        body: SafeArea(
          child: Column(
            children: [
              _buildHeader(context, isDark, isDesktop),
              Expanded(
                child: BlocBuilder<ContactsBloc, ContactsState>(
                  builder: (context, state) {
                    return _buildContent(context, state, isDark, isDesktop);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, bool isDark, bool isDesktop) {
    return Container(
      padding: EdgeInsets.all(isDesktop ? 24 : 20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0B1426) : const Color(0xFFF7F8FC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // آیکون مخاطبین
          Container(
                width: isDesktop ? 48 : 44,
                height: isDesktop ? 48 : 44,
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
                  boxShadow: [
                    BoxShadow(
                      color: Theme.of(context).primaryColor.withOpacity(0.3),
                      blurRadius: isDesktop ? 12 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  Icons.people_rounded,
                  color: Colors.white,
                  size: isDesktop ? 24 : 22,
                ),
              )
              .animate(controller: _animationController)
              .scale(
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
              ),
          SizedBox(width: isDesktop ? 16 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                      'مخاطبین',
                      style: TextStyle(
                        fontSize: isDesktop ? 24 : 20,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    )
                    .animate(controller: _animationController)
                    .slideX(
                      begin: -0.2,
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                    ),
                BlocBuilder<ContactsBloc, ContactsState>(
                      builder: (context, state) {
                        String subtitle = '';
                        if (state.status == ContactsStatus.backgroundSyncing) {
                          subtitle = 'در حال بروزرسانی...';
                        } else if (state.lastSyncTime != null) {
                          final now = DateTime.now();
                          final diff = now.difference(state.lastSyncTime!);
                          if (diff.inMinutes < 1) {
                            subtitle = 'همین الان بروزرسانی شد';
                          } else if (diff.inMinutes < 60) {
                            subtitle =
                                '${diff.inMinutes} دقیقه پیش بروزرسانی شد';
                          } else {
                            subtitle = '${state.syncedContacts.length} مخاطب';
                          }
                        } else {
                          subtitle = '${state.syncedContacts.length} مخاطب';
                        }

                        return Text(
                          subtitle,
                          style: TextStyle(
                            fontSize: isDesktop ? 14 : 13,
                            color:
                                state.status == ContactsStatus.backgroundSyncing
                                ? Theme.of(context).primaryColor
                                : (isDark ? Colors.white60 : Colors.black54),
                            fontWeight: FontWeight.w500,
                          ),
                        );
                      },
                    )
                    .animate(controller: _animationController)
                    .slideX(
                      begin: -0.2,
                      delay: const Duration(milliseconds: 100),
                      duration: const Duration(milliseconds: 600),
                      curve: Curves.easeOutCubic,
                    ),
              ],
            ),
          ),
          // دکمه refresh
          Container(
                decoration: BoxDecoration(
                  color: isDark
                      ? const Color(0xFF1E293B).withOpacity(0.6)
                      : Colors.white.withOpacity(0.8),
                  borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
                  border: Border.all(
                    color: isDark
                        ? const Color(0xFF334155)
                        : const Color(0xFFE2E8F0),
                  ),
                ),
                child: IconButton(
                  icon: AnimatedBuilder(
                    animation: _refreshController,
                    builder: (context, child) {
                      return Transform.rotate(
                        angle: _refreshController.value * 2 * 3.14159,
                        child: Icon(
                          Icons.refresh_rounded,
                          color: _isRefreshing
                              ? Theme.of(context).primaryColor
                              : (isDark ? Colors.white70 : Colors.black54),
                          size: isDesktop ? 22 : 20,
                        ),
                      );
                    },
                  ),
                  onPressed: _isRefreshing ? null : _handleRefresh,
                ),
              )
              .animate(controller: _animationController)
              .scaleXY(
                begin: 0.0,
                delay: const Duration(milliseconds: 300),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutBack,
              ),
        ],
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    ContactsState state,
    bool isDark,
    bool isDesktop,
  ) {
    switch (state.status) {
      case ContactsStatus.initial:
      case ContactsStatus.loading:
        return _buildLoadingState(isDark, isDesktop);

      case ContactsStatus.syncing:
        return _buildSyncingState(state, isDark, isDesktop);

      case ContactsStatus.permissionDenied:
        return _buildPermissionDeniedState(isDark, isDesktop);

      case ContactsStatus.permissionPermanentlyDenied:
        return _buildPermissionPermanentlyDeniedState(isDark, isDesktop);

      case ContactsStatus.failure:
        return _buildErrorState(state.errorMessage, isDark, isDesktop);

      case ContactsStatus.success:
      case ContactsStatus.backgroundSyncing:
      case ContactsStatus.refreshing:
        if (state.syncedContacts.isEmpty) {
          return _buildEmptyState(isDark, isDesktop);
        }
        return _buildContactsList(state, isDark, isDesktop);

      default:
        return _buildLoadingState(isDark, isDesktop);
    }
  }

  Widget _buildLoadingState(bool isDark, bool isDesktop) {
    return Center(
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
            child: Center(
              child: SizedBox(
                width: isDesktop ? 32 : 28,
                height: isDesktop ? 32 : 28,
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
          SizedBox(height: isDesktop ? 32 : 24),
          Text(
            'در حال بارگذاری مخاطبین...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.w500,
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
        ],
      ),
    );
  }

  Widget _buildSyncingState(ContactsState state, bool isDark, bool isDesktop) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: isDesktop ? 100 : 80,
            height: isDesktop ? 100 : 80,
            decoration: BoxDecoration(
              color: Theme.of(context).primaryColor,
              borderRadius: BorderRadius.circular(isDesktop ? 25 : 20),
              boxShadow: [
                BoxShadow(
                  color: Theme.of(context).primaryColor.withOpacity(0.25),
                  blurRadius: isDesktop ? 24 : 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                width: isDesktop ? 36 : 32,
                height: isDesktop ? 36 : 32,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 3,
                ),
              ),
            ),
          ).animate().scale(
            duration: const Duration(milliseconds: 600),
            curve: Curves.elasticOut,
          ),
          SizedBox(height: isDesktop ? 32 : 24),
          Text(
            'در حال همگام‌سازی مخاطبین...',
            style: TextStyle(
              fontSize: isDesktop ? 20 : 18,
              fontWeight: FontWeight.w600,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 150)),
          SizedBox(height: isDesktop ? 16 : 12),
          Text(
            '${state.syncedCount} از ${state.totalContacts}',
            style: TextStyle(
              fontSize: isDesktop ? 16 : 14,
              color: isDark ? Colors.white60 : Colors.black54,
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
          SizedBox(height: isDesktop ? 24 : 20),
          Container(
            width: isDesktop ? 300 : 250,
            height: isDesktop ? 8 : 6,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
              borderRadius: BorderRadius.circular(isDesktop ? 4 : 3),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: state.totalContacts > 0
                  ? (state.syncedCount / state.totalContacts).clamp(0.0, 1.0)
                  : 0.0,
              child: Container(
                decoration: BoxDecoration(
                  color: Theme.of(context).primaryColor,
                  borderRadius: BorderRadius.circular(isDesktop ? 4 : 3),
                ),
              ),
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 250)),
        ],
      ),
    );
  }

  Widget _buildPermissionDeniedState(bool isDark, bool isDesktop) {
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
                color: Colors.orange.shade400,
                borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.orange.shade400.withOpacity(0.25),
                    blurRadius: isDesktop ? 24 : 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.contact_page_outlined,
                size: isDesktop ? 60 : 50,
                color: Colors.white,
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 600),
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
            ).animate().slideY(
              begin: 0.2,
              delay: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
            ),
            SizedBox(height: isDesktop ? 16 : 12),
            Text(
              'برای یافتن دوستانتان، نیاز به دسترسی به مخاطبین شما داریم.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDesktop ? 18 : 16,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ).animate().fadeIn(delay: const Duration(milliseconds: 300)),
            SizedBox(height: isDesktop ? 40 : 32),
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
                    borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
                  ),
                ),
                icon: Icon(Icons.lock_open_rounded, size: isDesktop ? 22 : 20),
                label: Text(
                  'اجازه دسترسی',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isDesktop ? 16 : 15,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.read<ContactsBloc>().add(ContactsProcessStarted());
                },
              ),
            ).animate().scale(
              delay: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPermissionPermanentlyDeniedState(bool isDark, bool isDesktop) {
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
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.shade400.withOpacity(0.25),
                    blurRadius: isDesktop ? 24 : 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.settings_suggest_outlined,
                size: isDesktop ? 60 : 50,
                color: Colors.white,
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 600),
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
            ).animate().slideY(
              begin: 0.2,
              delay: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
            ),
            SizedBox(height: isDesktop ? 16 : 12),
            Text(
              'شما دسترسی به مخاطبین را به صورت دائمی رد کرده‌اید. برای استفاده از این بخش، لطفاً از تنظیمات برنامه دسترسی را فعال کنید.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDesktop ? 18 : 16,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.5,
                fontWeight: FontWeight.w400,
              ),
            ).animate().fadeIn(delay: const Duration(milliseconds: 300)),
            SizedBox(height: isDesktop ? 40 : 32),
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
                    borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
                  ),
                ),
                icon: Icon(Icons.settings_rounded, size: isDesktop ? 22 : 20),
                label: Text(
                  'باز کردن تنظیمات',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isDesktop ? 16 : 15,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  openAppSettings();
                },
              ),
            ).animate().scale(
              delay: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String errorMessage, bool isDark, bool isDesktop) {
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
                color: Colors.red.shade400,
                borderRadius: BorderRadius.circular(isDesktop ? 30 : 25),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.shade400.withOpacity(0.25),
                    blurRadius: isDesktop ? 24 : 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Icon(
                Icons.error_outline_rounded,
                size: isDesktop ? 60 : 50,
                color: Colors.white,
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 600),
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
            ).animate().slideY(
              begin: 0.2,
              delay: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
            ),
            SizedBox(height: isDesktop ? 16 : 12),
            Text(
              errorMessage,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: isDark ? Colors.white60 : Colors.black54,
                height: 1.4,
              ),
            ).animate().fadeIn(delay: const Duration(milliseconds: 300)),
            SizedBox(height: isDesktop ? 40 : 32),
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
                    borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
                  ),
                ),
                icon: Icon(Icons.refresh_rounded, size: isDesktop ? 22 : 20),
                label: Text(
                  'تلاش مجدد',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isDesktop ? 16 : 15,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  context.read<ContactsBloc>().add(ContactsProcessStarted());
                },
              ),
            ).animate().scale(
              delay: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark, bool isDesktop) {
    return RefreshIndicator(
      color: Theme.of(context).primaryColor,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      strokeWidth: 2.5,
      onRefresh: _handleRefresh,
      child: LayoutBuilder(
        builder: (ctx, constraints) => SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: ConstrainedBox(
            constraints: BoxConstraints(minHeight: constraints.maxHeight),
            child: Center(
              child: Padding(
                padding: EdgeInsets.all(isDesktop ? 48 : 32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: isDesktop ? 140 : 120,
                      height: isDesktop ? 140 : 120,
                      decoration: BoxDecoration(
                        color: isDark
                            ? const Color(0xFF1E293B)
                            : const Color(0xFFF1F5F9),
                        borderRadius: BorderRadius.circular(
                          isDesktop ? 35 : 30,
                        ),
                        border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : const Color(0xFFE2E8F0),
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.people_outline_rounded,
                        size: isDesktop ? 70 : 60,
                        color: isDark ? Colors.white24 : Colors.black26,
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
                    ).animate().slide(
                      begin: const Offset(0, 0.2),
                      delay: const Duration(milliseconds: 200),
                      curve: Curves.easeOutCubic,
                    ),
                    SizedBox(height: isDesktop ? 16 : 12),
                    Text(
                      'هیچکدام از مخاطبین شما از این برنامه استفاده نمی‌کنند.\nدوستانتان را دعوت کنید تا بتوانید با آن‌ها چت کنید.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: isDesktop ? 18 : 16,
                        color: isDark ? Colors.white60 : Colors.black54,
                        height: 1.5,
                        fontWeight: FontWeight.w400,
                      ),
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
                              Icons.share_rounded,
                              color: Theme.of(context).primaryColor,
                              size: isDesktop ? 20 : 18,
                            ),
                          ),
                          SizedBox(width: isDesktop ? 12 : 10),
                          Text(
                            'دوستانتان را دعوت کنید',
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

  Widget _buildContactsList(ContactsState state, bool isDark, bool isDesktop) {
    return RefreshIndicator(
      color: Theme.of(context).primaryColor,
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      strokeWidth: 2.5,
      onRefresh: _handleRefresh,
      child: ListView.separated(
        padding: EdgeInsets.symmetric(vertical: isDesktop ? 12 : 8),
        itemCount: state.syncedContacts.length,
        separatorBuilder: (context, index) => Container(
          margin: EdgeInsets.only(right: isDesktop ? 88 : 80),
          child: Divider(
            height: 1,
            thickness: 0.5,
            color: isDark ? const Color(0xFF1E293B) : const Color(0xFFE2E8F0),
          ),
        ),
        itemBuilder: (context, index) {
          final contact = state.syncedContacts[index];
          return _ContactListItem(
            contact: contact,
            isDesktop: isDesktop,
            onTap: () {
              if (_currentUser != null) {
                HapticFeedback.selectionClick();
                context.read<ContactsBloc>().add(
                  StartChatWithContact(
                    recipient: contact,
                    currentUser: _currentUser!,
                  ),
                );
              }
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
      // بعد از بازگشت از چت، state را reset کنیم
      context.read<ContactsBloc>().add(ResetChatToOpen());
    });
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
}

class _ContactListItem extends StatelessWidget {
  final UserModel contact;
  final bool isDesktop;
  final VoidCallback onTap;

  const _ContactListItem({
    required this.contact,
    required this.isDesktop,
    required this.onTap,
  });

  String _getFullName() {
    final fullName = "${contact.firstName ?? ''} ${contact.lastName ?? ''}"
        .trim();
    return fullName.isEmpty ? contact.username : fullName;
  }

  String _getAvatarInitials() {
    final name = _getFullName();
    if (name.isEmpty) return "?";

    final words = name.split(' ').where((s) => s.isNotEmpty).toList();
    if (words.length > 1 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return (words[0][0] + words[1][0]).toUpperCase();
    } else if (words.isNotEmpty && words[0].isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return "?";
  }

  String _formatLastSeen(DateTime? lastActive) {
    if (lastActive == null) return 'نامشخص';

    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inMinutes < 1) {
      return 'همین الان';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} دقیقه پیش';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} روز پیش';
    } else {
      final jalaliDate = Jalali.fromDateTime(lastActive);
      return '${jalaliDate.formatter.d} ${jalaliDate.formatter.mN}';
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

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
              // Avatar
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    width: isDesktop ? 56 : 52,
                    height: isDesktop ? 56 : 52,
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
                          fontSize: isDesktop ? 18 : 16,
                        ),
                      ),
                    ),
                  ),
                  // Online indicator
                  if (contact.isOnline)
                    Positioned(
                      bottom: 2,
                      right: 2,
                      child: Container(
                        width: isDesktop ? 16 : 14,
                        height: isDesktop ? 16 : 14,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: Colors.green.shade400,
                          border: Border.all(
                            color: isDark
                                ? const Color(0xFF0B1426)
                                : const Color(0xFFF7F8FC),
                            width: 2,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              SizedBox(width: isDesktop ? 16 : 12),
              // Contact info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getFullName(),
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isDesktop ? 16 : 15,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isDesktop ? 4 : 2),
                    Text(
                      contact.isOnline
                          ? 'آنلاین'
                          : _formatLastSeen(contact.lastActive),
                      style: TextStyle(
                        color: contact.isOnline
                            ? Colors.green.shade400
                            : (isDark ? Colors.white54 : Colors.black54),
                        fontSize: isDesktop ? 14 : 13,
                        fontWeight: FontWeight.w400,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Phone number
              if (contact.phoneNumber != null)
                Padding(
                  padding: EdgeInsets.only(left: isDesktop ? 12 : 8),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: isDesktop ? 12 : 8,
                      vertical: isDesktop ? 6 : 4,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E293B).withOpacity(0.6)
                          : Colors.white.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        width: 0.5,
                      ),
                    ),
                    child: Text(
                      contact.phoneNumber!,
                      style: TextStyle(
                        fontSize: isDesktop ? 12 : 11,
                        color: isDark ? Colors.white70 : Colors.black54,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              // Arrow
              SizedBox(width: isDesktop ? 8 : 4),
              Icon(
                Icons.arrow_forward_ios_rounded,
                size: isDesktop ? 16 : 14,
                color: isDark ? Colors.white24 : Colors.black26,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
