// lib/src/features/contacts/presentation/screens/contacts_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:solvix/src/features/contacts/presentation/bloc/contacts_bloc.dart';

class ContactsScreen extends StatefulWidget {
  const ContactsScreen({super.key});

  @override
  State<ContactsScreen> createState() => _ContactsScreenState();
}

class _ContactsScreenState extends State<ContactsScreen> {
  @override
  void initState() {
    super.initState();
    // ۱. رویداد جدید را برای شروع فرآیند ارسال می‌کنیم
    context.read<ContactsBloc>().add(ContactsProcessStarted());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocBuilder<ContactsBloc, ContactsState>(
        builder: (context, state) {
          switch (state.status) {
            case ContactsStatus.loading:
            case ContactsStatus.initial:
              return const Center(child: CircularProgressIndicator());

            // ۲. حالت جدید برای زمانی که دسترسی رد شده است
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
                        onPressed: () {
                          // با کلیک، دوباره فرآیند را شروع می‌کنیم
                          context.read<ContactsBloc>().add(
                            ContactsProcessStarted(),
                          );
                        },
                        child: const Text('اجازه دسترسی'),
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
                onRefresh: () async {
                  context.read<ContactsBloc>().add(ContactsProcessStarted());
                },
                child: ListView.builder(
                  itemCount: state.syncedContacts.length,
                  itemBuilder: (context, index) {
                    final user = state.syncedContacts[index];
                    return ListTile(
                      leading: CircleAvatar(
                        // ...
                      ),
                      title: Text(
                        "${user.firstName ?? ''} ${user.lastName ?? ''}".trim(),
                      ),
                      subtitle: Text(user.phoneNumber ?? 'شماره نامشخص'),
                      onTap: () {
                        // TODO: Navigate to start chat
                      },
                    );
                  },
                ),
              );
          }
        },
      ),
    );
  }
}
