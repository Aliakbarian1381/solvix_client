import 'package:flutter/material.dart';
import 'package:solvix/src/core/models/group_info_model.dart';
import 'package:solvix/src/core/utils/group_permission_manager.dart';

class RoleBadge extends StatelessWidget {
  final GroupRole role;
  final bool showIcon;
  final double? fontSize;

  const RoleBadge({
    Key? key,
    required this.role,
    this.showIcon = true,
    this.fontSize,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getRoleColor().withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _getRoleColor().withOpacity(0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(
              _getRoleIcon(),
              size: (fontSize ?? 12) + 2,
              color: _getRoleColor(),
            ),
            const SizedBox(width: 4),
          ],
          Text(
            GroupPermissionManager.getRoleDisplayName(role),
            style: TextStyle(
              color: _getRoleColor(),
              fontSize: fontSize ?? 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Color _getRoleColor() {
    switch (role) {
      case GroupRole.owner:
        return Colors.red;
      case GroupRole.admin:
        return Colors.blue;
      case GroupRole.member:
        return Colors.grey;
    }
  }

  IconData _getRoleIcon() {
    switch (role) {
      case GroupRole.owner:
        return Icons.star;
      case GroupRole.admin:
        return Icons.admin_panel_settings;
      case GroupRole.member:
        return Icons.person;
    }
  }
}
