import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/utils/snackbar_utils.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';
import 'package:vibestream/features/profiles/presentation/widgets/profile_dropdown.dart';
import 'package:vibestream/features/recommendations/data/recommendation_service.dart';
import 'package:vibestream/features/recommendations/data/interaction_service.dart';
import 'package:vibestream/core/services/home_refresh_service.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final ProfileService _profileService = ProfileService();
  final HomeRefreshService _homeRefreshService = HomeRefreshService();
  bool _showProfileDropdown = false;
  final GlobalKey _profileIconKey = GlobalKey();
  OverlayEntry? _overlayEntry;
  String? _lastProfileId;
  DateTime? _lastLoadTime;

  // Data state
  List<RecentVibe> _recentVibes = [];
  List<TopTitle> _topTitles = [];
  bool _isLoadingVibes = true;
  bool _isLoadingTopTitles = true;
  Set<String> _titlesWithFeedback = {};
  bool _initialCacheChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    
    // Check cache SYNCHRONOUSLY before first build to avoid shimmer flash
    _checkCacheImmediately();
    
    _profileService.init().then((_) => _initializeData());
    _profileService.addListener(_onProfilesChanged);
    _homeRefreshService.addListener(_onRefreshRequested);
    RecommendationService.addHomeDataListener(_onHomeDataCacheInvalidated);
  }
  
  /// Synchronously check cache before the first build to avoid shimmer flash
  void _checkCacheImmediately() {
    final profileId = _profileService.selectedProfileId;
    if (profileId == null) return;
    
    final cachedVibes = RecommendationService.getCachedRecentVibes(profileId);
    final cachedTopTitles = RecommendationService.getCachedTopTitles(profileId);
    final cachedFeedbackStatus = InteractionService.getCachedHomeFeedbackStatus(profileId);
    
    if (cachedVibes != null) {
      _recentVibes = cachedVibes;
      _isLoadingVibes = false;
      debugPrint('HomePage: Loaded ${cachedVibes.length} vibes from cache synchronously');
    }
    if (cachedTopTitles != null) {
      _topTitles = cachedTopTitles;
      _isLoadingTopTitles = false;
      debugPrint('HomePage: Loaded ${cachedTopTitles.length} top titles from cache synchronously');
    }
    if (cachedFeedbackStatus != null) {
      _titlesWithFeedback = cachedFeedbackStatus;
      debugPrint('HomePage: Loaded ${cachedFeedbackStatus.length} feedback status from cache synchronously');
    }
    
    _initialCacheChecked = cachedVibes != null || cachedTopTitles != null;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profileService.removeListener(_onProfilesChanged);
    _homeRefreshService.removeListener(_onRefreshRequested);
    RecommendationService.removeHomeDataListener(_onHomeDataCacheInvalidated);
    _removeOverlay();
    super.dispose();
  }

  void _onHomeDataCacheInvalidated() {
    debugPrint('HomePage: Home data cache invalidated, refreshing...');
    _loadDataWithForceRefresh();
  }

  void _onRefreshRequested() {
    debugPrint('HomePage: Received refresh request from HomeRefreshService');
    _loadDataWithForceRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Refresh when app comes back to foreground
    if (state == AppLifecycleState.resumed) {
      _refreshIfNeeded();
    }
  }

  /// Called when the page becomes visible again (e.g., after pop from quiz/recommendations)
  void refreshData() {
    debugPrint('HomePage: refreshData called');
    _loadDataWithForceRefresh();
  }

  /// Stale threshold: 5 minutes (300 seconds)
  /// Data is considered stale after this duration and will be refreshed silently on app resume.
  static const int _staleThresholdSeconds = 300;

  /// Refresh data if stale (more than 5 minutes old)
  void _refreshIfNeeded() {
    if (_lastLoadTime == null) return;
    final timeSinceLastLoad = DateTime.now().difference(_lastLoadTime!);
    if (timeSinceLastLoad.inSeconds > _staleThresholdSeconds) {
      debugPrint('HomePage: Data is stale (${timeSinceLastLoad.inSeconds}s > ${_staleThresholdSeconds}s threshold), refreshing silently...');
      _loadDataSilently();
    }
  }

  void _onProfilesChanged() {
    if (mounted) {
      // Reload data if profile changed
      final currentProfileId = _profileService.selectedProfileId;
      if (currentProfileId != _lastProfileId) {
        // Reset flag and check cache for new profile synchronously
        _initialCacheChecked = false;
        _checkCacheImmediately();
        _initializeData();
      }
      setState(() {});
    }
  }

  /// Initialize data: show cached data immediately if available, then refresh in background if stale
  Future<void> _initializeData() async {
    final profileId = _profileService.selectedProfileId;
    if (profileId == null) return;

    _lastProfileId = profileId;
    _lastLoadTime = DateTime.now();

    // If cache was already checked synchronously in initState, just handle staleness/feedback
    if (_initialCacheChecked) {
      debugPrint('HomePage: Using cache checked in initState');
      
      // Check if cache is stale and needs background refresh
      final vibesStale = RecommendationService.isRecentVibesCacheStale(profileId);
      final topTitlesStale = RecommendationService.isTopTitlesCacheStale(profileId);
      
      if (vibesStale || topTitlesStale) {
        debugPrint('HomePage: Cache is stale, refreshing in background');
        _loadDataSilently();
      } else {
        // Still need to check feedback for cached vibes
        _loadFeedbackStatus(_recentVibes);
      }
      return;
    }

    // Check for cached data (fallback if not checked synchronously)
    final cachedVibes = RecommendationService.getCachedRecentVibes(profileId);
    final cachedTopTitles = RecommendationService.getCachedTopTitles(profileId);
    final hasCache = cachedVibes != null || cachedTopTitles != null;

    if (hasCache) {
      // Show cached data immediately without shimmer
      debugPrint('HomePage: Showing cached data immediately');
      setState(() {
        if (cachedVibes != null) {
          _recentVibes = cachedVibes;
          _isLoadingVibes = false;
        }
        if (cachedTopTitles != null) {
          _topTitles = cachedTopTitles;
          _isLoadingTopTitles = false;
        }
      });

      // Check if cache is stale and needs background refresh
      final vibesStale = RecommendationService.isRecentVibesCacheStale(profileId);
      final topTitlesStale = RecommendationService.isTopTitlesCacheStale(profileId);
      
      if (vibesStale || topTitlesStale) {
        debugPrint('HomePage: Cache is stale, refreshing in background');
        _loadDataSilently();
      } else {
        // Still need to check feedback for cached vibes
        _loadFeedbackStatus(cachedVibes ?? []);
      }
    } else {
      // No cache - show shimmer and load fresh data
      debugPrint('HomePage: No cache, loading fresh data');
      _loadData();
    }
  }

  /// Load feedback status for vibes without fetching vibes again
  Future<void> _loadFeedbackStatus(List<RecentVibe> vibes) async {
    final profileId = _profileService.selectedProfileId;
    if (profileId == null) return;
    
    // If we have a valid non-stale cache, skip the fetch
    if (InteractionService.hasHomeFeedbackCache(profileId) && 
        !InteractionService.isHomeFeedbackCacheStale(profileId)) {
      debugPrint('HomePage: Using cached feedback status (not stale)');
      return;
    }

    final feedbackSet = <String>{};
    final interactionService = InteractionService();
    for (final vibe in vibes) {
      final hasFeedback = await interactionService.hasTitleFeedback(
        profileId: profileId,
        titleId: vibe.titleId,
      );
      if (hasFeedback) {
        feedbackSet.add(vibe.titleId);
      }
    }
    
    // Update the cache
    InteractionService.updateHomeFeedbackCache(profileId, feedbackSet);

    if (mounted) {
      setState(() {
        _titlesWithFeedback = feedbackSet;
      });
    }
  }

  /// Load data with force refresh (after cache invalidation)
  Future<void> _loadDataWithForceRefresh() async {
    final profileId = _profileService.selectedProfileId;
    if (profileId == null) return;

    _lastProfileId = profileId;
    _lastLoadTime = DateTime.now();

    // Load data with force refresh (bypass cache)
    final results = await Future.wait([
      RecommendationService.getRecentVibes(profileId, forceRefresh: true),
      RecommendationService.getTopTitles(profileId, forceRefresh: true),
    ]);

    final recentVibes = results[0] as List<RecentVibe>;
    
    // Check which titles already have feedback
    final feedbackSet = <String>{};
    final interactionService = InteractionService();
    for (final vibe in recentVibes) {
      final hasFeedback = await interactionService.hasTitleFeedback(
        profileId: profileId,
        titleId: vibe.titleId,
      );
      if (hasFeedback) {
        feedbackSet.add(vibe.titleId);
      }
    }
    
    // Update the cache
    InteractionService.updateHomeFeedbackCache(profileId, feedbackSet);

    if (mounted) {
      setState(() {
        _recentVibes = recentVibes;
        _topTitles = results[1] as List<TopTitle>;
        _titlesWithFeedback = feedbackSet;
        _isLoadingVibes = false;
        _isLoadingTopTitles = false;
      });
      debugPrint('HomePage: Force refresh complete - ${_recentVibes.length} vibes and ${_topTitles.length} top titles');
    }
  }

  Future<void> _loadData() async {
    final profileId = _profileService.selectedProfileId;
    if (profileId == null) return;

    _lastProfileId = profileId;
    _lastLoadTime = DateTime.now();
    
    setState(() {
      _isLoadingVibes = true;
      _isLoadingTopTitles = true;
    });

    // Load data in parallel
    final results = await Future.wait([
      RecommendationService.getRecentVibes(profileId, forceRefresh: true),
      RecommendationService.getTopTitles(profileId, forceRefresh: true),
    ]);

    final recentVibes = results[0] as List<RecentVibe>;
    
    // Check which titles already have feedback
    final feedbackSet = <String>{};
    final interactionService = InteractionService();
    for (final vibe in recentVibes) {
      final hasFeedback = await interactionService.hasTitleFeedback(
        profileId: profileId,
        titleId: vibe.titleId,
      );
      if (hasFeedback) {
        feedbackSet.add(vibe.titleId);
      }
    }
    
    // Update the cache
    InteractionService.updateHomeFeedbackCache(profileId, feedbackSet);

    if (mounted) {
      setState(() {
        _recentVibes = recentVibes;
        _topTitles = results[1] as List<TopTitle>;
        _titlesWithFeedback = feedbackSet;
        _isLoadingVibes = false;
        _isLoadingTopTitles = false;
      });
      debugPrint('HomePage: Loaded ${_recentVibes.length} vibes and ${_topTitles.length} top titles, ${_titlesWithFeedback.length} have feedback');
    }
  }

  /// Silent refresh: Shows cached data first, updates in background without loading spinners.
  /// This provides a smoother UX for stale data refreshes.
  Future<void> _loadDataSilently() async {
    final profileId = _profileService.selectedProfileId;
    if (profileId == null) return;

    _lastProfileId = profileId;
    _lastLoadTime = DateTime.now();
    
    // Don't show loading states - keep existing data visible
    debugPrint('HomePage: Starting silent background refresh...');

    try {
      // Load data in parallel with force refresh to update cache
      final results = await Future.wait([
        RecommendationService.getRecentVibes(profileId, forceRefresh: true),
        RecommendationService.getTopTitles(profileId, forceRefresh: true),
      ]);

      final recentVibes = results[0] as List<RecentVibe>;
      
      // Check which titles already have feedback
      final feedbackSet = <String>{};
      final interactionService = InteractionService();
      for (final vibe in recentVibes) {
        final hasFeedback = await interactionService.hasTitleFeedback(
          profileId: profileId,
          titleId: vibe.titleId,
        );
        if (hasFeedback) {
          feedbackSet.add(vibe.titleId);
        }
      }
      
      // Update the cache
      InteractionService.updateHomeFeedbackCache(profileId, feedbackSet);

      if (mounted) {
        setState(() {
          _recentVibes = recentVibes;
          _topTitles = results[1] as List<TopTitle>;
          _titlesWithFeedback = feedbackSet;
        });
        debugPrint('HomePage: Silent refresh complete - ${_recentVibes.length} vibes and ${_topTitles.length} top titles');
      }
    } catch (e) {
      debugPrint('HomePage: Silent refresh failed: $e');
      // On silent refresh failure, just keep the cached data - don't show error
    }
  }

  void _toggleProfileDropdown() {
    if (_showProfileDropdown) {
      _removeOverlay();
    } else {
      _showOverlay();
    }
  }

  void _showOverlay() {
    final renderBox = _profileIconKey.currentContext?.findRenderObject() as RenderBox?;
    if (renderBox == null) return;

    final position = renderBox.localToGlobal(Offset.zero);
    final size = renderBox.size;

    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: position.dy + size.height + 8,
        left: 0,
        right: 0,
        bottom: 0,
        child: ProfileDropdown(
          profiles: _profileService.profiles,
          selectedProfileId: _profileService.selectedProfileId,
          onDismiss: _removeOverlay,
        ),
      ),
    );

    Overlay.of(context).insert(_overlayEntry!);
    setState(() => _showProfileDropdown = true);
  }

  void _removeOverlay() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    if (mounted) setState(() => _showProfileDropdown = false);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FeelingsHeader(
                isDark: isDark,
                profileIconKey: _profileIconKey,
                onProfileIconTap: _toggleProfileDropdown,
                selectedProfileName: _profileService.selectedProfile?.name,
              ),
              const SizedBox(height: 16),
              _PromoCard(isDark: isDark),
              const SizedBox(height: 24),
              _RecentVibesSection(
                isDark: isDark,
                vibes: _recentVibes,
                isLoading: _isLoadingVibes,
                titlesWithFeedback: _titlesWithFeedback,
              ),
              const SizedBox(height: 24),
              _QuickMatchSection(isDark: isDark),
              const SizedBox(height: 24),
              _TopMoviesSection(
                isDark: isDark,
                titles: _topTitles,
                isLoading: _isLoadingTopTitles,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeelingsHeader extends StatelessWidget {
  final bool isDark;
  final GlobalKey profileIconKey;
  final VoidCallback onProfileIconTap;
  final String? selectedProfileName;
  
  const _FeelingsHeader({
    required this.isDark,
    required this.profileIconKey,
    required this.onProfileIconTap,
    this.selectedProfileName,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Row(
        children: [
          GestureDetector(
            key: profileIconKey,
            onTap: onProfileIconTap,
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                border: Border.all(
                  color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
                  width: 1,
                ),
              ),
              child: Icon(
                Icons.person_outline,
                size: 22,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Welcome back 👋',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  selectedProfileName != null
                      ? 'Profile: $selectedProfileName'
                      : 'Last feelings: Reflective & Calm',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
          Visibility(
            visible: false,
            child: Stack(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                  ),
                  child: Icon(
                    Icons.notifications_outlined,
                    size: 22,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                Positioned(
                  top: 4,
                  right: 4,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: AppColors.accent,
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isDark ? AppColors.darkBackground : AppColors.lightBackground,
                        width: 2,
                      ),
                    ),
                    child: const Center(
                      child: Text(
                        '4',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
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
}

class _PromoCard extends StatelessWidget {
  final bool isDark;
  const _PromoCard({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: const Color(0xFFE8766C),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'What do you want to watch today?',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Take 30 seconds to find your next movie mood.',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white.withValues(alpha: 0.85),
              ),
            ),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: () => context.push(AppRoutes.moodQuiz),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text(
                      '✨',
                      style: TextStyle(fontSize: 16),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Find me something to watch',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.lightText : AppColors.lightText,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecentVibesSection extends StatelessWidget {
  final bool isDark;
  final List<RecentVibe> vibes;
  final bool isLoading;
  final Set<String> titlesWithFeedback;

  const _RecentVibesSection({
    required this.isDark,
    required this.vibes,
    required this.isLoading,
    required this.titlesWithFeedback,
  });

  String _getTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final diff = now.difference(dateTime);
    if (diff.inDays > 0) return '${diff.inDays}d ago';
    if (diff.inHours > 0) return '${diff.inHours}h ago';
    return 'Just now';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Your Recent Vibes',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              if (vibes.isNotEmpty)
                GestureDetector(
                  onTap: () => context.push(AppRoutes.allRecentVibes),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                    ),
                    child: Icon(
                      Icons.arrow_outward,
                      size: 18,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        if (isLoading)
          _RecentVibesShimmer(isDark: isDark)
        else if (vibes.isEmpty)
          _RecentVibesEmptyState(isDark: isDark)
        else
          SizedBox(
            height: 220,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: vibes.length,
              itemBuilder: (context, index) {
                final vibe = vibes[index];
                final hasFeedback = titlesWithFeedback.contains(vibe.titleId);
                return _RecentVibeCard(
                  isDark: isDark,
                  vibes: vibe.genres.take(2).toList(),
                  isTopMatch: vibe.rankIndex == 0,
                  timeAgo: _getTimeAgo(vibe.createdAt),
                  title: vibe.title,
                  titleId: vibe.titleId,
                  sessionId: vibe.sessionId,
                  posterUrl: vibe.posterUrl,
                  showFeedbackButton: !hasFeedback,
                  matchScore: vibe.matchScore,
                );
              },
            ),
          ),
      ],
    );
  }
}

class _RecentVibesShimmer extends StatelessWidget {
  final bool isDark;
  const _RecentVibesShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 220,
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: ListView.builder(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          itemCount: 2,
          itemBuilder: (context, index) => Container(
            width: 284,
            margin: const EdgeInsets.symmetric(horizontal: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  height: 12,
                  width: 80,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(height: 6),
                Container(
                  height: 14,
                  width: 180,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RecentVibesEmptyState extends StatelessWidget {
  final bool isDark;
  const _RecentVibesEmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.movie_filter_outlined,
            size: 48,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'No vibes yet!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Take the mood quiz to discover your first recommendations',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.push(AppRoutes.moodQuiz),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Start Mood Quiz',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RecentVibeCard extends StatelessWidget {
  final bool isDark;
  final List<String> vibes;
  final bool isTopMatch;
  final String timeAgo;
  final String title;
  final String titleId;
  final String? sessionId;
  final String? posterUrl;
  final bool showFeedbackButton;
  final int? matchScore;

  const _RecentVibeCard({
    required this.isDark,
    required this.vibes,
    required this.isTopMatch,
    required this.timeAgo,
    required this.title,
    required this.titleId,
    this.sessionId,
    this.posterUrl,
    required this.showFeedbackButton,
    this.matchScore,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.titleDetailsPath(titleId, matchScore: matchScore)),
      child: Container(
        width: 284,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Stack(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: posterUrl != null && posterUrl!.isNotEmpty
                        ? CachedNetworkImage(
                            imageUrl: posterUrl!,
                            width: double.infinity,
                            height: double.infinity,
                            fit: BoxFit.cover,
                            placeholder: (_, __) => Container(
                              decoration: BoxDecoration(
                                color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                            ),
                            errorWidget: (_, __, ___) => _buildPlaceholder(),
                          )
                        : _buildPlaceholder(),
                  ),
                  if (vibes.isNotEmpty)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: vibes.map((vibe) => _GlassChip(label: vibe)).toList(),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                if (isTopMatch) ...[
                  Text(
                    'Top match',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                  if (timeAgo.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    Text(
                      timeAgo,
                      style: TextStyle(
                        fontSize: 12,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ],
              ],
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 6),
            if (showFeedbackButton)
              _GlassPillButton(
                label: 'Leave a Feedback',
                isDark: isDark,
                onTap: () => context.push(
                  AppRoutes.shareExperiencePath(titleId, sessionId: sessionId),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildPlaceholder() => Container(
    width: double.infinity,
    height: double.infinity,
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient,
      borderRadius: BorderRadius.circular(12),
    ),
    child: const Center(
      child: Icon(Icons.movie, size: 40, color: Colors.white),
    ),
  );
}

class _GlassChip extends StatelessWidget {
  final String label;
  const _GlassChip({required this.label});

  @override
  Widget build(BuildContext context) {
    // Using semi-transparent container instead of BackdropFilter for better web performance
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(
          color: Colors.white.withValues(alpha: 0.40),
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _GlassPillButton extends StatelessWidget {
  final String label;
  final bool isDark;
  final VoidCallback? onTap;
  const _GlassPillButton({required this.label, required this.isDark, this.onTap});

  @override
  Widget build(BuildContext context) {
    // Using semi-transparent container instead of BackdropFilter for better web performance
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: isDark
              ? Colors.white.withValues(alpha: 0.15)
              : Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark
                ? Colors.white.withValues(alpha: 0.2)
                : Colors.black.withValues(alpha: 0.12),
            width: 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
      ),
    );
  }
}

class _QuickMatchSection extends StatefulWidget {
  final bool isDark;
  const _QuickMatchSection({required this.isDark});

  @override
  State<_QuickMatchSection> createState() => _QuickMatchSectionState();
}

class _QuickMatchSectionState extends State<_QuickMatchSection> {
  final ProfileService _profileService = ProfileService();
  bool _isLoading = false;
  String? _loadingTag;

  Future<void> _onQuickMatchTap(BuildContext context, String tag) async {
    if (_isLoading) return;

    final profileId = _profileService.selectedProfileId;
    if (profileId == null) {
      SnackbarUtils.showWarning(context, 'Please select a profile first');
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingTag = tag;
    });

    // Show full-screen loading overlay
    _showLoadingOverlay(context, tag);

    try {
      final session = await RecommendationService.createQuickMatchSession(
        profileId: profileId,
        quickMatchTag: tag.toLowerCase(),
      );

      // Remove loading overlay before navigating
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Dismiss dialog using root navigator
        
        // Request home page refresh after quick match completion
        HomeRefreshService().requestRefresh(reason: HomeRefreshReason.quickMatchCompleted);
        
        // Small delay to ensure dialog is fully dismissed
        await Future.delayed(const Duration(milliseconds: 100));
        
        if (context.mounted) {
          context.push(AppRoutes.recommendations, extra: {
            'session': session,
            'source': InteractionSource.quickMatch,
          });
        }
      }
    } catch (e) {
      debugPrint('QuickMatch error: $e');
      if (context.mounted) {
        Navigator.of(context, rootNavigator: true).pop(); // Remove loading overlay using root navigator
        SnackbarUtils.showError(
          context,
          'Failed to get recommendations. Please try again.',
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _loadingTag = null;
        });
      }
    }
  }

  void _showLoadingOverlay(BuildContext context, String tag) {
    showDialog(
      context: context,
      barrierDismissible: false,
      barrierColor: Colors.transparent,
      builder: (context) => _QuickMatchLoadingOverlay(
        isDark: widget.isDark,
        tag: tag,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Quick Match',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: widget.isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 44,
          child: ListView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            children: [
              _QuickMatchChip(
                icon: Icons.self_improvement,
                label: 'Relaxing',
                iconColor: AppColors.moodRelaxed,
                isDark: widget.isDark,
                onTap: () => _onQuickMatchTap(context, 'Relaxing'),
              ),
              _QuickMatchChip(
                icon: Icons.bolt,
                label: 'Adrenaline',
                iconColor: AppColors.moodExcited,
                isDark: widget.isDark,
                onTap: () => _onQuickMatchTap(context, 'Adrenaline'),
              ),
              _QuickMatchChip(
                icon: Icons.favorite,
                label: 'Feel-Good',
                iconColor: AppColors.moodRomantic,
                isDark: widget.isDark,
                onTap: () => _onQuickMatchTap(context, 'Feel-Good'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _QuickMatchLoadingOverlay extends StatelessWidget {
  final bool isDark;
  final String tag;

  const _QuickMatchLoadingOverlay({required this.isDark, required this.tag});

  IconData _getTagIcon() {
    switch (tag) {
      case 'Relaxing':
        return Icons.self_improvement;
      case 'Adrenaline':
        return Icons.bolt;
      case 'Feel-Good':
        return Icons.favorite;
      default:
        return Icons.movie_filter;
    }
  }

  Color _getTagColor() {
    switch (tag) {
      case 'Relaxing':
        return AppColors.moodRelaxed;
      case 'Adrenaline':
        return AppColors.moodExcited;
      case 'Feel-Good':
        return AppColors.moodRomantic;
      default:
        return AppColors.accent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: Stack(
        children: [
          // Semi-transparent background (replaced BackdropFilter for better web performance)
          Container(
            color: isDark
                ? Colors.black.withValues(alpha: 0.8)
                : Colors.white.withValues(alpha: 0.85),
          ),
          // Loading content
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Animated shimmer cards preview
                _ShimmerCardStack(isDark: isDark),
                const SizedBox(height: 32),
                // Icon with pulse animation
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.8, end: 1.0),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeInOut,
                  builder: (context, value, child) => Transform.scale(
                    scale: value,
                    child: Container(
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        color: _getTagColor().withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        _getTagIcon(),
                        size: 32,
                        color: _getTagColor(),
                      ),
                    ),
                  ),
                  onEnd: () {},
                ),
                const SizedBox(height: 20),
                Text(
                  'Finding $tag vibes...',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Curating perfect matches for you',
                  style: TextStyle(
                    fontSize: 14,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: 120,
                  child: LinearProgressIndicator(
                    backgroundColor: isDark
                        ? Colors.white.withValues(alpha: 0.1)
                        : Colors.black.withValues(alpha: 0.1),
                    valueColor: AlwaysStoppedAnimation(_getTagColor()),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ShimmerCardStack extends StatelessWidget {
  final bool isDark;
  const _ShimmerCardStack({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 160,
      width: 200,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Back card
          Positioned(
            top: 0,
            child: Transform.rotate(
              angle: -0.08,
              child: _buildShimmerCard(0.5),
            ),
          ),
          // Middle card
          Positioned(
            top: 8,
            child: Transform.rotate(
              angle: 0.04,
              child: _buildShimmerCard(0.7),
            ),
          ),
          // Front card
          Positioned(
            top: 16,
            child: _buildShimmerCard(1.0),
          ),
        ],
      ),
    );
  }

  Widget _buildShimmerCard(double opacity) {
    return Opacity(
      opacity: opacity,
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[600]! : Colors.grey[100]!,
        child: Container(
          width: 100,
          height: 140,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.1),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickMatchChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color iconColor;
  final bool isDark;
  final VoidCallback onTap;

  const _QuickMatchChip({
    required this.icon,
    required this.label,
    required this.iconColor,
    required this.isDark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    // Using semi-transparent container instead of BackdropFilter for better web performance
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isDark
                  ? Colors.white.withValues(alpha: 0.18)
                  : Colors.black.withValues(alpha: 0.12),
              width: 0.5,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TopMoviesSection extends StatelessWidget {
  final bool isDark;
  final List<TopTitle> titles;
  final bool isLoading;

  const _TopMoviesSection({
    required this.isDark,
    required this.titles,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            titles.isEmpty && !isLoading
                ? 'Your Top Picks'
                : 'Top ${titles.length > 3 ? 3 : titles.length} movies for you',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ),
        const SizedBox(height: 12),
        if (isLoading)
          _TopMoviesShimmer(isDark: isDark)
        else if (titles.isEmpty)
          _TopMoviesEmptyState(isDark: isDark)
        else
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: titles.take(3).map((title) {
                final index = titles.indexOf(title);
                return Padding(
                  padding: EdgeInsets.only(bottom: index < titles.length - 1 && index < 2 ? 12 : 0),
                  child: _TopMovieCard(
                    isDark: isDark,
                    titleId: title.titleId,
                    imdbRating: title.imdbRating ?? '-',
                    ageRating: title.ageRating ?? '-',
                    title: title.title,
                    year: title.yearString,
                    duration: title.durationString,
                    genres: title.genresString,
                    posterUrl: title.posterUrl,
                    matchScore: title.matchScore,
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}

class _TopMoviesShimmer extends StatelessWidget {
  final bool isDark;
  const _TopMoviesShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Shimmer.fromColors(
        baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
        highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
        child: Column(
          children: List.generate(3, (index) => Padding(
            padding: EdgeInsets.only(bottom: index < 2 ? 12 : 0),
            child: Container(
              height: 134,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          )),
        ),
      ),
    );
  }
}

class _TopMoviesEmptyState extends StatelessWidget {
  final bool isDark;
  const _TopMoviesEmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
          width: 0.5,
        ),
      ),
      child: Column(
        children: [
          Icon(
            Icons.stars_outlined,
            size: 48,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            'Your picks are coming!',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Explore some recommendations and your personalized top picks will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 13,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
          const SizedBox(height: 16),
          GestureDetector(
            onTap: () => context.push(AppRoutes.moodQuiz),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              decoration: BoxDecoration(
                gradient: AppColors.primaryGradient,
                borderRadius: BorderRadius.circular(24),
              ),
              child: const Text(
                'Find Something to Watch',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopMovieCard extends StatelessWidget {
  final bool isDark;
  final String titleId;
  final String imdbRating;
  final String ageRating;
  final String title;
  final String year;
  final String duration;
  final String genres;
  final String? posterUrl;
  final int? matchScore;

  const _TopMovieCard({
    required this.isDark,
    required this.titleId,
    required this.imdbRating,
    required this.ageRating,
    required this.title,
    required this.year,
    required this.duration,
    required this.genres,
    this.posterUrl,
    this.matchScore,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push(AppRoutes.titleDetailsPath(titleId, matchScore: matchScore)),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: posterUrl != null && posterUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: posterUrl!,
                      width: 80,
                      height: 110,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(
                        width: 80,
                        height: 110,
                        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
                        child: const Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      errorWidget: (_, __, ___) => _buildPosterPlaceholder(),
                    )
                  : _buildPosterPlaceholder(),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (imdbRating.isNotEmpty && imdbRating != '-')
                        _RatingBadge(label: 'IMDb $imdbRating', isDark: isDark),
                      if (imdbRating.isNotEmpty && imdbRating != '-' && ageRating.isNotEmpty && ageRating != '-')
                        const SizedBox(width: 8),
                      if (ageRating.isNotEmpty && ageRating != '-')
                        _RatingBadge(label: ageRating, isDark: isDark),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (year.isNotEmpty || duration.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      [year, duration].where((s) => s.isNotEmpty).join(', '),
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                  if (genres.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(
                      genres,
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPosterPlaceholder() => Container(
    width: 80,
    height: 110,
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Center(
      child: Icon(Icons.movie, size: 30, color: Colors.white),
    ),
  );
}

class _RatingBadge extends StatelessWidget {
  final String label;
  final bool isDark;
  const _RatingBadge({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: isDark
            ? Colors.white.withValues(alpha: 0.1)
            : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
    );
  }
}
