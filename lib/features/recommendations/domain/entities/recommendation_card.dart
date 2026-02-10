class RecommendationCard {
  final String titleId;
  final String title;
  final String year;
  final String duration;
  final List<String> genres;
  final String rating;
  final String ageRating;
  final String quote;
  final String description;
  final String? posterUrl;
  final int? matchScore;
  final String? tmdbType; // "movie" or "tv"
  final String? director;
  final List<String> starring;

  RecommendationCard({
    required this.titleId,
    required this.title,
    required this.year,
    required this.duration,
    required this.genres,
    required this.rating,
    required this.ageRating,
    required this.quote,
    required this.description,
    this.posterUrl,
    this.matchScore,
    this.tmdbType,
    this.director,
    this.starring = const [],
  });

  bool get isMovie => tmdbType == 'movie';
  bool get isTvShow => tmdbType == 'tv';

  factory RecommendationCard.fromJson(Map<String, dynamic> json) {
    return RecommendationCard(
      titleId: json['title_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      year: json['year']?.toString() ?? '',
      duration: json['duration'] as String? ?? '',
      genres: (json['genres'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      rating: json['rating']?.toString() ?? '',
      ageRating: json['age_rating'] as String? ?? '',
      quote: json['quote'] as String? ?? '',
      description: json['description'] as String? ?? '',
      posterUrl: json['poster_url'] as String?,
      matchScore: json['match_score'] as int?,
      tmdbType: json['tmdb_type'] as String?,
      director: json['director'] as String?,
      starring: (json['starring'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'title_id': titleId,
    'title': title,
    'year': year,
    'duration': duration,
    'genres': genres,
    'rating': rating,
    'age_rating': ageRating,
    'quote': quote,
    'description': description,
    'poster_url': posterUrl,
    'match_score': matchScore,
    'tmdb_type': tmdbType,
    'director': director,
    'starring': starring,
  };
}

class RecommendationSession {
  final String id;
  final String profileId;
  final String sessionType;
  final Map<String, dynamic> moodInput;
  final List<RecommendationCard> cards;
  final DateTime createdAt;
  final int totalExpectedCards;
  final bool isComplete;

  RecommendationSession({
    required this.id,
    required this.profileId,
    required this.sessionType,
    required this.moodInput,
    required this.cards,
    required this.createdAt,
    this.totalExpectedCards = 5,
    this.isComplete = true,
  });

  factory RecommendationSession.fromJson(Map<String, dynamic> json) {
    final cardsJson = json['cards'] as List<dynamic>? ?? [];
    return RecommendationSession(
      id: json['id'] as String? ?? '',
      profileId: json['profile_id'] as String? ?? '',
      sessionType: json['session_type'] as String? ?? '',
      moodInput: json['mood_input'] as Map<String, dynamic>? ?? {},
      cards: cardsJson.map((c) => RecommendationCard.fromJson(c as Map<String, dynamic>)).toList(),
      createdAt: json['created_at'] != null 
          ? DateTime.parse(json['created_at'] as String) 
          : DateTime.now(),
      totalExpectedCards: json['total_expected'] as int? ?? 5,
      isComplete: json['is_complete'] as bool? ?? true,
    );
  }

  RecommendationSession copyWith({
    String? id,
    String? profileId,
    String? sessionType,
    Map<String, dynamic>? moodInput,
    List<RecommendationCard>? cards,
    DateTime? createdAt,
    int? totalExpectedCards,
    bool? isComplete,
  }) {
    return RecommendationSession(
      id: id ?? this.id,
      profileId: profileId ?? this.profileId,
      sessionType: sessionType ?? this.sessionType,
      moodInput: moodInput ?? this.moodInput,
      cards: cards ?? this.cards,
      createdAt: createdAt ?? this.createdAt,
      totalExpectedCards: totalExpectedCards ?? this.totalExpectedCards,
      isComplete: isComplete ?? this.isComplete,
    );
  }
}

/// Represents a streaming event from the recommendation service
sealed class StreamingRecommendationEvent {}

/// Session metadata received at the start of streaming
class StreamingSessionStarted extends StreamingRecommendationEvent {
  final String sessionId;
  final String profileId;
  final String sessionType;
  final int totalExpectedCards;
  final DateTime createdAt;

  StreamingSessionStarted({
    required this.sessionId,
    required this.profileId,
    required this.sessionType,
    required this.totalExpectedCards,
    required this.createdAt,
  });
}

/// A new card arrived during streaming
class StreamingCardReceived extends StreamingRecommendationEvent {
  final RecommendationCard card;
  final int cardIndex;

  StreamingCardReceived({
    required this.card,
    required this.cardIndex,
  });
}

/// Streaming completed successfully
class StreamingCompleted extends StreamingRecommendationEvent {
  final RecommendationSession session;

  StreamingCompleted({required this.session});
}

/// Streaming encountered an error
class StreamingError extends StreamingRecommendationEvent {
  final String message;

  StreamingError({required this.message});
}
