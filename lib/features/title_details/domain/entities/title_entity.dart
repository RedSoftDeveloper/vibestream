import 'package:equatable/equatable.dart';

enum TitleType { movie, series }

class TitleEntity extends Equatable {
  final String id;
  final String tmdbId;
  final String? imdbId;
  final String title;
  final String? overview;
  final String? posterPath;
  final String? backdropPath;
  final DateTime? releaseDate;
  final TitleType type;
  final List<String> genres;
  final int? runtime;
  final double? voteAverage;
  final int? voteCount;
  final List<String> vibeTags;
  final String? vibeExplanation;
  final TitleRatings? ratings;
  final List<StreamingProvider> streamingProviders;
  final String? ageRating;
  final String? director;
  final List<String> starring;
  final int? moodMatchPercent;
  final DateTime createdAt;
  final DateTime updatedAt;

  const TitleEntity({
    required this.id,
    required this.tmdbId,
    this.imdbId,
    required this.title,
    this.overview,
    this.posterPath,
    this.backdropPath,
    this.releaseDate,
    required this.type,
    this.genres = const [],
    this.runtime,
    this.voteAverage,
    this.voteCount,
    this.vibeTags = const [],
    this.vibeExplanation,
    this.ratings,
    this.streamingProviders = const [],
    this.ageRating,
    this.director,
    this.starring = const [],
    this.moodMatchPercent,
    required this.createdAt,
    required this.updatedAt,
  });

  String get year => releaseDate?.year.toString() ?? 'N/A';
  
  String get runtimeFormatted {
    if (runtime == null) return 'N/A';
    final hours = runtime! ~/ 60;
    final minutes = runtime! % 60;
    if (hours > 0) return '${hours}h ${minutes}m';
    return '${minutes}m';
  }

  @override
  List<Object?> get props => [id, tmdbId, title, type];
}

class TitleRatings extends Equatable {
  final double? imdbRating;
  final String? imdbVotes;
  final int? rottenTomatoesCritics;
  final int? rottenTomatoesAudience;
  final int? metacritic;

  const TitleRatings({
    this.imdbRating,
    this.imdbVotes,
    this.rottenTomatoesCritics,
    this.rottenTomatoesAudience,
    this.metacritic,
  });

  @override
  List<Object?> get props => [
        imdbRating,
        rottenTomatoesCritics,
        rottenTomatoesAudience,
        metacritic,
      ];
}

class StreamingProvider extends Equatable {
  final String id;
  final String name;
  final String? logoPath;
  final String type; // 'flatrate', 'rent', 'buy'

  const StreamingProvider({
    required this.id,
    required this.name,
    this.logoPath,
    required this.type,
  });

  @override
  List<Object?> get props => [id, name, type];
}
