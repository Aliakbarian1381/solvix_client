// lib/src/features/contacts/presentation/screens/contacts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solvix/src/features/contacts/presentation/bloc/contacts_bloc.dart';
import 'package:permission_handler/permission_handler.dart';
import '../../../../core/api/chat/chat_service.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/network/signalr_service.dart';
import '../../../auth/presentation/bloc/auth_bloc.dart';
import '../../../chat/presentation/bloc/chat_messages_bloc.dart';
import '../../../chat/presentation/screens/chat_screen.dart';
import '../../../auth/presentation/bloc/auth_state.dart' as auth_state;

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  UserModel? _currentUser;

  @override
  void initState() {
    super.initState();
    // اطلاعات کاربر فعلی را از AuthBloc می‌خوانیم
    final authState = context.read<AuthBloc>().state;
    if (authState is auth_state.AuthSuccess) {
      _currentUser = authState.user;
    }
    // فرآیند دریافت مخاطبین را شروع می‌کنیم
    context.read<ContactsBloc>().add(ContactsProcessStarted());
  }

  @override
  Widget build(BuildContext context) {
    // از BlocListener برای مدیریت ناوبری (رفتن به صفحه چت) استفاده می‌کنیم
    return BlocListener<ContactsBloc, ContactsState>(
      listener: (context, state) {
        if (state.chatToOpen != null && _currentUser != null) {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => BlocProvider(
                create: (blocContext) => ChatMessagesBloc(
                  blocContext.read<ChatService>(),
                  blocContext.read<SignalRService>(),
                  chatId: state.chatToOpen!.id,
                  currentUserId: _currentUser!.id,
                ),
                child: ChatScreen(
                  chatModel: state.chatToOpen!,
                  currentUser: _currentUser,
                ),
              ),
            ),
          );
        }
        // می‌توانید برای نمایش خطاها هم از SnackBar استفاده کنید
        if (state.status == ContactsStatus.failure &&
            state.errorMessage.isNotEmpty) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text(state.errorMessage)));
        }
      },
      child: Scaffold(
        body: BlocBuilder<ContactsBloc, ContactsState>(
          builder: (context, state) {
            switch (state.status) {
              case ContactsStatus.loading:
              case ContactsStatus.initial:
                return const Center(child: CircularProgressIndicator());

              // حالت نمایش پیشرفت همگام‌سازی
              case ContactsStatus.syncing:
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(),
                      const SizedBox(height: 24),
                      Text(
                        'در حال همگام‌سازی مخاطبین...',
                        style: TextStyle(
                          fontSize: 16,
                          color: Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${state.syncedCount} از ${state.totalContacts}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Colors.grey,
                        ),
                      ),
                    ],
                  ),
                );

              // حالت دسترسی رد شده (موقت)
              case ContactsStatus.permissionDenied:
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.contact_page_outlined,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'برای یافتن دوستانتان، نیاز به دسترسی به مخاطبین شما داریم.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => context.read<ContactsBloc>().add(
                            ContactsProcessStarted(),
                          ),
                          child: const Text('اجازه دسترسی'),
                        ),
                      ],
                    ),
                  ),
                );

              // حالت دسترسی رد شده (دائمی)
              case ContactsStatus.permissionPermanentlyDenied:
                return Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(
                          Icons.settings_suggest_outlined,
                          size: 80,
                          color: Colors.grey,
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'شما دسترسی به مخاطبین را به صورت دائمی رد کرده‌اید. برای استفاده از این بخش، لطفاً از تنظیمات برنامه دسترسی را فعال کنید.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, height: 1.5),
                        ),
                        const SizedBox(height: 24),
                        ElevatedButton(
                          onPressed: () => openAppSettings(),
                          child: const Text('باز کردن تنظیمات'),
                        ),
                      ],
                    ),
                  ),
                );

              case ContactsStatus.failure:
                return Center(child: Text('خطا: ${state.errorMessage}'));

              case ContactsStatus.success:
                if (state.syncedContacts.isEmpty) {
                  return const Center(
                    child: Text(
                      'هیچکدام از مخاطبین شما از این برنامه استفاده نمی‌کنند.',
                      textAlign: TextAlign.center,
                    ),
                  );
                }
                return RefreshIndicator(
                  onRefresh: () async => context.read<ContactsBloc>().add(
                    ContactsProcessStarted(),
                  ),
                  child: ListView.builder(
                    itemCount: state.syncedContacts.length,
                    itemBuilder: (context, index) {
                      final user = state.syncedContacts[index];
                      final fullName =
                          "${user.firstName ?? ''} ${user.lastName ?? ''}"
                              .trim();
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(fullName.isNotEmpty ? fullName[0] : '?'),
                        ),
                        title: Text(
                          fullName.isNotEmpty ? fullName : user.username,
                        ),
                        subtitle: Text(user.phoneNumber ?? 'شماره نامشخص'),
                        onTap: () {
                          // با کلیک روی هر مخاطب، رویداد شروع چت را ارسال می‌کنیم
                          if (_currentUser != null) {
                            context.read<ContactsBloc>().add(
                              StartChatWithContact(
                                recipient: user,
                                currentUser: _currentUser!,
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                );
            }
          },
        ),
      ),
    );
  }
}
