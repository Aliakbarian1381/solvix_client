import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:solvix/src/core/models/group_info_model.dart';
import 'package:solvix/src/features/group/presentation/widgets/group_avatar.dart';
import 'package:solvix/src/features/group/presentation/widgets/role_badge.dart';

class MemberTile extends StatelessWidget {
  final GroupMemberModel member;
  final bool isCurrentUser;
  final Function(GroupMemberModel)? onTap;

  const MemberTile({
    super.key,
    required this.member,
    required this.isCurrentUser,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20,
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
                ),
              )
            : null,
      ),
      title: Text(member.displayName),
      subtitle: Text(_getStatusText()),
      trailing: _buildRoleBadge(context),
      onTap: onTap != null ? () => onTap!(member) : null,
    );
  }

  String _getStatusText() {
    if (member.isOnline) {
      return 'آنلاین';
    } else if (member.lastActive != null) {
      return 'آخرین بازدید: ${_formatLastActive(member.lastActive!)}';
    }
    return 'آفلاین';
  }

  String _formatLastActive(DateTime lastActive) {
    final now = DateTime.now();
    final difference = now.difference(lastActive);

    if (difference.inMinutes < 1) {
      return 'همین الان';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} دقیقه پیش';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} ساعت پیش';
    } else {
      return '${difference.inDays} روز پیش';
    }
  }

  Widget _buildRoleBadge(BuildContext context) {
    Color badgeColor;
    String roleText;

    switch (member.role) {
      case GroupRole.owner:
        badgeColor = Colors.purple;
        roleText = 'مالک';
        break;
      case GroupRole.admin:
        badgeColor = Colors.blue;
        roleText = 'ادمین';
        break;
      case GroupRole.member:
        badgeColor = Colors.grey;
        roleText = 'عضو';
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: badgeColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: badgeColor, width: 1),
      ),
      child: Text(
        roleText,
        style: TextStyle(
          color: badgeColor,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}
