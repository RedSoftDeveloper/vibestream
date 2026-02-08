import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibestream/features/recommendations/presentation/cubits/recommendations_state.dart';
import 'package:vibestream/features/recommendations/domain/entities/recommendation_card.dart';
import 'package:vibestream/features/recommendations/data/interaction_service.dart';
import 'package:vibestream/core/services/home_refresh_service.dart';

class RecommendationsCubit extends Cubit<RecommendationsState> {
  final InteractionService _interactionService;
  final HomeRefreshService _homeRefreshService;

  RecommendationsCubit({
    InteractionService? interactionService,
    HomeRefreshService? homeRefreshService,
  })  : _interactionService = interactionService ?? InteractionService(),
        _homeRefreshService = homeRefreshService ?? HomeRefreshService(),
        super(const RecommendationsState());

  void initialize(RecommendationSession session, InteractionSource source) {
    emit(state.copyWith(
      status: RecommendationsStatus.swiping,
      session: session,
      source: source,
      currentCardIndex: 0,
      swipeOffset: 0,
      swipeRotation: 0,
    ));
  }

  void onDragUpdate(double deltaX) {
    if (state.isAnimating || !state.hasMoreCards) return;
    emit(state.copyWith(
      swipeOffset: state.swipeOffset + deltaX,
      swipeRotation: (state.swipeOffset + deltaX) / 1000,
    ));
  }

  void onDragEnd(double? primaryVelocity) {
    if (state.isAnimating || !state.hasMoreCards) return;
    
    final velocity = primaryVelocity ?? 0;
    if (state.swipeOffset.abs() > 100 || velocity.abs() > 500) {
      if (state.swipeOffset > 0 || velocity > 500) {
        _swipe(InteractionAction.like, 1);
      } else {
        _swipe(InteractionAction.dislike, -1);
      }
    } else {
      _snapBack();
    }
  }

  void swipeLeft() {
    if (state.isAnimating || !state.hasMoreCards) return;
    _swipe(InteractionAction.dislike, -1);
  }

  void swipeRight() {
    if (state.isAnimating || !state.hasMoreCards) return;
    _swipe(InteractionAction.like, 1);
  }

  Future<void> _swipe(InteractionAction action, int direction) async {
    emit(state.copyWith(status: RecommendationsStatus.animating));

    // Log interaction
    final card = state.currentCard;
    if (card != null && state.session != null) {
      _interactionService.logInteraction(
        profileId: state.session!.profileId,
        titleId: card.titleId,
        sessionId: state.session!.id,
        action: action,
        source: state.source,
      );
    }

    // Animate out
    final targetOffset = direction * 400.0;
    final targetRotation = direction * 0.3;

    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 16));
      if (isClosed) return;
      
      emit(state.copyWith(
        swipeOffset: state.swipeOffset + (targetOffset - state.swipeOffset) * 0.3,
        swipeRotation: state.swipeRotation + (targetRotation - state.swipeRotation) * 0.3,
      ));
    }

    // Move to next card
    final nextIndex = state.currentCardIndex + 1;
    final isCompleted = nextIndex >= state.cards.length;

    emit(state.copyWith(
      status: isCompleted ? RecommendationsStatus.completed : RecommendationsStatus.swiping,
      currentCardIndex: nextIndex,
      swipeOffset: 0,
      swipeRotation: 0,
    ));
  }

  Future<void> _snapBack() async {
    for (int i = 0; i < 8; i++) {
      await Future.delayed(const Duration(milliseconds: 16));
      if (isClosed) return;
      
      emit(state.copyWith(
        swipeOffset: state.swipeOffset * 0.6,
        swipeRotation: state.swipeRotation * 0.6,
      ));
    }

    emit(state.copyWith(
      swipeOffset: 0,
      swipeRotation: 0,
    ));
  }

  void requestHomeRefresh() {
    _homeRefreshService.requestRefresh();
  }

  List<String> get allTitleIds => state.cards.map((c) => c.titleId).toList();
}
