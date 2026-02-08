import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/utils/snackbar_utils.dart';
import 'package:vibestream/features/auth/data/auth_service.dart';
import 'package:vibestream/features/auth/presentation/cubits/auth_cubit.dart';
import 'package:vibestream/features/auth/presentation/cubits/auth_state.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';

class OtpVerificationPage extends StatefulWidget {
  final String email;
  final AuthFlowType flowType;

  const OtpVerificationPage({
    super.key,
    required this.email,
    required this.flowType,
  });

  @override
  State<OtpVerificationPage> createState() => _OtpVerificationPageState();
}

class _OtpVerificationPageState extends State<OtpVerificationPage> {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }

  String get _otpCode => _controllers.map((c) => c.text).join();

  void _onOtpChanged(BuildContext context, int index, String value) {
    if (value.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }
    if (_otpCode.length == 6) {
      _verifyOtp(context);
    }
  }

  void _onKeyPressed(int index, RawKeyEvent event) {
    if (event is RawKeyDownEvent && event.logicalKey == LogicalKeyboardKey.backspace) {
      if (_controllers[index].text.isEmpty && index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
  }

  void _verifyOtp(BuildContext context) {
    if (_otpCode.length != 6) {
      SnackbarUtils.showWarning(context, 'Please enter the complete 6-digit code');
      return;
    }
    context.read<AuthCubit>().verifyOtp(widget.email, _otpCode, widget.flowType);
  }

  void _clearOtp() {
    for (final controller in _controllers) {
      controller.clear();
    }
    _focusNodes[0].requestFocus();
  }

  Future<void> _navigateOnSuccess(BuildContext context) async {
    switch (widget.flowType) {
      case AuthFlowType.signIn:
        // Check if user has completed onboarding
        try {
          final profileService = ProfileService();
          final hasCompletedOnboarding = await profileService.hasCompletedOnboarding();
          if (!mounted) return;
          if (hasCompletedOnboarding) {
            debugPrint('OtpVerificationPage: User has completed onboarding, navigating to home');
            context.go(AppRoutes.home);
          } else {
            debugPrint('OtpVerificationPage: User needs onboarding, navigating to onboarding');
            context.go(AppRoutes.onboarding);
          }
        } catch (e) {
          debugPrint('OtpVerificationPage: Error checking onboarding status: $e');
          if (mounted) context.go(AppRoutes.home);
        }
        break;
      case AuthFlowType.signUp:
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) context.go(AppRoutes.onboarding);
        break;
      case AuthFlowType.resetPassword:
        context.pushReplacement(AppRoutes.createNewPassword);
        break;
      case AuthFlowType.emailChange:
        SnackbarUtils.showSuccess(context, 'Email updated successfully');
        context.go(AppRoutes.myProfile);
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => AuthCubit()..startResendCooldown(),
      child: BlocConsumer<AuthCubit, AuthState>(
        listener: (context, state) {
          if (state.isFailure && state.errorMessage != null) {
            SnackbarUtils.showError(context, state.errorMessage!);
            _clearOtp();
            context.read<AuthCubit>().clearError();
          } else if (state.isSuccess) {
            _navigateOnSuccess(context);
          }
        },
        builder: (context, state) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final backgroundColor = isDark ? AppColors.darkBackground : AppColors.lightBackground;
          final textColor = isDark ? AppColors.darkText : AppColors.lightText;
          final secondaryTextColor = isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary;
          final surfaceColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant;
          final borderColor = isDark ? AppColors.darkBorder : AppColors.lightBorder;

          return GestureDetector(
            onTap: () => FocusScope.of(context).unfocus(),
            child: Scaffold(
              backgroundColor: backgroundColor,
              body: SafeArea(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
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
                                'Verification',
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
                        child: Icon(Icons.mail_outline_rounded, size: 40, color: AppColors.accent),
                      ),
                      const SizedBox(height: 24),
                      Text(
                        'Enter Verification Code',
                        style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: textColor,
                            ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "We've sent a 6-digit code to ${widget.email}",
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(color: secondaryTextColor),
                      ),
                      const SizedBox(height: 40),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: List.generate(
                          6,
                          (index) => _OtpField(
                            controller: _controllers[index],
                            focusNode: _focusNodes[index],
                            isDark: isDark,
                            surfaceColor: surfaceColor,
                            textColor: textColor,
                            borderColor: borderColor,
                            onChanged: (value) => _onOtpChanged(context, index, value),
                            onKeyEvent: (event) => _onKeyPressed(index, event),
                          ),
                        ),
                      ),
                      const SizedBox(height: 32),
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: state.isLoading ? null : () => _verifyOtp(context),
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
                                  'Verify',
                                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w600,
                                        color: textColor,
                                      ),
                                ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      Center(
                        child: state.isResending
                            ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(strokeWidth: 2, color: secondaryTextColor),
                              )
                            : GestureDetector(
                                onTap: state.resendCooldown > 0
                                    ? null
                                    : () => context.read<AuthCubit>().resendOtp(widget.email, widget.flowType),
                                child: RichText(
                                  text: TextSpan(
                                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: secondaryTextColor),
                                    children: [
                                      const TextSpan(text: "Didn't receive the code? "),
                                      TextSpan(
                                        text: state.resendCooldown > 0
                                            ? 'Resend in ${state.resendCooldown}s'
                                            : 'Resend',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: state.resendCooldown > 0 ? secondaryTextColor : textColor,
                                        ),
                                      ),
                                    ],
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
      onTap: () => context.canPop() ? context.pop() : context.go(AppRoutes.login),
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(color: backgroundColor, shape: BoxShape.circle),
        child: Icon(Icons.chevron_left, color: iconColor, size: 28),
      ),
    );
  }
}

class _OtpField extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool isDark;
  final Color surfaceColor;
  final Color textColor;
  final Color borderColor;
  final ValueChanged<String> onChanged;
  final ValueChanged<RawKeyEvent> onKeyEvent;

  const _OtpField({
    required this.controller,
    required this.focusNode,
    required this.isDark,
    required this.surfaceColor,
    required this.textColor,
    required this.borderColor,
    required this.onChanged,
    required this.onKeyEvent,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 48,
      height: 56,
      child: RawKeyboardListener(
        focusNode: FocusNode(),
        onKey: onKeyEvent,
        child: TextField(
          controller: controller,
          focusNode: focusNode,
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          textInputAction: TextInputAction.next,
          maxLength: 1,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700, color: textColor),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          onChanged: onChanged,
          decoration: InputDecoration(
            counterText: '',
            filled: true,
            fillColor: surfaceColor,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: AppColors.accent, width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),
      ),
    );
  }
}
