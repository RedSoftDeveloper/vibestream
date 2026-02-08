import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibestream/features/recommendations/data/recommendation_service.dart';

/// Entity representing a favorite title
class FavoriteTitle {
  final String id;
  final String profileId;
  final String titleId;
  final DateTime createdAt;
  final TitleDetail? title;

  FavoriteTitle({
    required this.id,
    required this.profileId,
    required this.titleId,
    required this.createdAt,
    this.title,
  });

  factory FavoriteTitle.fromJson(Map<String, dynamic> json) {
    TitleDetail? titleDetail;
    if (json['media_titles'] != null) {
      titleDetail = TitleDetail.fromJson(json['media_titles'] as Map<String, dynamic>);
    }
    
    return FavoriteTitle(
      id: json['id'] as String,
      profileId: json['profile_id'] as String,
      titleId: json['title_id'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
      title: titleDetail,
    );
  }
}

/// Cached favorites data with timestamp
class _CachedFavorites {
  final List<FavoriteTitle> favorites;
  final DateTime cachedAt;
  final String profileId;

  _CachedFavorites({
    required this.favorites,
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

/// Service for managing user favorites with caching
class FavoriteService {
  static final _supabase = Supabase.instance.client;
  
  // In-memory cache
  static _CachedFavorites? _cache;
  
  // Listeners for cache invalidation
  static final List<VoidCallback> _listeners = [];

  /// Add a listener that will be called when favorites are updated
  static void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  /// Remove a listener
  static void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  /// Notify all listeners that favorites have changed
  static void _notifyListeners() {
    for (final listener in _listeners) {
      listener();
    }
  }

  /// Invalidate the cache (call when favorites are modified)
  static void invalidateCache() {
    _cache = null;
    _notifyListeners();
    debugPrint('FavoriteService: Cache invalidated');
  }

  /// Get cached favorites if available and valid for the profile
  static List<FavoriteTitle>? getCachedFavorites(String profileId) {
    if (_cache != null && 
        _cache!.profileId == profileId && 
        !_cache!.isExpired) {
      return _cache!.favorites;
    }
    return null;
  }

  /// Check if cache is stale and needs background refresh
  static bool isCacheStale(String profileId) {
    if (_cache == null || _cache!.profileId != profileId) return true;
    return _cache!.isStale;
  }

  /// Check if a title is favorited by a profile
  static Future<bool> isFavorite({
    required String profileId,
    required String titleId,
  }) async {
    // Check cache first
    final cached = getCachedFavorites(profileId);
    if (cached != null) {
      return cached.any((f) => f.titleId == titleId);
    }

    try {
      final response = await _supabase
          .from('profile_favorites')
          .select('id')
          .eq('profile_id', profileId)
          .eq('title_id', titleId)
          .maybeSingle();
      
      return response != null;
    } catch (e) {
      debugPrint('FavoriteService.isFavorite error: $e');
      return false;
    }
  }

  /// Add a title to favorites
  static Future<bool> addFavorite({
    required String profileId,
    required String titleId,
  }) async {
    try {
      await _supabase.from('profile_favorites').insert({
        'profile_id': profileId,
        'title_id': titleId,
      });
      // Invalidate cache after successful add
      invalidateCache();
      return true;
    } catch (e) {
      debugPrint('FavoriteService.addFavorite error: $e');
      return false;
    }
  }

  /// Remove a title from favorites
  static Future<bool> removeFavorite({
    required String profileId,
    required String titleId,
  }) async {
    try {
      await _supabase
          .from('profile_favorites')
          .delete()
          .eq('profile_id', profileId)
          .eq('title_id', titleId);
      // Invalidate cache after successful remove
      invalidateCache();
      return true;
    } catch (e) {
      debugPrint('FavoriteService.removeFavorite error: $e');
      return false;
    }
  }

  /// Toggle favorite status
  static Future<bool> toggleFavorite({
    required String profileId,
    required String titleId,
  }) async {
    final isFav = await isFavorite(profileId: profileId, titleId: titleId);
    if (isFav) {
      return await removeFavorite(profileId: profileId, titleId: titleId);
    } else {
      return await addFavorite(profileId: profileId, titleId: titleId);
    }
  }

  /// Remove favorite from cache optimistically (for immediate UI update)
  static void removeFavoriteFromCache(String titleId) {
    if (_cache != null) {
      final updatedFavorites = _cache!.favorites
          .where((f) => f.titleId != titleId)
          .toList();
      _cache = _CachedFavorites(
        favorites: updatedFavorites,
        cachedAt: _cache!.cachedAt,
        profileId: _cache!.profileId,
      );
    }
  }

  /// Get all favorites for a profile with title details
  /// Uses cache if available, otherwise fetches from server
  static Future<List<FavoriteTitle>> getFavorites({
    required String profileId,
    int limit = 50,
    int offset = 0,
    bool forceRefresh = false,
  }) async {
    // Return cached data if valid and not forcing refresh
    if (!forceRefresh && offset == 0) {
      final cached = getCachedFavorites(profileId);
      if (cached != null && !isCacheStale(profileId)) {
        debugPrint('FavoriteService: Returning cached favorites (${cached.length} items)');
        return cached;
      }
    }

    try {
      final response = await _supabase
          .from('profile_favorites')
          .select('''
            id,
            profile_id,
            title_id,
            created_at,
            media_titles (
              id,
              tmdb_id,
              tmdb_type,
              imdb_id,
              title,
              overview,
              poster_url,
              backdrop_url,
              genres,
              runtime_minutes,
              imdb_rating,
              age_rating,
              director,
              starring,
              year
            )
          ''')
          .eq('profile_id', profileId)
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      final favorites = (response as List)
          .map((json) => FavoriteTitle.fromJson(json as Map<String, dynamic>))
          .toList();

      // Update cache for first page fetch
      if (offset == 0) {
        _cache = _CachedFavorites(
          favorites: favorites,
          cachedAt: DateTime.now(),
          profileId: profileId,
        );
        debugPrint('FavoriteService: Cached ${favorites.length} favorites');
      }

      return favorites;
    } catch (e) {
      debugPrint('FavoriteService.getFavorites error: $e');
      // Return cached data on error if available
      final cached = getCachedFavorites(profileId);
      if (cached != null) {
        debugPrint('FavoriteService: Returning stale cache due to error');
        return cached;
      }
      return [];
    }
  }

  /// Get count of favorites for a profile
  static Future<int> getFavoritesCount({required String profileId}) async {
    // Use cache if available
    final cached = getCachedFavorites(profileId);
    if (cached != null) {
      return cached.length;
    }

    try {
      final response = await _supabase
          .from('profile_favorites')
          .select('id')
          .eq('profile_id', profileId);
      
      return (response as List).length;
    } catch (e) {
      debugPrint('FavoriteService.getFavoritesCount error: $e');
      return 0;
    }
  }
}
