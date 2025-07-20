import 'package:flutter/material.dart';
import 'dart:math';

class TypingIndicator extends StatefulWidget {
  final List<String> typingUsers;

  const TypingIndicator({Key? key, required this.typingUsers})
    : super(key: key);

  @override
  State<TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<TypingIndicator>
    with TickerProviderStateMixin {
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.typingUsers.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Text(
            widget.typingUsers.length == 1
                ? '${widget.typingUsers.first} در حال تایپ...'
                : '${widget.typingUsers.length} نفر در حال تایپ...',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(width: 8),
          _buildTypingAnimation(),
        ],
      ),
    );
  }

  Widget _buildTypingAnimation() {
    return AnimatedBuilder(
      animation: _animationController,
      builder: (context, child) {
        return Row(
          children: List.generate(3, (index) {
            final delay = index * 0.3;
            final animationValue = (_animationController.value - delay).clamp(
              0.0,
              1.0,
            );
            final opacity = (sin(animationValue * pi) * 0.5 + 0.5).clamp(
              0.0,
              1.0,
            );

            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 1),
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(opacity),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
