import 'package:flutter/material.dart';
import 'dart:ui';
import '../../models/layout_spec.dart';

/// Dynamic ambient card that renders based on Claude's layout spec
class AmbientCard extends StatefulWidget {
  final TimelineItem item;
  final VoidCallback? onTap;

  const AmbientCard({
    super.key,
    required this.item,
    this.onTap,
  });

  @override
  State<AmbientCard> createState() => _AmbientCardState();
}

class _AmbientCardState extends State<AmbientCard> with SingleTickerProviderStateMixin {
  late AnimationController _revealController;
  late Animation<double> _cardFadeAnimation;
  late Animation<double> _sweepPositionAnimation;
  late Animation<double> _sweepFadeAnimation;

  @override
  void initState() {
    super.initState();

    // Single reveal animation controller
    _revealController = AnimationController(
      duration: const Duration(milliseconds: 1400),
      vsync: this,
    );

    // Card fades in from 0 to 1 over first 1000ms
    _cardFadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOut),
      ),
    );

    // Gradient sweep moves from left (-2.0) to right (2.0) to fully cover edges
    _sweepPositionAnimation = Tween<double>(begin: -2.0, end: 2.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.0, 0.7, curve: Curves.easeInOut),
      ),
    );

    // Sweep fades out after it reaches the right side (800-1200ms)
    _sweepFadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _revealController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    // Start animation immediately
    _revealController.forward();
  }

  @override
  void dispose() {
    _revealController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _revealController,
      builder: (context, child) {
        return Opacity(
          opacity: _cardFadeAnimation.value,
          child: GestureDetector(
            onTap: widget.onTap,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              height: widget.item.visual.height,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(widget.item.visual.cornerRadius),
                child: Stack(
                  children: [
                    // Background layer (always grey)
                    _buildBackground(),
                    // Gradient sweep overlay (animates from left to right, then fades out)
                    _buildGradientSweep(),
                    // Content
                    _buildContent(),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildBackground() {
    // Always show simple grey background
    return Container(
      color: const Color(0xFF2A2A2A),
    );
  }

  Widget _buildGradientSweep() {
    // Gradient sweep that moves from left to right, covering full card width
    return Opacity(
      opacity: _sweepFadeAnimation.value,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment(_sweepPositionAnimation.value - 1.5, 0),
            end: Alignment(_sweepPositionAnimation.value + 1.5, 0),
            colors: const [
              Colors.transparent,
              Color(0xFFFF6B35),
              Color(0xFFEC4899),
              Color(0xFFC026D3),
              Color(0xFF8B5CF6),
              Colors.transparent,
            ],
            stops: const [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
          ),
        ),
      ),
    );
  }

  Widget _buildGlassmorphism() {
    return BackdropFilter(
      filter: ImageFilter.blur(
        sigmaX: widget.item.visual.blur ?? 20,
        sigmaY: widget.item.visual.blur ?? 20,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(widget.item.visual.opacity ?? 0.08),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: widget.item.contentBlocks.map((block) {
          return _renderContentBlock(block);
        }).toList(),
      ),
    );
  }

  Widget _renderContentBlock(ContentBlock block) {
    // Dynamic content rendering based on block type
    switch (block.type) {
      case 'temperature':
        return _buildTemperatureBlock(block);
      case 'headline':
        return _buildHeadlineBlock(block);
      case 'detail':
        return _buildDetailBlock(block);
      case 'action':
        return _buildActionBlock(block);
      default:
        return _buildDefaultBlock(block);
    }
  }

  Widget _buildTemperatureBlock(ContentBlock block) {
    final temp = block.data['temperature'] ?? '79';
    final condition = block.data['condition'] ?? 'Clear';

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$temp°',
          style: TextStyle(
            fontSize: _getSizeValue(block.size, 72, 48, 36),
            fontWeight: FontWeight.w200,
            color: Colors.white,
            height: 1.0,
          ),
        ),
        const SizedBox(width: 12),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            condition,
            style: TextStyle(
              fontSize: 16,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeadlineBlock(ContentBlock block) {
    final text = block.data['text'] ?? '';
    return Text(
      text,
      style: TextStyle(
        fontSize: _getSizeValue(block.size, 24, 18, 14),
        fontWeight: FontWeight.w600,
        color: Colors.white,
      ),
    );
  }

  Widget _buildDetailBlock(ContentBlock block) {
    final text = block.data['text'] ?? '';
    final icon = block.data['icon'] as IconData?;

    return Row(
      children: [
        if (icon != null) ...[
          Icon(
            icon,
            size: 16,
            color: Colors.white.withOpacity(0.6),
          ),
          const SizedBox(width: 8),
        ],
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 14,
              color: Colors.white.withOpacity(0.7),
              fontWeight: FontWeight.w400,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildActionBlock(ContentBlock block) {
    final text = block.data['text'] ?? 'Action';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }

  Widget _buildDefaultBlock(ContentBlock block) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Text(
        'Unknown block type: ${block.type}',
        style: TextStyle(
          color: Colors.white.withOpacity(0.5),
          fontSize: 12,
        ),
      ),
    );
  }

  double _getSizeValue(String size, double large, double medium, double small) {
    switch (size) {
      case 'hero':
      case 'large':
        return large;
      case 'medium':
        return medium;
      case 'small':
        return small;
      default:
        return medium;
    }
  }

  Color _hexToColor(String hex) {
    hex = hex.replaceAll('#', '');
    if (hex.length == 6) {
      hex = 'FF$hex';
    }
    return Color(int.parse(hex, radix: 16));
  }
}

/// Gentle pulse animation
class _AnimatedPulse extends StatefulWidget {
  final Widget child;

  const _AnimatedPulse({required this.child});

  @override
  State<_AnimatedPulse> createState() => _AnimatedPulseState();
}

class _AnimatedPulseState extends State<_AnimatedPulse>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    )..repeat(reverse: true);

    _animation = Tween<double>(begin: 0.95, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _animation,
      child: widget.child,
    );
  }
}
