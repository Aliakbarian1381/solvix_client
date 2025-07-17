class GroupAvatar extends StatelessWidget {
  final String? imageUrl;
  final String groupName;
  final double radius;
  final VoidCallback? onTap;

  const GroupAvatar({
    super.key,
    this.imageUrl,
    required this.groupName,
    this.radius = 24,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      backgroundImage: imageUrl != null
          ? CachedNetworkImageProvider(imageUrl!)
          : null,
      child: imageUrl == null
          ? Text(
              groupName.isNotEmpty ? groupName[0].toUpperCase() : 'G',
              style: TextStyle(
                color: Theme.of(context).primaryColor,
                fontWeight: FontWeight.bold,
                fontSize: radius * 0.6,
              ),
            )
          : null,
    );

    if (onTap != null) {
      return GestureDetector(onTap: onTap, child: avatar);
    }

    return avatar;
  }
}
