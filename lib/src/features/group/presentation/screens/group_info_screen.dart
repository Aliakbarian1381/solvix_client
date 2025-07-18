import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:shamsi_date/shamsi_date.dart';
import 'package:solvix/src/core/models/group_info_model.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/features/group/presentation/bloc/group_info_bloc.dart';
import 'package:solvix/src/features/group/presentation/bloc/group_members_bloc.dart';
import 'package:solvix/src/features/group/presentation/screens/group_members_screen.dart';
import 'package:solvix/src/features/group/presentation/screens/group_settings_screen.dart';
import 'package:solvix/src/features/group/presentation/screens/edit_group_screen.dart';
import 'package:solvix/src/features/group/presentation/widgets/group_avatar.dart';

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

          if (state is GroupInfoError) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: Colors.red[400]),
                  const SizedBox(height: 16),
                  Text(
                    'خطا در بارگذاری اطلاعات گروه',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    state.message,
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      context.read<GroupInfoBloc>().add(
                        LoadGroupInfo(widget.chatId),
                      );
                    },
                    child: const Text('تلاش مجدد'),
                  ),
                ],
              ),
            );
          }

          if (state is GroupInfoLoaded) {
            return _buildGroupInfo(context, state.groupInfo);
          }

          return const Center(child: Text('وضعیت نامشخص'));
        },
      ),
    );
  }

  Widget _buildGroupInfo(BuildContext context, GroupInfoModel groupInfo) {
    final currentUser = widget.currentUser;
    final isOwner = currentUser?.id == groupInfo.ownerId;
    final isAdmin = _isUserAdmin(groupInfo, currentUser?.id);

    return CustomScrollView(
      slivers: [
        // App Bar
        SliverAppBar(
          expandedHeight: 200,
          floating: false,
          pinned: true,
          flexibleSpace: FlexibleSpaceBar(
            background: _buildHeaderBackground(context, groupInfo),
            title: Text(
              groupInfo.title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Colors.white,
                shadows: [
                  Shadow(
                    offset: Offset(0, 1),
                    blurRadius: 3,
                    color: Colors.black45,
                  ),
                ],
              ),
            ),
            centerTitle: true,
          ),
          actions: [
            if (isAdmin)
              IconButton(
                onPressed: () => _navigateToEditGroup(context, groupInfo),
                icon: const Icon(Icons.edit, color: Colors.white),
                tooltip: 'ویرایش گروه',
              ),
            PopupMenuButton<String>(
              onSelected: (value) =>
                  _handleMenuAction(context, value, groupInfo),
              icon: const Icon(Icons.more_vert, color: Colors.white),
              itemBuilder: (context) => [
                if (isOwner)
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red),
                        SizedBox(width: 8),
                        Text('حذف گروه'),
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
                const PopupMenuItem(
                  value: 'report',
                  child: Row(
                    children: [
                      Icon(Icons.report, color: Colors.red),
                      SizedBox(width: 8),
                      Text('گزارش گروه'),
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

                // Quick Actions
                _buildQuickActions(context, groupInfo, isAdmin),

                const SizedBox(height: 16),

                // Group Info Cards
                _buildInfoCards(context, groupInfo),

                const SizedBox(height: 16),

                // Members Preview
                _buildMembersPreview(context, groupInfo),

                const SizedBox(height: 16),

                // Settings Summary
                _buildSettingsSummary(context, groupInfo),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderBackground(BuildContext context, GroupInfoModel groupInfo) {
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
      child: Stack(
        children: [
          Positioned.fill(
            child: CustomPaint(
              painter: _PatternPainter(),
            ),
          ),
          Center(
            child: Hero(
              tag: 'group_avatar_${groupInfo.id}',
              child: GroupAvatar(
                title: groupInfo.title, // استفاده از title
                avatarUrl: groupInfo.avatarUrl,
                radius: 48,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDescriptionCard(BuildContext context, String description) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.description,
                  color: Theme.of(context).primaryColor,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'توضیحات گروه',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              description,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.justify,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickActions(
    BuildContext context,
    GroupInfoModel groupInfo,
    bool isAdmin,
  ) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'عملیات سریع',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _buildActionButton(
                  context,
                  Icons.people,
                  'اعضا',
                  '${groupInfo.membersCount} نفر',
                  () => _navigateToMembers(context, groupInfo),
                ),
                _buildActionButton(
                  context,
                  Icons.settings,
                  'تنظیمات',
                  isAdmin ? 'مدیریت' : 'مشاهده',
                  () => _navigateToSettings(context, groupInfo),
                ),
                _buildActionButton(
                  context,
                  Icons.share,
                  'اشتراک‌گذاری',
                  'دعوت',
                  () => _shareGroup(context, groupInfo),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    IconData icon,
    String title,
    String subtitle,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                color: Theme.of(context).primaryColor,
                size: 24,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoCards(BuildContext context, GroupInfoModel groupInfo) {
    return Column(
      children: [
        // Creation Info
        Card(
          elevation: 2,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'اطلاعات گروه',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _buildInfoRow('شناسه گروه', groupInfo.id),
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
      ],
    );
  }

  Widget _buildMembersPreview(BuildContext context, GroupInfoModel groupInfo) {
    final membersToShow = groupInfo.members.take(5).toList();

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToMembers(context, groupInfo),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.people,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'اعضای گروه',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    '${groupInfo.membersCount} نفر',
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ],
              ),
              const SizedBox(height: 16),
              ...membersToShow.map(
                (member) => _buildMemberItem(context, member),
              ),
              if (groupInfo.membersCount > 5)
                Container(
                  margin: const EdgeInsets.only(top: 8),
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    'و ${groupInfo.membersCount - 5} عضو دیگر...',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMemberItem(BuildContext context, GroupMemberModel member) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
            backgroundImage: member.profilePictureUrl != null
                ? CachedNetworkImageProvider(member.profilePictureUrl!)
                : null,
            child: member.profilePictureUrl == null
                ? Text(
                    member.displayName[0].toUpperCase(),
                    style: TextStyle(
                      color: Theme.of(context).primaryColor,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  member.displayName,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                ),
                Text(
                  _getRoleDisplayName(member.role),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: _getRoleColor(member.role),
                  ),
                ),
              ],
            ),
          ),
          if (member.isOnline)
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: Colors.green,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSettingsSummary(BuildContext context, GroupInfoModel groupInfo) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToSettings(context, groupInfo),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.security,
                    color: Theme.of(context).primaryColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'تنظیمات امنیتی',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: Colors.grey[600],
                  ),
                ],
              ),
              const SizedBox(height: 16),
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
                groupInfo.settings.onlyAdminsCanEditInfo
                    ? 'فقط ادمین‌ها'
                    : 'همه اعضا',
                groupInfo.settings.onlyAdminsCanEditInfo,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSettingRow(String label, String value, bool isRestricted) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(
            isRestricted ? Icons.lock : Icons.lock_open,
            size: 16,
            color: isRestricted ? Colors.orange : Colors.green,
          ),
          const SizedBox(width: 8),
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          const Spacer(),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: isRestricted ? Colors.orange : Colors.green,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final jalali = Jalali.fromDateTime(date);
    return '${jalali.day}/${jalali.month}/${jalali.year}';
  }

  String _getRoleDisplayName(GroupRole role) {
    switch (role) {
      case GroupRole.owner:
        return 'مالک گروه';
      case GroupRole.admin:
        return 'ادمین';
      case GroupRole.member:
        return 'عضو';
    }
  }

  Color _getRoleColor(GroupRole role) {
    switch (role) {
      case GroupRole.owner:
        return Colors.purple;
      case GroupRole.admin:
        return Colors.blue;
      case GroupRole.member:
        return Colors.grey;
    }
  }

  bool _isUserAdmin(GroupInfoModel groupInfo, int? userId) {
    if (userId == null) return false;
    if (userId == groupInfo.ownerId) return true;

    final member = groupInfo.members.firstWhere(
      (m) => m.id == userId,
      orElse: () => GroupMemberModel(
        id: -1,
        userId: -1,
        username: '',
        role: GroupRole.member,
        joinedAt: DateTime.now(),
        isOnline: false,
      ),
    );
    return member.role == GroupRole.admin;
  }

  void _navigateToEditGroup(BuildContext context, GroupInfoModel groupInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: context.read<GroupInfoBloc>(),
          child: EditGroupScreen(chatId: widget.chatId, groupInfo: groupInfo),
        ),
      ),
    );
  }

  void _navigateToMembers(BuildContext context, GroupInfoModel groupInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: context.read<GroupMembersBloc>(),
          child: GroupMembersScreen(
            chatId: widget.chatId,
            groupInfo: groupInfo,
            currentUser: widget.currentUser,
          ),
        ),
      ),
    );
  }

  void _navigateToSettings(BuildContext context, GroupInfoModel groupInfo) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => BlocProvider.value(
          value: context.read<GroupInfoBloc>(),
          child: GroupSettingsScreen(
            chatId: widget.chatId,
            groupInfo: groupInfo,
            currentUser: widget.currentUser,
          ),
        ),
      ),
    );
  }

  void _shareGroup(BuildContext context, GroupInfoModel groupInfo) {
    if (groupInfo.settings.joinLink != null) {
      Clipboard.setData(ClipboardData(text: groupInfo.settings.joinLink!));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لینک دعوت کپی شد'),
          backgroundColor: Colors.green,
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('لینک دعوت برای این گروه وجود ندارد'),
          backgroundColor: Colors.orange,
        ),
      );
    }
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
      case 'report':
        _showReportGroupDialog(context);
        break;
    }
  }

  void _showDeleteGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('حذف گروه'),
        content: const Text(
          'آیا مطمئن هستید که می‌خواهید این گروه را حذف کنید؟ این عمل غیرقابل بازگشت است.',
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
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('حذف'),
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
            style: TextButton.styleFrom(foregroundColor: Colors.orange),
            child: const Text('خروج'),
          ),
        ],
      ),
    );
  }

  void _showReportGroupDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('گزارش گروه'),
        content: const Text('قابلیت گزارش گروه به زودی اضافه خواهد شد.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('متوجه شدم'),
          ),
        ],
      ),
    );
  }
}

// Custom painter for header pattern
class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.1)
      ..style = PaintingStyle.fill;

    const double spacing = 30.0;
    const double radius = 2.0;

    for (double x = 0; x < size.width; x += spacing) {
      for (double y = 0; y < size.height; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
