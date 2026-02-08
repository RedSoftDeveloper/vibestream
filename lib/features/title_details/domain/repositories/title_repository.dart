import 'package:vibestream/features/title_details/domain/entities/title_entity.dart';

/// Abstract repository interface for title-related operations.
/// Implementations will connect to TMDB, OMDb, and other services.
abstract class TitleRepository {
  /// Search titles by query string
  /// TODO: Implement TMDB search API call
  Future<List<TitleEntity>> searchTitles(String query, {TitleType? type});

  /// Get title details by ID
  /// TODO: Implement TMDB details + OMDb ratings API calls
  Future<TitleEntity> getTitleDetails(String id);

  /// Get trending titles
  /// TODO: Implement TMDB trending API
  Future<List<TitleEntity>> getTrendingTitles({TitleType? type});

  /// Get titles by genre
  /// TODO: Implement TMDB discover with genre filter
  Future<List<TitleEntity>> getTitlesByGenre(String genreId, {TitleType? type});

  /// Get recommended titles based on a title
  /// TODO: Implement TMDB recommendations API
  Future<List<TitleEntity>> getRecommendations(String titleId);

  /// Get similar titles
  /// TODO: Implement TMDB similar API
  Future<List<TitleEntity>> getSimilarTitles(String titleId);
}

/// Abstract repository for streaming availability data
abstract class StreamingAvailabilityRepository {
  /// Get streaming providers for a title in a specific region
  /// TODO: Implement TMDB watch providers API
  Future<List<StreamingProvider>> getStreamingProviders(
    String titleId, {
    String region = 'US',
  });
}

/// Abstract repository for ratings from multiple sources
abstract class RatingsRepository {
  /// Get ratings from OMDb using IMDb ID
  /// TODO: Implement OMDb API call
  Future<TitleRatings> getRatings(String imdbId);
}
