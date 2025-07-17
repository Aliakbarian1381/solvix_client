import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:solvix/src/core/models/group_info_model.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/features/group/presentation/bloc/group_members_bloc.dart';
import 'package:solvix/src/features/contacts/presentation/screens/contacts_screen.dart';

class GroupMembersScreen extends StatefulWidget {
  final String chatId;
  final GroupInfoModel groupInfo;
  final UserModel? currentUser;

  const GroupMembersScreen({
    super.key,
    required this.chatId,
    required this.groupInfo,
    required this.currentUser,
  });

  @override
  State<GroupMembersScreen> createState() => _GroupMembersScreenState();
}

class _GroupMembersScreenState extends State<GroupMembersScreen> {
  late GroupRole? currentUserRole;

  bool get isOwner => currentUserRole == GroupRole.owner;

  bool get isAdmin => currentUserRole == GroupRole.admin || isOwner;

  @override
  void initState() {
    super.initState();
    currentUserRole = _getCurrentUserRole();
    context.read<GroupMembersBloc>().add(LoadGroupMembers(widget.chatId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('اعضای گروه (${widget.groupInfo.membersCount})'),
        actions: [
          if (isAdmin && widget.groupInfo.membersCount <
              widget.groupInfo.settings.maxMembers)
            IconButton(
              onPressed: _addMembers,
              icon: const Icon(Icons.person_add),
              tooltip: 'اضافه کردن عضو',
            ),
        ],
      ),
      body: BlocConsumer<GroupMembersBloc, GroupMembersState>(
        listener: (context, state) {
          if (state is GroupMembersError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is GroupMembersUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is GroupMembersLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is GroupMembersLoaded) {
            return _buildMembersList(context, state.members);
          }

          if (state is GroupMembersError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 64,
                    color: Colors.red[300],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<GroupMembersBloc>().add(
                          LoadGroupMembers(widget.chatId));
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('تلاش مجدد'),
                  ),
                ],
              ),
            );
          }

          return _buildMembersList(context, widget.groupInfo.members);
        },
      ),
    );
  }

  Widget _buildMembersList(BuildContext context,
      List<GroupMemberModel> members) {
    // Sort members: Owner first, then Admins, then Members
    final sortedMembers = List<GroupMemberModel>.from(members);
    sortedMembers.sort((a, b) {
      if (a.role != b.role) {
        return b.role.index.compareTo(
            a.role.index); // Owner=2, Admin=1, Member=0
      }
      return a.displayName.compareTo(b.displayName);
    });

    return ListView.builder(
      itemCount: sortedMembers.length,
      itemBuilder: (context, index) {
        final member = sortedMembers[index];
        return _buildMemberTile(context, member);
      },
    );
  }

  Widget _buildMemberTile(BuildContext context, GroupMemberModel member) {
    final theme = Theme.of(context);
    final isCurrentUser = member.userId == widget.currentUser?.id;
    final canManage = isAdmin && !isCurrentUser &&
        member.role != GroupRole.owner;

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Stack(
          children: [
            CircleAvatar(
              radius: 24,
              backgroundColor: theme.primaryColor.withOpacity(0.1),
              backgroundImage: member.profilePictureUrl != null
                  ? CachedNetworkImageProvider(member.profilePictureUrl!)
                  : null,
              child: member.profilePictureUrl == null
                  ? Text(
                member.displayName.isNotEmpty
                    ? member.displayName[0].toUpperCase()
                    : 'U',
                style: TextStyle(
                  color: theme.primaryColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              )
                  : null,
            ),
            if (member.isOnline)
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Colors.green,
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                  ),
                ),
              ),
          ],
        ),
        title: Row(
          children: [
            Expanded(
              child: Text(
                member.displayName,
                style: const TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 16,
                ),
              ),
            ),
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: theme.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'شما',
                  style: TextStyle(
                    color: theme.primaryColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                _buildRoleBadge(member.role),
                const SizedBox(width: 8),
                Text(
                  '@${member.username}',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              member.isOnline
                  ? 'آنلاین'
                  : 'آخرین بازدید: ${_formatLastSeen(member.lastSeen)}',
              style: TextStyle(
                color: member.isOnline ? Colors.green : Colors.grey[500],
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'عضو از: ${_formatDate(member.joinedAt)}',
              style: TextStyle(
                color: Colors.grey[500],
                fontSize: 12,
              ),
            ),
          ],
        ),
        trailing: canManage
            ? PopupMenuButton<String>(
          onSelected: (value) => _handleMemberAction(context, value, member),
          itemBuilder: (context) =>
          [
            if (member.role == GroupRole.member && isOwner)
              const PopupMenuItem(
                value: 'promote_admin',
                child: Row(
                  children: [
                    Icon(Icons.admin_panel_settings, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('ارتقا به ادمین'),
                  ],
                ),
              ),
            if (member.role == GroupRole.admin && isOwner)
              const PopupMenuItem(
                value: 'demote_member',
                child: Row(
                  children: [
                    Icon(Icons.remove_moderator, color: Colors.orange),
                    SizedBox(width: 8),
                    Text('تنزل به عضو'),
                  ],
                ),
              ),
            if (isOwner && member.role != GroupRole.owner)
              const PopupMenuItem(
                value: 'transfer_ownership',
                child: Row(
                  children: [
                    Icon(Icons.crown, color: Colors.amber),
                    SizedBox(width: 8),
                    Text('انتقال مالکیت'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'remove',
              child: Row(
                children: [
                  Icon(Icons.person_remove, color: Colors.red),
                  SizedBox(width: 8),
                  Text('حذف از گروه', style: TextStyle(color: Colors.red)),
                ],
              ),
            ),
          ],
        )
            : null,
      ),
    );
  }

  Widget _buildRoleBadge(GroupRole role) {
    Color color;
    String text;
    IconData icon;

    switch (role) {
      case GroupRole.owner:
        color = Colors.amber;
        text = 'مالک';
        icon = Icons.crown;
        break;
      case GroupRole.admin:
        color = Colors.blue;
        text = 'ادمین';
        icon = Icons.admin_panel_settings;
        break;
      case GroupRole.member:
        color = Colors.grey;
        text = 'عضو';
        icon = Icons.person;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _handleMemberAction(BuildContext context, String action,
      GroupMemberModel member) {
    switch (action) {
      case 'promote_admin':
        _showPromoteDialog(context, member);
        break;
      case 'demote_member':
        _showDemoteDialog(context, member);
        break;
      case 'transfer_ownership':
        _showTransferOwnershipDialog(context, member);
        break;
      case 'remove':
        _showRemoveMemberDialog(context, member);
        break;
    }
  }

  void _showPromoteDialog(BuildContext context, GroupMemberModel member) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('ارتقا به ادمین'),
            content: Text(
              'آیا می‌خواهید ${member.displayName} را به ادمین ارتقا دهید؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<GroupMembersBloc>().add(
                    UpdateMemberRole(
                      chatId: widget.chatId,
                      memberId: member.userId,
                      newRole: GroupRole.admin,
                    ),
                  );
                },
                child: const Text('ارتقا'),
              ),
            ],
          ),
    );
  }

  void _showDemoteDialog(BuildContext context, GroupMemberModel member) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('تنزل به عضو'),
            content: Text(
              'آیا می‌خواهید ${member.displayName} را به عضو عادی تنزل دهید؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<GroupMembersBloc>().add(
                    UpdateMemberRole(
                      chatId: widget.chatId,
                      memberId: member.userId,
                      newRole: GroupRole.member,
                    ),
                  );
                },
                child: const Text('تنزل'),
              ),
            ],
          ),
    );
  }

  void _showTransferOwnershipDialog(BuildContext context,
      GroupMemberModel member) {
    showDialog(
        context: context,
        builder: (context) =>
            AlertDialog(
                title: const Text('انتقال مالکیت'),
                content: Text(
                  'آیا مطمئن هستید که می‌خواهید مالکیت گروه را به ${member
                      .displayName} منتقل کنید؟ این عمل قابل بازگشت نیست.',
                ),
                actions: [
                TextButton(
                onPressed: () => Navigator.pop(context),
    child: const Text('انصراف'),
    ),
    TextButton(
    onPressed: () {
    Navigator.pop(context);
    context.read<GroupMembersBloc>().add(
    TransferOwnership(
    chatId: widget.chatId,
    newOwnerId: member.userId,
    ),
    );
    },
    TextButton(
    onPressed: () {
    Navigator.pop(context);
    context.read<GroupMembersBloc>().add(
    TransferOwnership(
    chatId: widget.chatId,
    newOwnerId: member.userId,
    ),
    );
    },
    child: const Text(
    'انتقال',
    style: TextStyle(color: Colors.red),
    ),
    ),
    ],
    ),
    );
  }

  void _showRemoveMemberDialog(BuildContext context, GroupMemberModel member) {
    showDialog(
      context: context,
      builder: (context) =>
          AlertDialog(
            title: const Text('حذف عضو'),
            content: Text(
              'آیا می‌خواهید ${member.displayName} را از گروه حذف کنید؟',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('انصراف'),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(context);
                  context.read<GroupMembersBloc>().add(
                    RemoveMember(
                      chatId: widget.chatId,
                      memberId: member.userId,
                    ),
                  );
                },
                child: const Text(
                  'حذف',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );
  }

  void _addMembers() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            AddMembersScreen(
              chatId: widget.chatId,
              existingMemberIds: widget.groupInfo.members
                  .map((m) => m.userId)
                  .toList(),
            ),
      ),
    ).then((selectedUserIds) {
      if (selectedUserIds != null && selectedUserIds is List<int> &&
          selectedUserIds.isNotEmpty) {
        context.read<GroupMembersBloc>().add(
          AddMembers(
            chatId: widget.chatId,
            userIds: selectedUserIds,
          ),
        );
      }
    });
  }

  GroupRole? _getCurrentUserRole() {
    if (widget.currentUser == null) return null;

    final currentMember = widget.groupInfo.members.firstWhere(
          (member) => member.userId == widget.currentUser!.id,
      orElse: () =>
      const GroupMemberModel(
        userId: -1,
        username: '',
        role: GroupRole.member,
        joinedAt: DateTime.now(),
        isOnline: false,
      ),
    );

    return currentMember.userId != -1 ? currentMember.role : null;
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final difference = now.difference(date);

    if (difference.inDays == 0) {
      return 'امروز';
    } else if (difference.inDays == 1) {
      return 'دیروز';
    } else if (difference.inDays < 30) {
      return '${difference.inDays} روز پیش';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '$months ماه پیش';
    } else {
      final years = (difference.inDays / 365).floor();
      return '$years سال پیش';
    }
  }

  String _formatLastSeen(DateTime? lastSeen) {
    if (lastSeen == null) return 'نامشخص';

    final now = DateTime.now();
    final difference = now.difference(lastSeen);

    if (difference.inMinutes < 1) {
      return 'همین الان';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} دقیقه پیش';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} روز پیش';
    } else {
      return _formatDate(lastSeen);
    }
  }
}

// =============================================================================
// ADD MEMBERS SCREEN - صفحه اضافه کردن عضو جدید
// =============================================================================

class AddMembersScreen extends StatefulWidget {
  final String chatId;
  final List<int> existingMemberIds;

  const AddMembersScreen({
    super.key,
    required this.chatId,
    required this.existingMemberIds,
  });

  @override
  State<AddMembersScreen> createState() => _AddMembersScreenState();
}

class _AddMembersScreenState extends State<AddMembersScreen> {
  final Set<int> _selectedUserIds = {};
  List<UserModel> _availableUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _loadAvailableUsers();
  }

  Future<void> _loadAvailableUsers() async {
    setState(() => _isLoading = true);

    try {
      // TODO: Load users from your contacts/users service
      // final userService = context.read<UserService>();
      // final allUsers = await userService.getAllUsers();
      // _availableUsers = allUsers.where((user) => !widget.existingMemberIds.contains(user.id)).toList();

      // For now, using dummy data
      _availableUsers = [];
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('خطا در بارگذاری کاربران: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredUsers = _availableUsers.where((user) {
      final query = _searchQuery.toLowerCase();
      final name = '${user.firstName ?? ''} ${user.lastName ?? ''}'
          .toLowerCase();
      final username = user.username.toLowerCase();
      return name.contains(query) || username.contains(query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('اضافه کردن عضو'),
        actions: [
          if (_selectedUserIds.isNotEmpty)
            TextButton(
              onPressed: () =>
                  Navigator.pop(context, _selectedUserIds.toList()),
              child: Text(
                'اضافه (${_selectedUserIds.length})',
                style: const TextStyle(color: Colors.white),
              ),
            ),
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              onChanged: (value) => setState(() => _searchQuery = value),
              decoration: InputDecoration(
                hintText: 'جستجوی کاربران...',
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                filled: true,
                fillColor: Colors.grey[100],
              ),
            ),
          ),

          // Selected Users Count
          if (_selectedUserIds.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              color: Theme
                  .of(context)
                  .primaryColor
                  .withOpacity(0.1),
              child: Text(
                '${_selectedUserIds.length} کاربر انتخاب شده',
                style: TextStyle(
                  color: Theme
                      .of(context)
                      .primaryColor,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),

          // Users List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filteredUsers.isEmpty
                ? const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person_search, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text(
                    'هیچ کاربری یافت نشد',
                    style: TextStyle(color: Colors.grey, fontSize: 16),
                  ),
                ],
              ),
            )
                : ListView.builder(
              itemCount: filteredUsers.length,
              itemBuilder: (context, index) {
                final user = filteredUsers[index];
                final isSelected = _selectedUserIds.contains(user.id);

                return Card(
                  margin: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 4),
                  child: CheckboxListTile(
                    value: isSelected,
                    onChanged: (bool? value) {
                      setState(() {
                        if (value == true) {
                          _selectedUserIds.add(user.id);
                        } else {
                          _selectedUserIds.remove(user.id);
                        }
                      });
                    },
                    secondary: CircleAvatar(
                      backgroundColor: Theme
                          .of(context)
                          .primaryColor
                          .withOpacity(0.1),
                      backgroundImage: user.profilePictureUrl != null
                          ? CachedNetworkImageProvider(user.profilePictureUrl!)
                          : null,
                      child: user.profilePictureUrl == null
                          ? Text(
                        user.firstName?.isNotEmpty == true
                            ? user.firstName![0].toUpperCase()
                            : user.username[0].toUpperCase(),
                        style: TextStyle(
                          color: Theme
                              .of(context)
                              .primaryColor,
                          fontWeight: FontWeight.bold,
                        ),
                      )
                          : null,
                    ),
                    title: Text(
                      '${user.firstName ?? ''} ${user.lastName ?? ''}'
                          .trim()
                          .isEmpty
                          ? user.username
                          : '${user.firstName ?? ''} ${user.lastName ?? ''}'
                          .trim(),
                      style: const TextStyle(fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text('@${user.username}'),
                    activeColor: Theme
                        .of(context)
                        .primaryColor,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}