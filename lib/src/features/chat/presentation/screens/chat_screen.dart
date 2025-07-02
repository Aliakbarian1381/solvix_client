import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:solvix/src/core/api/chat/chat_service.dart';
import 'package:solvix/src/core/models/chat_model.dart';
import 'package:solvix/src/core/models/message_model.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/core/network/signalr_service.dart';
import 'package:solvix/src/features/chat/presentation/bloc/chat_messages_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:solvix/src/core/theme/app_theme.dart';
import '../../../../core/models/client_message_status.dart';
import '../../../../core/utils/date_helper.dart';
import '../../../../utils/date_formatter.dart';

class ChatScreen extends StatefulWidget {
  final ChatModel chatModel;
  final UserModel? currentUser;

  const ChatScreen({
    super.key,
    required this.chatModel,
    required this.currentUser,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  bool _didDeleteMessage = false;
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    if (widget.currentUser != null) {
      context
          .read<ChatMessagesBloc>()
          .stream
          .firstWhere((state) => state is ChatMessagesLoaded)
          .then((_) {
            if (mounted) {
              context.read<ChatMessagesBloc>().add(const MarkMessagesAsRead());
            }
          });
      context.read<ChatMessagesBloc>().add(
        FetchChatMessages(widget.chatModel.id),
      );
    }
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
            duration: const Duration(milliseconds: 250),
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
    final isDesktop = screenWidth > 600;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (currentUserId == null) {
      return Scaffold(
        backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
        body: Center(
          child: Container(
            padding: EdgeInsets.all(isDesktop ? 32 : 24),
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
                ),
                SizedBox(height: isDesktop ? 24 : 20),
                Text(
                  "خطا: اطلاعات کاربر برای نمایش چت یافت نشد.",
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: isDesktop ? 16 : 15,
                    color: isDark ? Colors.white60 : Colors.black54,
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final otherParticipant = _getOtherParticipant();

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
      appBar: _TelegramChatAppBar(
        otherParticipant: otherParticipant,
        chatModel: widget.chatModel,
        isDesktop: isDesktop,
      ),
      body: Column(
        children: [
          Expanded(
            child: Container(
              constraints: isDesktop
                  ? const BoxConstraints(maxWidth: 800)
                  : null,
              margin: isDesktop
                  ? const EdgeInsets.symmetric(horizontal: 24)
                  : null,
              child: BlocConsumer<ChatMessagesBloc, ChatMessagesState>(
                listener: (context, state) {
                  if (state is ChatMessagesLoaded) {
                    final bool wasAtBottom =
                        _scrollController.hasClients &&
                        (_scrollController.position.maxScrollExtent -
                                _scrollController.position.pixels) <
                            100;
                    if (wasAtBottom ||
                        (state.messages.isNotEmpty &&
                            state.messages.last.senderId == currentUserId)) {
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
                          _TelegramDateSeparator(
                            date: message.sentAt,
                            isDesktop: isDesktop,
                          ),
                        );
                        lastMessageDate = messageDate;
                      }
                      final bool isMe = message.senderId == currentUserId;
                      chatItemsWithDateSeparators.add(
                        _TelegramMessageBubble(
                          message: message,
                          isMe: isMe,
                          isDesktop: isDesktop,
                        ),
                      );
                    }

                    return ListView.builder(
                      controller: _scrollController,
                      padding: EdgeInsets.symmetric(
                        vertical: isDesktop ? 12 : 8,
                        horizontal: isDesktop ? 16 : 12,
                      ),
                      itemCount: chatItemsWithDateSeparators.length,
                      itemBuilder: (context, index) {
                        return chatItemsWithDateSeparators[index];
                      },
                    );
                  }
                  if (state is ChatMessagesError) {
                    return _buildErrorState(state.message, isDesktop, isDark);
                  }
                  return _buildLoadingState(isDesktop, isDark);
                },
              ),
            ),
          ),
          Container(
            constraints: isDesktop ? const BoxConstraints(maxWidth: 800) : null,
            margin: isDesktop
                ? const EdgeInsets.symmetric(horizontal: 24)
                : null,
            child: _TelegramMessageInput(
              currentUserId: currentUserId,
              chatId: widget.chatModel.id,
              isDesktop: isDesktop,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDesktop, bool isDark) {
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
          ),
          SizedBox(height: isDesktop ? 20 : 16),
          Text(
            'در حال بارگذاری...',
            style: TextStyle(
              color: isDark ? Colors.white70 : Colors.black54,
              fontSize: isDesktop ? 15 : 14,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(bool isDesktop, bool isDark) {
    return Center(
      child: Container(
        padding: EdgeInsets.all(isDesktop ? 40 : 30),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: isDesktop ? 100 : 80,
              height: isDesktop ? 100 : 80,
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF1E1E1E)
                    : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(isDesktop ? 25 : 20),
              ),
              child: Icon(
                Icons.chat_bubble_outline,
                size: isDesktop ? 50 : 40,
                color: isDark ? Colors.white12 : Colors.black12,
              ),
            ),
            SizedBox(height: isDesktop ? 24 : 20),
            Text(
              'اولین پیام را شما ارسال کنید!',
              style: TextStyle(
                fontSize: isDesktop ? 18 : 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: isDesktop ? 8 : 6),
            Text(
              'گفتگو را با ارسال پیام شروع کنید.',
              style: TextStyle(
                fontSize: isDesktop ? 14 : 13,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String message, bool isDesktop, bool isDark) {
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
            ),
            SizedBox(height: isDesktop ? 24 : 20),
            Text(
              'خطا در بارگذاری پیام‌ها',
              style: TextStyle(
                fontSize: isDesktop ? 18 : 16,
                fontWeight: FontWeight.w500,
                color: isDark ? Colors.white : Colors.black87,
              ),
            ),
            SizedBox(height: isDesktop ? 8 : 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: isDesktop ? 14 : 13,
                color: isDark ? Colors.white60 : Colors.black54,
                fontWeight: FontWeight.w400,
              ),
            ),
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
                  borderRadius: BorderRadius.circular(isDesktop ? 12 : 10),
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
                context.read<ChatMessagesBloc>().add(
                  FetchChatMessages(widget.chatModel.id),
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _TelegramChatAppBar extends StatelessWidget
    implements PreferredSizeWidget {
  final UserModel? otherParticipant;
  final ChatModel chatModel;
  final bool isDesktop;

  const _TelegramChatAppBar({
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

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AppBar(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: isDark ? const Color(0xFF0D1117) : Colors.white,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back,
          color: isDark ? Colors.white : Colors.black87,
          size: isDesktop ? 24 : 22,
        ),
        onPressed: () {
          HapticFeedback.selectionClick();
          Navigator.of(context).pop();
        },
      ),
      centerTitle: false,
      titleSpacing: 0,
      title: Row(
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: isDesktop ? 44 : 40,
                height: isDesktop ? 44 : 40,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.15),
                      Theme.of(context).primaryColor.withOpacity(0.08),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Center(
                  child: Text(
                    _getAvatarInitials(),
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: isDesktop ? 16 : 14,
                      color: Theme.of(context).primaryColor,
                    ),
                  ),
                ),
              ),
              if (otherParticipant != null && otherParticipant!.isOnline)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: isDesktop ? 14 : 12,
                    height: isDesktop ? 14 : 12,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.green.shade400,
                      border: Border.all(
                        color: isDark ? const Color(0xFF0D1117) : Colors.white,
                        width: 2,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          SizedBox(width: isDesktop ? 14 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  _getChatTitle(),
                  style: TextStyle(
                    fontSize: isDesktop ? 17 : 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white : Colors.black87,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (_getParticipantStatusSubtitle().isNotEmpty)
                  Text(
                    _getParticipantStatusSubtitle(),
                    style: TextStyle(
                      fontSize: isDesktop ? 13 : 12,
                      color: isDark ? Colors.white60 : Colors.black54,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        IconButton(
          icon: Icon(
            Icons.call_outlined,
            color: isDark ? Colors.white70 : Colors.black54,
            size: isDesktop ? 24 : 22,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text('قابلیت تماس صوتی به زودی اضافه خواهد شد.'),
                backgroundColor: Theme.of(context).primaryColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        IconButton(
          icon: Icon(
            Icons.videocam_outlined,
            color: isDark ? Colors.white70 : Colors.black54,
            size: isDesktop ? 26 : 24,
          ),
          onPressed: () {
            HapticFeedback.selectionClick();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: const Text(
                  'قابلیت تماس تصویری به زودی اضافه خواهد شد.',
                ),
                backgroundColor: Theme.of(context).primaryColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                margin: const EdgeInsets.all(16),
                duration: const Duration(seconds: 2),
              ),
            );
          },
        ),
        SizedBox(width: isDesktop ? 8 : 4),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _TelegramMessageInput extends StatefulWidget {
  final int currentUserId;
  final String chatId;
  final bool isDesktop;

  const _TelegramMessageInput({
    required this.currentUserId,
    required this.chatId,
    required this.isDesktop,
  });

  @override
  State<_TelegramMessageInput> createState() => _TelegramMessageInputState();
}

class _TelegramMessageInputState extends State<_TelegramMessageInput> {
  final TextEditingController _messageController = TextEditingController();
  final Uuid _uuid = const Uuid();
  bool _showSendButton = false;
  TextAlign _textAlign = TextAlign.right;

  @override
  void initState() {
    super.initState();
    _messageController.addListener(() {
      if (mounted) {
        final currentText = _messageController.text;
        _updateTextAlignment(currentText);
        setState(() {
          _showSendButton = currentText.trim().isNotEmpty;
        });
      }
    });
  }

  void _updateTextAlignment(String text) {
    if (text.isEmpty) {
      if (_textAlign != TextAlign.right) {
        setState(() {
          _textAlign = TextAlign.right;
        });
      }
      return;
    }
    final bool isRtl = RegExp(
      r'[\u0600-\u06FF\u0750-\u077F\u0590-\u05FF\uFB50-\uFDFF\uFE70-\uFEFF]',
    ).hasMatch(text[0]);

    if (isRtl && _textAlign != TextAlign.right) {
      setState(() {
        _textAlign = TextAlign.right;
      });
    } else if (!isRtl && _textAlign != TextAlign.left) {
      setState(() {
        _textAlign = TextAlign.left;
      });
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    super.dispose();
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty) {
      HapticFeedback.selectionClick();
      final correlationId = _uuid.v4();
      context.read<ChatMessagesBloc>().add(
        SendNewMessage(content: text, correlationId: correlationId),
      );
      _messageController.clear();
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final chatScreenState = context
            .findAncestorStateOfType<_ChatScreenState>();
        chatScreenState?._scrollToBottom(animate: true, afterBuild: false);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0D1117) : Colors.white,
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF30363D) : const Color(0xFFE1E4E8),
            width: 0.5,
          ),
        ),
      ),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: widget.isDesktop ? 16 : 12,
          vertical: widget.isDesktop ? 12 : 8,
        ),
        child: SafeArea(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              if (!_showSendButton)
                IconButton(
                  icon: Icon(
                    Icons.attach_file,
                    color: isDark ? Colors.white54 : Colors.black45,
                    size: widget.isDesktop ? 24 : 22,
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'قابلیت ارسال فایل به زودی اضافه خواهد شد.',
                        ),
                        backgroundColor: Theme.of(context).primaryColor,
                        behavior: SnackBarBehavior.floating,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        margin: const EdgeInsets.all(16),
                        duration: const Duration(seconds: 2),
                      ),
                    );
                  },
                ),
              Expanded(
                child: Container(
                  constraints: BoxConstraints(
                    maxHeight: widget.isDesktop ? 120 : 100,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E1E1E)
                        : const Color(0xFFF5F5F5),
                    borderRadius: BorderRadius.circular(
                      widget.isDesktop ? 20 : 18,
                    ),
                  ),
                  child: TextField(
                    controller: _messageController,
                    textAlign: _textAlign,
                    style: TextStyle(
                      fontSize: widget.isDesktop ? 16 : 15,
                      color: isDark ? Colors.white : Colors.black87,
                      height: 1.3,
                    ),
                    decoration: InputDecoration(
                      hintText: "پیام خود را بنویسید...",
                      hintStyle: TextStyle(
                        color: isDark ? Colors.white54 : Colors.black45,
                        fontSize: widget.isDesktop ? 16 : 15,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: widget.isDesktop ? 14 : 12,
                        horizontal: widget.isDesktop ? 18 : 16,
                      ),
                      isDense: true,
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    maxLines: widget.isDesktop ? 6 : 5,
                    minLines: 1,
                    keyboardType: TextInputType.multiline,
                  ),
                ),
              ),
              SizedBox(width: widget.isDesktop ? 12 : 8),
              Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _showSendButton
                      ? _sendMessage
                      : () {
                          HapticFeedback.selectionClick();
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'قابلیت ارسال پیام صوتی به زودی اضافه خواهد شد.',
                              ),
                              backgroundColor: Theme.of(context).primaryColor,
                              behavior: SnackBarBehavior.floating,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              margin: const EdgeInsets.all(16),
                              duration: const Duration(seconds: 2),
                            ),
                          );
                        },
                  borderRadius: BorderRadius.circular(
                    widget.isDesktop ? 22 : 20,
                  ),
                  child: Container(
                    width: widget.isDesktop ? 44 : 40,
                    height: widget.isDesktop ? 44 : 40,
                    decoration: BoxDecoration(
                      color: Theme.of(context).primaryColor,
                      borderRadius: BorderRadius.circular(
                        widget.isDesktop ? 22 : 20,
                      ),
                    ),
                    child: Center(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 150),
                        transitionBuilder: (child, animation) {
                          return ScaleTransition(
                            scale: animation,
                            child: child,
                          );
                        },
                        child: _showSendButton
                            ? Icon(
                                Icons.send,
                                color: Colors.white,
                                size: widget.isDesktop ? 20 : 18,
                                key: const ValueKey('send'),
                              )
                            : Icon(
                                Icons.mic,
                                color: Colors.white,
                                size: widget.isDesktop ? 22 : 20,
                                key: const ValueKey('mic'),
                              ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TelegramMessageBubble extends StatelessWidget {
  final MessageModel message;
  final bool isMe;
  final bool isDesktop;

  const _TelegramMessageBubble({
    required this.message,
    required this.isMe,
    required this.isDesktop,
  });

  void _showMessageOptions(BuildContext context, MessageModel message) {
    if (isMe && !message.isDeleted) {
      HapticFeedback.selectionClick();
      showModalBottomSheet(
        context: context,
        backgroundColor: Colors.transparent,
        builder: (ctx) => Container(
          decoration: BoxDecoration(
            color: Theme.of(context).brightness == Brightness.dark
                ? const Color(0xFF1E1E1E)
                : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(top: 12, bottom: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).brightness == Brightness.dark
                        ? const Color(0xFF3A3A3A)
                        : const Color(0xFFE0E0E0),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.edit_outlined),
                  title: const Text('ویرایش پیام'),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showEditDialog(context, message);
                  },
                ),
                ListTile(
                  leading: Icon(
                    Icons.delete_outline,
                    color: Colors.red.shade400,
                  ),
                  title: Text(
                    'حذف پیام',
                    style: TextStyle(color: Colors.red.shade400),
                  ),
                  onTap: () {
                    Navigator.of(ctx).pop();
                    _showDeleteConfirmation(context, message.id);
                  },
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      );
    }
  }

  void _showEditDialog(BuildContext context, MessageModel message) {
    final textController = TextEditingController(text: message.content);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('ویرایش پیام'),
        content: TextField(
          controller: textController,
          autofocus: true,
          maxLines: null,
          decoration: const InputDecoration(
            hintText: 'متن جدید...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            child: const Text('لغو'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Theme.of(context).primaryColor,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('ذخیره'),
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
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('تایید حذف'),
        content: const Text(
          'آیا از حذف این پیام مطمئن هستید؟ این عمل غیرقابل بازگشت است.',
        ),
        actions: [
          TextButton(
            child: const Text('لغو'),
            onPressed: () => Navigator.of(ctx).pop(),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade400,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: const Text('حذف'),
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
        iconData = Icons.access_time;
        iconColor = Colors.white70;
        break;
      case ClientMessageStatus.failed:
        iconData = Icons.error_outline;
        iconColor = Colors.red.shade300;
        break;
      case ClientMessageStatus.sent:
      default:
        if (message.isRead) {
          iconData = Icons.done_all;
          iconColor = Colors.lightBlue.shade300;
        } else {
          iconData = Icons.done;
          iconColor = Colors.white70;
        }
    }
    return Padding(
      padding: EdgeInsets.only(left: isDesktop ? 4 : 2),
      child: Icon(iconData, color: iconColor, size: isDesktop ? 14 : 12),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    if (message.isDeleted) {
      return Container(
        margin: EdgeInsets.symmetric(vertical: isDesktop ? 4 : 3),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 16 : 12,
                vertical: isDesktop ? 10 : 8,
              ),
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width *
                    (isDesktop ? 0.6 : 0.75),
              ),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF30363D)
                    : const Color(0xFFF0F0F0),
                borderRadius: BorderRadius.circular(isDesktop ? 16 : 14),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.block,
                    size: isDesktop ? 16 : 14,
                    color: isDark ? Colors.white54 : Colors.black54,
                  ),
                  SizedBox(width: isDesktop ? 8 : 6),
                  Flexible(
                    child: Text(
                      message.content,
                      style: TextStyle(
                        fontStyle: FontStyle.italic,
                        color: isDark ? Colors.white54 : Colors.black54,
                        fontSize: isDesktop ? 15 : 14,
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
      bubbleColor = isDark ? const Color(0xFF1E1E1E) : const Color(0xFFF5F5F5);
      textColor = isDark ? Colors.white : Colors.black87;
    }

    final borderRadius = BorderRadius.only(
      topLeft: Radius.circular(isDesktop ? 16 : 14),
      topRight: Radius.circular(isDesktop ? 16 : 14),
      bottomLeft: isMe
          ? Radius.circular(isDesktop ? 16 : 14)
          : const Radius.circular(4),
      bottomRight: isMe
          ? const Radius.circular(4)
          : Radius.circular(isDesktop ? 16 : 14),
    );

    return GestureDetector(
      onLongPress: () => _showMessageOptions(context, message),
      child: Container(
        margin: EdgeInsets.symmetric(vertical: isDesktop ? 4 : 3),
        child: Row(
          mainAxisAlignment: isMe
              ? MainAxisAlignment.end
              : MainAxisAlignment.start,
          children: [
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isDesktop ? 16 : 12,
                vertical: isDesktop ? 10 : 8,
              ),
              constraints: BoxConstraints(
                maxWidth:
                    MediaQuery.of(context).size.width *
                    (isDesktop ? 0.6 : 0.75),
              ),
              decoration: BoxDecoration(
                color: bubbleColor,
                borderRadius: borderRadius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 2,
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: isMe
                    ? CrossAxisAlignment.end
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    message.content,
                    style: TextStyle(
                      color: textColor,
                      fontSize: isDesktop ? 16 : 15,
                      height: 1.3,
                    ),
                  ),
                  SizedBox(height: isDesktop ? 6 : 4),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (message.isEdited)
                        Text(
                          'ویرایش شد ',
                          style: TextStyle(
                            fontSize: isDesktop ? 11 : 10,
                            fontStyle: FontStyle.italic,
                            color: textColor.withOpacity(0.7),
                          ),
                        ),
                      Text(
                        _formatMessageBubbleTime(message.sentAt),
                        style: TextStyle(
                          color: textColor.withOpacity(0.7),
                          fontSize: isDesktop ? 12 : 11,
                        ),
                      ),
                      if (isMe) SizedBox(width: isDesktop ? 6 : 4),
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

class _TelegramDateSeparator extends StatelessWidget {
  final DateTime date;
  final bool isDesktop;

  const _TelegramDateSeparator({required this.date, required this.isDesktop});

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
          vertical: isDesktop ? 16 : 12,
          horizontal: isDesktop ? 12 : 8,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: isDesktop ? 16 : 12,
          vertical: isDesktop ? 8 : 6,
        ),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF30363D) : const Color(0xFFE8E8E8),
          borderRadius: BorderRadius.circular(isDesktop ? 14 : 12),
        ),
        child: Text(
          _formatDateSeparator(date),
          style: TextStyle(
            color: isDark ? Colors.white70 : Colors.black54,
            fontSize: isDesktop ? 13 : 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
