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
import 'package:vibestream/features/auth/presentation/pages/login_page.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _register(BuildContext context, AuthState state) {
    if (!_formKey.currentState!.validate()) return;
    if (!state.agreeToTerms) {
      SnackbarUtils.showWarning(context, 'Please agree to the terms and conditions');
      return;
    }

    context.read<AuthCubit>().register(
          _emailController.text.trim(),
          _passwordController.text,
          _nameController.text.trim(),
        );
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
            if (state.userAlreadyExists) {
              SnackbarUtils.showWarning(
                context,
                'This email is already registered. Please sign in.',
                duration: const Duration(seconds: 4),
              );
              context.go(AppRoutes.login);
            } else {
              SnackbarUtils.showError(context, state.errorMessage!);
            }
            context.read<AuthCubit>().clearError();
          } else if (state.isSuccess) {
            if (state.needsVerification) {
              context.push(
                AppRoutes.otpVerification,
                extra: {
                  'email': _emailController.text.trim(),
                  'flowType': AuthFlowType.signUp,
                },
              );
            } else {
              context.go(AppRoutes.onboarding);
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
                                  'Sign up',
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
                          'Create Account',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Start discovering movies and series that match your vibe',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: secondaryTextColor,
                              ),
                        ),
                        const SizedBox(height: 32),
                        AuthTextField(
                          controller: _nameController,
                          hintText: 'Enter your full name',
                          keyboardType: TextInputType.name,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: () => _emailFocusNode.requestFocus(),
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          secondaryTextColor: secondaryTextColor,
                          borderColor: borderColor,
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Name is required';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _emailController,
                          hintText: 'Enter your email',
                          keyboardType: TextInputType.emailAddress,
                          focusNode: _emailFocusNode,
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
                          hintText: 'Create a password',
                          obscureText: state.registerObscurePassword,
                          focusNode: _passwordFocusNode,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: () => _confirmPasswordFocusNode.requestFocus(),
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          secondaryTextColor: secondaryTextColor,
                          borderColor: borderColor,
                          suffixIcon: IconButton(
                            icon: Icon(
                              state.registerObscurePassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: secondaryTextColor,
                            ),
                            onPressed: () => context.read<AuthCubit>().toggleRegisterPasswordVisibility(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Password is required';
                            if (value.length < 8) return 'Password must be at least 8 characters';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        AuthTextField(
                          controller: _confirmPasswordController,
                          hintText: 'Confirm your password',
                          obscureText: state.registerObscureConfirmPassword,
                          focusNode: _confirmPasswordFocusNode,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: () => _register(context, state),
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          secondaryTextColor: secondaryTextColor,
                          borderColor: borderColor,
                          suffixIcon: IconButton(
                            icon: Icon(
                              state.registerObscureConfirmPassword
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: secondaryTextColor,
                            ),
                            onPressed: () => context.read<AuthCubit>().toggleRegisterConfirmPasswordVisibility(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please confirm your password';
                            if (value != _passwordController.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            SizedBox(
                              width: 24,
                              height: 24,
                              child: Checkbox(
                                value: state.agreeToTerms,
                                onChanged: (value) => context.read<AuthCubit>().setAgreeToTerms(value ?? false),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                                side: BorderSide(color: borderColor, width: 1.5),
                                activeColor: AppColors.accent,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Wrap(
                                children: [
                                  Text(
                                    'I agree to the ',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: secondaryTextColor,
                                        ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _showComingSoonSnackbar('Terms of Service'),
                                    child: Text(
                                      'Terms of Service',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                            decoration: TextDecoration.underline,
                                          ),
                                    ),
                                  ),
                                  Text(
                                    ' and ',
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                          color: secondaryTextColor,
                                        ),
                                  ),
                                  GestureDetector(
                                    onTap: () => _showComingSoonSnackbar('Privacy Policy'),
                                    child: Text(
                                      'Privacy Policy',
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                            decoration: TextDecoration.underline,
                                          ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: state.isLoading ? null : () => _register(context, state),
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
                                    'Create Account',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 32),
                        // Social auth - platform aware
                        _RegisterSocialAuthSection(
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
                              'Already have an account? ',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                    color: secondaryTextColor,
                                  ),
                            ),
                            GestureDetector(
                              onTap: () => context.pop(),
                              child: Text(
                                'Sign in',
                                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: textColor,
                                    ),
                              ),
                            ),
                          ],
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

/// Platform-aware social auth section for register page
/// Shows Apple Sign In only on iOS/macOS, Google Sign In on all platforms
class _RegisterSocialAuthSection extends StatelessWidget {
  final bool isDark;
  final Color surfaceColor;
  final Color textColor;
  final Color secondaryTextColor;
  final Color borderColor;
  final bool isGoogleLoading;
  final bool isAppleLoading;
  final VoidCallback? onGooglePressed;
  final VoidCallback? onApplePressed;

  const _RegisterSocialAuthSection({
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
