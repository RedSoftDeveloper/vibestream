import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/theme/theme_cubit.dart';
import 'package:vibestream/core/utils/snackbar_utils.dart';
import 'package:vibestream/features/settings/presentation/cubits/settings_cubit.dart';
import 'package:vibestream/features/settings/presentation/cubits/settings_state.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => SettingsCubit()..init(),
      child: const _SettingsPageContent(),
    );
  }
}

class _SettingsPageContent extends StatelessWidget {
  const _SettingsPageContent();

  void _showComingSoonSnackbar(BuildContext context, String feature) {
    SnackbarUtils.showInfo(
      context,
      '$feature will be available soon',
      duration: const Duration(seconds: 2),
    );
  }

  static const String _contactEmail = 'info@vibestreamhq.com';
  static const String _emailSubject = 'VibeStream Support Request';

  Future<void> _launchContactEmail(BuildContext context) async {
    final Uri emailUri = Uri(
      scheme: 'mailto',
      path: _contactEmail,
      queryParameters: {'subject': _emailSubject},
    );

    try {
      // Try external application first
      final launched = await launchUrl(emailUri, mode: LaunchMode.externalApplication);
      if (launched) return;

      // Fallback to platform default
      final platformLaunched = await launchUrl(emailUri, mode: LaunchMode.platformDefault);
      if (platformLaunched) return;

      // If mailto fails, show options dialog
      if (context.mounted) {
        _showContactOptionsDialog(context);
      }
    } catch (e) {
      debugPrint('Error launching email: $e');
      if (context.mounted) {
        _showContactOptionsDialog(context);
      }
    }
  }

  void _showContactOptionsDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Contact Us',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _contactEmail,
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? const Color(0xFF808080) : const Color(0xFF606060),
                ),
              ),
              const SizedBox(height: 20),
              _buildContactOption(
                context: ctx,
                icon: Icons.copy,
                title: 'Copy email address',
                isDark: isDark,
                onTap: () => _copyEmailToClipboard(ctx),
              ),
              const SizedBox(height: 8),
              _buildContactOption(
                context: ctx,
                icon: Icons.email_outlined,
                title: 'Open in Gmail',
                isDark: isDark,
                onTap: () => _openGmailCompose(ctx),
              ),
              const SizedBox(height: 8),
              _buildContactOption(
                context: ctx,
                icon: Icons.open_in_browser,
                title: 'Open in Outlook',
                isDark: isDark,
                onTap: () => _openOutlookCompose(ctx),
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContactOption({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isDark ? const Color(0xFF808080) : const Color(0xFF808080)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            Icon(
              Icons.arrow_forward_ios,
              size: 16,
              color: isDark ? const Color(0xFF606060) : const Color(0xFFA0A0A0),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _copyEmailToClipboard(BuildContext context) async {
    await Clipboard.setData(const ClipboardData(text: _contactEmail));
    if (context.mounted) {
      Navigator.pop(context);
      SnackbarUtils.showSuccess(
        context,
        'Email address copied to clipboard',
        duration: const Duration(seconds: 2),
      );
    }
  }

  Future<void> _openGmailCompose(BuildContext context) async {
    final gmailUrl = Uri.parse(
      'https://mail.google.com/mail/?view=cm&fs=1&to=$_contactEmail&su=${Uri.encodeComponent(_emailSubject)}',
    );
    Navigator.pop(context);
    await _launchUrlWithFallback(context, gmailUrl);
  }

  Future<void> _openOutlookCompose(BuildContext context) async {
    final outlookUrl = Uri.parse(
      'https://outlook.live.com/mail/0/deeplink/compose?to=$_contactEmail&subject=${Uri.encodeComponent(_emailSubject)}',
    );
    Navigator.pop(context);
    await _launchUrlWithFallback(context, outlookUrl);
  }

  Future<void> _launchUrlWithFallback(BuildContext context, Uri url) async {
    try {
      // Try external browser first
      final launched = await launchUrl(url, mode: LaunchMode.externalApplication);
      if (launched) return;

      // Fallback to in-app browser
      final inAppLaunched = await launchUrl(url, mode: LaunchMode.inAppBrowserView);
      if (inAppLaunched) return;

      // Fallback to platform default
      final platformLaunched = await launchUrl(url, mode: LaunchMode.platformDefault);
      if (platformLaunched) return;

      if (context.mounted) {
        SnackbarUtils.showError(context, 'Could not open the link');
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      if (context.mounted) {
        SnackbarUtils.showError(context, 'Could not open the link');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocConsumer<SettingsCubit, SettingsState>(
      listener: (context, state) {
        if (state.status == SettingsStatus.success && state.appUser == null) {
          // User signed out
          context.go(AppRoutes.login);
        } else if (state.status == SettingsStatus.failure && state.errorMessage != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Icons.error_outline, color: Colors.white, size: 20),
                  const SizedBox(width: 12),
                  Expanded(child: Text(state.errorMessage!)),
                ],
              ),
              backgroundColor: Colors.red,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 80),
            ),
          );
          context.read<SettingsCubit>().clearError();
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: isDark ? const Color(0xFF0D0D0D) : const Color(0xFFF8F9FA),
          body: SafeArea(
            child: Column(
              children: [
                _buildAppBar(context, isDark),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: Column(
                      children: [
                        const SizedBox(height: 8),
                        _buildProfileHeader(context, state, isDark),
                        const SizedBox(height: 16),
                        _buildCard(isDark, [
                          _buildTileItem(
                            icon: Icons.person_outline,
                            title: 'My Profile',
                            isDark: isDark,
                            onTap: () => context.push(AppRoutes.myProfile),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _buildCard(isDark, [
                          _buildTileWithValue(
                            context: context,
                            icon: Icons.contrast,
                            title: 'Theme',
                            value: context.watch<ThemeCubit>().themeDisplayName,
                            isDark: isDark,
                            onTap: () => _showThemeSheet(context),
                          ),
                          _buildTileWithSwitch(
                            context: context,
                            icon: Icons.visibility_off_outlined,
                            title: 'Hide Spoilers',
                            value: state.hideSpoilers,
                            isDark: isDark,
                            onChanged: (v) => context.read<SettingsCubit>().toggleHideSpoilers(),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _buildCard(isDark, [
                          _buildTileItem(
                            icon: Icons.history,
                            title: 'Clear History',
                            isDark: isDark,
                            onTap: state.isClearingHistory ? null : () => _showClearHistoryDialog(context),
                            isLoading: state.isClearingHistory,
                          ),
                          _buildTileItem(
                            icon: Icons.shield_outlined,
                            title: 'Privacy Policy',
                            isDark: isDark,
                            onTap: () => _showComingSoonSnackbar(context, 'Privacy Policy'),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _buildCard(isDark, [
                          _buildTileItem(
                            icon: Icons.chat_bubble_outline,
                            title: 'Give Feedback',
                            isDark: isDark,
                            onTap: () => context.push(AppRoutes.appFeedback),
                          ),
                          _buildTileItem(
                            icon: Icons.help_outline,
                            title: 'Help Center',
                            isDark: isDark,
                            onTap: () => _showComingSoonSnackbar(context, 'Help Center'),
                          ),
                          _buildTileItem(
                            icon: Icons.mail_outline,
                            title: 'Contact Us',
                            isDark: isDark,
                            onTap: () => _launchContactEmail(context),
                          ),
                        ]),
                        const SizedBox(height: 16),
                        _buildCard(isDark, [
                          _buildTileItem(
                            icon: Icons.delete_outline,
                            title: 'Delete Account',
                            isDark: isDark,
                            onTap: () => context.push(AppRoutes.deleteAccount),
                          ),
                          _buildTileItem(
                            icon: Icons.logout,
                            title: 'Log out',
                            isDark: isDark,
                            onTap: () => _showLogoutDialog(context),
                          ),
                        ]),
                        const SizedBox(height: 32),
                        _buildFooter(state, isDark),
                        const SizedBox(height: 100),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Settings',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileHeader(BuildContext context, SettingsState state, bool isDark) {
    final displayName = state.appUser?.displayNameOrDefault ?? 'Movie Lover';
    final memberSinceYear = state.appUser?.memberSinceYear ?? DateTime.now().year;
    final avatarUrl = state.appUser?.avatarUrl;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF0F0F0),
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? const Color(0xFF3A3A3A) : const Color(0xFFE0E0E0),
                width: 1,
              ),
            ),
            child: avatarUrl != null && avatarUrl.isNotEmpty
                ? ClipOval(
                    child: Image.network(
                      avatarUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Icon(
                        Icons.person_outline,
                        size: 28,
                        color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
                      ),
                    ),
                  )
                : Icon(
                    Icons.person_outline,
                    size: 28,
                    color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
                  ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: state.isLoadingUser
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        height: 20,
                        width: 120,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        height: 14,
                        width: 180,
                        decoration: BoxDecoration(
                          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE0E0E0),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: isDark ? Colors.white : Colors.black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Movie enthusiast since $memberSinceYear',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                          color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildCard(bool isDark, List<Widget> children) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFE5E5E5),
          width: 1,
        ),
      ),
      child: Column(children: children),
    );
  }

  Widget _buildTileItem({
    required IconData icon,
    required String title,
    required bool isDark,
    VoidCallback? onTap,
    bool isLoading = false,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isDark ? const Color(0xFF808080) : const Color(0xFF808080)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildTileWithValue({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String value,
    required bool isDark,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isDark ? const Color(0xFF808080) : const Color(0xFF808080)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                title,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTileWithSwitch({
    required BuildContext context,
    required IconData icon,
    required String title,
    required bool value,
    required bool isDark,
    required ValueChanged<bool> onChanged,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          Icon(icon, size: 22, color: isDark ? const Color(0xFF808080) : const Color(0xFF808080)),
          const SizedBox(width: 14),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w400,
                color: isDark ? Colors.white : Colors.black,
              ),
            ),
          ),
          SizedBox(
            width: 50,
            height: 28,
            child: FittedBox(
              fit: BoxFit.contain,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
                activeTrackColor: isDark ? Colors.white : const Color(0xFF1A1A1A),
                inactiveThumbColor: isDark ? const Color(0xFF606060) : Colors.white,
                inactiveTrackColor: isDark ? const Color(0xFF404040) : const Color(0xFFD0D0D0),
                trackOutlineColor: WidgetStateProperty.all(Colors.transparent),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(SettingsState state, bool isDark) {
    final versionText = state.appVersion.isNotEmpty
        ? 'VibeStream v${state.appVersion}${state.buildNumber.isNotEmpty ? ' (${state.buildNumber})' : ''}'
        : 'VibeStream';

    return Column(
      children: [
        Text(
          versionText,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: isDark ? Colors.white : Colors.black,
          ),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'Made with ',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
              ),
            ),
            const Icon(Icons.favorite, size: 14, color: Color(0xFFE57373)),
            Text(
              ' for movie lovers',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: isDark ? const Color(0xFF808080) : const Color(0xFF808080),
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _showThemeSheet(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final themeCubit = context.read<ThemeCubit>();
    const navBarOffset = 80.0;

    showModalBottomSheet(
      context: context,
      backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => BlocProvider.value(
        value: themeCubit,
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, currentTheme) {
            final sheetIsDark = Theme.of(context).brightness == Brightness.dark;
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 24, 24, 24 + navBarOffset),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Select Theme',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: sheetIsDark ? Colors.white : Colors.black,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _buildThemeOption(context, 'Light', ThemeMode.light, Icons.light_mode_outlined, sheetIsDark, currentTheme),
                    const SizedBox(height: 8),
                    _buildThemeOption(context, 'Dark', ThemeMode.dark, Icons.dark_mode_outlined, sheetIsDark, currentTheme),
                    const SizedBox(height: 8),
                    _buildThemeOption(context, 'System', ThemeMode.system, Icons.settings_suggest_outlined, sheetIsDark, currentTheme),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildThemeOption(BuildContext context, String label, ThemeMode mode, IconData icon, bool isDark, ThemeMode currentTheme) {
    final isSelected = currentTheme == mode;
    return GestureDetector(
      onTap: () {
        context.read<ThemeCubit>().setTheme(mode);
        Navigator.pop(context);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected
              ? (isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5))
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Icon(icon, size: 22, color: isDark ? const Color(0xFF808080) : const Color(0xFF808080)),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                  color: isDark ? Colors.white : Colors.black,
                ),
              ),
            ),
            if (isSelected) Icon(Icons.check, size: 20, color: isDark ? Colors.white : Colors.black),
          ],
        ),
      ),
    );
  }

  void _showLogoutDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsCubit = context.read<SettingsCubit>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Log out',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Text(
          'Are you sure you want to log out?',
          style: TextStyle(color: isDark ? const Color(0xFF808080) : const Color(0xFF808080)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: TextStyle(color: isDark ? const Color(0xFF808080) : const Color(0xFF808080))),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await settingsCubit.signOut();
              if (context.mounted) {
                context.go(AppRoutes.login);
              }
            },
            child: const Text('Log out', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  void _showClearHistoryDialog(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final settingsCubit = context.read<SettingsCubit>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: isDark ? const Color(0xFF1A1A1A) : Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Clear History',
          style: TextStyle(color: isDark ? Colors.white : Colors.black),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This will reset your discovery session:',
              style: TextStyle(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 12),
            _buildClearItem('Recent Vibes & quiz sessions', isDark),
            _buildClearItem('Likes, dislikes & feedback', isDark),
            _buildClearItem('Previously generated recommendations', isDark),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF2A2A2A) : const Color(0xFFF5F5F5),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    size: 18,
                    color: isDark ? const Color(0xFF808080) : const Color(0xFF606060),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Your Favorites and account settings will not be affected.',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? const Color(0xFF808080) : const Color(0xFF606060),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: TextStyle(color: isDark ? const Color(0xFF808080) : const Color(0xFF808080)),
            ),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final success = await settingsCubit.clearHistory();
              if (context.mounted && success) {
                SnackbarUtils.showSuccess(context, 'History cleared successfully');
              }
            },
            child: const Text('Clear History', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }

  Widget _buildClearItem(String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(
            Icons.remove_circle_outline,
            size: 16,
            color: Colors.red.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? const Color(0xFFB0B0B0) : const Color(0xFF606060),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
