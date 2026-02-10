import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/services/home_refresh_service.dart';
import 'package:vibestream/features/recommendations/domain/entities/recommendation_card.dart';
import 'package:vibestream/features/recommendations/data/interaction_service.dart';
import 'package:vibestream/features/recommendations/presentation/cubits/recommendations_cubit.dart';
import 'package:vibestream/features/recommendations/presentation/cubits/recommendations_state.dart';

class RecommendationResultsPage extends StatefulWidget {
  final RecommendationSession? session;
  final InteractionSource source;
  
  // Streaming parameters (used when session is null)
  final String? profileId;
  final String? viewingStyle;
  final Map<String, double>? sliders;
  final List<String>? selectedGenres;
  final String? freeText;
  final List<String>? contentTypes;
  final String? quickMatchTag;

  const RecommendationResultsPage({
    super.key,
    this.session,
    required this.source,
    this.profileId,
    this.viewingStyle,
    this.sliders,
    this.selectedGenres,
    this.freeText,
    this.contentTypes,
    this.quickMatchTag,
  });

  @override
  State<RecommendationResultsPage> createState() => _RecommendationResultsPageState();
}

class _RecommendationResultsPageState extends State<RecommendationResultsPage> {
  late final RecommendationsCubit _cubit;
  final HomeRefreshService _homeRefreshService = HomeRefreshService();

  @override
  void initState() {
    super.initState();
    _cubit = RecommendationsCubit();
    _initializeSession();
  }

  void _initializeSession() {
    if (widget.session != null) {
      // Non-streaming: use pre-loaded session
      _cubit.initialize(widget.session!, widget.source);
    } else if (widget.profileId != null) {
      // Streaming: start streaming session
      if (widget.quickMatchTag != null) {
        _cubit.startQuickMatchSessionStreaming(
          profileId: widget.profileId!,
          quickMatchTag: widget.quickMatchTag!,
          viewingStyle: widget.viewingStyle ?? 'personal',
          contentTypes: widget.contentTypes ?? ['movie', 'tv'],
          source: widget.source,
        );
      } else if (widget.sliders != null && widget.selectedGenres != null) {
        _cubit.startMoodSessionStreaming(
          profileId: widget.profileId!,
          viewingStyle: widget.viewingStyle ?? 'personal',
          sliders: widget.sliders!,
          selectedGenres: widget.selectedGenres!,
          freeText: widget.freeText,
          contentTypes: widget.contentTypes ?? ['movie', 'tv'],
          source: widget.source,
        );
      }
    }
  }

  @override
  void dispose() {
    _cubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return BlocProvider.value(
      value: _cubit,
      child: Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: BlocBuilder<RecommendationsCubit, RecommendationsState>(
              builder: (context, state) {
                // Show error state
                if (state.streamingError != null) {
                  return _buildErrorState(context, isDark, state.streamingError!);
                }

                return Column(
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
                      state.isStreaming 
                          ? 'Finding perfect matches for you...'
                          : 'Swipe right on films you love, left on ones you don\'t',
                      style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildProgressIndicator(context, isDark, state),
                    const SizedBox(height: 16),
                    Expanded(child: _buildCardStack(context, isDark, state)),
                    const SizedBox(height: 20),
                    if (state.hasMoreCards && !state.isStreaming) _buildActionButtons(context, isDark),
                    if (state.isStreaming) _buildStreamingIndicator(context, isDark, state),
                    const SizedBox(height: 24),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, bool isDark, String error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            const SizedBox(height: 24),
            Text(
              'Something went wrong',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              error,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => _navigateBack(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: isDark ? AppColors.lightSurface : AppColors.lightText,
                foregroundColor: isDark ? AppColors.lightText : AppColors.lightSurface,
                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
              ),
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateBack(BuildContext context) {
    _homeRefreshService.requestRefresh();
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

  Widget _buildProgressIndicator(BuildContext context, bool isDark, RecommendationsState state) {
    final totalDots = state.totalExpectedCards;
    final currentIndex = state.currentCardIndex;
    final receivedCount = state.receivedCardsCount;
    final isStreaming = state.isStreaming;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(
        totalDots,
        (index) {
          final isCurrentCard = index == currentIndex;
          final isPastCard = index < currentIndex;
          final isLoaded = index < receivedCount;
          final isLoading = isStreaming && !isLoaded;

          if (isLoading) {
            // Shimmer for loading dots
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Shimmer.fromColors(
                baseColor: isDark 
                    ? AppColors.darkSurfaceVariant 
                    : AppColors.lightBorder,
                highlightColor: isDark 
                    ? AppColors.darkTextSecondary 
                    : AppColors.lightTextSecondary,
                child: Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            );
          }

          return Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            width: isCurrentCard ? 24 : 8,
            height: 8,
            decoration: BoxDecoration(
              color: isCurrentCard
                  ? (isDark ? AppColors.darkText : AppColors.lightText)
                  : isPastCard
                      ? AppColors.accent
                      : (isDark ? AppColors.darkSurfaceVariant : AppColors.lightBorder),
              borderRadius: BorderRadius.circular(4),
            ),
          );
        },
      ),
    );
  }

  Widget _buildCardStack(BuildContext context, bool isDark, RecommendationsState state) {
    // Show completion state (only when all cards are exhausted)
    if (state.isCompleted && !state.isStreaming && state.cards.isNotEmpty) {
      return _buildCompletionState(context, isDark, state);
    }

    // Show shimmer loading while streaming with no cards yet
    if (state.cards.isEmpty) {
      return _buildStreamingShimmerCard(isDark);
    }

    // Show card stack (works during streaming and after)
    return Stack(
      alignment: Alignment.center,
      children: [
        // Background shimmer placeholder for next loading card
        if (state.isStreaming && state.currentCardIndex >= state.cards.length - 1) 
          Positioned.fill(
            child: Transform.scale(
              scale: 0.95,
              child: Opacity(
                opacity: 0.5,
                child: _buildShimmerCardPlaceholder(isDark),
              ),
            ),
          ),
        
        // Next card preview (if available)
        if (state.nextCard != null)
          Transform.scale(
            scale: 0.95,
            child: Opacity(
              opacity: 0.5,
              child: _RecommendationCardWidget(
                card: state.nextCard!,
                isDark: isDark,
              ),
            ),
          ),
        
        // Current card with drag (if available)
        if (state.currentCard != null)
          GestureDetector(
            onHorizontalDragUpdate: state.isStreaming ? null : (details) => _cubit.onDragUpdate(details.delta.dx),
            onHorizontalDragEnd: state.isStreaming ? null : (details) => _cubit.onDragEnd(details.primaryVelocity),
            child: Transform.translate(
              offset: Offset(state.swipeOffset, 0),
              child: Transform.rotate(
                angle: state.swipeRotation,
                child: _RecommendationCardWidget(
                  card: state.currentCard!,
                  isDark: isDark,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStreamingShimmerCard(bool isDark) {
    return _buildShimmerCardPlaceholder(isDark);
  }

  Widget _buildShimmerCardPlaceholder(bool isDark) {
    final cardBgColor = isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurface;
    final shimmerBase = isDark ? AppColors.darkSurfaceVariant : Colors.grey[300]!;
    final shimmerHighlight = isDark ? AppColors.darkTextSecondary : Colors.grey[100]!;

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
      child: Shimmer.fromColors(
        baseColor: shimmerBase,
        highlightColor: shimmerHighlight,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Image placeholder
            ClipRRect(
              borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
              child: AspectRatio(
                aspectRatio: 16 / 10,
                child: Container(
                  color: Colors.white,
                ),
              ),
            ),
            // Content placeholder
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating badges
                    Row(
                      children: [
                        Container(
                          width: 70,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          width: 45,
                          height: 24,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Title
                    Container(
                      width: double.infinity,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Year/duration
                    Container(
                      width: 120,
                      height: 16,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Description lines
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: double.infinity,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      width: 200,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamingIndicator(BuildContext context, bool isDark, RecommendationsState state) {
    return Column(
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: state.streamingProgress,
            backgroundColor: isDark ? AppColors.darkSurfaceVariant : AppColors.lightBorder,
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.accent),
            minHeight: 4,
          ),
        ),
        const SizedBox(height: 12),
        // Status text
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              'Loading ${state.receivedCardsCount}/${state.totalExpectedCards} recommendations...',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCompletionState(BuildContext context, bool isDark, RecommendationsState state) {
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
            onPressed: () => _navigateToFeedback(context, state),
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
  
  void _navigateToFeedback(BuildContext context, RecommendationsState state) {
    final allTitleIds = state.cards.map((c) => c.titleId).toList();
    if (allTitleIds.isEmpty) return;
    
    final lastTitleId = allTitleIds.last;
    final remainingIds = allTitleIds.where((id) => id != lastTitleId).toList();
    
    context.push(
      AppRoutes.shareExperienceFromRecommendationsPath(
        lastTitleId,
        sessionId: state.session?.id ?? '',
        remainingTitleIds: remainingIds,
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context, bool isDark) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        GestureDetector(
          onTap: _cubit.swipeLeft,
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
          onTap: _cubit.swipeRight,
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
                    Positioned.fill(
                      child: IgnorePointer(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.black.withValues(alpha: 0.18),
                                Colors.black.withValues(alpha: 0.55),
                              ],
                              stops: const [0.45, 0.75, 1.0],
                            ),
                          ),
                        ),
                      ),
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
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                          child: Center(
                            child: _QuoteOverlay(text: card.quote),
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

class _QuoteOverlay extends StatelessWidget {
  final String text;
  const _QuoteOverlay({required this.text});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.42),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18), width: 1),
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelMedium?.copyWith(
              fontStyle: FontStyle.italic,
              height: 1.35,
              color: Colors.white.withValues(alpha: 0.92),
              shadows: [
                Shadow(
                  color: Colors.black.withValues(alpha: 0.65),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
