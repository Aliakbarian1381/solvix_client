import 'package:flutter/material.dart';
import 'package:solvix/src/core/models/client_message_status.dart';

class MessageStatusIndicator extends StatelessWidget {
  final ClientMessageStatus status;
  final bool isRead;
  final VoidCallback? onRetry;

  const MessageStatusIndicator({
    Key? key,
    required this.status,
    required this.isRead,
    this.onRetry,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    switch (status) {
      case ClientMessageStatus.sending:
        return const SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor: AlwaysStoppedAnimation<Color>(Colors.grey),
          ),
        );

      case ClientMessageStatus.sent:
        return Icon(
          Icons.check,
          size: 16,
          color: isRead ? Colors.blue : Colors.grey,
        );

      case ClientMessageStatus.failed:
        return GestureDetector(
          onTap: onRetry,
          child: const Icon(Icons.error_outline, size: 16, color: Colors.red),
        );

      default:
        return const SizedBox.shrink();
    }
  }
}
