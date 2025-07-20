import 'package:flutter/material.dart';

class ChatLoadingShimmer extends StatefulWidget {
  const ChatLoadingShimmer({Key? key}) : super(key: key);

  @override
  State<ChatLoadingShimmer> createState() => _ChatLoadingShimmerState();
}

class _ChatLoadingShimmerState extends State<ChatLoadingShimmer>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    _animation = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.repeat(reverse: true);
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          children: List.generate(
            10,
            (index) => _buildMessageShimmer(index.isEven),
          ),
        );
      },
    );
  }

  Widget _buildMessageShimmer(bool isMe) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: isMe
            ? MainAxisAlignment.end
            : MainAxisAlignment.start,
        children: [
          if (!isMe) ...[_buildShimmerCircle(32), const SizedBox(width: 8)],
          _buildShimmerContainer(width: 200 + (isMe ? 50 : -50), height: 40),
          if (isMe) ...[const SizedBox(width: 8), _buildShimmerCircle(32)],
        ],
      ),
    );
  }

  Widget _buildShimmerCircle(double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.grey[300]!.withOpacity(_animation.value),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildShimmerContainer({
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: Colors.grey[300]!.withOpacity(_animation.value),
        borderRadius: BorderRadius.circular(20),
      ),
    );
  }
}
