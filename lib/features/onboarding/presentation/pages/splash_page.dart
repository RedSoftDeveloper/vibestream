import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';
import 'package:vibestream/supabase/supabase_config.dart';

/// Key used to track pending OAuth deletion flow
const String kPendingDeletionKey = 'pending_oauth_deletion';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;
  StreamSubscription? _authSubscription;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5, curve: Curves.easeOut)),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _controller, curve: const Interval(0, 0.5, curve: Curves.easeOut)),
    );

    _controller.forward();

    // Listen for auth state changes (handles OAuth callback)
    _authSubscription = SupabaseConfig.auth.onAuthStateChange.listen((data) async {
      final event = data.event;
      debugPrint('SplashPage: Auth state changed - $event');
      
      if (event == AuthChangeEvent.signedIn && mounted) {
        await _handleOAuthSignIn();
      }
    });

    // Initial auth check after animation
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _checkAuthAndNavigate();
      }
    });
  }

  /// Handle OAuth sign-in callback
  Future<void> _handleOAuthSignIn() async {
    debugPrint('SplashPage: Handling OAuth sign-in...');
    
    // Check if we're in the middle of a deletion flow
    final prefs = await SharedPreferences.getInstance();
    final pendingDeletion = prefs.getBool(kPendingDeletionKey) ?? false;
    
    if (pendingDeletion) {
      debugPrint('SplashPage: Pending deletion detected, navigating to delete account page');
      // Navigate to delete account page to handle the OAuth callback
      context.go(AppRoutes.deleteAccount);
      return;
    }
    
    // Normal OAuth sign-in flow - check if user needs onboarding
    await _navigateBasedOnOnboardingStatus();
  }

  /// Navigate based on whether user has completed onboarding
  Future<void> _navigateBasedOnOnboardingStatus() async {
    try {
      final profileService = ProfileService();
      final hasCompletedOnboarding = await profileService.hasCompletedOnboarding();
      
      if (!mounted) return;
      
      if (hasCompletedOnboarding) {
        debugPrint('SplashPage: User has completed onboarding, navigating to home');
        context.go(AppRoutes.home);
      } else {
        debugPrint('SplashPage: User needs onboarding, navigating to onboarding');
        context.go(AppRoutes.onboarding);
      }
    } catch (e) {
      debugPrint('SplashPage: Error checking onboarding status: $e');
      // Default to onboarding if we can't determine status
      if (mounted) context.go(AppRoutes.onboarding);
    }
  }

  void _checkAuthAndNavigate() async {
    final user = SupabaseConfig.auth.currentUser;
    
    if (user != null) {
      // User is logged in - check if email is verified
      if (user.emailConfirmedAt != null) {
        debugPrint('SplashPage: User authenticated, checking onboarding status...');
        await _navigateBasedOnOnboardingStatus();
      } else {
        // Email not verified - go to login so they can complete verification
        debugPrint('SplashPage: User exists but email not verified');
        context.go(AppRoutes.login);
      }
    } else {
      debugPrint('SplashPage: No user, navigating to login');
      context.go(AppRoutes.login);
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      body: Center(
        child: AnimatedBuilder(
          animation: _controller,
          builder: (context, child) => Opacity(
            opacity: _fadeAnimation.value,
            child: Transform.scale(
              scale: _scaleAnimation.value,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(
                        color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.08),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Icon(
                        Icons.play_circle_filled,
                        size: 56,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'VibeStream',
                    style: theme.textTheme.headlineLarge?.copyWith(
                      color: theme.colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Find your vibe',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
