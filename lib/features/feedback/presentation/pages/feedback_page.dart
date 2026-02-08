import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/features/feedback/presentation/pages/share_experience_page.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';
import 'package:vibestream/features/recommendations/data/recommendation_service.dart';

class FeedbackPage extends StatefulWidget {
  const FeedbackPage({super.key});

  @override
  State<FeedbackPage> createState() => _FeedbackPageState();
}

class _FeedbackPageState extends State<FeedbackPage> {
  final ProfileService _profileService = ProfileService();
  
  bool _isLoading = true;
  bool _isRefreshingInBackground = false;
  ({String titleId, String sessionId})? _latestTitle;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    RecommendationService.addLatestRecommendationListener(_onCacheInvalidated);
    _loadLatestRecommendation();
  }

  @override
  void dispose() {
    RecommendationService.removeLatestRecommendationListener(_onCacheInvalidated);
    super.dispose();
  }

  void _onCacheInvalidated() {
    // When cache is invalidated (new session created), refresh the data
    if (mounted) {
      _loadLatestRecommendation(forceRefresh: true);
    }
  }

  Future<void> _loadLatestRecommendation({bool forceRefresh = false}) async {
    final profileId = _profileService.selectedProfileId;
    
    if (profileId == null) {
      debugPrint('FeedbackPage: No profile selected');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _latestTitle = null;
        });
      }
      return;
    }

    // Check for cached data first (stale-while-revalidate pattern)
    if (!forceRefresh && RecommendationService.hasLatestRecommendationCache(profileId)) {
      final cached = RecommendationService.getCachedLatestRecommendation(profileId);
      debugPrint('FeedbackPage: Using cached data, titleId: ${cached?.titleId ?? 'none'}');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _latestTitle = cached;
          _errorMessage = null;
        });
      }

      // If cache is stale, refresh in background
      if (RecommendationService.isLatestRecommendationCacheStale(profileId)) {
        debugPrint('FeedbackPage: Cache is stale, refreshing in background');
        _refreshInBackground(profileId);
      }
      return;
    }

    try {
      final latestTitle = await RecommendationService.getLatestRecommendedTitle(
        profileId,
        forceRefresh: forceRefresh,
      );
      debugPrint('FeedbackPage: Loaded latest title: ${latestTitle?.titleId ?? 'none'}');
      
      if (mounted) {
        setState(() {
          _isLoading = false;
          _latestTitle = latestTitle;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('FeedbackPage: Error loading recommendation: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to load recommendations';
        });
      }
    }
  }

  Future<void> _refreshInBackground(String profileId) async {
    if (_isRefreshingInBackground) return;
    _isRefreshingInBackground = true;

    try {
      final latestTitle = await RecommendationService.getLatestRecommendedTitle(
        profileId,
        forceRefresh: true,
      );
      
      // Only update UI if the data has changed
      if (mounted && latestTitle?.titleId != _latestTitle?.titleId) {
        debugPrint('FeedbackPage: Background refresh found new data');
        setState(() {
          _latestTitle = latestTitle;
          _errorMessage = null;
        });
      }
    } catch (e) {
      debugPrint('FeedbackPage: Background refresh failed: $e');
      // Don't update error state during background refresh
    } finally {
      _isRefreshingInBackground = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return _FeedbackLoadingState(isDark: isDark);
    }

    if (_latestTitle == null || _errorMessage != null) {
      return _FeedbackEmptyState(
        isDark: isDark,
        errorMessage: _errorMessage,
        onTakeQuiz: () => context.push(AppRoutes.moodQuiz),
        onRefresh: () {
          setState(() {
            _isLoading = true;
            _errorMessage = null;
          });
          _loadLatestRecommendation(forceRefresh: true);
        },
      );
    }

    // Navigate to share experience with the loaded title
    return ShareExperiencePage(
      titleId: _latestTitle!.titleId,
      sessionId: _latestTitle!.sessionId,
      showBackButton: false,
    );
  }
}

class _FeedbackLoadingState extends StatelessWidget {
  final bool isDark;
  
  const _FeedbackLoadingState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            _FeedbackAppBar(isDark: isDark),
            const Expanded(
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackEmptyState extends StatelessWidget {
  final bool isDark;
  final String? errorMessage;
  final VoidCallback onTakeQuiz;
  final VoidCallback onRefresh;

  const _FeedbackEmptyState({
    required this.isDark,
    this.errorMessage,
    required this.onTakeQuiz,
    required this.onRefresh,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Column(
          children: [
            _FeedbackAppBar(isDark: isDark),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AppColors.primary.withValues(alpha: 0.2),
                            AppColors.primaryDark.withValues(alpha: 0.2),
                          ],
                        ),
                      ),
                      child: Icon(
                        Icons.rate_review_outlined,
                        size: 48,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                    ),
                    const SizedBox(height: 32),
                    Text(
                      errorMessage != null 
                          ? 'Something went wrong'
                          : 'No recommendations yet!',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: isDark ? AppColors.darkText : AppColors.lightText,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      errorMessage ?? 
                          'Take a mood quiz first to get personalized movie & TV suggestions. Then come back here to share your feedback!',
                      style: TextStyle(
                        fontSize: 15,
                        height: 1.5,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 40),
                    _PrimaryButton(
                      isDark: isDark,
                      label: errorMessage != null ? 'Try Again' : 'Take Mood Quiz',
                      icon: errorMessage != null ? Icons.refresh : Icons.emoji_emotions_rounded,
                      onTap: errorMessage != null ? onRefresh : onTakeQuiz,
                    ),
                    if (errorMessage == null) ...[
                      const SizedBox(height: 16),
                      _SecondaryButton(
                        isDark: isDark,
                        label: 'Refresh',
                        icon: Icons.refresh,
                        onTap: onRefresh,
                      ),
                    ],
                  ],
                ),
              ),
            ),
            // Add bottom padding for nav bar
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }
}

class _FeedbackAppBar extends StatelessWidget {
  final bool isDark;

  const _FeedbackAppBar({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Share Your Experience',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final bool isDark;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.isDark,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(30),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isDark ? Colors.black : Colors.white),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? Colors.black : Colors.white,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SecondaryButton extends StatelessWidget {
  final bool isDark;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SecondaryButton({
    required this.isDark,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.15),
            width: 1,
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 20, color: isDark ? AppColors.darkText : AppColors.lightText),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
