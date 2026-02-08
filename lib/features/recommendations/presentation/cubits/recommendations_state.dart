import 'package:equatable/equatable.dart';
import 'package:vibestream/features/recommendations/domain/entities/recommendation_card.dart';
import 'package:vibestream/features/recommendations/data/interaction_service.dart';

enum RecommendationsStatus { initial, swiping, animating, completed }

class RecommendationsState extends Equatable {
  final RecommendationsStatus status;
  final RecommendationSession? session;
  final InteractionSource source;
  final int currentCardIndex;
  final double swipeOffset;
  final double swipeRotation;

  const RecommendationsState({
    this.status = RecommendationsStatus.initial,
    this.session,
    this.source = InteractionSource.moodResults,
    this.currentCardIndex = 0,
    this.swipeOffset = 0,
    this.swipeRotation = 0,
  });

  List<RecommendationCard> get cards => session?.cards ?? [];
  bool get hasMoreCards => currentCardIndex < cards.length;
  bool get isAnimating => status == RecommendationsStatus.animating;
  bool get isCompleted => status == RecommendationsStatus.completed || !hasMoreCards;

  RecommendationCard? get currentCard {
    if (!hasMoreCards) return null;
    return cards[currentCardIndex];
  }

  RecommendationCard? get nextCard {
    if (currentCardIndex >= cards.length - 1) return null;
    return cards[currentCardIndex + 1];
  }

  RecommendationsState copyWith({
    RecommendationsStatus? status,
    RecommendationSession? session,
    InteractionSource? source,
    int? currentCardIndex,
    double? swipeOffset,
    double? swipeRotation,
  }) {
    return RecommendationsState(
      status: status ?? this.status,
      session: session ?? this.session,
      source: source ?? this.source,
      currentCardIndex: currentCardIndex ?? this.currentCardIndex,
      swipeOffset: swipeOffset ?? this.swipeOffset,
      swipeRotation: swipeRotation ?? this.swipeRotation,
    );
  }

  @override
  List<Object?> get props => [status, session, source, currentCardIndex, swipeOffset, swipeRotation];
}
