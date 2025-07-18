import 'package:flutter/material.dart';
import 'package:solvix/src/core/models/group_info_model.dart';

class RoleBadge extends StatelessWidget {
  final GroupRole role;
  final bool showText;

  const RoleBadge({super.key, required this.role, this.showText = true});

  @override
  Widget build(BuildContext context) {
    Color color;
    String text;
    IconData icon;

    switch (role) {
      case GroupRole.owner:
        color = Colors.amber;
        text = 'مالک';
        icon = Icons.star; // تغییر از crown به star
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
      padding: EdgeInsets.symmetric(horizontal: showText ? 8 : 4, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          if (showText) ...[
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
        ],
      ),
    );
  }
}
