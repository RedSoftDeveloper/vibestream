import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/utils/snackbar_utils.dart';
import 'package:vibestream/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:vibestream/features/auth/presentation/cubits/auth_state.dart';
import 'package:vibestream/features/auth/presentation/pages/login_page.dart';

class CreateNewPasswordPage extends StatefulWidget {
  const CreateNewPasswordPage({super.key});

  @override
  State<CreateNewPasswordPage> createState() => _CreateNewPasswordPageState();
}

class _CreateNewPasswordPageState extends State<CreateNewPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _confirmPasswordFocusNode = FocusNode();

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _updatePassword(BuildContext context) {
    if (!_formKey.currentState!.validate()) return;
    context.read<AuthCubit>().updatePassword(_passwordController.text);
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
          } else if (state.isSuccess && state.passwordUpdateSuccess) {
            SnackbarUtils.showSuccess(
              context,
              'Password updated successfully! Please sign in with your new password.',
              duration: const Duration(seconds: 2),
            );
            Future.delayed(const Duration(milliseconds: 1500), () {
              if (mounted) context.go(AppRoutes.login);
            });
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
                                  'New Password',
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
                          child: Icon(Icons.lock_outline_rounded, size: 40, color: AppColors.accent),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'Create New Password',
                          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                fontWeight: FontWeight.w700,
                                color: textColor,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Your new password must be different from previously used passwords.',
                          style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: secondaryTextColor),
                        ),
                        const SizedBox(height: 32),
                        AuthTextField(
                          controller: _passwordController,
                          hintText: 'Enter new password',
                          obscureText: state.createPasswordObscure,
                          textInputAction: TextInputAction.next,
                          onFieldSubmitted: () => _confirmPasswordFocusNode.requestFocus(),
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          secondaryTextColor: secondaryTextColor,
                          borderColor: borderColor,
                          suffixIcon: IconButton(
                            icon: Icon(
                              state.createPasswordObscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: secondaryTextColor,
                            ),
                            onPressed: () => context.read<AuthCubit>().toggleCreatePasswordVisibility(),
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
                          hintText: 'Confirm new password',
                          obscureText: state.createPasswordConfirmObscure,
                          focusNode: _confirmPasswordFocusNode,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: () => _updatePassword(context),
                          isDark: isDark,
                          surfaceColor: surfaceColor,
                          secondaryTextColor: secondaryTextColor,
                          borderColor: borderColor,
                          suffixIcon: IconButton(
                            icon: Icon(
                              state.createPasswordConfirmObscure
                                  ? Icons.visibility_outlined
                                  : Icons.visibility_off_outlined,
                              color: secondaryTextColor,
                            ),
                            onPressed: () => context.read<AuthCubit>().toggleCreatePasswordConfirmVisibility(),
                          ),
                          validator: (value) {
                            if (value == null || value.isEmpty) return 'Please confirm your password';
                            if (value != _passwordController.text) return 'Passwords do not match';
                            return null;
                          },
                        ),
                        const SizedBox(height: 12),
                        _PasswordRequirements(password: _passwordController.text, isDark: isDark),
                        const SizedBox(height: 32),
                        SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: state.isLoading ? null : () => _updatePassword(context),
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
                                    'Reset Password',
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                          fontWeight: FontWeight.w600,
                                          color: textColor,
                                        ),
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

class _PasswordRequirements extends StatefulWidget {
  final String password;
  final bool isDark;

  const _PasswordRequirements({required this.password, required this.isDark});

  @override
  State<_PasswordRequirements> createState() => _PasswordRequirementsState();
}

class _PasswordRequirementsState extends State<_PasswordRequirements> {
  @override
  Widget build(BuildContext context) {
    final hasMinLength = widget.password.length >= 8;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _RequirementRow(
          label: 'At least 8 characters',
          isMet: hasMinLength,
          isDark: widget.isDark,
        ),
      ],
    );
  }
}

class _RequirementRow extends StatelessWidget {
  final String label;
  final bool isMet;
  final bool isDark;

  const _RequirementRow({required this.label, required this.isMet, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;

    return Row(
      children: [
        Icon(
          isMet ? Icons.check_circle : Icons.circle_outlined,
          size: 16,
          color: isMet ? Colors.green : secondaryTextColor,
        ),
        const SizedBox(width: 8),
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isMet ? Colors.green : secondaryTextColor,
              ),
        ),
      ],
    );
  }
}
