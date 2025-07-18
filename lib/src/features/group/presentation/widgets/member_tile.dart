import 'package:flutter/material.dart';
import 'package:solvix/src/core/models/group_info_model.dart';
import 'package:solvix/src/features/group/presentation/widgets/group_avatar.dart';
import 'package:solvix/src/features/group/presentation/widgets/role_badge.dart';

class MemberTile extends StatelessWidget {
  final GroupMemberModel member;
  final bool isCurrentUser;
  final bool canManage;
  final VoidCallback? onTap;
  final VoidCallback? onManage;

  const MemberTile({
    super.key,
    required this.member,
    this.isCurrentUser = false,
    this.canManage = false,
    this.onTap,
    this.onManage,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        onTap: onTap,
        contentPadding: const EdgeInsets.all(12),
        leading: GroupAvatar(
          imageUrl: member.profilePictureUrl,
          groupName: member.displayName,
          radius: 24,
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
                RoleBadge(role: member.role),
                const SizedBox(width: 8),
                Text(
                  '@${member.username}',
                  style: TextStyle(color: Colors.grey[600], fontSize: 14),
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
          ],
        ),
        trailing: canManage
            ? IconButton(onPressed: onManage, icon: const Icon(Icons.more_vert))
            : null,
      ),
    );
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
      final months = (difference.inDays / 30).floor();
      return '$months ماه پیش';
    }
  }
}
