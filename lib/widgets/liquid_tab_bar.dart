import 'package:flutter/material.dart';
import 'dart:ui';

class LiquidTabBar extends StatefulWidget {
  final int currentIndex;
  final Function(int) onTabChanged;

  const LiquidTabBar({
    super.key,
    required this.currentIndex,
    required this.onTabChanged,
  });

  @override
  State<LiquidTabBar> createState() => _LiquidTabBarState();
}

class _LiquidTabBarState extends State<LiquidTabBar> {
  final List<TabItemData> _tabs = [
    TabItemData(icon: Icons.timeline, label: 'Timeline'),
    TabItemData(icon: Icons.auto_awesome, label: 'Generate'),
    TabItemData(icon: Icons.settings, label: 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16, left: 50, right: 50),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(32),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            height: 62,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.08),
              borderRadius: BorderRadius.circular(32),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 30,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(_tabs.length, (index) {
                  return _buildTabItem(index);
                }),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTabItem(int index) {
    final isSelected = widget.currentIndex == index;
    final tab = _tabs[index];

    return GestureDetector(
      onTap: () => widget.onTabChanged(index),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        child: Center(
          child: AnimatedScale(
            scale: isSelected ? (index == 0 ? 1.5 : 1.4) : 1.0,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOutCubic,
            child: isSelected
                ? ShaderMask(
                    shaderCallback: (bounds) {
                      return LinearGradient(
                        colors: [
                          Color(0xFFFF6B35),
                          Color(0xFFEC4899),
                          Color(0xFFC026D3),
                          Color(0xFF8B5CF6),
                        ],
                      ).createShader(bounds);
                    },
                    child: Icon(
                      tab.icon,
                      color: Colors.white,
                      size: 26,
                    ),
                  )
                : Icon(
                    tab.icon,
                    color: Colors.white,
                    size: 26,
                  ),
          ),
        ),
      ),
    );
  }
}

class TabItemData {
  final IconData icon;
  final String label;

  TabItemData({required this.icon, required this.label});
}
