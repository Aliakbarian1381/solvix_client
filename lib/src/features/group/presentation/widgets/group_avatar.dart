import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class GroupAvatar extends StatelessWidget {
  final String? groupName;
  final String? title;
  final String? avatarUrl;
  final double radius;

  const GroupAvatar({
    super.key,
    this.groupName,
    this.title,
    this.avatarUrl,
    this.radius = 24,
  });

  @override
  Widget build(BuildContext context) {
    final displayName = groupName ?? title ?? 'G';

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
      backgroundImage: avatarUrl != null
          ? CachedNetworkImageProvider(avatarUrl!)
          : null,
      child: avatarUrl == null
          ? Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : 'G',
        style: TextStyle(
          color: Theme.of(context).primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: radius * 0.8,
        ),
      )
          : null,
    );
  }
}