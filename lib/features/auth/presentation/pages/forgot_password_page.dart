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

class ForgotPasswordPage extends StatefulWidget {
  const ForgotPasswordPage({super.key});

  @override
  State<ForgotPasswordPage> createState() => _ForgotPasswordPageState();
}

class _ForgotPasswordPageState extends State<ForgotPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  void _sendResetLink(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().sendPasswordResetOtp(_emailController.text.trim());
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
          } else if (state.isSuccess && state.flowType == AuthFlowType.resetPassword) {
            context.push(
              AppRoutes.otpVerification,
              extra: {
                'email': _emailController.text.trim(),
                'flowType': AuthFlowType.resetPassword,
              },
            );
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
                            _BackButton(isDark: isDark),
                            Expanded(
                              child: Center(
                                child: Text(
                                  'Reset Password',
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
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Icon(Icons.lock_reset_rounded, size: 40, color: AppColors.accent),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Forgot Password?',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          "No worries! Enter your email address and we'll send you a link to reset your password.",
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                                color: secondaryTextColor,
                              ),
                        ),
                        const SizedBox(height: 32),
                        AuthTextField(
                          controller: _emailController,
                          hintText: 'Enter your email',
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: () => _sendResetLink(context),
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
                        const SizedBox(height: 24),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: state.isLoading ? null : () => _sendResetLink(context),
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
                                    'Send Reset Link',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
                                  ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Center(
                          child: GestureDetector(
                            onTap: () => context.pop(),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.arrow_back, size: 18, color: textColor),
                                const SizedBox(width: 8),
                                Text(
                                  'Back to Sign In',
                                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                ),
                              ],
                            ),
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

class _BackButton extends StatelessWidget {
  final bool isDark;
  const _BackButton({required this.isDark});

  @override
  Widget build(BuildContext context) {
    final backgroundColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
    final iconColor = isDark ? AppColors.darkText : AppColors.lightText;

    return GestureDetector(
      onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.home),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
        child: Icon(Icons.chevron_left, color: iconColor, size: 28),
      ),
    );
  }
}
