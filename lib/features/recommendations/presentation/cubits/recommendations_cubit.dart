import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibestream/features/recommendations/presentation/cubits/recommendations_state.dart';
import 'package:vibestream/features/recommendations/domain/entities/recommendation_card.dart';
import 'package:vibestream/features/recommendations/data/interaction_service.dart';
import 'package:vibestream/features/recommendations/data/recommendation_service.dart';
import 'package:vibestream/core/services/home_refresh_service.dart';

class RecommendationsCubit extends Cubit<RecommendationsState> {
  final InteractionService _interactionService;
  final HomeRefreshService _homeRefreshService;
  StreamSubscription<StreamingRecommendationEvent>? _streamSubscription;

  RecommendationsCubit({
    InteractionService? interactionService,
    HomeRefreshService? homeRefreshService,
  })  : _interactionService = interactionService ?? InteractionService(),
        _homeRefreshService = homeRefreshService ?? HomeRefreshService(),
        super(const RecommendationsState());

  @override
  Future<void> close() {
    _streamSubscription?.cancel();
    return super.close();
  }

  /// Initialize with a pre-loaded session (non-streaming)
  void initialize(RecommendationSession session, InteractionSource source) {
    emit(state.copyWith(
      status: RecommendationsStatus.swiping,
      session: session,
      source: source,
      currentCardIndex: 0,
      swipeOffset: 0,
      swipeRotation: 0,
      totalExpectedCards: session.cards.length,
      receivedCardsCount: session.cards.length,
      clearError: true,
    ));
  }

  /// Start a streaming mood session
  void startMoodSessionStreaming({
    required String profileId,
    required String viewingStyle,
    required Map<String, double> sliders,
    required List<String> selectedGenres,
    String? freeText,
    List<String> contentTypes = const ['movie', 'tv'],
    InteractionSource source = InteractionSource.moodResults,
  }) {
    _startStreaming(
      stream: RecommendationService.createMoodSessionStreaming(
        profileId: profileId,
        viewingStyle: viewingStyle,
        sliders: sliders,
        selectedGenres: selectedGenres,
        freeText: freeText,
        contentTypes: contentTypes,
      ),
      source: source,
    );
  }

  /// Start a streaming quick match session
  void startQuickMatchSessionStreaming({
    required String profileId,
    required String quickMatchTag,
    String viewingStyle = 'personal',
    List<String> contentTypes = const ['movie', 'tv'],
    InteractionSource source = InteractionSource.quickMatch,
  }) {
    _startStreaming(
      stream: RecommendationService.createQuickMatchSessionStreaming(
        profileId: profileId,
        quickMatchTag: quickMatchTag,
        viewingStyle: viewingStyle,
        contentTypes: contentTypes,
      ),
      source: source,
    );
  }

  void _startStreaming({
    required Stream<StreamingRecommendationEvent> stream,
    required InteractionSource source,
  }) {
    // Cancel any existing stream
    _streamSubscription?.cancel();

    // Reset state for streaming
    emit(RecommendationsState(
      status: RecommendationsStatus.streaming,
      source: source,
      totalExpectedCards: 5, // Default, will be updated when session starts
      receivedCardsCount: 0,
    ));

    _streamSubscription = stream.listen(
      _handleStreamEvent,
      onError: (error) {
        debugPrint('RecommendationsCubit: Stream error: $error');
        emit(state.copyWith(
          streamingError: error.toString(),
        ));
      },
      onDone: () {
        debugPrint('RecommendationsCubit: Stream completed');
      },
    );
  }

  void _handleStreamEvent(StreamingRecommendationEvent event) {
    if (isClosed) return;

    switch (event) {
      case StreamingSessionStarted():
        debugPrint('RecommendationsCubit: Session started - ${event.sessionId}');
        // Create initial session shell
        final session = RecommendationSession(
          id: event.sessionId,
          profileId: event.profileId,
          sessionType: event.sessionType,
          moodInput: {},
          cards: [],
          createdAt: event.createdAt,
          totalExpectedCards: event.totalExpectedCards,
          isComplete: false,
        );
        emit(state.copyWith(
          session: session,
          totalExpectedCards: event.totalExpectedCards,
          receivedCardsCount: 0,
        ));
        
      case StreamingCardReceived():
        debugPrint('RecommendationsCubit: Card received - ${event.card.title}');
        if (state.session != null) {
          final updatedCards = [...state.session!.cards, event.card];
          final updatedSession = state.session!.copyWith(
            cards: updatedCards,
            isComplete: false,
          );
          emit(state.copyWith(
            session: updatedSession,
            receivedCardsCount: updatedCards.length,
          ));
        }
        
      case StreamingCompleted():
        debugPrint('RecommendationsCubit: Streaming completed with ${event.session.cards.length} cards');
        emit(state.copyWith(
          status: RecommendationsStatus.swiping,
          session: event.session,
          totalExpectedCards: event.session.cards.length,
          receivedCardsCount: event.session.cards.length,
        ));
        
      case StreamingError():
        debugPrint('RecommendationsCubit: Streaming error - ${event.message}');
        emit(state.copyWith(
          streamingError: event.message,
        ));
    }
  }

  void clearError() {
    emit(state.copyWith(clearError: true));
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
