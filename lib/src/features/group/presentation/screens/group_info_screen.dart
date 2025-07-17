import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:solvix/src/core/models/group_info_model.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/features/group/presentation/bloc/group_info_bloc.dart';
import 'package:solvix/src/features/group/presentation/screens/group_members_screen.dart';
import 'package:solvix/src/features/group/presentation/screens/group_settings_screen.dart';
import 'package:solvix/src/features/group/presentation/screens/edit_group_screen.dart';

class GroupInfoScreen extends StatefulWidget {
  final String chatId;
  final UserModel? currentUser;

  const GroupInfoScreen({
    super.key,
    required this.chatId,
    required this.currentUser,
  });

  @override
  State<GroupInfoScreen> createState() => _GroupInfoScreenState();
}

class _GroupInfoScreenState extends State<GroupInfoScreen> {
  @override
  void initState() {
    super.initState();
    context.read<GroupInfoBloc>().add(LoadGroupInfo(widget.chatId));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: BlocConsumer<GroupInfoBloc, GroupInfoState>(
        listener: (context, state) {
          if (state is GroupInfoError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.red,
              ),
            );
          } else if (state is GroupInfoUpdated) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: Colors.green,
              ),
            );
          } else if (state is GroupLeft) {
            Navigator.of(context).popUntil((route) => route.isFirst);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('شما از گروه خارج شدید'),
                backgroundColor: Colors.orange,
              ),
            );
          } else if (state is GroupDeleted) {
            Navigator.of(context).popUntil((route) => route.isFirst);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('گروه حذف شد'),
                backgroundColor: Colors.red,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is GroupInfoLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is GroupInfoLoaded) {
            return _buildGroupInfoContent(context, state.groupInfo);
          }

          if (state is GroupInfoError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
                  const SizedBox(height: 16),
                  Text(
                    state.message,
                    style: TextStyle(fontSize: 16, color: Colors.grey[600]),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: () {
                      context.read<GroupInfoBloc>().add(
                        LoadGroupInfo(widget.chatId),
                      );
                    },
                    icon: const Icon(Icons.refresh),
                    label: const Text('تلاش مجدد'),
                  ),
                ],
              ),
            );
          }

          return const Center(child: CircularProgressIndicator());
        },
      ),
    );
  }

  Widget _buildGroupInfoContent(
    BuildContext context,
    GroupInfoModel groupInfo,
  ) {
    final theme = Theme.of(context);
    final currentUserRole = _getCurrentUserRole(groupInfo);
    final isOwner = currentUserRole == GroupRole.owner;
    final isAdmin = currentUserRole == GroupRole.admin || isOwner;

    return CustomScrollView(
      slivers: [
        // App Bar with Group Image
        SliverAppBar(
          expandedHeight: 300,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildGroupHeader(context, groupInfo),
          ),
          actions: [
            if (isAdmin)
              IconButton(
                onPressed: () => _navigateToEditGroup(context, groupInfo),
                icon: const Icon(Icons.edit),
                tooltip: 'ویرایش گروه',
              ),
            PopupMenuButton<String>(
              onSelected: (value) =>
                  _handleMenuAction(context, value, groupInfo),
              itemBuilder: (context) => [
                if (isOwner)
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('حذف گروه', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                if (!isOwner)
                  const PopupMenuItem(
                    value: 'leave',
                    child: Row(
                      children: [
                        Icon(Icons.exit_to_app, color: Colors.orange),
                        SizedBox(width: 8),
                        Text(
                          'خروج از گروه',
                          style: TextStyle(color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ],
        ),

        // Group Details
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Group Description
                if (groupInfo.description != null &&
                    groupInfo.description!.isNotEmpty)
                  _buildDescriptionCard(context, groupInfo.description!),

                const SizedBox(height: 16),

                // Members Section
                _buildMembersCard(context, groupInfo, isAdmin),

                const SizedBox(height: 16),

                // Settings Section (Admin only)
                if (isAdmin) _buildSettingsCard(context, groupInfo),

                const SizedBox(height: 16),

                // Info Cards
                _buildInfoCards(context, groupInfo),

                const SizedBox(height: 100), // Bottom padding
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildGroupHeader(BuildContext context, GroupInfoModel groupInfo) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Theme.of(context).primaryColor,
            Theme.of(context).primaryColor.withOpacity(0.8),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 40),
            // Group Avatar
            Hero(
              tag: 'group_avatar_${groupInfo.id}',
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.white,
                child: groupInfo.groupImageUrl != null
                    ? ClipOval(
                        child: CachedNetworkImage(
                          imageUrl: groupInfo.groupImageUrl!,
                          width: 100,
                          height: 100,
                          fit: BoxFit.cover,
                          placeholder: (context, url) =>
                              const CircularProgressIndicator(),
                          errorWidget: (context, url, error) =>
                              _buildGroupAvatar(groupInfo.title),
                        ),
                      )
                    : _buildGroupAvatar(groupInfo.title),
              ),
            ),
            const SizedBox(height: 16),
            // Group Title
            Text(
              groupInfo.title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            // Group Stats
            Text(
              '${groupInfo.membersCount} عضو • ساخته شده در ${_formatDate(groupInfo.createdAt)}',
              style: TextStyle(
                fontSize: 14,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGroupAvatar(String title) {
    return Container(
      width: 100,
      height: 100,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [Colors.blue[400]!, Colors.purple[400]!],
        ),
      ),
      child: Center(
        child: Text(
          title.isNotEmpty ? title[0].toUpperCase() : 'G',
          style: const TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context, String description) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.description, color: Theme.of(context).primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'توضیحات گروه',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[700],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMembersCard(
    BuildContext context,
    GroupInfoModel groupInfo,
    bool isAdmin,
  ) {
    return Card(
      child: InkWell(
        onTap: () => _navigateToMembers(context, groupInfo),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.group, color: Theme.of(context).primaryColor),
                  const SizedBox(width: 8),
                  const Text(
                    'اعضای گروه',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  Text(
                    '${groupInfo.membersCount} نفر',
                    style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.arrow_forward_ios, size: 16),
                ],
              ),
              const SizedBox(height: 12),
              // Preview of first few members
              ...groupInfo.members
                  .take(3)
                  .map(
                    (member) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Theme.of(
                              context,
                            ).primaryColor.withOpacity(0.1),
                            backgroundImage: member.profilePictureUrl != null
                                ? CachedNetworkImageProvider(
                                    member.profilePictureUrl!,
                                  )
                                : null,
                            child: member.profilePictureUrl == null
                                ? Text(
                                    member.displayName.isNotEmpty
                                        ? member.displayName[0].toUpperCase()
                                        : 'U',
                                    style: TextStyle(
                                      color: Theme.of(context).primaryColor,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  )
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        member.displayName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    if (member.role == GroupRole.owner)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.amber,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Text(
                                          '👑',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      )
                                    else if (member.role == GroupRole.admin)
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.blue,
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: const Text(
                                          '⭐',
                                          style: TextStyle(fontSize: 10),
                                        ),
                                      ),
                                  ],
                                ),
                                Text(
                                  member.isOnline
                                      ? 'آنلاین'
                                      : _formatLastSeen(member.lastSeen),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: member.isOnline
                                        ? Colors.green
                                        : Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              if (groupInfo.membersCount > 3)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'و ${groupInfo.membersCount - 3} عضو دیگر...',
                    style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsCard(BuildContext context, GroupInfoModel groupInfo) {
    return Card(
      child: InkWell(
        onTap: () => _navigateToSettings(context, groupInfo),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(Icons.settings, color: Theme.of(context).primaryColor),
              const SizedBox(width: 8),
              const Text(
                'تنظیمات گروه',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoCards(BuildContext context, GroupInfoModel groupInfo) {
    return Column(
      children: [
        // Creation Info
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: Theme.of(context).primaryColor,
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'اطلاعات گروه',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildInfoRow('مالک گروه', groupInfo.ownerName),
                _buildInfoRow('تاریخ ایجاد', _formatDate(groupInfo.createdAt)),
                _buildInfoRow('تعداد اعضا', '${groupInfo.membersCount} نفر'),
                _buildInfoRow(
                  'حداکثر اعضا',
                  '${groupInfo.settings.maxMembers} نفر',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Settings Summary
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.security, color: Theme.of(context).primaryColor),
                    const SizedBox(width: 8),
                    const Text(
                      'تنظیمات امنیتی',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildSettingRow(
                  'ارسال پیام',
                  groupInfo.settings.onlyAdminsCanSendMessages
                      ? 'فقط ادمین‌ها'
                      : 'همه اعضا',
                  groupInfo.settings.onlyAdminsCanSendMessages,
                ),
                _buildSettingRow(
                  'اضافه کردن عضو',
                  groupInfo.settings.onlyAdminsCanAddMembers
                      ? 'فقط ادمین‌ها'
                      : 'همه اعضا',
                  groupInfo.settings.onlyAdminsCanAddMembers,
                ),
                _buildSettingRow(
                  'ویرایش اطلاعات',
                  groupInfo.settings.onlyAdminsCanEditGroupInfo
                      ? 'فقط ادمین‌ها'
                      : 'همه اعضا',
                  groupInfo.settings.onlyAdminsCanEditGroupInfo,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value, bool isRestricted) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
          ),
          Expanded(
            child: Row(
              children: [
                Icon(
                  isRestricted ? Icons.lock : Icons.lock_open,
                  size: 16,
                  color: isRestricted ? Colors.orange : Colors.green,
                ),
                const SizedBox(width: 4),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isRestricted ? Colors.orange : Colors.green,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  GroupRole? _getCurrentUserRole(GroupInfoModel groupInfo) {
    if (widget.currentUser == null) return null;

    final currentMember = groupInfo.members.firstWhere(
      (member) => member.userId == widget.currentUser!.id,
      orElse: () => const GroupMemberModel(
        userId: -1,
        username: '',
        role: GroupRole.member,
        joinedAt: null,
        isOnline: false,
      ),
    );

    return currentMember.userId != -1 ? currentMember.role : null;
  }

  void _navigateToMembers(BuildContext context, GroupInfoModel groupInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupMembersScreen(
          chatId: widget.chatId,
          groupInfo: groupInfo,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  void _navigateToSettings(BuildContext context, GroupInfoModel groupInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => GroupSettingsScreen(
          chatId: widget.chatId,
          groupInfo: groupInfo,
          currentUser: widget.currentUser,
        ),
      ),
    );
  }

  void _navigateToEditGroup(BuildContext context, GroupInfoModel groupInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            EditGroupScreen(chatId: widget.chatId, groupInfo: groupInfo),
      ),
    );
  }

  void _handleMenuAction(
    BuildContext context,
    String action,
    GroupInfoModel groupInfo,
  ) {
    switch (action) {
      case 'delete':
        _showDeleteGroupDialog(context);
        break;
      case 'leave':
        _showLeaveGroupDialog(context);
        break;
    }
  }

  void _showDeleteGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف گروه'),
        content: const Text(
          'آیا مطمئن هستید که می‌خواهید این گروه را حذف کنید؟ این عمل قابل بازگشت نیست.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<GroupInfoBloc>().add(DeleteGroup(widget.chatId));
            },
            child: const Text('حذف', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showLeaveGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('خروج از گروه'),
        content: const Text(
          'آیا مطمئن هستید که می‌خواهید از این گروه خارج شوید؟',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('انصراف'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<GroupInfoBloc>().add(LeaveGroup(widget.chatId));
            },
            child: const Text('خروج', style: TextStyle(color: Colors.orange)),
          ),
        ],
      ),
    );
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
