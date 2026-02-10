import 'package:equatable/equatable.dart';
import 'package:vibestream/features/recommendations/domain/entities/recommendation_card.dart';
import 'package:vibestream/features/recommendations/data/interaction_service.dart';

enum RecommendationsStatus { 
  initial, 
  streaming,  // New: receiving cards via stream
  swiping, 
  animating, 
  completed 
}

class RecommendationsState extends Equatable {
  final RecommendationsStatus status;
  final RecommendationSession? session;
  final InteractionSource source;
  final int currentCardIndex;
  final double swipeOffset;
  final double swipeRotation;
  final int totalExpectedCards;
  final int receivedCardsCount;
  final String? streamingError;

  const RecommendationsState({
    this.status = RecommendationsStatus.initial,
    this.session,
    this.source = InteractionSource.moodResults,
    this.currentCardIndex = 0,
    this.swipeOffset = 0,
    this.swipeRotation = 0,
    this.totalExpectedCards = 5,
    this.receivedCardsCount = 0,
    this.streamingError,
  });

  List<RecommendationCard> get cards => session?.cards ?? [];
  bool get hasMoreCards => currentCardIndex < cards.length;
  bool get isAnimating => status == RecommendationsStatus.animating;
  bool get isCompleted => status == RecommendationsStatus.completed || (!isStreaming && !hasMoreCards && cards.isNotEmpty);
  bool get isStreaming => status == RecommendationsStatus.streaming;
  
  /// Returns true if there are still cards being loaded
  bool get hasMoreCardsLoading => isStreaming && receivedCardsCount < totalExpectedCards;
  
  /// Progress of streaming (0.0 to 1.0)
  double get streamingProgress => totalExpectedCards > 0 
      ? receivedCardsCount / totalExpectedCards 
      : 0.0;

  RecommendationCard? get currentCard {
    if (!hasMoreCards) return null;
    return cards[currentCardIndex];
  }

  RecommendationCard? get nextCard {
    if (currentCardIndex >= cards.length - 1) return null;
    return cards[currentCardIndex + 1];
  }

  /// Check if a placeholder should be shown at a given index
  bool shouldShowPlaceholder(int index) {
    if (!isStreaming) return false;
    return index >= cards.length && index < totalExpectedCards;
  }

  /// Get the number of placeholder cards to show
  int get placeholderCount {
    if (!isStreaming) return 0;
    return (totalExpectedCards - cards.length).clamp(0, totalExpectedCards);
  }

  RecommendationsState copyWith({
    RecommendationsStatus? status,
    RecommendationSession? session,
    InteractionSource? source,
    int? currentCardIndex,
    double? swipeOffset,
    double? swipeRotation,
    int? totalExpectedCards,
    int? receivedCardsCount,
    String? streamingError,
    bool clearError = false,
  }) {
    return RecommendationsState(
      status: status ?? this.status,
      session: session ?? this.session,
      source: source ?? this.source,
      currentCardIndex: currentCardIndex ?? this.currentCardIndex,
      swipeOffset: swipeOffset ?? this.swipeOffset,
      swipeRotation: swipeRotation ?? this.swipeRotation,
      totalExpectedCards: totalExpectedCards ?? this.totalExpectedCards,
      receivedCardsCount: receivedCardsCount ?? this.receivedCardsCount,
      streamingError: clearError ? null : (streamingError ?? this.streamingError),
    );
  }

  @override
  List<Object?> get props => [
    status, 
    session, 
    source, 
    currentCardIndex, 
    swipeOffset, 
    swipeRotation,
    totalExpectedCards,
    receivedCardsCount,
    streamingError,
  ];
}
