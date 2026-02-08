import 'package:flutter/material.dart';
import 'package:vibestream/core/theme/app_theme.dart';

enum SnackbarType { success, error, warning, info }

/// Centralized snackbar utility for consistent UI feedback across the app
class SnackbarUtils {
  /// Show a snackbar with consistent styling based on type
  static void show(
    BuildContext context,
    String message, {
    SnackbarType type = SnackbarType.info,
    Duration duration = const Duration(seconds: 3),
    bool showIcon = true,
  }) {
    if (!context.mounted) return;

    final config = _getSnackbarConfig(type);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            if (showIcon) ...[
              Icon(config.icon, color: Colors.white, size: 20),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: config.color,
        duration: duration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
        ),
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  /// Show success snackbar (green)
  static void showSuccess(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) =>
      show(context, message, type: SnackbarType.success, duration: duration);

  /// Show error snackbar (red)
  static void showError(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) =>
      show(context, message, type: SnackbarType.error, duration: duration);

  /// Show warning snackbar (amber)
  static void showWarning(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) =>
      show(context, message, type: SnackbarType.warning, duration: duration);

  /// Show info snackbar (blue)
  static void showInfo(
    BuildContext context,
    String message, {
    Duration duration = const Duration(seconds: 3),
  }) =>
      show(context, message, type: SnackbarType.info, duration: duration);

  static _SnackbarConfig _getSnackbarConfig(SnackbarType type) {
    switch (type) {
      case SnackbarType.success:
        return _SnackbarConfig(
          color: AppColors.snackbarSuccess,
          icon: Icons.check_circle,
        );
      case SnackbarType.error:
        return _SnackbarConfig(
          color: AppColors.snackbarError,
          icon: Icons.error,
        );
      case SnackbarType.warning:
        return _SnackbarConfig(
          color: AppColors.snackbarWarning,
          icon: Icons.warning,
        );
      case SnackbarType.info:
        return _SnackbarConfig(
          color: AppColors.snackbarInfo,
          icon: Icons.info,
        );
    }
  }
}

class _SnackbarConfig {
  final Color color;
  final IconData icon;

  _SnackbarConfig({required this.color, required this.icon});
}
