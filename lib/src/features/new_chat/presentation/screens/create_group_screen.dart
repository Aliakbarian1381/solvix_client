// In: lib/src/features/new_chat/presentation/screens/create_group_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solvix/src/core/api/chat/chat_service.dart';
import 'package:solvix/src/core/api/user/user_service.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/features/contacts/presentation/bloc/contacts_bloc.dart';
import 'package:solvix/src/features/home/presentation/bloc/chat_list_bloc.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({super.key});

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final Set<int> _selectedUserIds = {};
  final _groupTitleController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    context.read<ContactsBloc>().add(ContactsProcessStarted());
  }

  @override
  void dispose() {
    _groupTitleController.dispose();
    super.dispose();
  }

  void _toggleUserSelection(int userId) {
    setState(() {
      if (_selectedUserIds.contains(userId)) {
        _selectedUserIds.remove(userId);
      } else {
        _selectedUserIds.add(userId);
      }
    });
  }

  Future<void> _createGroup() async {
    if (_groupTitleController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('لطفاً یک نام برای گروه انتخاب کنید.')),
      );
      return;
    }
    if (_selectedUserIds.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('حداقل باید دو نفر را برای ساخت گروه انتخاب کنید.'),
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final chatService = context.read<ChatService>();
      await chatService.createGroupChat(
        _groupTitleController.text.trim(),
        _selectedUserIds.toList(),
      );

      // Refresh chat list
      context.read<ChatListBloc>().add(FetchChatList());

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('خطا در ساخت گروه: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('گروه جدید'),
        actions: [
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: CircularProgressIndicator(),
            )
          else
            IconButton(icon: const Icon(Icons.check), onPressed: _createGroup),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _groupTitleController,
              decoration: const InputDecoration(
                labelText: 'نام گروه',
                prefixIcon: Icon(Icons.group),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16.0,
              vertical: 8.0,
            ),
            child: Text(
              '${_selectedUserIds.length} نفر انتخاب شده‌اند',
              style: theme.textTheme.titleSmall,
            ),
          ),
          Expanded(
            child: BlocBuilder<ContactsBloc, ContactsState>(
              builder: (context, state) {
                if (state.status == ContactsStatus.loading) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (state.status == ContactsStatus.failure) {
                  return Center(child: Text('خطا: ${state.errorMessage}'));
                }
                if (state.syncedContacts.isEmpty) {
                  return const Center(child: Text('هیچ مخاطبی یافت نشد.'));
                }
                return ListView.builder(
                  itemCount: state.syncedContacts.length,
                  itemBuilder: (context, index) {
                    final user = state.syncedContacts[index];
                    final isSelected = _selectedUserIds.contains(user.id);
                    return ListTile(
                      leading: CircleAvatar(
                        // ... (کد آواتار مشابه قبل)
                      ),
                      title: Text(
                        "${user.firstName ?? ''} ${user.lastName ?? ''}".trim(),
                      ),
                      subtitle: Text(user.phoneNumber ?? ''),
                      trailing: Checkbox(
                        value: isSelected,
                        onChanged: (bool? value) {
                          _toggleUserSelection(user.id);
                        },
                      ),
                      onTap: () => _toggleUserSelection(user.id),
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
