import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:vibestream/supabase/supabase_config.dart';
import 'package:vibestream/features/recommendations/domain/entities/recommendation_card.dart';

class RecommendationLimitException implements Exception {
  final String message;
  final String tier;
  final int dailyLimit;
  final int usedToday;

  RecommendationLimitException({required this.message, required this.tier, required this.dailyLimit, required this.usedToday});

  factory RecommendationLimitException.fromResponseData(dynamic data) {
    try {
      final map = data is Map<String, dynamic> ? data : (data is String ? (jsonDecode(data) as Map<String, dynamic>) : <String, dynamic>{});
      return RecommendationLimitException(
        message: map['message'] as String? ?? 'Daily recommendation limit reached.',
        tier: map['tier'] as String? ?? 'free',
        dailyLimit: (map['daily_limit'] as num?)?.toInt() ?? 0,
        usedToday: (map['used_today'] as num?)?.toInt() ?? 0,
      );
    } catch (e) {
      debugPrint('RecommendationLimitException.fromResponseData parse error: $e');
      return RecommendationLimitException(message: 'Daily recommendation limit reached.', tier: 'free', dailyLimit: 0, usedToday: 0);
    }
  }

  @override
  String toString() => message;
}

/// Model for recent vibe data displayed on home page
class RecentVibe {
  final String sessionId;
  final String titleId;
  final String title;
  final String? posterUrl;
  final List<String> moodTags;
  final List<String> genres;
  final DateTime createdAt;
  final int rankIndex;
  final int? matchScore;

  RecentVibe({
    required this.sessionId,
    required this.titleId,
    required this.title,
    this.posterUrl,
    required this.moodTags,
    required this.genres,
    required this.createdAt,
    required this.rankIndex,
    this.matchScore,
  });
}

/// Full title detail model for the title details page
class TitleDetail {
  final String id;
  final String title;
  final String? posterUrl;
  final String? description;
  final String? imdbRating;
  final String? ageRating;
  final int? year;
  final int? runtimeMinutes;
  final List<String> genres;
  final String? director;
  final List<String> starring;
  final List<Map<String, dynamic>> streamingProviders;
  final String? tmdbId;
  final String? imdbId;
  final String? type;
  final List<String> vibeTags;
  final int? moodMatchPercent;

  TitleDetail({
    required this.id,
    required this.title,
    this.posterUrl,
    this.description,
    this.imdbRating,
    this.ageRating,
    this.year,
    this.runtimeMinutes,
    required this.genres,
    this.director,
    required this.starring,
    required this.streamingProviders,
    this.tmdbId,
    this.imdbId,
    this.type,
    this.vibeTags = const [],
    this.moodMatchPercent,
  });

  factory TitleDetail.fromJson(Map<String, dynamic> json) {
    return TitleDetail(
      id: json['id'] as String,
      title: json['title'] as String? ?? '',
      posterUrl: json['poster_url'] as String?,
      description: json['description'] as String?,
      imdbRating: json['imdb_rating']?.toString(),
      ageRating: json['age_rating'] as String?,
      year: json['year'] as int?,
      runtimeMinutes: json['runtime_minutes'] as int?,
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      director: json['director'] as String?,
      starring: (json['starring'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      streamingProviders: (json['streaming_providers'] as List<dynamic>?)
          ?.map((e) => e as Map<String, dynamic>)
          .toList() ?? [],
      tmdbId: json['tmdb_id']?.toString(),
      imdbId: json['imdb_id'] as String?,
      type: json['type'] as String?,
      vibeTags: (json['vibe_tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      moodMatchPercent: json['mood_match_percent'] as int?,
    );
  }

  String get yearString => year?.toString() ?? '';
  
  String get runtimeFormatted {
    if (runtimeMinutes == null) return 'N/A';
    final hours = runtimeMinutes! ~/ 60;
    final mins = runtimeMinutes! % 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }

  String get genresString => genres.take(2).join(', ');
  
  bool get isMovie => type == 'movie';
  bool get isSeries => type == 'series';
}

/// Model for top title data displayed on home page
class TopTitle {
  final String titleId;
  final String title;
  final String? posterUrl;
  final String? imdbRating;
  final String? ageRating;
  final int? year;
  final int? runtimeMinutes;
  final List<String> genres;
  final String? openaiReason;
  final int? matchScore;

  TopTitle({
    required this.titleId,
    required this.title,
    this.posterUrl,
    this.imdbRating,
    this.ageRating,
    this.year,
    this.runtimeMinutes,
    required this.genres,
    this.openaiReason,
    this.matchScore,
  });

  String get yearString => year?.toString() ?? '';
  String get durationString {
    if (runtimeMinutes == null) return '';
    final hours = runtimeMinutes! ~/ 60;
    final mins = runtimeMinutes! % 60;
    if (hours > 0) return '${hours}h ${mins}m';
    return '${mins}m';
  }
  String get genresString => genres.take(2).join(', ');
}

/// Cached latest recommendation data with timestamp
class _CachedLatestRecommendation {
  final ({String titleId, String sessionId})? data;
  final DateTime cachedAt;
  final String profileId;

  _CachedLatestRecommendation({
    required this.data,
    required this.cachedAt,
    required this.profileId,
  });

  bool get isStale {
    // Consider data stale after 5 minutes
    return DateTime.now().difference(cachedAt).inMinutes > 5;
  }

  bool get isExpired {
    // Consider data expired after 30 minutes
    return DateTime.now().difference(cachedAt).inMinutes > 30;
  }
}

/// Cached recent vibes data with timestamp
class _CachedRecentVibes {
  final List<RecentVibe> data;
  final DateTime cachedAt;
  final String profileId;

  _CachedRecentVibes({
    required this.data,
    required this.cachedAt,
    required this.profileId,
  });

  bool get isStale => DateTime.now().difference(cachedAt).inMinutes > 5;
  bool get isExpired => DateTime.now().difference(cachedAt).inMinutes > 30;
}

/// Cached top titles data with timestamp
class _CachedTopTitles {
  final List<TopTitle> data;
  final DateTime cachedAt;
  final String profileId;

  _CachedTopTitles({
    required this.data,
    required this.cachedAt,
    required this.profileId,
  });

  bool get isStale => DateTime.now().difference(cachedAt).inMinutes > 5;
  bool get isExpired => DateTime.now().difference(cachedAt).inMinutes > 30;
}

class RecommendationService {
  // Cache of recently seen title IDs per profile to help with client-side deduplication
  static final Map<String, Set<String>> _recentlySeenTitles = {};
  
  // Cache for latest recommendation per profile
  static _CachedLatestRecommendation? _latestRecommendationCache;
  
  // Cache for recent vibes per profile
  static _CachedRecentVibes? _recentVibesCache;
  
  // Cache for top titles per profile
  static _CachedTopTitles? _topTitlesCache;
  
  // Listeners for cache invalidation
  static final List<VoidCallback> _latestRecommendationListeners = [];
  
  // Listeners for home data cache invalidation
  static final List<VoidCallback> _homeDataListeners = [];

  /// Add a listener that will be called when latest recommendation changes
  static void addLatestRecommendationListener(VoidCallback listener) {
    _latestRecommendationListeners.add(listener);
  }

  /// Remove a listener
  static void removeLatestRecommendationListener(VoidCallback listener) {
    _latestRecommendationListeners.remove(listener);
  }

  /// Notify all listeners that latest recommendation has changed
  static void _notifyLatestRecommendationListeners() {
    for (final listener in _latestRecommendationListeners) {
      listener();
    }
  }

  /// Invalidate the latest recommendation cache (call when new recommendations are created)
  static void invalidateLatestRecommendationCache() {
    _latestRecommendationCache = null;
    _notifyLatestRecommendationListeners();
    debugPrint('RecommendationService: Latest recommendation cache invalidated');
  }

  /// Add a listener for home data cache changes
  static void addHomeDataListener(VoidCallback listener) {
    _homeDataListeners.add(listener);
  }

  /// Remove a home data listener
  static void removeHomeDataListener(VoidCallback listener) {
    _homeDataListeners.remove(listener);
  }

  /// Notify all home data listeners
  static void _notifyHomeDataListeners() {
    for (final listener in _homeDataListeners) {
      listener();
    }
  }

  /// Invalidate all home data caches (call when new recommendations are created)
  static void invalidateHomeDataCache() {
    _recentVibesCache = null;
    _topTitlesCache = null;
    _notifyHomeDataListeners();
    debugPrint('RecommendationService: Home data cache invalidated');
  }

  /// Get cached recent vibes if available and valid for the profile
  static List<RecentVibe>? getCachedRecentVibes(String profileId) {
    if (_recentVibesCache != null && 
        _recentVibesCache!.profileId == profileId && 
        !_recentVibesCache!.isExpired) {
      return _recentVibesCache!.data;
    }
    return null;
  }

  /// Check if recent vibes cache exists for profile (even if stale)
  static bool hasRecentVibesCache(String profileId) {
    return _recentVibesCache != null && 
           _recentVibesCache!.profileId == profileId &&
           !_recentVibesCache!.isExpired;
  }

  /// Check if recent vibes cache is stale and needs background refresh
  static bool isRecentVibesCacheStale(String profileId) {
    if (_recentVibesCache == null || _recentVibesCache!.profileId != profileId) return true;
    return _recentVibesCache!.isStale;
  }

  /// Get cached top titles if available and valid for the profile
  static List<TopTitle>? getCachedTopTitles(String profileId) {
    if (_topTitlesCache != null && 
        _topTitlesCache!.profileId == profileId && 
        !_topTitlesCache!.isExpired) {
      return _topTitlesCache!.data;
    }
    return null;
  }

  /// Check if top titles cache exists for profile (even if stale)
  static bool hasTopTitlesCache(String profileId) {
    return _topTitlesCache != null && 
           _topTitlesCache!.profileId == profileId &&
           !_topTitlesCache!.isExpired;
  }

  /// Check if top titles cache is stale and needs background refresh
  static bool isTopTitlesCacheStale(String profileId) {
    if (_topTitlesCache == null || _topTitlesCache!.profileId != profileId) return true;
    return _topTitlesCache!.isStale;
  }

  /// Get cached latest recommendation if available and valid for the profile
  static ({String titleId, String sessionId})? getCachedLatestRecommendation(String profileId) {
    if (_latestRecommendationCache != null && 
        _latestRecommendationCache!.profileId == profileId && 
        !_latestRecommendationCache!.isExpired) {
      return _latestRecommendationCache!.data;
    }
    return null;
  }

  /// Check if latest recommendation cache exists for profile (even if stale)
  static bool hasLatestRecommendationCache(String profileId) {
    return _latestRecommendationCache != null && 
           _latestRecommendationCache!.profileId == profileId &&
           !_latestRecommendationCache!.isExpired;
  }

  /// Check if cache is stale and needs background refresh
  static bool isLatestRecommendationCacheStale(String profileId) {
    if (_latestRecommendationCache == null || _latestRecommendationCache!.profileId != profileId) return true;
    return _latestRecommendationCache!.isStale;
  }
  
  /// Track a title as seen for a profile (called when displaying recommendations)
  static void markTitleAsSeen(String profileId, String titleId) {
    _recentlySeenTitles.putIfAbsent(profileId, () => {});
    _recentlySeenTitles[profileId]!.add(titleId);
    
    // Keep only last 100 titles to prevent memory bloat
    if (_recentlySeenTitles[profileId]!.length > 100) {
      final list = _recentlySeenTitles[profileId]!.toList();
      _recentlySeenTitles[profileId] = list.skip(list.length - 100).toSet();
    }
  }
  
  /// Check if a title was recently seen
  static bool wasTitleRecentlySeen(String profileId, String titleId) {
    return _recentlySeenTitles[profileId]?.contains(titleId) ?? false;
  }
  
  /// Clear seen titles cache for a profile
  static void clearSeenTitlesCache(String profileId) {
    _recentlySeenTitles.remove(profileId);
  }

  /// Creates a recommendation session and returns AI-generated cards
  /// [sessionType]: "onboarding" | "quick_match" | "mood"
  /// [profileId]: The active profile ID
  /// [moodInput]: Context data for the AI
  /// [contentTypes]: List of content types to recommend ("movie", "tv", or both)
  static Future<RecommendationSession> createSession({
    required String sessionType,
    required String profileId,
    required Map<String, dynamic> moodInput,
    List<String> contentTypes = const ['movie', 'tv'],
  }) async {
    try {
      // Log session state for debugging
      final session = SupabaseConfig.auth.currentSession;
      final user = SupabaseConfig.auth.currentUser;

      debugPrint('RecommendationService: --- Session Debug Info ---');
      debugPrint('RecommendationService: User ID: ${user?.id}');
      debugPrint('RecommendationService: User email: ${user?.email}');
      debugPrint('RecommendationService: Session exists: ${session != null}');

      if (session == null) {
        debugPrint('RecommendationService: No active session, attempting refresh...');
        try {
          await SupabaseConfig.auth.refreshSession();
          final refreshedSession = SupabaseConfig.auth.currentSession;
          debugPrint('RecommendationService: After refresh - session exists: ${refreshedSession != null}');
          if (refreshedSession == null) {
            throw Exception('User not authenticated. Please log in again.');
          }
        } catch (refreshError) {
          debugPrint('RecommendationService: Refresh failed: $refreshError');
          throw Exception('User not authenticated. Please log in again.');
        }
      }

      // Get the current session (possibly refreshed)
      final currentSession = SupabaseConfig.auth.currentSession;
      if (currentSession == null) {
        throw Exception('User not authenticated. Please log in again.');
      }

      final accessToken = currentSession.accessToken;
      debugPrint('RecommendationService: Token preview: ${accessToken.substring(0, 50)}...');
      debugPrint('RecommendationService: Token expires at: ${currentSession.expiresAt}');

      debugPrint('RecommendationService: Calling Edge Function via Supabase SDK...');

      // Use Supabase SDK functions.invoke() - this automatically handles auth headers
      final res = await SupabaseConfig.client.functions.invoke(
        'create_recommendation_session',
        body: {
          'session_type': sessionType,
          'profile_id': profileId,
          'mood_input': moodInput,
          'content_types': contentTypes,
        },
      );

      debugPrint('RecommendationService: Response status: ${res.status}');
      debugPrint('RecommendationService: Response data: ${res.data}');

      if (res.status == 429) {
        final limitEx = RecommendationLimitException.fromResponseData(res.data);
        debugPrint('RecommendationService: Daily limit reached: ${limitEx.message}');
        throw limitEx;
      }

      if (res.status != 200) {
        debugPrint('Edge Function error: ${res.status} - ${res.data}');
        throw Exception('Failed to get recommendations: ${res.status} - ${res.data}');
      }

      final data = res.data as Map<String, dynamic>;
      final recommendationSession = RecommendationSession.fromJson(data);
      
      // Mark all returned titles as seen for future deduplication
      for (final card in recommendationSession.cards) {
        markTitleAsSeen(profileId, card.titleId);
      }
      
      // Invalidate caches since we have a new session
      invalidateLatestRecommendationCache();
      invalidateHomeDataCache();
      
      debugPrint('RecommendationService: Session created with ${recommendationSession.cards.length} cards, marked as seen');
      return recommendationSession;
    } catch (e) {
      debugPrint('RecommendationService.createSession error: $e');
      rethrow;
    }
  }


  /// Creates a recommendation session with streaming support
  /// Returns a Stream of [StreamingRecommendationEvent] that emits:
  /// 1. [StreamingSessionStarted] - When session is created with metadata
  /// 2. [StreamingCardReceived] - For each card as it becomes available
  /// 3. [StreamingCompleted] - When all cards are received with final session
  /// 4. [StreamingError] - If an error occurs
  static Stream<StreamingRecommendationEvent> createSessionStreaming({
    required String sessionType,
    required String profileId,
    required Map<String, dynamic> moodInput,
    List<String> contentTypes = const ['movie', 'tv'],
  }) async* {
    try {
      // Verify authentication
      final session = SupabaseConfig.auth.currentSession;
      if (session == null) {
        debugPrint('RecommendationService: No active session, attempting refresh...');
        try {
          await SupabaseConfig.auth.refreshSession();
        } catch (refreshError) {
          debugPrint('RecommendationService: Refresh failed: $refreshError');
          yield StreamingError(message: 'User not authenticated. Please log in again.');
          return;
        }
      }

      final currentSession = SupabaseConfig.auth.currentSession;
      if (currentSession == null) {
        yield StreamingError(message: 'User not authenticated. Please log in again.');
        return;
      }

      final accessToken = currentSession.accessToken;
      final functionUrl = '${SupabaseConfig.supabaseUrl}/functions/v1/create_recommendation_session';

      debugPrint('RecommendationService: Starting streaming request to $functionUrl');

      final request = http.Request('POST', Uri.parse(functionUrl));
      request.headers.addAll({
        'Authorization': 'Bearer $accessToken',
        'Content-Type': 'application/json',
        'Accept': 'text/event-stream',
        'apikey': SupabaseConfig.anonKey,
      });
      request.body = jsonEncode({
        'session_type': sessionType,
        'profile_id': profileId,
        'mood_input': moodInput,
        'content_types': contentTypes,
        'stream': true,
      });

      final client = http.Client();
      final streamedResponse = await client.send(request);

      if (streamedResponse.statusCode != 200) {
        final responseBody = await streamedResponse.stream.bytesToString();
        debugPrint('RecommendationService: Stream error ${streamedResponse.statusCode}: $responseBody');

        if (streamedResponse.statusCode == 429) {
          final limitEx = RecommendationLimitException.fromResponseData(responseBody);
          yield StreamingError(message: limitEx.message);
        } else {
          yield StreamingError(message: 'Failed to start recommendation stream: ${streamedResponse.statusCode}');
        }

        client.close();
        return;
      }

      String? sessionId;
      String receivedProfileId = profileId;
      String receivedSessionType = sessionType;
      int totalExpectedCards = 5;
      DateTime createdAt = DateTime.now();
      final List<RecommendationCard> cards = [];
      String buffer = '';

      await for (final chunk in streamedResponse.stream.transform(utf8.decoder)) {
        buffer += chunk;
        
        // Process complete lines from buffer
        while (buffer.contains('\n')) {
          final lineEnd = buffer.indexOf('\n');
          final line = buffer.substring(0, lineEnd).trim();
          buffer = buffer.substring(lineEnd + 1);
          
          if (line.isEmpty) continue;
          
          // Handle SSE format: "data: {...}" or "event: type"
          String jsonData = line;
          if (line.startsWith('data:')) {
            jsonData = line.substring(5).trim();
          } else if (line.startsWith('event:')) {
            continue; // Skip event type lines
          }
          
          if (jsonData.isEmpty || jsonData == '[DONE]') continue;
          
          try {
            final data = jsonDecode(jsonData) as Map<String, dynamic>;
            final eventType = data['type'] as String? ?? data['event'] as String?;
            
            if (eventType == 'session_started' || data.containsKey('session_id') && !data.containsKey('card')) {
              // Session started event
              sessionId = data['session_id'] as String? ?? data['id'] as String?;
              receivedProfileId = data['profile_id'] as String? ?? profileId;
              receivedSessionType = data['session_type'] as String? ?? sessionType;
              totalExpectedCards = data['total_expected'] as int? ?? 5;
              if (data['created_at'] != null) {
                createdAt = DateTime.parse(data['created_at'] as String);
              }
              
              debugPrint('RecommendationService: Session started - $sessionId, expecting $totalExpectedCards cards');
              
              yield StreamingSessionStarted(
                sessionId: sessionId ?? '',
                profileId: receivedProfileId,
                sessionType: receivedSessionType,
                totalExpectedCards: totalExpectedCards,
                createdAt: createdAt,
              );
            } else if (eventType == 'card' || data.containsKey('card')) {
              // Card received event
              final cardData = data['card'] as Map<String, dynamic>? ?? data;
              final cardIndex = data['index'] as int? ?? cards.length;
              
              final card = RecommendationCard.fromJson(cardData);
              cards.add(card);
              
              // Mark title as seen
              markTitleAsSeen(profileId, card.titleId);
              
              debugPrint('RecommendationService: Card received - ${card.title} (${cardIndex + 1}/$totalExpectedCards)');
              
              yield StreamingCardReceived(card: card, cardIndex: cardIndex);
            } else if (eventType == 'complete' || eventType == 'done' || data.containsKey('cards')) {
              // Completion event - might include all cards in final payload
              if (data.containsKey('cards') && cards.isEmpty) {
                final cardsJson = data['cards'] as List<dynamic>? ?? [];
                for (int i = 0; i < cardsJson.length; i++) {
                  final card = RecommendationCard.fromJson(cardsJson[i] as Map<String, dynamic>);
                  cards.add(card);
                  markTitleAsSeen(profileId, card.titleId);
                  yield StreamingCardReceived(card: card, cardIndex: i);
                }
              }
              
              sessionId ??= data['id'] as String? ?? data['session_id'] as String?;
              if (data['created_at'] != null && createdAt == DateTime.now()) {
                createdAt = DateTime.parse(data['created_at'] as String);
              }
            } else if (eventType == 'error') {
              yield StreamingError(message: data['message'] as String? ?? 'Unknown streaming error');
              client.close();
              return;
            }
          } catch (e) {
            debugPrint('RecommendationService: Error parsing stream data: $e - Line: $jsonData');
            // Continue processing other events
          }
        }
      }
      
      client.close();
      
      // Create final session
      final finalSession = RecommendationSession(
        id: sessionId ?? '',
        profileId: receivedProfileId,
        sessionType: receivedSessionType,
        moodInput: moodInput,
        cards: cards,
        createdAt: createdAt,
        totalExpectedCards: totalExpectedCards,
        isComplete: true,
      );
      
      // Invalidate caches since we have a new session
      invalidateLatestRecommendationCache();
      invalidateHomeDataCache();
      
      debugPrint('RecommendationService: Streaming complete with ${cards.length} cards');
      
      yield StreamingCompleted(session: finalSession);
    } catch (e) {
      debugPrint('RecommendationService.createSessionStreaming error: $e');
      yield StreamingError(message: e.toString());
    }
  }

  /// Creates a mood-based session with streaming
  static Stream<StreamingRecommendationEvent> createMoodSessionStreaming({
    required String profileId,
    required String viewingStyle,
    required Map<String, double> sliders,
    required List<String> selectedGenres,
    String? freeText,
    List<String> contentTypes = const ['movie', 'tv'],
  }) {
    return createSessionStreaming(
      sessionType: 'mood',
      profileId: profileId,
      moodInput: {
        'viewing_style': viewingStyle,
        'sliders': sliders,
        'selected_genres': selectedGenres,
        'quick_match_tag': null,
        'free_text': freeText ?? '',
      },
      contentTypes: contentTypes,
    );
  }

  /// Creates a quick match session with streaming
  static Stream<StreamingRecommendationEvent> createQuickMatchSessionStreaming({
    required String profileId,
    required String quickMatchTag,
    String viewingStyle = 'personal',
    List<String> contentTypes = const ['movie', 'tv'],
  }) {
    return createSessionStreaming(
      sessionType: 'quick_match',
      profileId: profileId,
      moodInput: {
        'quick_match_tag': quickMatchTag,
        'viewing_style': viewingStyle,
      },
      contentTypes: contentTypes,
    );
  }

  /// Creates an onboarding session
  static Future<RecommendationSession> createOnboardingSession({
    required String profileId,
    Map<String, dynamic>? preferences,
    List<String> contentTypes = const ['movie', 'tv'],
  }) async {
    return createSession(
      sessionType: 'onboarding',
      profileId: profileId,
      moodInput: preferences ?? {},
      contentTypes: contentTypes,
    );
  }

  /// Creates a quick match session
  static Future<RecommendationSession> createQuickMatchSession({
    required String profileId,
    required String quickMatchTag,
    String viewingStyle = 'personal',
    List<String> contentTypes = const ['movie', 'tv'],
  }) async {
    return createSession(
      sessionType: 'quick_match',
      profileId: profileId,
      moodInput: {
        'quick_match_tag': quickMatchTag,
        'viewing_style': viewingStyle,
      },
      contentTypes: contentTypes,
    );
  }

  /// Creates a mood-based session
  static Future<RecommendationSession> createMoodSession({
    required String profileId,
    required String viewingStyle,
    required Map<String, double> sliders,
    required List<String> selectedGenres,
    String? freeText,
    List<String> contentTypes = const ['movie', 'tv'],
  }) async {
    return createSession(
      sessionType: 'mood',
      profileId: profileId,
      moodInput: {
        'viewing_style': viewingStyle,
        'sliders': sliders,
        'selected_genres': selectedGenres,
        'quick_match_tag': null,
        'free_text': freeText ?? '',
      },
      contentTypes: contentTypes,
    );
  }

  /// Fetches recent vibes (recommendation sessions with titles) for a profile
  /// Uses cache if available, otherwise fetches from server
  static Future<List<RecentVibe>> getRecentVibes(
    String profileId, {
    int limit = 10,
    bool forceRefresh = false,
  }) async {
    // Return cached data if valid and not forcing refresh
    if (!forceRefresh) {
      final cached = getCachedRecentVibes(profileId);
      if (cached != null && !isRecentVibesCacheStale(profileId)) {
        debugPrint('RecommendationService: Returning cached recent vibes');
        return cached;
      }
    }

    try {
      // Get recent recommendation sessions with their items and titles
      final sessionsData = await SupabaseConfig.client
          .from('recommendation_sessions')
          .select('''
            id,
            mood_tags,
            created_at,
            recommendation_items (
              rank_index,
              title_id,
              match_score,
              media_titles (
                id,
                title,
                poster_url,
                genres
              )
            )
          ''')
          .eq('profile_id', profileId)
          .order('created_at', ascending: false)
          .limit(5);

      final List<RecentVibe> vibes = [];
      
      for (final session in sessionsData as List<dynamic>) {
        final sessionId = session['id'] as String;
        final moodTags = (session['mood_tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [];
        final createdAt = DateTime.parse(session['created_at'] as String);
        final items = session['recommendation_items'] as List<dynamic>? ?? [];

        // Get top 2 items from each session
        final sortedItems = List<Map<String, dynamic>>.from(items)
          ..sort((a, b) => (a['rank_index'] as int).compareTo(b['rank_index'] as int));

        for (final item in sortedItems.take(2)) {
          final titleData = item['media_titles'] as Map<String, dynamic>?;
          if (titleData == null) continue;

          final titleGenres = (titleData['genres'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ?? [];
          
          vibes.add(RecentVibe(
            sessionId: sessionId,
            titleId: titleData['id'] as String,
            title: titleData['title'] as String? ?? '',
            posterUrl: titleData['poster_url'] as String?,
            moodTags: moodTags,
            genres: titleGenres,
            createdAt: createdAt,
            rankIndex: item['rank_index'] as int,
            matchScore: item['match_score'] as int?,
          ));

          if (vibes.length >= limit) break;
        }
        if (vibes.length >= limit) break;
      }

      // Mark these titles as seen for deduplication
      for (final vibe in vibes) {
        markTitleAsSeen(profileId, vibe.titleId);
      }

      // Update cache
      _recentVibesCache = _CachedRecentVibes(
        data: vibes,
        cachedAt: DateTime.now(),
        profileId: profileId,
      );
      debugPrint('RecommendationService: Loaded and cached ${vibes.length} recent vibes for profile $profileId');
      
      return vibes;
    } catch (e) {
      debugPrint('RecommendationService.getRecentVibes error: $e');
      // Return cached data on error if available
      final cached = getCachedRecentVibes(profileId);
      if (cached != null) {
        debugPrint('RecommendationService: Returning stale cache due to error');
        return cached;
      }
      return [];
    }
  }

  /// Fetches a single title by ID from the media_titles table
  /// Includes retry logic for network errors
  static Future<TitleDetail?> getTitleById(String titleId, {int maxRetries = 3}) async {
    if (titleId.isEmpty) {
      debugPrint('RecommendationService.getTitleById: Empty titleId provided');
      return null;
    }

    for (int attempt = 1; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('RecommendationService.getTitleById: Fetching title $titleId (attempt $attempt)');
        final data = await SupabaseConfig.client
            .from('media_titles')
            .select()
            .eq('id', titleId)
            .maybeSingle();

        if (data == null) {
          debugPrint('RecommendationService.getTitleById: Title not found: $titleId');
          return null;
        }

        debugPrint('RecommendationService.getTitleById: Successfully fetched title: ${data['title']}');
        return TitleDetail.fromJson(data);
      } catch (e) {
        debugPrint('RecommendationService.getTitleById error (attempt $attempt): $e');
        if (attempt < maxRetries) {
          // Wait before retry with exponential backoff
          await Future.delayed(Duration(milliseconds: 500 * attempt));
        }
      }
    }
    debugPrint('RecommendationService.getTitleById: All $maxRetries attempts failed for titleId: $titleId');
    return null;
  }

  /// Fetches more suggestions for a profile (excluding a specific title)
  static Future<List<TitleDetail>> getMoreSuggestions(String profileId, {String? excludeTitleId, int limit = 3}) async {
    try {
      final itemsData = await SupabaseConfig.client
          .from('recommendation_items')
          .select('''
            title_id,
            recommendation_sessions!inner (
              profile_id
            ),
            media_titles (
              id,
              title,
              poster_url,
              imdb_rating,
              age_rating,
              year,
              runtime_minutes,
              genres,
              description,
              director,
              starring,
              streaming_providers,
              tmdb_id,
              imdb_id,
              type
            )
          ''')
          .eq('recommendation_sessions.profile_id', profileId)
          .order('created_at', ascending: false)
          .limit(20);

      final List<TitleDetail> suggestions = [];
      final Set<String> seenIds = {};
      
      for (final item in itemsData as List<dynamic>) {
        final titleData = item['media_titles'] as Map<String, dynamic>?;
        if (titleData == null) continue;

        final titleId = titleData['id'] as String;
        if (seenIds.contains(titleId) || titleId == excludeTitleId) continue;
        seenIds.add(titleId);

        suggestions.add(TitleDetail.fromJson(titleData));
        if (suggestions.length >= limit) break;
      }

      debugPrint('RecommendationService: Loaded ${suggestions.length} more suggestions');
      return suggestions;
    } catch (e) {
      debugPrint('RecommendationService.getMoreSuggestions error: $e');
      return [];
    }
  }

  /// Gets the latest recommended vibe for a profile (most recent recommendation)
  /// Returns the titleId and sessionId of the latest recommendation, or null if none
  /// Uses cache if available, otherwise fetches from server
  static Future<({String titleId, String sessionId})?> getLatestRecommendedTitle(
    String profileId, {
    bool forceRefresh = false,
  }) async {
    // Return cached data if valid and not forcing refresh
    if (!forceRefresh) {
      final cached = getCachedLatestRecommendation(profileId);
      if (cached != null && !isLatestRecommendationCacheStale(profileId)) {
        debugPrint('RecommendationService: Returning cached latest recommendation');
        return cached;
      }
    }

    try {
      debugPrint('RecommendationService: Fetching latest recommended title for profile $profileId');
      
      final itemData = await SupabaseConfig.client
          .from('recommendation_items')
          .select('''
            title_id,
            session_id,
            recommendation_sessions!inner (
              profile_id
            )
          ''')
          .eq('recommendation_sessions.profile_id', profileId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      ({String titleId, String sessionId})? result;

      if (itemData == null) {
        debugPrint('RecommendationService: No recommendations found for profile $profileId');
        result = null;
      } else {
        final titleId = itemData['title_id'] as String?;
        final sessionId = itemData['session_id'] as String?;

        if (titleId == null || sessionId == null) {
          debugPrint('RecommendationService: Missing title_id or session_id');
          result = null;
        } else {
          debugPrint('RecommendationService: Latest recommendation - titleId: $titleId, sessionId: $sessionId');
          result = (titleId: titleId, sessionId: sessionId);
        }
      }

      // Update cache
      _latestRecommendationCache = _CachedLatestRecommendation(
        data: result,
        cachedAt: DateTime.now(),
        profileId: profileId,
      );
      debugPrint('RecommendationService: Cached latest recommendation');

      return result;
    } catch (e) {
      debugPrint('RecommendationService.getLatestRecommendedTitle error: $e');
      // Return cached data on error if available
      final cached = getCachedLatestRecommendation(profileId);
      if (cached != null) {
        debugPrint('RecommendationService: Returning stale cache due to error');
        return cached;
      }
      return null;
    }
  }

  /// Fetches top titles for a profile (from recent recommendations)
  /// Uses cache if available, otherwise fetches from server
  static Future<List<TopTitle>> getTopTitles(
    String profileId, {
    int limit = 3,
    bool forceRefresh = false,
  }) async {
    // Return cached data if valid and not forcing refresh
    if (!forceRefresh) {
      final cached = getCachedTopTitles(profileId);
      if (cached != null && !isTopTitlesCacheStale(profileId)) {
        debugPrint('RecommendationService: Returning cached top titles');
        return cached;
      }
    }

    try {
      // Get recent recommendation items with their titles, ordered by rank
      final itemsData = await SupabaseConfig.client
          .from('recommendation_items')
          .select('''
            rank_index,
            openai_reason,
            match_score,
            title_id,
            session_id,
            recommendation_sessions!inner (
              profile_id
            ),
            media_titles (
              id,
              title,
              poster_url,
              imdb_rating,
              age_rating,
              year,
              runtime_minutes,
              genres
            )
          ''')
          .eq('recommendation_sessions.profile_id', profileId)
          .order('created_at', ascending: false)
          .limit(20);

      // Deduplicate by title_id and take top ranked
      final Map<String, TopTitle> uniqueTitles = {};
      
      for (final item in itemsData as List<dynamic>) {
        final titleData = item['media_titles'] as Map<String, dynamic>?;
        if (titleData == null) continue;

        final titleId = titleData['id'] as String;
        if (uniqueTitles.containsKey(titleId)) continue;

        uniqueTitles[titleId] = TopTitle(
          titleId: titleId,
          title: titleData['title'] as String? ?? '',
          posterUrl: titleData['poster_url'] as String?,
          imdbRating: titleData['imdb_rating']?.toString(),
          ageRating: titleData['age_rating'] as String?,
          year: titleData['year'] as int?,
          runtimeMinutes: titleData['runtime_minutes'] as int?,
          genres: (titleData['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
          openaiReason: item['openai_reason'] as String?,
          matchScore: item['match_score'] as int?,
        );

        if (uniqueTitles.length >= limit) break;
      }

      // Mark these titles as seen for deduplication
      for (final title in uniqueTitles.values) {
        markTitleAsSeen(profileId, title.titleId);
      }

      // Update cache
      final titles = uniqueTitles.values.toList();
      _topTitlesCache = _CachedTopTitles(
        data: titles,
        cachedAt: DateTime.now(),
        profileId: profileId,
      );
      debugPrint('RecommendationService: Loaded and cached ${titles.length} top titles for profile $profileId');
      
      return titles;
    } catch (e) {
      debugPrint('RecommendationService.getTopTitles error: $e');
      // Return cached data on error if available
      final cached = getCachedTopTitles(profileId);
      if (cached != null) {
        debugPrint('RecommendationService: Returning stale cache due to error');
        return cached;
      }
      return [];
    }
  }
}
