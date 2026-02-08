import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/utils/snackbar_utils.dart';
import 'package:vibestream/features/auth/data/auth_service.dart';
import 'package:vibestream/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:vibestream/features/auth/presentation/cubits/auth_state.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _passwordFocusNode = FocusNode();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  bool _isNavigating = false;

  void _login(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().login(
          _emailController.text.trim(),
          _passwordController.text,
        );
  }

  /// Navigate based on onboarding status after successful login
  Future<void> _navigateAfterLogin() async {
    if (_isNavigating) return;
    _isNavigating = true;
    
    try {
      final profileService = ProfileService();
      final hasCompletedOnboarding = await profileService.hasCompletedOnboarding();
      
      if (!mounted) return;
      
      if (hasCompletedOnboarding) {
        debugPrint('LoginPage: User has completed onboarding, navigating to home');
        context.go(AppRoutes.home);
      } else {
        debugPrint('LoginPage: User needs onboarding, navigating to onboarding');
        context.go(AppRoutes.onboarding);
      }
    } catch (e) {
      debugPrint('LoginPage: Error checking onboarding status: $e');
      // Default to onboarding if we can't determine status
      if (mounted) context.go(AppRoutes.onboarding);
    }
  }

  void _showComingSoonSnackbar(String feature) {
    SnackbarUtils.showInfo(context, '$feature will be available soon', duration: const Duration(seconds: 2));
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit(),
      child: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.isFailure && state.errorMessage != null) {
            SnackbarUtils.showError(context, state.errorMessage!);
            context.read<AuthCubit>().clearError();
          } else if (state.isSuccess) {
            if (state.needsVerification) {
              context.push(
                AppRoutes.otpVerification,
                extra: {
                  'email': _emailController.text.trim(),
                  'flowType': AuthFlowType.signIn,
                },
              );
            } else {
              // Check onboarding status before navigating
              _navigateAfterLogin();
            }
          }
        },
        builder: (context, state) {
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
                        Row(
                          children: [
                            const SizedBox(width: 48),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Sign in',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 48),
                          ],
                        ),
                        const SizedBox(height: 32),
                        Text(
                          'Welcome to VibeStream!',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to your account',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: secondaryTextColor,
                              ),
                        ),
                        const SizedBox(height: 32),
                        AuthTextField(
                          controller: _emailController,
                          hintText: 'Enter your email',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: () => _passwordFocusNode.requestFocus(),
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          secondaryTextColor: secondaryTextColor,
                          borderColor: borderColor,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Email is required';
                            if (!value.contains('@')) return 'Enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _passwordController,
                          hintText: 'Enter your password',
                          obscureText: state.loginObscurePassword,
                          focusNode: _passwordFocusNode,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: () => _login(context),
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          secondaryTextColor: secondaryTextColor,
                          borderColor: borderColor,
                          suffixIcon: IconButton(
                            icon: Icon(
                              state.loginObscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: secondaryTextColor,
                            ),
                            onPressed: () => context.read<AuthCubit>().toggleLoginPasswordVisibility(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Password is required';
                            if (value.length < 8) return 'Password must be at least 8 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            GestureDetector(
                              onTap: () => context.push(AppRoutes.forgotPassword),
                              child: Text(
                                'Forgot password?',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: state.isLoading ? null : () => _login(context),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accent,
                              foregroundColor: textColor,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
                              elevation: 0,
                            ),
                            child: state.isLoading
                                ? SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
                                  )
                                : Text(
                                    'Sign in',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Social auth - platform aware
                        _SocialAuthSection(
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          textColor: textColor,
                          secondaryTextColor: secondaryTextColor,
                          borderColor: borderColor,
                          isGoogleLoading: state.isGoogleLoading,
                          isAppleLoading: state.isAppleLoading,
                          onGooglePressed: state.isOAuthLoading ? null : () => context.read<AuthCubit>().signInWithGoogle(),
                          onApplePressed: state.isOAuthLoading ? null : () => context.read<AuthCubit>().signInWithApple(),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: secondaryTextColor,
                                  ),
                            ),
                            GestureDetector(
                              onTap: () => context.push(AppRoutes.register),
                              child: Text(
                                'Sign up',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            children: [
                              Text(
                                'By signing in, you agree to our ',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: secondaryTextColor,
                                    ),
                              ),
                              GestureDetector(
                                onTap: () => _showComingSoonSnackbar('Terms of Service'),
                                child: Text(
                                  'Terms of Service',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        decoration: TextDecoration.underline,
                                        color: secondaryTextColor,
                                      ),
                                ),
                              ),
                              Text(
                                ' and ',
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      color: secondaryTextColor,
                                    ),
                              ),
                              GestureDetector(
                                onTap: () => _showComingSoonSnackbar('Privacy Policy'),
                                child: Text(
                                  'Privacy Policy',
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        decoration: TextDecoration.underline,
                                        color: secondaryTextColor,
                                      ),
                                ),
                              ),
                            ],
                          ),
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
        },
      ),
    );
  }
}

/// Reusable auth text field widget
class AuthTextField extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextCapitalization textCapitalization;
  final Widget? suffixIcon;
  final String? Function(String?)? validator;
  final bool isDark;
  final Color surfaceColor;
  final Color secondaryTextColor;
  final Color borderColor;
  final TextInputAction? textInputAction;
  final VoidCallback? onFieldSubmitted;
  final FocusNode? focusNode;

  const AuthTextField({
    super.key,
    required this.controller,
    required this.hintText,
    this.obscureText = false,
    this.keyboardType,
    this.textCapitalization = TextCapitalization.none,
    this.suffixIcon,
    this.validator,
    required this.isDark,
    required this.surfaceColor,
    required this.secondaryTextColor,
    required this.borderColor,
    this.textInputAction,
    this.onFieldSubmitted,
    this.focusNode,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDark ? AppColors.darkText : AppColors.lightText;

    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      validator: validator,
      textInputAction: textInputAction,
      focusNode: focusNode,
      onFieldSubmitted: onFieldSubmitted != null ? (_) => onFieldSubmitted!() : null,
      style: TextStyle(color: textColor),
      decoration: InputDecoration(
        hintText: hintText,
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
          borderSide: BorderSide(color: AppColors.accent, width: 1.5),
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
        suffixIcon: suffixIcon,
      ),
    );
  }
}

/// Reusable social button widget
class SocialButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final IconData? icon;
  final Widget? customIcon;
  final String label;
  final bool isDark;
  final Color surfaceColor;
  final Color textColor;
  final Color borderColor;
  final bool isLoading;

  const SocialButton({
    super.key,
    required this.onPressed,
    this.icon,
    this.customIcon,
    required this.label,
    required this.isDark,
    required this.surfaceColor,
    required this.textColor,
    required this.borderColor,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.transparent,
          side: BorderSide(color: borderColor, width: 1),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        ),
        child: isLoading
            ? SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: textColor),
              )
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (icon != null) Icon(icon, color: textColor, size: 24),
                  if (customIcon != null) customIcon!,
                  const SizedBox(width: 12),
                  Text(
                    label,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                  ),
                ],
              ),
      ),
    );
  }
}

/// Platform-aware social auth section
/// Shows Apple Sign In only on iOS/macOS, Google Sign In on all platforms
class _SocialAuthSection extends StatelessWidget {
  final bool isDark;
  final Color surfaceColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color borderColor;
  final bool isGoogleLoading;
  final bool isAppleLoading;
  final VoidCallback? onGooglePressed;
  final VoidCallback? onApplePressed;

  const _SocialAuthSection({
    required this.isDark,
    required this.surfaceColor,
    required this.textColor,
    required this.secondaryTextColor,
    required this.borderColor,
    required this.isGoogleLoading,
    required this.isAppleLoading,
    this.onGooglePressed,
    this.onApplePressed,
  });

  bool get _showAppleSignIn {
    // Show Apple Sign In only on iOS and macOS
    if (kIsWeb) return false;
    return defaultTargetPlatform == TargetPlatform.iOS ||
        defaultTargetPlatform == TargetPlatform.macOS;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: Divider(color: borderColor)),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                'or continue with',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: secondaryTextColor,
                    ),
              ),
            ),
            Expanded(child: Divider(color: borderColor)),
          ],
        ),
        const SizedBox(height: 24),
        // Apple Sign In - only on iOS/macOS
        if (_showAppleSignIn) ...[
          SocialButton(
            onPressed: onApplePressed,
            icon: Icons.apple,
            label: 'Continue with Apple',
            isDark: isDark,
            surfaceColor: surfaceColor,
            textColor: textColor,
            borderColor: borderColor,
            isLoading: isAppleLoading,
          ),
          const SizedBox(height: 12),
        ],
        // Google Sign In - always visible
        SocialButton(
          onPressed: onGooglePressed,
          icon: null,
          label: 'Continue with Google',
          isDark: isDark,
          surfaceColor: surfaceColor,
          textColor: textColor,
          borderColor: borderColor,
          isLoading: isGoogleLoading,
          customIcon: Text(
            'G',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: textColor,
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
