import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/utils/snackbar_utils.dart';
import 'package:vibestream/features/feedback/data/app_feedback_service.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';

class AppFeedbackPage extends StatefulWidget {
  const AppFeedbackPage({super.key});

  @override
  State<AppFeedbackPage> createState() => _AppFeedbackPageState();
}

class _AppFeedbackPageState extends State<AppFeedbackPage> {
  final TextEditingController _feedbackController = TextEditingController();
  bool _isSubmitting = false;
  static const int _maxLength = 400;

  @override
  void dispose() {
    _feedbackController.dispose();
    super.dispose();
  }

  Future<void> _submitFeedback() async {
    final text = _feedbackController.text.trim();
    
    if (text.isEmpty) {
      SnackbarUtils.showWarning(context, 'Please enter your feedback');
      return;
    }

    final profileId = ProfileService().selectedProfileId;
    if (profileId == null) {
      SnackbarUtils.showWarning(context, 'No profile selected. Please select a profile.');
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final success = await AppFeedbackService.submitFeedback(
        text,
        profileId: profileId,
      );
      
      if (!mounted) return;
      
      if (success) {
        SnackbarUtils.showSuccess(context, 'Thank you for your feedback!');
        context.pop();
      } else {
        SnackbarUtils.showError(context, 'Failed to submit feedback. Please try again.');
      }
    } finally {
      if (mounted) {
        setState(() => _isSubmitting = false);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final charCount = _feedbackController.text.length;
    final isOverLimit = charCount > _maxLength;

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          child: Column(
            children: [
              _AppFeedbackAppBar(isDark: isDark, onBack: () => context.pop()),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 16),
                    _HeaderSection(isDark: isDark),
                    const SizedBox(height: 24),
                    _FeedbackInputField(
                      isDark: isDark,
                      controller: _feedbackController,
                      maxLength: _maxLength,
                      onChanged: (_) => setState(() {}),
                    ),
                    const SizedBox(height: 8),
                    _CharacterCounter(
                      isDark: isDark,
                      current: charCount,
                      max: _maxLength,
                      isOverLimit: isOverLimit,
                    ),
                    const SizedBox(height: 32),
                    _SubmitButton(
                      isDark: isDark,
                      isEnabled: !isOverLimit && charCount > 0 && !_isSubmitting,
                      isLoading: _isSubmitting,
                      onTap: _submitFeedback,
                    ),
                    const SizedBox(height: 24),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AppFeedbackAppBar extends StatelessWidget {
  final bool isDark;
  final VoidCallback onBack;

  const _AppFeedbackAppBar({required this.isDark, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: Icon(
              Icons.chevron_left_rounded,
              size: 28,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          Expanded(
            child: Text(
              'Give Feedback',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
          const SizedBox(width: 48),
        ],
      ),
    );
  }
}

class _HeaderSection extends StatelessWidget {
  final bool isDark;

  const _HeaderSection({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 64,
          height: 64,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.accent.withValues(alpha: 0.15),
                AppColors.accentLight.withValues(alpha: 0.15),
              ],
            ),
          ),
          child: Icon(
            Icons.chat_bubble_outline_rounded,
            size: 28,
            color: AppColors.accent,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          'We\'d love to hear from you',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Share your thoughts, suggestions, or report any issues you\'ve encountered. Your feedback helps us improve VibeStream for everyone.',
          style: TextStyle(
            fontSize: 15,
            height: 1.5,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
    );
  }
}

class _FeedbackInputField extends StatelessWidget {
  final bool isDark;
  final TextEditingController controller;
  final int maxLength;
  final ValueChanged<String> onChanged;

  const _FeedbackInputField({
    required this.isDark,
    required this.controller,
    required this.maxLength,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.05)
            : Colors.black.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark
              ? Colors.white.withValues(alpha: 0.1)
              : Colors.black.withValues(alpha: 0.08),
          width: 1,
        ),
      ),
      child: TextField(
        controller: controller,
        maxLines: 8,
        maxLength: maxLength + 50, // Allow slight over-type but show warning
        textInputAction: TextInputAction.done,
        buildCounter: (context, {required currentLength, required isFocused, maxLength}) => null,
        onChanged: onChanged,
        style: TextStyle(
          fontSize: 15,
          height: 1.5,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
        decoration: InputDecoration(
          hintText: 'Tell us what you think about VibeStream...',
          hintStyle: TextStyle(
            fontSize: 15,
            color: isDark
                ? AppColors.darkTextSecondary.withValues(alpha: 0.6)
                : AppColors.lightTextSecondary.withValues(alpha: 0.6),
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.all(20),
        ),
      ),
    );
  }
}

class _CharacterCounter extends StatelessWidget {
  final bool isDark;
  final int current;
  final int max;
  final bool isOverLimit;

  const _CharacterCounter({
    required this.isDark,
    required this.current,
    required this.max,
    required this.isOverLimit,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: Text(
        '$current / $max',
        style: TextStyle(
          fontSize: 13,
          fontWeight: isOverLimit ? FontWeight.w600 : FontWeight.w400,
          color: isOverLimit 
              ? Colors.red[400]
              : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary),
        ),
      ),
    );
  }
}

class _SubmitButton extends StatelessWidget {
  final bool isDark;
  final bool isEnabled;
  final bool isLoading;
  final VoidCallback onTap;

  const _SubmitButton({
    required this.isDark,
    required this.isEnabled,
    required this.isLoading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: isEnabled ? onTap : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isEnabled
              ? (isDark ? Colors.white : const Color(0xFF1A1A1A))
              : (isDark 
                  ? Colors.white.withValues(alpha: 0.2) 
                  : const Color(0xFF1A1A1A).withValues(alpha: 0.3)),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (isLoading)
              SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation(isDark ? Colors.black : Colors.white),
                ),
              )
            else
              Icon(
                Icons.send_rounded,
                size: 18,
                color: isEnabled
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark 
                        ? Colors.black.withValues(alpha: 0.4) 
                        : Colors.white.withValues(alpha: 0.5)),
              ),
            const SizedBox(width: 10),
            Text(
              isLoading ? 'Submitting...' : 'Submit Feedback',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isEnabled
                    ? (isDark ? Colors.black : Colors.white)
                    : (isDark 
                        ? Colors.black.withValues(alpha: 0.4) 
                        : Colors.white.withValues(alpha: 0.5)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FooterNote extends StatelessWidget {
  final bool isDark;

  const _FooterNote({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Your feedback is anonymous and helps us\nmake VibeStream better for everyone.',
        textAlign: TextAlign.center,
        style: TextStyle(
          fontSize: 12,
          height: 1.5,
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        ),
      ),
    );
  }
}
