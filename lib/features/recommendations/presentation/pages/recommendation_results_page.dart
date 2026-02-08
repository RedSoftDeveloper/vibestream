import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/services/home_refresh_service.dart';
import 'package:vibestream/features/recommendations/domain/entities/recommendation_card.dart';
import 'package:vibestream/features/recommendations/data/interaction_service.dart';

class RecommendationResultsPage extends StatefulWidget {
  final RecommendationSession session;
  final InteractionSource source;

  const RecommendationResultsPage({
    super.key,
    required this.session,
    required this.source,
  });

  @override
  State<RecommendationResultsPage> createState() => _RecommendationResultsPageState();
}

class _RecommendationResultsPageState extends State<RecommendationResultsPage> {
  final InteractionService _interactionService = InteractionService();
  final HomeRefreshService _homeRefreshService = HomeRefreshService();
  int _currentCardIndex = 0;
  double _swipeOffset = 0;
  double _swipeRotation = 0;
  bool _isAnimating = false;

  List<RecommendationCard> get cards => widget.session.cards;
  bool get hasMoreCards => _currentCardIndex < cards.length;

  void _onSwipeLeft() {
    if (_isAnimating || !hasMoreCards) return;
    _animateSwipe(-1, InteractionAction.dislike);
  }

  void _onSwipeRight() {
    if (_isAnimating || !hasMoreCards) return;
    _animateSwipe(1, InteractionAction.like);
  }

  void _animateSwipe(int direction, InteractionAction action) async {
    setState(() => _isAnimating = true);
    final targetOffset = direction * 400.0;
    final targetRotation = direction * 0.3;

    // Log interaction
    final card = cards[_currentCardIndex];
    _interactionService.logInteraction(
      profileId: widget.session.profileId,
      titleId: card.titleId,
      sessionId: widget.session.id,
      action: action,
      source: widget.source,
    );

    // Animate out
    for (int i = 0; i < 10; i++) {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      setState(() {
        _swipeOffset += (targetOffset - _swipeOffset) * 0.3;
        _swipeRotation += (targetRotation - _swipeRotation) * 0.3;
      });
    }

    // Reset and move to next card
    setState(() {
      _currentCardIndex++;
      _swipeOffset = 0;
      _swipeRotation = 0;
      _isAnimating = false;
    });
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (_isAnimating || !hasMoreCards) return;
    setState(() {
      _swipeOffset += details.delta.dx;
      _swipeRotation = _swipeOffset / 1000;
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (_isAnimating || !hasMoreCards) return;
    final velocity = details.primaryVelocity ?? 0;
    if (_swipeOffset.abs() > 100 || velocity.abs() > 500) {
      if (_swipeOffset > 0 || velocity > 500) {
        _onSwipeRight();
      } else {
        _onSwipeLeft();
      }
    } else {
      _snapBack();
    }
  }

  void _snapBack() async {
    for (int i = 0; i < 8; i++) {
      await Future.delayed(const Duration(milliseconds: 16));
      if (!mounted) return;
      setState(() {
        _swipeOffset *= 0.6;
        _swipeRotation *= 0.6;
      });
    }
    setState(() {
      _swipeOffset = 0;
      _swipeRotation = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 16),
              _buildHeader(context, isDark),
              const SizedBox(height: 24),
              Text(
                'Your Recommendations',
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                'Swipe right on films you love, left on ones you don\'t',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 16),
              _buildProgressIndicator(isDark),
              const SizedBox(height: 16),
              Expanded(child: _buildCardStack(isDark)),
              const SizedBox(height: 20),
              if (hasMoreCards) _buildActionButtons(isDark),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateBack(BuildContext context) {
    // Request home page refresh before navigating back
    _homeRefreshService.requestRefresh();
    // Always go to home page to avoid returning to already completed flows
    context.go('/home');
  }

  Widget _buildHeader(BuildContext context, bool isDark) {
    return Row(
      children: [
        GestureDetector(
          onTap: () => _navigateBack(context),
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface,
              shape: BoxShape.circle,
              boxShadow: isDark ? null : [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Icon(
              Icons.chevron_left,
              color: isDark ? AppColors.darkText : AppColors.lightText,
              size: 28,
            ),
          ),
        ),
        const Spacer(),
        Text(
          _getSourceTitle(),
          style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const Spacer(),
        const SizedBox(width: 48),
      ],
    );
  }

  String _getSourceTitle() {
    switch (widget.source) {
      case InteractionSource.quickMatch:
        return 'Quick Match';
      case InteractionSource.moodResults:
        return 'Mood Results';
      default:
        return 'Recommendations';
    }
  }

  Widget _buildProgressIndicator(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        cards.length,
        (index) => Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: index == _currentCardIndex ? 24 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: index == _currentCardIndex
                ? (isDark ? AppColors.darkText : AppColors.lightText)
                : index < _currentCardIndex
                    ? AppColors.accent
                    : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightBorder),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  Widget _buildCardStack(bool isDark) {
    if (!hasMoreCards) {
      return _buildCompletionState(isDark);
    }

    return Stack(
      alignment: Alignment.center,
      children: [
        // Next card preview
        if (_currentCardIndex < cards.length - 1)
          Transform.scale(
            scale: 0.95,
            child: Opacity(
              opacity: 0.5,
              child: _RecommendationCardWidget(
                card: cards[_currentCardIndex + 1],
                isDark: isDark,
              ),
            ),
          ),
        // Current card with drag
        GestureDetector(
          onHorizontalDragUpdate: _onDragUpdate,
          onHorizontalDragEnd: _onDragEnd,
          child: Transform.translate(
            offset: Offset(_swipeOffset, 0),
            child: Transform.rotate(
              angle: _swipeRotation,
              child: _RecommendationCardWidget(
                card: cards[_currentCardIndex],
                isDark: isDark,
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildCompletionState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 80,
            color: AppColors.accent,
          ),
          const SizedBox(height: 24),
          Text(
            'All done!',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            'You\'ve gone through all recommendations',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          // Leave Feedback button
          ElevatedButton.icon(
            onPressed: () => _navigateToFeedback(context),
            icon: const Icon(Icons.rate_review_outlined, size: 20),
            label: const Text('Leave Feedback'),
            style: ElevatedButton.styleFrom(
              backgroundColor: isDark ? AppColors.lightSurface : AppColors.lightText,
              foregroundColor: isDark ? AppColors.lightText : AppColors.lightSurface,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            ),
          ),
          const SizedBox(height: 16),
          // Back to Home button (outlined style)
          OutlinedButton(
            onPressed: () => _navigateBack(context),
            style: OutlinedButton.styleFrom(
              foregroundColor: isDark ? AppColors.darkText : AppColors.lightText,
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              side: BorderSide(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightBorder,
                width: 1.5,
              ),
            ),
            child: const Text('Back to Home'),
          ),
        ],
      ),
    );
  }
  
  void _navigateToFeedback(BuildContext context) {
    // Get all title IDs from the session
    final allTitleIds = cards.map((c) => c.titleId).toList();
    if (allTitleIds.isEmpty) return;
    
    // Start with the last card (most recent) and allow cycling through all
    final lastTitleId = allTitleIds.last;
    final remainingIds = allTitleIds.where((id) => id != lastTitleId).toList();
    
    context.push(
      AppRoutes.shareExperienceFromRecommendationsPath(
        lastTitleId,
        sessionId: widget.session.id,
        remainingTitleIds: remainingIds,
      ),
    );
  }

  Widget _buildActionButtons(bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _onSwipeLeft,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightBorder,
                width: 1.5,
              ),
            ),
            child: Icon(Icons.close, color: isDark ? AppColors.darkText : AppColors.lightText, size: 24),
          ),
        ),
        const SizedBox(width: 32),
        GestureDetector(
          onTap: _onSwipeRight,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightBorder,
                width: 1.5,
              ),
            ),
            child: Icon(Icons.favorite_border, color: isDark ? AppColors.darkText : AppColors.lightText, size: 24),
          ),
        ),
      ],
    );
  }
}

class _RecommendationCardWidget extends StatelessWidget {
  final RecommendationCard card;
  final bool isDark;

  const _RecommendationCardWidget({required this.card, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final cardBgColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Adapt to available height - use smaller image on shorter screens
        final availableHeight = constraints.maxHeight;
        final isCompact = availableHeight < 450;
        final imageAspectRatio = isCompact ? 16 / 8 : 16 / 10;
        final contentPadding = isCompact ? 12.0 : 16.0;
        final spacingSmall = isCompact ? 6.0 : 8.0;
        final spacingMedium = isCompact ? 8.0 : 12.0;

        return Container(
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: BorderRadius.circular(24),
            boxShadow: isDark ? null : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.08),
                blurRadius: 20,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                child: Stack(
                  children: [
                    AspectRatio(
                      aspectRatio: imageAspectRatio,
                      child: card.posterUrl != null && card.posterUrl!.isNotEmpty
                          ? Image.network(
                              card.posterUrl!,
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) => _buildPlaceholder(),
                            )
                          : _buildPlaceholder(),
                    ),
                    Positioned(
                      top: 12,
                      left: 12,
                      child: Row(
                        children: card.genres.take(2).map((genre) => Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: _GlassChip(label: genre),
                        )).toList(),
                      ),
                    ),
                    if (card.quote.isNotEmpty)
                      Positioned(
                        bottom: 12,
                        left: 0,
                        right: 0,
                        child: Center(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              card.quote,
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: AppColors.accent.withValues(alpha: 0.9),
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.all(contentPadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _RatingBadge(label: 'IMDb - ${card.rating}', isDark: isDark),
                          const SizedBox(width: 8),
                          if (card.ageRating.isNotEmpty)
                            _RatingBadge(label: card.ageRating, isDark: isDark),
                        ],
                      ),
                      SizedBox(height: spacingMedium),
                      Text(
                        card.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: isDark ? AppColors.darkText : AppColors.lightText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: spacingSmall / 2),
                      Text(
                        '${card.year}, ${card.duration}',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                        ),
                      ),
                      SizedBox(height: spacingMedium),
                      Expanded(
                        child: Text(
                          card.description,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                            height: 1.4,
                          ),
                          overflow: TextOverflow.ellipsis,
                          maxLines: isCompact ? 3 : 4,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildPlaceholder() => Container(
    color: AppColors.accent.withValues(alpha: 0.2),
    child: const Center(child: Icon(Icons.movie, size: 48, color: Colors.white54)),
  );
}

class _GlassChip extends StatelessWidget {
  final String label;
  const _GlassChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.3), width: 1),
          ),
          child: Text(
            label,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.black87),
          ),
        ),
      ),
    );
  }
}

class _RatingBadge extends StatelessWidget {
  final String label;
  final bool isDark;
  const _RatingBadge({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDark ? AppColors.darkTextSecondary : AppColors.lightBorder,
          width: 1,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? AppColors.darkText : AppColors.lightText,
        ),
      ),
    );
  }
}
