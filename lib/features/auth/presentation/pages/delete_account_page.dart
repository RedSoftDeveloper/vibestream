import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/utils/snackbar_utils.dart';
import 'package:vibestream/features/auth/data/auth_service.dart';
import 'package:vibestream/features/onboarding/presentation/pages/splash_page.dart' show kPendingDeletionKey;
import 'package:vibestream/supabase/supabase_config.dart';

class DeleteAccountPage extends StatefulWidget {
  const DeleteAccountPage({super.key});

  @override
  State<DeleteAccountPage> createState() => _DeleteAccountPageState();
}

class _DeleteAccountPageState extends State<DeleteAccountPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool _obscurePassword = true;
  bool _isLoading = false;
  bool _confirmDelete = false;
  
  // OAuth re-auth state
  bool _isAwaitingOAuthReauth = false;
  String? _originalEmail;
  StreamSubscription<AuthState>? _authSubscription;
  
  // Store OAuth status before re-auth (since sign out clears currentUser)
  bool _wasOAuthUser = false;
  String? _storedOAuthProvider;

  @override
  void initState() {
    super.initState();
    _setupAuthListener();
    _checkPendingDeletion();
    // Store OAuth status immediately before any re-auth could clear currentUser
    _wasOAuthUser = _authService.isOAuthUser;
    _storedOAuthProvider = _authService.oauthProvider;
  }

  /// Check if we're resuming from an OAuth callback for deletion
  Future<void> _checkPendingDeletion() async {
    final prefs = await SharedPreferences.getInstance();
    final pendingDeletion = prefs.getBool(kPendingDeletionKey) ?? false;
    final savedEmail = prefs.getString('${kPendingDeletionKey}_email');
    
    if (pendingDeletion && savedEmail != null && mounted) {
      debugPrint('DeleteAccountPage: Resuming pending deletion flow');
      _originalEmail = savedEmail;
      
      // Check if we're already signed in (OAuth callback happened)
      final user = SupabaseConfig.auth.currentUser;
      if (user != null) {
        setState(() {
          _isAwaitingOAuthReauth = false;
          _confirmDelete = true;
        });
        _handleOAuthCallback(user);
      } else {
        // User not signed in, clear pending state
        await _clearPendingDeletion();
      }
    }
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _authSubscription?.cancel();
    super.dispose();
  }

  /// Set up listener for OAuth callback
  void _setupAuthListener() {
    _authSubscription = SupabaseConfig.auth.onAuthStateChange.listen((data) {
      final event = data.event;
      final session = data.session;
      
      debugPrint('DeleteAccountPage auth event: $event');
      
      // Only handle if we're waiting for re-auth
      if (!_isAwaitingOAuthReauth) return;
      
      if (event == AuthChangeEvent.signedIn && session != null) {
        _handleOAuthCallback(session.user);
      }
    });
  }

  /// Handle OAuth callback after re-authentication
  Future<void> _handleOAuthCallback(User user) async {
    if (!mounted) return;
    
    debugPrint('DeleteAccountPage: OAuth callback received');
    debugPrint('Original email: $_originalEmail');
    debugPrint('New email: ${user.email}');
    
    setState(() {
      _isAwaitingOAuthReauth = false;
      _isLoading = true;
    });
    
    // Compare emails
    final newEmail = user.email?.toLowerCase().trim();
    final originalEmail = _originalEmail?.toLowerCase().trim();
    
    if (newEmail != originalEmail) {
      // Different account logged in - sign out and show error
      debugPrint('DeleteAccountPage: Email mismatch! Signing out...');
      await _clearPendingDeletion();
      await _authService.signOut();
      
      if (!mounted) return;
      setState(() => _isLoading = false);
      
      _showError('You signed in with a different account. Please sign in with your original account to delete it.');
      
      // Navigate to login
      context.go(AppRoutes.login);
      return;
    }
    
    // Email matches - proceed with deletion
    debugPrint('DeleteAccountPage: Email matches, proceeding with deletion...');
    await _proceedWithDeletion();
  }

  // Use stored values since re-auth signs out the user first
  bool get _isOAuthUser => _wasOAuthUser;
  String? get _oauthProvider => _storedOAuthProvider;

  Future<void> _deleteAccount() async {
    if (_isOAuthUser) {
      await _initiateOAuthReauth();
    } else {
      await _deletePasswordAccount();
    }
  }

  Future<void> _deletePasswordAccount() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_confirmDelete) {
      _showError('Please confirm that you want to delete your account');
      return;
    }

    setState(() => _isLoading = true);

    // First verify the password
    final verifyResult = await _authService.verifyPassword(_passwordController.text);
    
    if (!mounted) return;

    if (!verifyResult.success) {
      setState(() => _isLoading = false);
      _showError(verifyResult.errorMessage ?? 'Invalid password');
      return;
    }

    // Password verified, now delete account
    await _proceedWithDeletion();
  }

  /// Set pending deletion flag before OAuth redirect
  Future<void> _setPendingDeletion(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kPendingDeletionKey, true);
    await prefs.setString('${kPendingDeletionKey}_email', email);
    debugPrint('DeleteAccountPage: Set pending deletion flag for $email');
  }

  /// Clear pending deletion flag
  Future<void> _clearPendingDeletion() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(kPendingDeletionKey);
    await prefs.remove('${kPendingDeletionKey}_email');
    debugPrint('DeleteAccountPage: Cleared pending deletion flag');
  }

  /// Initiate OAuth re-authentication for account deletion
  Future<void> _initiateOAuthReauth() async {
    if (!_confirmDelete) {
      _showError('Please confirm that you want to delete your account');
      return;
    }

    final provider = _oauthProvider;
    if (provider == null) {
      _showError('Unable to determine your sign-in method.');
      return;
    }

    // Show confirmation dialog
    final shouldProceed = await _showReauthDialog(provider);
    if (!shouldProceed) return;

    // Store original email before re-auth
    _originalEmail = _authService.currentUser?.email;
    
    if (_originalEmail == null) {
      _showError('Unable to verify your account. Please try again.');
      return;
    }

    debugPrint('DeleteAccountPage: Starting OAuth re-auth for provider: $provider');
    debugPrint('DeleteAccountPage: Original email: $_originalEmail');

    // Set pending deletion flag to persist across OAuth redirect
    await _setPendingDeletion(_originalEmail!);

    setState(() {
      _isLoading = true;
      _isAwaitingOAuthReauth = true;
    });

    // Trigger OAuth re-authentication
    final result = await _authService.reAuthenticateWithOAuth(provider);
    
    if (!mounted) return;

    if (!result.success) {
      await _clearPendingDeletion();
      setState(() {
        _isLoading = false;
        _isAwaitingOAuthReauth = false;
      });
      _showError(result.errorMessage ?? 'Re-authentication failed. Please try again.');
      return;
    }

    // Handle native sign-in (Apple/Google on mobile) - user is returned directly
    // For web OAuth redirect, result.user will be null and auth listener handles it
    if (result.user != null) {
      debugPrint('DeleteAccountPage: Native re-auth successful, handling directly');
      setState(() => _isAwaitingOAuthReauth = false);
      _handleOAuthCallback(result.user!);
    }
    // If result.user is null, OAuth flow will redirect and _handleOAuthCallback will be called via listener
  }

  /// Show dialog explaining re-authentication requirement
  Future<bool> _showReauthDialog(String provider) async {
    final providerName = provider.toLowerCase() == 'google' ? 'Google' : 
                         provider.toLowerCase() == 'apple' ? 'Apple' : provider;
    
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        final backgroundColor = isDark ? AppColors.darkSurface : AppColors.lightSurface;
        final textColor = isDark ? AppColors.darkText : AppColors.lightText;
        final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
        
        return AlertDialog(
          backgroundColor: backgroundColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: Row(
            children: [
              Icon(Icons.security, color: Colors.orange.shade400, size: 28),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Verify Your Identity',
                  style: TextStyle(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'To delete your account, you need to verify your identity by signing in with $providerName again.',
                style: TextStyle(color: secondaryTextColor, height: 1.5),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.orange.shade400, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Make sure to sign in with the same account.',
                        style: TextStyle(
                          color: Colors.orange.shade400,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
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
              onPressed: () => Navigator.of(context).pop(false),
              child: Text(
                'Cancel',
                style: TextStyle(color: secondaryTextColor),
              ),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(true),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red.shade600,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: Text('Continue with $providerName'),
            ),
          ],
        );
      },
    );
    
    return result ?? false;
  }

  /// Proceed with account deletion after verification
  Future<void> _proceedWithDeletion() async {
    // Clear the pending deletion flag first
    await _clearPendingDeletion();
    
    final deleteResult = await _authService.deleteAccount();
    
    if (!mounted) return;
    setState(() => _isLoading = false);

    if (deleteResult.success) {
      _showSuccess('Account deleted successfully');
      context.go(AppRoutes.login);
    } else {
      _showError(deleteResult.errorMessage ?? 'Failed to delete account');
    }
  }

  void _showError(String message) {
    debugPrint('Delete account error: $message');
    SnackbarUtils.showError(context, message);
  }

  void _showSuccess(String message) {
    SnackbarUtils.showSuccess(context, message);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
    final surfaceColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
    final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: backgroundColor,
        body: SafeArea(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _AppBar(isDark: isDark, textColor: textColor),
                  const SizedBox(height: 32),
                  _Header(textColor: textColor, secondaryTextColor: secondaryTextColor),
                  const SizedBox(height: 24),
                  _WarningCard(isDark: isDark, secondaryTextColor: secondaryTextColor),
                  const SizedBox(height: 32),
                  if (!_isOAuthUser) ...[
                    _PasswordField(
                      controller: _passwordController,
                      obscurePassword: _obscurePassword,
                      onToggleVisibility: () => setState(() => _obscurePassword = !_obscurePassword),
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      secondaryTextColor: secondaryTextColor,
                      borderColor: borderColor,
                    ),
                    const SizedBox(height: 24),
                  ] else ...[
                    _OAuthInfo(
                      provider: _oauthProvider ?? 'OAuth',
                      isDark: isDark,
                      surfaceColor: surfaceColor,
                      textColor: textColor,
                      secondaryTextColor: secondaryTextColor,
                    ),
                    const SizedBox(height: 24),
                  ],
                  _ConfirmCheckbox(
                    value: _confirmDelete,
                    onChanged: (value) => setState(() => _confirmDelete = value ?? false),
                    isDark: isDark,
                    textColor: textColor,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 32),
                  _DeleteButton(
                    isLoading: _isLoading,
                    enabled: _confirmDelete,
                    onPressed: _deleteAccount,
                    textColor: textColor,
                  ),
                  const SizedBox(height: 16),
                  _CancelButton(
                    onPressed: () => context.pop(),
                    isDark: isDark,
                    textColor: textColor,
                    borderColor: borderColor,
                  ),
                  const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AppBar extends StatelessWidget {
  final bool isDark;
  final Color textColor;

  const _AppBar({required this.isDark, required this.textColor});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final iconColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Row(
      children: [
        GestureDetector(
          onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.settings),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
            child: Icon(Icons.chevron_left, color: iconColor, size: 28),
          ),
        ),
        Expanded(
          child: Center(
            child: Text(
              'Delete Account',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: textColor,
              ),
            ),
          ),
        ),
        const SizedBox(width: 48),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  final Color textColor;
  final Color secondaryTextColor;

  const _Header({required this.textColor, required this.secondaryTextColor});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'We\'re sad to see you go',
        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w700,
          color: textColor,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        'Deleting your account is permanent and cannot be undone.',
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: secondaryTextColor),
      ),
    ],
  );
}

class _WarningCard extends StatelessWidget {
  final bool isDark;
  final Color secondaryTextColor;

  const _WarningCard({required this.isDark, required this.secondaryTextColor});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.red.withValues(alpha: isDark ? 0.15 : 0.1),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.red.shade400, size: 24),
            const SizedBox(width: 12),
            Text(
              'What will be deleted:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.red.shade400,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...[
          'Your profile and personal information',
          'Your mood quiz and recommendation history',
          'All your favorite movies and shows',
          'Your vibe tags and personalization data',
        ].map((item) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.remove, size: 16, color: secondaryTextColor),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: secondaryTextColor),
                ),
              ),
            ],
          ),
        )),
      ],
    ),
  );
}

class _PasswordField extends StatelessWidget {
  final TextEditingController controller;
  final bool obscurePassword;
  final VoidCallback onToggleVisibility;
  final bool isDark;
  final Color surfaceColor;
  final Color secondaryTextColor;
  final Color borderColor;

  const _PasswordField({
    required this.controller,
    required this.obscurePassword,
    required this.onToggleVisibility,
    required this.isDark,
    required this.surfaceColor,
    required this.secondaryTextColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Enter your password to confirm',
          style: Theme.of(context).textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: textColor,
          ),
        ),
        const SizedBox(height: 12),
        TextFormField(
          controller: controller,
          obscureText: obscurePassword,
          textInputAction: TextInputAction.done,
          style: TextStyle(color: textColor),
          decoration: InputDecoration(
            hintText: 'Enter your password',
            hintStyle: TextStyle(color: secondaryTextColor),
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: Colors.red.shade400, width: 1.5),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
            suffixIcon: IconButton(
              icon: Icon(
                obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: secondaryTextColor,
              ),
              onPressed: onToggleVisibility,
            ),
          ),
          validator: (value) {
            if (value == null || value.isEmpty) return 'Password is required';
            return null;
          },
        ),
      ],
    );
  }
}

class _OAuthInfo extends StatelessWidget {
  final String provider;
  final bool isDark;
  final Color surfaceColor;
  final Color textColor;
  final Color secondaryTextColor;

  const _OAuthInfo({
    required this.provider,
    required this.isDark,
    required this.surfaceColor,
    required this.textColor,
    required this.secondaryTextColor,
  });

  String get _providerDisplayName {
    switch (provider.toLowerCase()) {
      case 'google': return 'Google';
      case 'apple': return 'Apple';
      default: return provider;
    }
  }

  IconData get _providerIcon {
    switch (provider.toLowerCase()) {
      case 'google': return Icons.g_mobiledata;
      case 'apple': return Icons.apple;
      default: return Icons.account_circle;
    }
  }

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: surfaceColor,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                shape: BoxShape.circle,
              ),
              child: Icon(_providerIcon, color: textColor, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Signed in with $_providerDisplayName',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'You\'ll need to verify your identity',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: secondaryTextColor),
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.blue.withValues(alpha: isDark ? 0.15 : 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              Icon(Icons.info_outline, color: Colors.blue.shade400, size: 18),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'You\'ll be asked to sign in with $_providerDisplayName again to confirm your identity before deletion.',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.blue.shade400,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class _ConfirmCheckbox extends StatelessWidget {
  final bool value;
  final ValueChanged<bool?> onChanged;
  final bool isDark;
  final Color textColor;
  final Color borderColor;

  const _ConfirmCheckbox({
    required this.value,
    required this.onChanged,
    required this.isDark,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SizedBox(
        width: 24,
        height: 24,
        child: Checkbox(
          value: value,
          onChanged: onChanged,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          side: BorderSide(color: borderColor, width: 1.5),
          activeColor: Colors.red.shade400,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: GestureDetector(
          onTap: () => onChanged(!value),
          child: Text(
            'I understand that deleting my account is permanent and all my data will be lost forever.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: textColor),
          ),
        ),
      ),
    ],
  );
}

class _DeleteButton extends StatelessWidget {
  final bool isLoading;
  final bool enabled;
  final VoidCallback onPressed;
  final Color textColor;

  const _DeleteButton({
    required this.isLoading,
    required this.enabled,
    required this.onPressed,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 56,
    child: ElevatedButton(
      onPressed: (isLoading || !enabled) ? null : onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: enabled ? Colors.red.shade600 : Colors.red.shade300,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 0,
        disabledBackgroundColor: Colors.red.shade200,
      ),
      child: isLoading
          ? const SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
            )
          : Text(
              'Delete My Account',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
    ),
  );
}

class _CancelButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool isDark;
  final Color textColor;
  final Color borderColor;

  const _CancelButton({
    required this.onPressed,
    required this.isDark,
    required this.textColor,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) => SizedBox(
    width: double.infinity,
    height: 56,
    child: OutlinedButton(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        backgroundColor: Colors.transparent,
        side: BorderSide(color: borderColor, width: 1),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      ),
      child: Text(
        'Cancel',
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w600,
          color: textColor,
        ),
      ),
    ),
  );
}
