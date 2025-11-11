import 'package:flutter/material.dart';
import 'dart:math' as math;

class EmptyState extends StatefulWidget {
  const EmptyState({super.key});

  @override
  State<EmptyState> createState() => _EmptyStateState();
}

class _EmptyStateState extends State<EmptyState> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(seconds: 4),
      vsync: this,
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const ValueKey('empty'),
      color: Colors.black,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Ambient breathing circle with brand gradient
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final breathe = math.sin(_controller.value * 2 * math.pi) * 0.1 + 1.0;
                return Transform.scale(
                  scale: breathe,
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          Color(0xFFFF6B35).withOpacity(0.6),
                          Color(0xFFEC4899).withOpacity(0.7),
                          Color(0xFFC026D3).withOpacity(0.6),
                          Color(0xFF8B5CF6).withOpacity(0.5),
                          Color(0xFF6366F1).withOpacity(0.4),
                          Color(0xFF4338CA).withOpacity(0.3),
                        ],
                        stops: [0.0, 0.2, 0.4, 0.6, 0.8, 1.0],
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: Color(0xFFFF6B35),
                            width: 2.5,
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 32),
            ShaderMask(
              shaderCallback: (bounds) => LinearGradient(
                colors: [
                  Color(0xFFFF6B35),
                  Color(0xFFEC4899),
                  Color(0xFFC026D3),
                  Color(0xFF8B5CF6),
                  Color(0xFF6366F1),
                ],
              ).createShader(bounds),
              child: Text(
                'Ambia',
                style: TextStyle(
                  fontSize: 24,
                  color: Colors.white,
                  fontWeight: FontWeight.w200,
                  letterSpacing: 4,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
