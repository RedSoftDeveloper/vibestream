import 'package:flutter/foundation.dart';
import 'package:vibestream/supabase/supabase_config.dart';

enum InteractionAction {
  impression,
  open,
  play,
  complete,
  like,
  dislike,
  skip,
  feedback,
}

enum InteractionSource {
  onboardingSwipe,
  quickMatch,
  moodResults,
  home,
  titleDetails,
}

class InteractionService {
  static final InteractionService _instance = InteractionService._internal();
  factory InteractionService() => _instance;
  InteractionService._internal();

  // Cache for pending feedback title IDs per profile
  static final Map<String, List<String>> _pendingTitlesCache = {};
  static final Map<String, DateTime> _pendingTitlesCacheTime = {};
  static const Duration _staleDuration = Duration(minutes: 5);
  static const Duration _expiryDuration = Duration(minutes: 30);
  
  // Cache for home page feedback status (title IDs that have feedback)
  static final Map<String, Set<String>> _homeFeedbackCache = {};
  static final Map<String, DateTime> _homeFeedbackCacheTime = {};

  /// Check if we have a cached list of pending feedback titles
  static bool hasPendingTitlesCache(String profileId) =>
      _pendingTitlesCache.containsKey(profileId) &&
      _pendingTitlesCacheTime.containsKey(profileId) &&
      DateTime.now().difference(_pendingTitlesCacheTime[profileId]!) < _expiryDuration;

  /// Get cached pending feedback titles (may be stale but still valid)
  static List<String>? getCachedPendingTitles(String profileId) =>
      _pendingTitlesCache[profileId];

  /// Check if the cache is stale (needs background refresh)
  static bool isPendingTitlesCacheStale(String profileId) {
    final cacheTime = _pendingTitlesCacheTime[profileId];
    if (cacheTime == null) return true;
    return DateTime.now().difference(cacheTime) > _staleDuration;
  }

  /// Remove a title from the cached pending list (after feedback submitted)
  static void removeTitleFromPendingCache(String profileId, String titleId) {
    final cached = _pendingTitlesCache[profileId];
    if (cached != null) {
      cached.remove(titleId);
      debugPrint('InteractionService: Removed $titleId from pending cache, ${cached.length} remaining');
    }
  }

  /// Invalidate the cache for a profile
  static void invalidatePendingTitlesCache(String profileId) {
    _pendingTitlesCache.remove(profileId);
    _pendingTitlesCacheTime.remove(profileId);
    debugPrint('InteractionService: Invalidated pending titles cache for profile $profileId');
  }
  
  // ============================================================
  // Home Page Feedback Status Cache (which titles have feedback)
  // ============================================================
  
  /// Get cached feedback status for home page
  static Set<String>? getCachedHomeFeedbackStatus(String profileId) =>
      _homeFeedbackCache[profileId];
  
  /// Check if home feedback cache exists and is not expired
  static bool hasHomeFeedbackCache(String profileId) =>
      _homeFeedbackCache.containsKey(profileId) &&
      _homeFeedbackCacheTime.containsKey(profileId) &&
      DateTime.now().difference(_homeFeedbackCacheTime[profileId]!) < _expiryDuration;
  
  /// Check if home feedback cache is stale (needs background refresh)
  static bool isHomeFeedbackCacheStale(String profileId) {
    final cacheTime = _homeFeedbackCacheTime[profileId];
    if (cacheTime == null) return true;
    return DateTime.now().difference(cacheTime) > _staleDuration;
  }
  
  /// Update home feedback cache
  static void updateHomeFeedbackCache(String profileId, Set<String> titlesWithFeedback) {
    _homeFeedbackCache[profileId] = titlesWithFeedback;
    _homeFeedbackCacheTime[profileId] = DateTime.now();
    debugPrint('InteractionService: Updated home feedback cache with ${titlesWithFeedback.length} titles');
  }
  
  /// Add a title to the home feedback cache (after feedback submitted)
  static void addTitleToHomeFeedbackCache(String profileId, String titleId) {
    final cached = _homeFeedbackCache[profileId];
    if (cached != null) {
      cached.add(titleId);
      debugPrint('InteractionService: Added $titleId to home feedback cache, ${cached.length} total');
    }
  }
  
  /// Invalidate home feedback cache
  static void invalidateHomeFeedbackCache(String profileId) {
    _homeFeedbackCache.remove(profileId);
    _homeFeedbackCacheTime.remove(profileId);
    debugPrint('InteractionService: Invalidated home feedback cache for profile $profileId');
  }

  /// Checks if a specific title has feedback from the given profile
  Future<bool> hasTitleFeedback({
    required String profileId,
    required String titleId,
  }) async {
    try {
      final response = await SupabaseConfig.client
          .from('profile_title_interactions')
          .select('id')
          .eq('profile_id', profileId)
          .eq('title_id', titleId)
          .eq('action', 'feedback')
          .limit(1);
      
      return (response as List).isNotEmpty;
    } catch (e) {
      debugPrint('InteractionService.hasTitleFeedback error: $e');
      return false;
    }
  }

  /// Gets all title IDs from recommendation_items for this profile that DON'T have feedback yet
  /// Returns titles across ALL sessions for the profile
  /// Uses cache with stale-while-revalidate pattern
  Future<List<String>> getPendingFeedbackTitleIds({
    required String profileId,
    bool forceRefresh = false,
  }) async {
    // Return cached data if available and not forcing refresh
    if (!forceRefresh && hasPendingTitlesCache(profileId)) {
      debugPrint('InteractionService: Returning cached pending titles for profile $profileId');
      return List<String>.from(_pendingTitlesCache[profileId]!);
    }

    try {
      // Step 1: Get all unique title_ids from recommendation_items for this profile's sessions
      final sessionsResponse = await SupabaseConfig.client
          .from('recommendation_sessions')
          .select('id')
          .eq('profile_id', profileId);
      
      final sessionIds = (sessionsResponse as List)
          .map((s) => s['id'] as String)
          .toList();
      
      if (sessionIds.isEmpty) {
        debugPrint('InteractionService: No sessions found for profile $profileId');
        _pendingTitlesCache[profileId] = [];
        _pendingTitlesCacheTime[profileId] = DateTime.now();
        return [];
      }

      // Step 2: Get all title_ids from recommendation_items for these sessions
      final itemsResponse = await SupabaseConfig.client
          .from('recommendation_items')
          .select('title_id')
          .inFilter('session_id', sessionIds);
      
      final allTitleIds = (itemsResponse as List)
          .map((item) => item['title_id'] as String)
          .toSet()
          .toList();
      
      if (allTitleIds.isEmpty) {
        debugPrint('InteractionService: No titles found in sessions');
        _pendingTitlesCache[profileId] = [];
        _pendingTitlesCacheTime[profileId] = DateTime.now();
        return [];
      }

      // Step 3: Get title_ids that already have feedback
      final feedbackResponse = await SupabaseConfig.client
          .from('profile_title_interactions')
          .select('title_id')
          .eq('profile_id', profileId)
          .eq('action', 'feedback')
          .inFilter('title_id', allTitleIds);
      
      final titlesWithFeedback = (feedbackResponse as List)
          .map((item) => item['title_id'] as String)
          .toSet();
      
      // Step 4: Return titles that don't have feedback yet
      final pendingTitles = allTitleIds
          .where((id) => !titlesWithFeedback.contains(id))
          .toList();
      
      // Cache the result
      _pendingTitlesCache[profileId] = pendingTitles;
      _pendingTitlesCacheTime[profileId] = DateTime.now();
      
      debugPrint('InteractionService: Found ${pendingTitles.length} pending feedback titles out of ${allTitleIds.length} total (cached)');
      return pendingTitles;
    } catch (e) {
      debugPrint('InteractionService.getPendingFeedbackTitleIds error: $e');
      // Return cached data on error if available
      if (_pendingTitlesCache.containsKey(profileId)) {
        debugPrint('InteractionService: Returning stale cache due to error');
        return List<String>.from(_pendingTitlesCache[profileId]!);
      }
      return [];
    }
  }

  /// Logs a user interaction with a title
  Future<bool> logInteraction({
    required String profileId,
    required String titleId,
    String? sessionId,
    required InteractionAction action,
    required InteractionSource source,
    int? rating,
    Map<String, dynamic>? extra,
  }) async {
    try {
      await SupabaseConfig.client.from('profile_title_interactions').insert({
        'profile_id': profileId,
        'title_id': titleId,
        'session_id': sessionId,
        'action': action.name,
        'source': _sourceToString(source),
        'rating': rating,
        'extra': extra ?? {},
      });
      debugPrint('InteractionService: Logged ${action.name} for title $titleId');
      
      // If feedback was submitted, update all caches
      if (action == InteractionAction.feedback) {
        removeTitleFromPendingCache(profileId, titleId);
        addTitleToHomeFeedbackCache(profileId, titleId);
      }
      
      return true;
    } catch (e) {
      debugPrint('InteractionService.logInteraction error: $e');
      return false;
    }
  }

  String _sourceToString(InteractionSource source) {
    switch (source) {
      case InteractionSource.onboardingSwipe:
        return 'onboarding_swipe';
      case InteractionSource.quickMatch:
        return 'quick_match';
      case InteractionSource.moodResults:
        return 'mood_results';
      case InteractionSource.home:
        return 'home';
      case InteractionSource.titleDetails:
        return 'title_details';
    }
  }
}
