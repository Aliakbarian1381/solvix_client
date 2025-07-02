import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solvix/src/core/api/chat/chat_service.dart';
import 'package:solvix/src/core/models/chat_model.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/core/network/signalr_service.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_bloc.dart';
import 'package:solvix/src/features/auth/presentation/bloc/auth_state.dart'
    as auth_bloc_states;
import 'package:solvix/src/features/chat/presentation/bloc/chat_messages_bloc.dart';
import 'package:solvix/src/features/chat/presentation/screens/chat_screen.dart';
import 'package:solvix/src/features/home/presentation/bloc/chat_list_bloc.dart';
import 'package:solvix/src/features/new_chat/presentation/bloc/new_chat_bloc.dart';
import 'package:solvix/src/features/new_chat/presentation/bloc/new_chat_event.dart';
import 'package:solvix/src/features/new_chat/presentation/bloc/new_chat_state.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final TextEditingController _searchController = TextEditingController();
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is auth_bloc_states.AuthSuccess) {
      _currentUser = authState.user;
    }

    _searchController.addListener(() {
      context.read<NewChatBloc>().add(
        SearchUsersQueryChanged(_searchController.text),
      );
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _startChatWithUser(
    BuildContext pageContext,
    UserModel recipientUser,
  ) async {
    if (_currentUser == null || _currentUser!.id == recipientUser.id) {
      if (mounted) {
        ScaffoldMessenger.of(pageContext).showSnackBar(
          const SnackBar(
            content: Text('امکان شروع چت با خودتان وجود ندارد!'),
            backgroundColor: Colors.orangeAccent,
          ),
        );
      }
      return;
    }

    showDialog(
      context: pageContext,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return const Center(child: CircularProgressIndicator());
      },
    );

    try {
      final chatService = pageContext.read<ChatService>();
      final result = await chatService.startChatWithUser(recipientUser.id);
      final chatId = result['chatId'] as String;

      if (mounted) Navigator.of(pageContext, rootNavigator: true).pop();

      if (mounted) pageContext.read<ChatListBloc>().add(FetchChatList());

      if (mounted) {
        Navigator.pushReplacement(
          pageContext,
          MaterialPageRoute(
            builder: (routeBuilderContext) => BlocProvider(
              create: (blocContext) => ChatMessagesBloc(
                blocContext.read<ChatService>(),
                blocContext.read<SignalRService>(),
                chatId: chatId,
                currentUserId: _currentUser!.id,
              ),
              child: ChatScreen(
                chatModel: ChatModel(
                  id: chatId,
                  isGroup: false,
                  title:
                      "${recipientUser.firstName ?? ''} ${recipientUser.lastName ?? ''}"
                          .trim()
                          .isEmpty
                      ? recipientUser.username
                      : "${recipientUser.firstName ?? ''} ${recipientUser.lastName ?? ''}"
                            .trim(),
                  createdAt: DateTime.now(),
                  unreadCount: 0,
                  participants: [_currentUser!, recipientUser],
                ),
                currentUser: _currentUser,
              ),
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) Navigator.of(pageContext, rootNavigator: true).pop();
      if (mounted) {
        ScaffoldMessenger.of(pageContext).showSnackBar(
          SnackBar(
            content: Text(
              'خطا در شروع چت: ${e.toString().replaceFirst("Exception: ", "")}',
            ),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: theme.canvasColor,
      appBar: AppBar(
        title: const Text(
          'گفتگوی جدید',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        backgroundColor: theme.canvasColor,
        elevation: 0.8,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: theme.primaryColor,
            size: 22,
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'جستجو بر اساس نام یا شماره...',
                hintStyle: TextStyle(color: theme.hintColor),
                prefixIcon: Icon(
                  Icons.search_rounded,
                  color: theme.primaryColor.withOpacity(0.7),
                ),
                filled: true,
                // --- اصلاح رنگ فیلد جستجو ---
                fillColor: theme.scaffoldBackgroundColor,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: theme.primaryColor, width: 1.5),
                ),
                contentPadding: const EdgeInsets.symmetric(vertical: 14),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: Icon(Icons.clear_rounded, color: theme.hintColor),
                        onPressed: () {
                          _searchController.clear();
                          context.read<NewChatBloc>().add(LoadOnlineUsers());
                        },
                      )
                    : null,
              ),
            ),
          ),
          Expanded(
            child: BlocBuilder<NewChatBloc, NewChatState>(
              builder: (context, state) {
                if (state.status == NewChatStatus.loading &&
                    state.users.isEmpty) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == NewChatStatus.failure) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.cloud_off_rounded,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'خطا: ${state.errorMessage}',
                          style: TextStyle(color: Colors.red.shade400),
                        ),
                      ],
                    ),
                  );
                }
                if (state.users.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          state.currentQuery.isNotEmpty
                              ? Icons.search_off_rounded
                              : Icons.wifi_off_rounded,
                          size: 60,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          state.currentQuery.isNotEmpty
                              ? 'هیچ کاربری با این مشخصات یافت نشد.'
                              : 'در حال حاضر کاربر آنلاینی یافت نشد.',
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 15,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  );
                }
                return ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  itemCount: state.users.length,
                  itemBuilder: (context, index) {
                    final user = state.users[index];
                    if (user.id == _currentUser?.id) {
                      return const SizedBox.shrink();
                    }
                    return _UserListItem(
                      user: user,
                      onTap: () => _startChatWithUser(context, user),
                    );
                  },
                  separatorBuilder: (context, index) {
                    final user = state.users[index];
                    if (user.id == _currentUser?.id)
                      return const SizedBox.shrink();
                    if (index + 1 < state.users.length &&
                        state.users[index + 1].id == _currentUser?.id)
                      return const SizedBox.shrink();

                    return Divider(
                      height: 1,
                      indent: 80,
                      color: theme.dividerColor,
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _UserListItem extends StatelessWidget {
  final UserModel user;
  final VoidCallback onTap;

  const _UserListItem({required this.user, required this.onTap});

  String _getAvatarInitials() {
    String firstName = user.firstName ?? "";
    String lastName = user.lastName ?? "";
    String username = user.username;

    if (firstName.isNotEmpty && lastName.isNotEmpty) {
      return (firstName[0] + lastName[0]).toUpperCase();
    } else if (firstName.isNotEmpty) {
      return firstName[0].toUpperCase();
    } else if (lastName.isNotEmpty) {
      return lastName[0].toUpperCase();
    } else if (username.isNotEmpty) {
      return username[0].toUpperCase();
    }
    return "?";
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListTile(
      onTap: onTap,
      leading: CircleAvatar(
        radius: 26,
        backgroundColor: theme.primaryColor.withOpacity(0.1),
        child: Text(
          _getAvatarInitials(),
          style: TextStyle(
            color: theme.primaryColor,
            fontWeight: FontWeight.bold,
            fontSize: 17,
          ),
        ),
      ),
      title: Text(
        "${user.firstName ?? ''} ${user.lastName ?? ''}".trim().isEmpty
            ? user.username
            : "${user.firstName ?? ''} ${user.lastName ?? ''}".trim(),
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        user.phoneNumber ?? 'شماره نامشخص',
        style: theme.textTheme.bodyMedium?.copyWith(color: theme.hintColor),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: user.isOnline
          ? Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                // --- اصلاح رنگ پس‌زمینه نشانگر آنلاین ---
                color: theme.cardColor,
                boxShadow: [
                  BoxShadow(
                    color: Colors.green.withOpacity(0.3),
                    spreadRadius: 1,
                    blurRadius: 3,
                  ),
                ],
              ),
              child: const CircleAvatar(
                radius: 5,
                backgroundColor: Colors.greenAccent,
              ),
            )
          : null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    );
  }
}
