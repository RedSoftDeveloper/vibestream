import 'dart:ui';
import 'package:flutter/material.dart';

class GlassNavBar extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  const GlassNavBar({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Padding(
      padding: EdgeInsets.only(left: 16, right: 16, bottom: bottomPadding + 12),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(40),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            height: 56,
            decoration: BoxDecoration(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.18)
                  : Colors.white.withValues(alpha: 0.18),
              borderRadius: BorderRadius.circular(40),
              border: Border.all(
                color: (isDark ? Colors.white : Colors.black).withValues(alpha: 0.15),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GlassNavItem(
                  icon: Icons.emoji_emotions_outlined,
                  selectedIcon: Icons.emoji_emotions,
                  label: 'Feelings',
                  isSelected: selectedIndex == 0,
                  onTap: () => onItemTapped(0),
                ),
                GlassNavItem(
                  icon: Icons.favorite_border_rounded,
                  selectedIcon: Icons.favorite_rounded,
                  label: 'Favorites',
                  isSelected: selectedIndex == 1,
                  onTap: () => onItemTapped(1),
                ),
                GlassNavItem(
                  icon: Icons.rate_review_outlined,
                  selectedIcon: Icons.rate_review,
                  label: 'Feedback',
                  isSelected: selectedIndex == 2,
                  onTap: () => onItemTapped(2),
                ),
                GlassNavItem(
                  icon: Icons.settings_outlined,
                  selectedIcon: Icons.settings,
                  label: 'Settings',
                  isSelected: selectedIndex == 3,
                  onTap: () => onItemTapped(3),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class GlassNavItem extends StatelessWidget {
  final IconData icon;
  final IconData selectedIcon;
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const GlassNavItem({
    super.key,
    required this.icon,
    required this.selectedIcon,
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isDark ? Colors.white : Colors.black;

    final content = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(isSelected ? selectedIcon : icon, size: 22, color: iconColor),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: isSelected
              ? Padding(
                  padding: const EdgeInsets.only(left: 8),
                  child: Text(
                    label,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: iconColor,
                    ),
                  ),
                )
              : const SizedBox.shrink(),
        ),
      ],
    );

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: isSelected
            ? ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.15)
                          : Colors.black.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(24),
                    ),
                    child: content,
                  ),
                ),
              )
            : Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: content,
              ),
      ),
    );
  }
}
