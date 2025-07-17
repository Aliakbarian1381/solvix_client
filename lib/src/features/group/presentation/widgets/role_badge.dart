class RoleBadge extends StatelessWidget {
  final GroupRole role;
  final bool showText;

  const RoleBadge({super.key, required this.role, this.showText = true});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: showText ? 8 : 4, vertical: 4),
      decoration: BoxDecoration(
        color: role.color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: role.color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(role.icon, size: 14, color: role.color),
          if (showText) ...[
            const SizedBox(width: 4),
            Text(
              role.displayName,
              style: TextStyle(
                color: role.color,
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
