import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'package:solvix/src/core/api/chat/chat_service.dart';
import 'package:solvix/src/core/models/chat_model.dart';
import 'package:solvix/src/core/models/message_model.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/core/network/signalr_service.dart';
import 'package:solvix/src/features/chat/presentation/bloc/chat_messages_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:solvix/src/core/theme/app_theme.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../../core/models/client_message_status.dart';
import '../../../../core/network/connection_status/connection_status_bloc.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../../utils/date_formatter.dart';
import 'package:solvix/src/features/group/presentation/screens/group_info_screen.dart';
import 'package:solvix/src/features/group/presentation/bloc/group_info_bloc.dart';
import 'package:solvix/src/features/group/presentation/bloc/group_members_bloc.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_state.dart' as auth_states;


class ChatScreen extends StatefulWidget {
  final ChatModel chatModel;
  final UserModel? currentUser;
  final bool isDesktopView;

  const ChatScreen({
    super.key,
    required this.chatModel,
    required this.currentUser,
    this.isDesktopView = false,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _didDeleteMessage = false;
  bool _showScrollToBottomButton = false;
  final ScrollController _scrollController = ScrollController();

  // Track message count to determine when to show scroll button
  int _messageCount = 0;
  bool _isNearBottom = true;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_scrollListener);

    if (widget.currentUser != null) {
      context
          .read<ChatMessagesBloc>()
          .stream
          .firstWhere((state) => state is ChatMessagesLoaded)
          .then((_) {
            if (mounted) {
              context.read<ChatMessagesBloc>().add(const MarkMessagesAsRead());
              _scrollToLastUnreadOrBottom();
            }
          });
      context.read<ChatMessagesBloc>().add(
        FetchChatMessages(widget.chatModel.id),
      );
    }
  }

  void _scrollListener() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;

      // Consider "near bottom" if within 100 pixels of bottom
      _isNearBottom = (maxScroll - currentScroll) <= 100;

      // Show scroll button only if:
      // 1. We have more than 6 messages
      // 2. We're not near the bottom
      final shouldShowButton = _messageCount > 6 && !_isNearBottom;

      if (shouldShowButton != _showScrollToBottomButton) {
        setState(() {
          _showScrollToBottomButton = shouldShowButton;
        });
      }
    }
  }

  void _scrollToLastUnreadOrBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;

      final state = context.read<ChatMessagesBloc>().state;
      if (state is ChatMessagesLoaded) {
        final currentUserId = widget.currentUser?.id;

        // Find last unread message
        int? lastUnreadIndex;
        for (int i = state.messages.length - 1; i >= 0; i--) {
          final message = state.messages[i];
          if (message.senderId != currentUserId && !message.isRead) {
            lastUnreadIndex = i;
            break;
          }
        }

        if (lastUnreadIndex != null) {
          // Scroll to last unread message
          _scrollController.animateTo(
            lastUnreadIndex * 100.0,
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          );
        } else {
          // Scroll to bottom
          _scrollToBottom(animate: true, afterBuild: false);
        }
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true, bool afterBuild = true}) {
    void doScroll() {
      if (_scrollController.hasClients &&
          _scrollController.position.hasContentDimensions) {
        if (animate) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        } else {
          _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
        }
      }
    }

    if (afterBuild) {
      WidgetsBinding.instance.addPostFrameCallback((_) => doScroll());
    } else {
      doScroll();
    }
  }

  UserModel? _getOtherParticipant() {
    if (!widget.chatModel.isGroup &&
        widget.currentUser != null &&
        widget.chatModel.participants.isNotEmpty) {
      try {
        return widget.chatModel.participants.firstWhere(
          (p) => p.id != widget.currentUser!.id,
        );
      } catch (e) {
        return widget.chatModel.participants.length == 1
            ? widget.chatModel.participants.first
            : null;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = widget.currentUser?.id;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 600 || widget.isDesktopView;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: isDark
            ? const Color(0xFF0B1426)
            : const Color(0xFFF7F8FC),
        body: Center(
          child: Container(
            padding: EdgeInsets.all(isDesktop ? 32 : 24),
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
                        blurRadius: isDesktop ? 24 : 20,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: Icon(
                    Icons.error_outline_rounded,
                    color: Colors.white,
                    size: isDesktop ? 48 : 40,
                  ),
                ).animate().scale(
                  duration: const Duration(milliseconds: 600),
                  curve: Curves.elasticOut,
                ),
                SizedBox(height: isDesktop ? 32 : 24),
                Text(
                  "خطا در بارگذاری چت",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 24 : 20,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ).animate().fadeIn(delay: const Duration(milliseconds: 150)),
                SizedBox(height: isDesktop ? 12 : 8),
                Text(
                  "اطلاعات کاربر برای نمایش چت یافت نشد.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 14,
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontWeight: FontWeight.w400,
                  ),
                ).animate().fadeIn(delay: const Duration(milliseconds: 250)),
              ],
            ),
          ),
        ),
      );
    }

    final otherParticipant = _getOtherParticipant();

    return Scaffold(
      backgroundColor: isDark
          ? const Color(0xFF0B1426)
          : const Color(0xFFF7F8FC),
      appBar: widget.isDesktopView
          ? null
          : _ModernChatAppBar(
              otherParticipant: otherParticipant,
              chatModel: widget.chatModel,
              isDesktop: isDesktop,
            ),
      body: Stack(
        children: [
          Column(
            children: [
              // Desktop header
              if (widget.isDesktopView)
                _buildDesktopHeader(otherParticipant, isDesktop, isDark),

              Expanded(
                child: Container(
                  constraints: isDesktop && !widget.isDesktopView
                      ? const BoxConstraints(maxWidth: 800)
                      : null,
                  margin: isDesktop && !widget.isDesktopView
                      ? const EdgeInsets.symmetric(horizontal: 24)
                      : null,
                  child: BlocConsumer<ChatMessagesBloc, ChatMessagesState>(
                    listener: (context, state) {
                      if (state is ChatMessagesLoaded) {
                        // Update message count
                        setState(() {
                          _messageCount = state.messages.length;
                        });

                        final bool wasAtBottom = _isNearBottom;

                        if (wasAtBottom ||
                            (state.messages.isNotEmpty &&
                                state.messages.last.senderId ==
                                    currentUserId)) {
                          _scrollToBottom(animate: true, afterBuild: true);
                        }
                      }
                    },
                    builder: (context, state) {
                      if (state is ChatMessagesLoading &&
                          state is! ChatMessagesLoaded) {
                        return _buildLoadingState(isDesktop, isDark);
                      }
                      if (state is ChatMessagesLoaded) {
                        if (state.messages.isEmpty) {
                          return _buildEmptyState(isDesktop, isDark);
                        }

                        List<Widget> chatItemsWithDateSeparators = [];
                        DateTime? lastMessageDate;

                        for (var message in state.messages) {
                          final messageDate = DateTime(
                            message.sentAt.year,
                            message.sentAt.month,
                            message.sentAt.day,
                          );
                          if (lastMessageDate == null ||
                              !messageDate.isAtSameMomentAs(lastMessageDate)) {
                            chatItemsWithDateSeparators.add(
                              _ModernDateSeparator(
                                date: message.sentAt,
                                isDesktop: isDesktop,
                              ),
                            );
                            lastMessageDate = messageDate;
                          }
                          final bool isMe = message.senderId == currentUserId;
                          chatItemsWithDateSeparators.add(
                            _ModernMessageBubble(
                                  message: message,
                                  isMe: isMe,
                                  isDesktop: isDesktop,
                                )
                                .animate()
                                .slideX(
                                  begin: isMe ? 0.05 : -0.05,
                                  duration: const Duration(milliseconds: 400),
                                  curve: Curves.easeOutCubic,
                                )
                                .then()
                                .fadeIn(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                ),
                          );
                        }

                        return ListView.builder(
                          controller: _scrollController,
                          padding: EdgeInsets.symmetric(
                            vertical: isDesktop ? 16 : 12,
                            horizontal: isDesktop ? 24 : 16,
                          ),
                          itemCount: chatItemsWithDateSeparators.length,
                          itemBuilder: (context, index) {
                            return chatItemsWithDateSeparators[index];
                          },
                        );
                      }
                      if (state is ChatMessagesError) {
                        return _buildErrorState(
                          state.message,
                          isDesktop,
                          isDark,
                        );
                      }
                      return _buildLoadingState(isDesktop, isDark);
                    },
                  ),
                ),
              ),
              Container(
                constraints: isDesktop && !widget.isDesktopView
                    ? const BoxConstraints(maxWidth: 800)
                    : null,
                margin: isDesktop && !widget.isDesktopView
                    ? const EdgeInsets.symmetric(horizontal: 24)
                    : null,
                child: _ModernMessageInput(
                  currentUserId: currentUserId,
                  chatId: widget.chatModel.id,
                  isDesktop: isDesktop,
                ),
              ),
            ],
          ),
          // Scroll to bottom button
          if (_showScrollToBottomButton)
            Positioned(
              bottom: isDesktop ? 100 : 80,
              right: isDesktop ? 40 : 20,
              child:
                  Container(
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: Theme.of(
                            context,
                          ).primaryColor.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(28),
                        onTap: () {
                          HapticFeedback.lightImpact();
                          _scrollToBottom(animate: true, afterBuild: false);
                        },
                        child: Container(
                          width: 56,
                          height: 56,
                          child: Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 28,
                          ),
                        ),
                      ),
                    ),
                  ).animate().scale(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutBack,
                  ),
            ),
        ],
      ),
    );
  }

  Widget _buildDesktopHeader(
    UserModel? otherParticipant,
    bool isDesktop,
    bool isDark,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
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
                _getChatTitle().substring(0, 1).toUpperCase(),
                style: TextStyle(
                  color: Theme.of(context).primaryColor,
                  fontWeight: FontWeight.w700,
                  fontSize: 20,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _getChatTitle(),
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 18,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                ),
                if (otherParticipant != null)
                  Text(
                    otherParticipant.isOnline ? 'آنلاین' : 'آفلاین',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : Colors.black54,
                    ),
                  ),
              ],
            ),
          ),
          _buildDesktopActionButtons(isDark),
        ],
      ),
    );
  }

  Widget _buildDesktopActionButtons(bool isDark) {
    return Row(
      children: [
        _buildDesktopActionButton(Icons.call_rounded, 'تماس صوتی', isDark),
        const SizedBox(width: 8),
        _buildDesktopActionButton(
          Icons.videocam_rounded,
          'تماس تصویری',
          isDark,
        ),
      ],
    );
  }

  Widget _buildDesktopActionButton(IconData icon, String tooltip, bool isDark) {
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
        icon: Icon(icon, color: Colors.white, size: 20),
        tooltip: tooltip,
        onPressed: () {
          HapticFeedback.lightImpact();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('$tooltip به زودی اضافه خواهد شد.'),
              backgroundColor: Theme.of(context).primaryColor,
            ),
          );
        },
      ),
    );
  }

  String _getChatTitle() {
    if (widget.chatModel.title != null && widget.chatModel.title!.isNotEmpty) {
      return widget.chatModel.title!;
    }
    final otherParticipant = _getOtherParticipant();
    if (otherParticipant != null) {
      return "${otherParticipant.firstName ?? ''} ${otherParticipant.lastName ?? ''}"
              .trim()
              .isEmpty
          ? otherParticipant.username
          : "${otherParticipant.firstName ?? ''} ${otherParticipant.lastName ?? ''}"
                .trim();
    }
    return "چت";
  }

  Widget _buildLoadingState(bool isDesktop, bool isDark) {
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
                  color: Theme.of(context).primaryColor.withOpacity(0.3),
                  blurRadius: isDesktop ? 20 : 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Center(
              child: SizedBox(
                width: isDesktop ? 32 : 28,
                height: isDesktop ? 32 : 28,
                child: const CircularProgressIndicator(
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
            'در حال بارگذاری پیام‌ها...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: isDesktop ? 18 : 16,
              fontWeight: FontWeight.w500,
            ),
          ).animate().fadeIn(delay: const Duration(milliseconds: 300)),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDesktop, bool isDark) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 48 : 32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 120 : 96,
              height: isDesktop ? 120 : 96,
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isDesktop ? 30 : 24),
                border: Border.all(
                  color: Theme.of(context).primaryColor.withOpacity(0.2),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.chat_bubble_outline_rounded,
                size: isDesktop ? 60 : 48,
                color: Theme.of(context).primaryColor.withOpacity(0.6),
              ),
            ).animate().scale(
              duration: const Duration(milliseconds: 600),
              curve: Curves.elasticOut,
            ),
            SizedBox(height: isDesktop ? 32 : 24),
            Text(
              'اولین پیام را شما ارسال کنید!',
              style: TextStyle(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
            SizedBox(height: isDesktop ? 12 : 8),
            Text(
              'گفتگو را با ارسال پیام شروع کنید و تجربه‌ای فوق‌العاده داشته باشید.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ).animate().fadeIn(delay: const Duration(milliseconds: 300)),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, bool isDesktop, bool isDark) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 48 : 32),
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
                    blurRadius: isDesktop ? 24 : 20,
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
              'خطا در بارگذاری پیام‌ها',
              style: TextStyle(
                fontSize: isDesktop ? 24 : 20,
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ).animate().fadeIn(delay: const Duration(milliseconds: 200)),
            SizedBox(height: isDesktop ? 12 : 8),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDesktop ? 16 : 14,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w400,
                height: 1.5,
              ),
            ).animate().fadeIn(delay: const Duration(milliseconds: 300)),
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
                    borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                  ),
                ),
                icon: Icon(Icons.refresh_rounded, size: isDesktop ? 24 : 20),
                label: Text(
                  'تلاش مجدد',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isDesktop ? 18 : 16,
                  ),
                ),
                onPressed: () {
                  HapticFeedback.lightImpact();
                  context.read<ChatMessagesBloc>().add(
                    FetchChatMessages(widget.chatModel.id),
                  );
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
}

class _ModernChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final UserModel? otherParticipant;
  final ChatModel chatModel;
  final bool isDesktop;

  const _ModernChatAppBar({
    super.key,
    this.otherParticipant,
    required this.chatModel,
    required this.isDesktop,
  });

  String _getChatTitle() {
    if (chatModel.title != null && chatModel.title!.isNotEmpty) {
      return chatModel.title!;
    }
    if (otherParticipant != null) {
      return "${otherParticipant!.firstName ?? ''} ${otherParticipant!.lastName ?? ''}"
              .trim()
              .isEmpty
          ? otherParticipant!.username
          : "${otherParticipant!.firstName ?? ''} ${otherParticipant!.lastName ?? ''}"
                .trim();
    }
    return "چت";
  }

  String _getParticipantStatusSubtitle() {
    if (chatModel.isGroup) {
      return "${chatModel.participants.length} عضو";
    }
    if (otherParticipant != null) {
      if (otherParticipant!.isOnline) return "آنلاین";
      if (otherParticipant!.lastActive != null) {
        return formatLastSeen(otherParticipant!.lastActive!);
      }
      return "آفلاین";
    }
    return "";
  }

  String _getAvatarInitials() {
    String title = _getChatTitle();
    if (title.isEmpty || title == "چت") return "?";
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

  Widget _buildSubtitle(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocBuilder<ConnectionStatusBloc, ConnectionStatusState>(
      builder: (context, state) {
        String subtitleText;
        Color subtitleColor;
        IconData? subtitleIcon;

        if (state.signalRStatus == SignalRConnectionStatus.Connected) {
          subtitleText = _getParticipantStatusSubtitle();
          subtitleColor = isDark ? Colors.white60 : Colors.black54;
          subtitleIcon = null;
        } else {
          if (state.connectivityStatus == ConnectivityResult.none) {
            subtitleText = "اتصال برقرار نیست";
            subtitleColor = Colors.red.shade400;
            subtitleIcon = Icons.wifi_off_rounded;
          } else {
            subtitleText = "در حال بروزرسانی...";
            subtitleColor = Colors.orange.shade600;
            subtitleIcon = Icons.sync_rounded;
          }
        }

        if (subtitleText.isEmpty) {
          return const SizedBox.shrink();
        }

        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          transitionBuilder: (child, animation) {
            return FadeTransition(opacity: animation, child: child);
          },
          child: Row(
            key: ValueKey<String>(subtitleText),
            mainAxisSize: MainAxisSize.min,
            children: [
              if (subtitleIcon != null)
                Icon(
                  subtitleIcon,
                  size: isDesktop ? 15 : 14,
                  color: subtitleColor,
                ),
              if (subtitleIcon != null) const SizedBox(width: 4),
              Text(
                subtitleText,
                style: TextStyle(
                  fontSize: isDesktop ? 14 : 13,
                  color: subtitleColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark
          ? const Color(0xFF0B1426)
          : const Color(0xFFF7F8FC),
      leading: Container(
        margin: EdgeInsets.all(isDesktop ? 12 : 8),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
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
        child: IconButton(
          icon: Icon(
            Icons.arrow_back_rounded,
            color: isDark ? Colors.white70 : Colors.black54,
            size: isDesktop ? 24 : 20,
          ),
          onPressed: () {
            HapticFeedback.lightImpact();
            Navigator.of(context).pop();
          },
          padding: EdgeInsets.zero,
        ),
      ),
      centerTitle: false,
      titleSpacing: isDesktop ? 16 : 12,
      title: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: isDesktop ? 56 : 48,
                height: isDesktop ? 56 : 48,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      primaryColor.withOpacity(0.2),
                      primaryColor.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(
                    color: primaryColor.withOpacity(0.3),
                    width: 2,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: primaryColor.withOpacity(0.2),
                      blurRadius: isDesktop ? 12 : 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    _getAvatarInitials(),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: isDesktop ? 20 : 18,
                      color: primaryColor,
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
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getChatTitle(),
                  style: TextStyle(
                    fontSize: isDesktop ? 20 : 18,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                _buildSubtitle(context),
              ],
            ),
          ),
        ],
      ),
      actions: [
        _buildActionButton(
          context,
          Icons.call_rounded,
          'قابلیت تماس صوتی به زودی اضافه خواهد شد.',
          isDesktop,
          isDark,
          primaryColor,
        ),
        _buildActionButton(
          context,
          Icons.videocam_rounded,
          'قابلیت تماس تصویری به زودی اضافه خواهد شد.',
          isDesktop,
          isDark,
          primaryColor,
        ),
        if (chatModel.isGroup)
          _buildActionButton(
            context,
            Icons.info_outline_rounded,
            '',
            isDesktop,
            isDark,
            primaryColor,
            isGroupInfo: true,
          ),
        SizedBox(width: isDesktop ? 12 : 8),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String message,
    bool isDesktop,
    bool isDark,
    Color primaryColor, {
    bool isGroupInfo = false, // ⭐ پارامتر جدید
  }) {
    return Container(
      margin: EdgeInsets.symmetric(vertical: isDesktop ? 8 : 6),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(isDesktop ? 16 : 12),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.3),
            blurRadius: isDesktop ? 8 : 6,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: IconButton(
        icon: Icon(icon, color: Colors.white, size: isDesktop ? 20 : 18),
        onPressed: () {
          HapticFeedback.lightImpact();

          // ⭐ اضافه کردن منطق گروه
          if (isGroupInfo) {
            _navigateToGroupInfo(context);
          } else {
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
                        Icons.info_outline_rounded,
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
                backgroundColor: primaryColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                elevation: 0,
                duration: const Duration(seconds: 2),
              ),
            );
          }
        },
        padding: EdgeInsets.zero,
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  UserModel? _getCurrentUser(BuildContext context) {
    final authState = context.read<AuthBloc>().state;
    if (authState is auth_states.AuthSuccess) {
      return authState.user;
    }
    return null;
  }

  void _navigateToGroupInfo(BuildContext context) {
    final currentUser = _getCurrentUser(context);
    if (currentUser == null) return;

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MultiBlocProvider(
          providers: [
            BlocProvider.value(value: context.read<GroupInfoBloc>()),
            BlocProvider.value(value: context.read<GroupMembersBloc>()),
          ],
          child: GroupInfoScreen(
            chatId: chatModel.id,
            currentUser: currentUser,
          ),
        ),
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  final String chatId;
  final int currentUserId;

  const _TypingIndicator({required this.chatId, required this.currentUserId});

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;
  List<String> _typingUsers = [];
  StreamSubscription? _typingSubscription;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    _listenToTyping();
  }

  void _listenToTyping() {
    final signalRService = context.read<SignalRService>();
    _typingSubscription = signalRService.onUserTyping.listen((data) {
      final chatId = data['chatId'] as String?;
      final userId = data['userId'] as int?;
      final isTyping = data['isTyping'] as bool?;

      if (chatId == widget.chatId && userId != widget.currentUserId) {
        setState(() {
          final userName = _getUserName(userId);
          if (isTyping == true) {
            if (!_typingUsers.contains(userName)) {
              _typingUsers.add(userName);
            }
          } else {
            _typingUsers.remove(userName);
          }
        });

        if (_typingUsers.isNotEmpty) {
          _animationController.repeat();
        } else {
          _animationController.stop();
        }
      }
    });
  }

  String _getUserName(int? userId) {
    if (userId == null) return 'کاربر';
    // اینجا می‌توانید از cache یا state management برای گرفتن نام کاربر استفاده کنید
    return 'کاربر $userId';
  }

  @override
  void dispose() {
    _animationController.dispose();
    _typingSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_typingUsers.isEmpty) {
      return const SizedBox.shrink();
    }

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final typingText = _typingUsers.length == 1
        ? '${_typingUsers.first} در حال نوشتن...'
        : '${_typingUsers.length} نفر در حال نوشتن...';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : const Color(0xFFF8FAFC),
        border: Border(
          bottom: BorderSide(
            color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          AnimatedBuilder(
            animation: _animation,
            builder: (context, child) {
              return Row(
                children: [
                  for (int i = 0; i < 3; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.only(right: 2),
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: Theme.of(context).primaryColor.withOpacity(
                          (((_animation.value + i * 0.3) % 1.0) * 0.7) + 0.3,
                        ),
                        shape: BoxShape.circle,
                      ),
                    ),
                ],
              );
            },
          ),
          const SizedBox(width: 8),
          Text(
            typingText,
            style: TextStyle(
              fontSize: 12,
              color: isDark ? Colors.grey[400] : Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }
}

class _ModernMessageInput extends StatefulWidget {
  final int currentUserId;
  final String chatId;
  final bool isDesktop;

  const _ModernMessageInput({
    required this.currentUserId,
    required this.chatId,
    required this.isDesktop,
  });

  @override
  State<_ModernMessageInput> createState() => _ModernMessageInputState();
}

class _ModernMessageInputState extends State<_ModernMessageInput> {
  final TextEditingController _messageController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  final Uuid _uuid = const Uuid();
  bool _showSendButton = false;
  TextDirection _textDirection = TextDirection.rtl;
  Timer? _typingTimer;
  bool _isTyping = false;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      if (mounted) {
        final currentText = _messageController.text;
        _updateTextDirection(currentText);
        setState(() {
          _showSendButton = currentText.trim().isNotEmpty;
        });
        _handleTyping(currentText.isNotEmpty);
      }
    });
  }

  void _handleTyping(bool isTyping) {
    if (_isTyping != isTyping) {
      _isTyping = isTyping;
      _notifyTypingStatus(isTyping);
    }

    // Reset typing timer
    _typingTimer?.cancel();
    if (isTyping) {
      _typingTimer = Timer(const Duration(seconds: 2), () {
        if (_isTyping) {
          _isTyping = false;
          _notifyTypingStatus(false);
        }
      });
    }
  }

  void _notifyTypingStatus(bool isTyping) {
    try {
      final signalRService = context.read<SignalRService>();
      signalRService.notifyTyping(widget.chatId, isTyping);
    } catch (e) {
      print('Error notifying typing status: $e');
    }
  }

  void _updateTextDirection(String text) {
    if (text.isEmpty) {
      if (_textDirection != TextDirection.rtl) {
        setState(() {
          _textDirection = TextDirection.rtl;
        });
      }
      return;
    }

    final bool isRtl = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u0590-\u05FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(text[0]);

    final newDirection = isRtl ? TextDirection.rtl : TextDirection.ltr;
    if (_textDirection != newDirection) {
      setState(() {
        _textDirection = newDirection;
      });
    }
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    if (_isTyping) {
      _notifyTypingStatus(false);
    }
    _messageController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      HapticFeedback.lightImpact();
      final correlationId = _uuid.v4();

      // Stop typing indicator
      if (_isTyping) {
        _isTyping = false;
        _notifyTypingStatus(false);
      }

      context.read<ChatMessagesBloc>().add(
        SendNewMessage(content: text, correlationId: correlationId),
      );
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _focusNode.requestFocus();
        }
      });
    }
  }

  void _handleKeyEvent(KeyEvent event) {
    if (event is KeyDownEvent) {
      if (widget.isDesktop) {
        if (event.logicalKey == LogicalKeyboardKey.enter &&
            !HardwareKeyboard.instance.isShiftPressed) {
          _sendMessage();
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    return Column(
      children: [
        // Typing indicator
        _TypingIndicator(
          chatId: widget.chatId,
          currentUserId: widget.currentUserId,
        ),

        // Message input
        Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0B1426) : const Color(0xFFF7F8FC),
            border: Border(
              top: BorderSide(
                color: isDark
                    ? const Color(0xFF334155)
                    : const Color(0xFFE2E8F0),
                width: 1,
              ),
            ),
          ),
          child: Container(
            padding: EdgeInsets.symmetric(
              horizontal: widget.isDesktop ? 24 : 16,
              vertical: widget.isDesktop ? 16 : 12,
            ),
            child: Row(
              children: [
                // Message input field
                Expanded(
                  child: Container(
                    constraints: BoxConstraints(
                      maxHeight: widget.isDesktop ? 120 : 100,
                    ),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(
                        widget.isDesktop ? 24 : 20,
                      ),
                      border: Border.all(
                        color: isDark
                            ? const Color(0xFF475569)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      ),
                    ),
                    child: TextField(
                      controller: _messageController,
                      focusNode: _focusNode,
                      textDirection: _textDirection,
                      maxLines: null,
                      keyboardType: TextInputType.multiline,
                      style: TextStyle(
                        fontSize: widget.isDesktop ? 16 : 14,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      decoration: InputDecoration(
                        hintText: 'پیام خود را بنویسید...',
                        hintStyle: TextStyle(
                          color: isDark ? Colors.grey[400] : Colors.grey[600],
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          horizontal: widget.isDesktop ? 20 : 16,
                          vertical: widget.isDesktop ? 16 : 12,
                        ),
                      ),
                      onSubmitted: (_) {
                        if (widget.isDesktop) {
                          _sendMessage();
                        }
                      },
                    ),
                  ),
                ),

                SizedBox(width: widget.isDesktop ? 16 : 12),

                // Send button
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: widget.isDesktop ? 56 : 48,
                  height: widget.isDesktop ? 56 : 48,
                  decoration: BoxDecoration(
                    color: _showSendButton
                        ? primaryColor
                        : (isDark
                              ? const Color(0xFF475569)
                              : const Color(0xFFE2E8F0)),
                    borderRadius: BorderRadius.circular(
                      widget.isDesktop ? 28 : 24,
                    ),
                    boxShadow: _showSendButton
                        ? [
                            BoxShadow(
                              color: primaryColor.withOpacity(0.3),
                              blurRadius: widget.isDesktop ? 12 : 8,
                              offset: const Offset(0, 4),
                            ),
                          ]
                        : null,
                  ),
                  child: IconButton(
                    icon: Icon(
                      Icons.send_rounded,
                      color: _showSendButton
                          ? Colors.white
                          : (isDark ? Colors.grey[400] : Colors.grey[600]),
                      size: widget.isDesktop ? 24 : 20,
                    ),
                    onPressed: _showSendButton ? _sendMessage : null,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ModernMessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isDesktop;

  const _ModernMessageBubble({
    required this.message,
    required this.isMe,
    required this.isDesktop,
  });

  void _showMessageOptions(BuildContext context, MessageModel message) {
    if (isMe && !message.isDeleted) {
      HapticFeedback.lightImpact();

      final isDark = Theme.of(context).brightness == Brightness.dark;
      final primaryColor = Theme.of(context).primaryColor;

      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 50,
                  height: 5,
                  margin: const EdgeInsets.only(top: 20, bottom: 30),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF475569)
                        : const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: primaryColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.edit_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'ویرایش پیام',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                    ),
                    subtitle: Text(
                      'متن پیام را تغییر دهید',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? Colors.white60 : Colors.black54,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: primaryColor,
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showEditDialog(context, message);
                    },
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.red.shade200, width: 1),
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 8,
                    ),
                    leading: Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.red.shade500,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.red.shade500.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.delete_rounded,
                        color: Colors.white,
                        size: 20,
                      ),
                    ),
                    title: Text(
                      'حذف پیام',
                      style: TextStyle(
                        color: Colors.red.shade700,
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    subtitle: Text(
                      'پیام برای همه حذف خواهد شد',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.red.shade600,
                      ),
                    ),
                    trailing: Icon(
                      Icons.arrow_forward_ios_rounded,
                      size: 16,
                      color: Colors.red.shade500,
                    ),
                    onTap: () {
                      Navigator.of(ctx).pop();
                      _showDeleteConfirmation(context, message.id);
                    },
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showEditDialog(BuildContext context, MessageModel message) {
    final textController = TextEditingController(text: message.content);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).primaryColor;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.edit_rounded, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 16),
            Text(
              'ویرایش پیام',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isDark ? const Color(0xFF334155) : const Color(0xFFE2E8F0),
            ),
          ),
          child: TextField(
            controller: textController,
            autofocus: true,
            maxLines: null,
            style: TextStyle(
              fontWeight: FontWeight.w500,
              color: isDark ? Colors.white : Colors.black87,
            ),
            decoration: InputDecoration(
              hintText: 'متن جدید...',
              hintStyle: TextStyle(
                color: isDark ? Colors.white38 : Colors.black38,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.all(16),
            ),
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white60 : Colors.black54,
            ),
            child: const Text('لغو'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'ذخیره',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              final newContent = textController.text.trim();
              if (newContent.isNotEmpty) {
                context.read<ChatMessagesBloc>().add(
                  EditMessageRequested(
                    messageId: message.id,
                    newContent: newContent,
                  ),
                );
              }
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  void _showDeleteConfirmation(BuildContext context, int messageId) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                Icons.delete_rounded,
                color: Colors.red.shade500,
                size: 20,
              ),
            ),
            const SizedBox(width: 16),
            Text(
              'تایید حذف',
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
          ],
        ),
        content: Text(
          'آیا از حذف این پیام مطمئن هستید؟ این عمل غیرقابل بازگشت است.',
          style: TextStyle(
            height: 1.5,
            color: isDark ? Colors.white70 : Colors.black54,
          ),
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: isDark ? Colors.white60 : Colors.black54,
            ),
            child: const Text('لغو'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade500,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            child: const Text(
              'حذف',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            onPressed: () {
              context.read<ChatMessagesBloc>().add(
                DeleteMessageRequested(messageId: messageId),
              );
              Navigator.of(ctx).pop();
            },
          ),
        ],
      ),
    );
  }

  String _formatMessageBubbleTime(DateTime time) {
    final tehranTime = toTehran(time);
    return DateFormat('HH:mm').format(tehranTime);
  }

  Widget _buildStatusIcon(BuildContext context) {
    if (!isMe) return const SizedBox.shrink();

    Color iconColor;
    IconData iconData;

    switch (message.clientStatus) {
      case ClientMessageStatus.sending:
        iconData = Icons.access_time_rounded;
        iconColor = Colors.white70;
        break;
      case ClientMessageStatus.failed:
        iconData = Icons.error_outline_rounded;
        iconColor = Colors.red.shade300;
        break;
      case ClientMessageStatus.sent:
      default:
        if (message.isRead) {
          iconData = Icons.done_all_rounded;
          iconColor = Colors.lightBlue.shade300;
        } else {
          iconData = Icons.done_rounded;
          iconColor = Colors.white70;
        }
    }
    return Padding(
      padding: EdgeInsets.only(left: isDesktop ? 6 : 4),
      child: Icon(iconData, color: iconColor, size: isDesktop ? 16 : 14),
    );
  }

  bool _isRtlText(String text) {
    if (text.isEmpty) return true;
    return RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u0590-\u05FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(text[0]);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final isRtl = _isRtlText(message.content);

    if (message.isDeleted) {
      return Container(
        margin: EdgeInsets.symmetric(
          vertical: isDesktop ? 6 : 4,
          horizontal: isDesktop ? 8 : 4,
        ),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 16,
                vertical: isDesktop ? 12 : 10,
              ),
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width *
                    (isDesktop ? 0.6 : 0.75),
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF374151)
                    : const Color(0xFFF1F5F9),
                borderRadius: BorderRadius.circular(isDesktop ? 20 : 16),
                border: Border.all(
                  color: isDark
                      ? const Color(0xFF4B5563)
                      : const Color(0xFFE2E8F0),
                  width: 1,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.block_rounded,
                    size: isDesktop ? 18 : 16,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  SizedBox(width: isDesktop ? 10 : 8),
                  Flexible(
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: isDesktop ? 16 : 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    Color bubbleColor;
    Color textColor;

    if (isMe) {
      bubbleColor = theme.primaryColor;
      textColor = Colors.white;
    } else {
      bubbleColor = isDark ? const Color(0xFF1E293B) : Colors.white;
      textColor = isDark ? Colors.white : Colors.black87;
    }

    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isDesktop ? 20 : 18),
      topRight: Radius.circular(isDesktop ? 20 : 18),
      bottomLeft: isMe
          ? Radius.circular(isDesktop ? 20 : 18)
          : const Radius.circular(6),
      bottomRight: isMe
          ? const Radius.circular(6)
          : Radius.circular(isDesktop ? 20 : 18),
    );

    return GestureDetector(
      onTap: isDesktop ? null : () => _showMessageOptions(context, message),
      onSecondaryTap: isDesktop
          ? () => _showMessageOptions(context, message)
          : null,
      child: Container(
        margin: EdgeInsets.symmetric(
          vertical: isDesktop ? 6 : 4,
          horizontal: isDesktop ? 8 : 4,
        ),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 20 : 16,
                vertical: isDesktop ? 14 : 12,
              ),
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width *
                    (isDesktop ? 0.6 : 0.75),
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: borderRadius,
                border: !isMe
                    ? Border.all(
                        color: isDark
                            ? const Color(0xFF334155)
                            : const Color(0xFFE2E8F0),
                        width: 1,
                      )
                    : null,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(isDesktop ? 0.08 : 0.06),
                    blurRadius: isDesktop ? 8 : 6,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isRtl
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    textAlign: isRtl ? TextAlign.right : TextAlign.left,
                    style: TextStyle(
                      color: textColor,
                      fontSize: isDesktop ? 17 : 16,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 8 : 6),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isEdited)
                        Text(
                          'ویرایش شده ',
                          style: TextStyle(
                            fontSize: isDesktop ? 12 : 11,
                            fontStyle: FontStyle.italic,
                            color: textColor.withOpacity(0.7),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      Text(
                        _formatMessageBubbleTime(message.sentAt),
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: isDesktop ? 13 : 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      if (isMe) SizedBox(width: isDesktop ? 8 : 6),
                      if (isMe) _buildStatusIcon(context),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModernDateSeparator extends StatelessWidget {
  final DateTime date;
  final bool isDesktop;

  const _ModernDateSeparator({required this.date, required this.isDesktop});

  String _formatDateSeparator(DateTime time) {
    final jalaliDate = Jalali.fromDateTime(time);
    final nowJalali = Jalali.now();
    final yesterdayJalali = nowJalali.addDays(-1);

    if (jalaliDate.year == nowJalali.year &&
        jalaliDate.month == nowJalali.month &&
        jalaliDate.day == nowJalali.day) {
      return "امروز";
    }

    if (jalaliDate.year == yesterdayJalali.year &&
        jalaliDate.month == yesterdayJalali.month &&
        jalaliDate.day == yesterdayJalali.day) {
      return "دیروز";
    }

    if (nowJalali.distanceTo(jalaliDate).abs() < 7) {
      return jalaliDate.formatter.wN;
    }

    final f = jalaliDate.formatter;
    return '${f.d} ${f.mN}';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Center(
      child: Container(
        margin: EdgeInsets.symmetric(
          vertical: isDesktop ? 20 : 16,
          horizontal: isDesktop ? 16 : 12,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 20 : 16,
          vertical: isDesktop ? 10 : 8,
        ),
        decoration: BoxDecoration(
          color: theme.primaryColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
          border: Border.all(
            color: theme.primaryColor.withOpacity(0.2),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: isDesktop ? 8 : 6,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          _formatDateSeparator(date),
          style: TextStyle(
            color: theme.primaryColor,
            fontSize: isDesktop ? 14 : 13,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }
}
