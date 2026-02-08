import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:shimmer/shimmer.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/utils/snackbar_utils.dart';
import 'package:vibestream/features/recommendations/data/recommendation_service.dart';
import 'package:vibestream/features/recommendations/data/interaction_service.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';
import 'package:vibestream/features/favorites/data/favorite_service.dart';
import 'package:vibestream/features/title_details/data/streaming_provider_service.dart';

class TitleDetailsPage extends StatefulWidget {
  final String titleId;
  final int? matchScore;

  const TitleDetailsPage({super.key, required this.titleId, this.matchScore});

  @override
  State<TitleDetailsPage> createState() => _TitleDetailsPageState();
}

class _TitleDetailsPageState extends State<TitleDetailsPage> {
  TitleDetail? _title;
  List<TitleDetail> _moreSuggestions = [];
  List<StreamingAvailability> _streamingProviders = [];
  String? _watchProviderLink;
  bool _isLoading = true;
  bool _hasError = false;
  bool _isFavorite = false;
  bool _isFavoriteLoading = false;
  bool _hasFeedback = false;
  int _currentSuggestionIndex = 0;
  final PageController _pageController = PageController();
  final ProfileService _profileService = ProfileService();
  final InteractionService _interactionService = InteractionService();
  final StreamingProviderService _streamingProviderService = StreamingProviderService();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  Future<void> _toggleFavorite() async {
    final profileId = _profileService.selectedProfileId;
    if (profileId == null || _isFavoriteLoading) return;

    setState(() => _isFavoriteLoading = true);

    final success = await FavoriteService.toggleFavorite(
      profileId: profileId,
      titleId: widget.titleId,
    );

    if (success && mounted) {
      setState(() {
        _isFavorite = !_isFavorite;
        _isFavoriteLoading = false;
      });
      
      if (_isFavorite) {
        SnackbarUtils.showSuccess(context, 'Added to favorites', duration: const Duration(seconds: 2));
      } else {
        SnackbarUtils.showInfo(context, 'Removed from favorites', duration: const Duration(seconds: 2));
      }
    } else if (mounted) {
      setState(() => _isFavoriteLoading = false);
      SnackbarUtils.showError(context, 'Failed to update favorites', duration: const Duration(seconds: 2));
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _hasError = false;
    });

    try {
      // Load title details
      final title = await RecommendationService.getTitleById(widget.titleId);
      
      if (title == null) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
        return;
      }

      // Load more suggestions, check feedback status, check favorite status, and streaming providers
      final profileId = _profileService.selectedProfileId;
      List<TitleDetail> suggestions = [];
      bool hasFeedback = false;
      bool isFavorite = false;
      List<StreamingAvailability> streamingProviders = [];
      String? watchProviderLink;
      
      // Fetch streaming providers and watch link in parallel with other data
      final providersFutures = Future.wait([
        _streamingProviderService.getAvailabilityForTitle(titleId: widget.titleId),
        _streamingProviderService.getWatchProviderLink(widget.titleId),
      ]);
      
      if (profileId != null) {
        final results = await Future.wait([
          RecommendationService.getMoreSuggestions(
            profileId,
            excludeTitleId: widget.titleId,
            limit: 5,
          ),
          _interactionService.hasTitleFeedback(
            profileId: profileId,
            titleId: widget.titleId,
          ),
          FavoriteService.isFavorite(
            profileId: profileId,
            titleId: widget.titleId,
          ),
          providersFutures,
        ]);
        suggestions = results[0] as List<TitleDetail>;
        hasFeedback = results[1] as bool;
        isFavorite = results[2] as bool;
        final providersResult = results[3] as List<dynamic>;
        streamingProviders = providersResult[0] as List<StreamingAvailability>;
        watchProviderLink = providersResult[1] as String?;
      } else {
        // Still load streaming providers even without a profile
        final providersResult = await providersFutures;
        streamingProviders = providersResult[0] as List<StreamingAvailability>;
        watchProviderLink = providersResult[1] as String?;
      }

      if (mounted) {
        setState(() {
          _title = title;
          _moreSuggestions = suggestions;
          _hasFeedback = hasFeedback;
          _isFavorite = isFavorite;
          _streamingProviders = streamingProviders;
          _watchProviderLink = watchProviderLink;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('TitleDetailsPage: Error loading data: $e');
      if (mounted) {
        setState(() {
          _hasError = true;
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_isLoading) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        body: _TitleDetailsShimmer(isDark: isDark),
      );
    }

    if (_hasError || _title == null) {
      return Scaffold(
        backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new_rounded, 
              color: isDark ? AppColors.darkText : AppColors.lightText),
            onPressed: () => context.pop(),
          ),
        ),
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.movie_filter_outlined,
                size: 64,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                'Title not found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: isDark ? AppColors.darkText : AppColors.lightText,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'The movie or show you\'re looking for doesn\'t exist',
                style: TextStyle(
                  fontSize: 14,
                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.home),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
                ),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }

    final currentTitle = _title!;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ImageSection(
                title: currentTitle,
                isDark: isDark,
                isFavorite: _isFavorite,
                isFavoriteLoading: _isFavoriteLoading,
                onFavoriteToggle: _toggleFavorite,
                onBack: () => context.pop(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TitleInfoSection(title: currentTitle, isDark: isDark),
                    const SizedBox(height: 20),
                    if (currentTitle.description?.isNotEmpty == true)
                      _DescriptionText(overview: currentTitle.description!, isDark: isDark),
                    const SizedBox(height: 20),
                    _MoodMatchCard(title: currentTitle, isDark: isDark, passedMatchScore: widget.matchScore),
                    const SizedBox(height: 24),
                    if (_moreSuggestions.isNotEmpty)
                      _MoreSuggestionsSection(
                        suggestions: _moreSuggestions,
                        isDark: isDark,
                      ),
                    if (_streamingProviders.isNotEmpty) ...[
                      const SizedBox(height: 24),
                      _WhereToWatchSection(
                        providers: _streamingProviders,
                        watchProviderLink: _watchProviderLink,
                        isDark: isDark,
                      ),
                    ],
                    const SizedBox(height: 24),
                    _CastCrewSection(title: currentTitle, isDark: isDark),
                    const SizedBox(height: 100),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TitleDetailsShimmer extends StatelessWidget {
  final bool isDark;
  const _TitleDetailsShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        child: Shimmer.fromColors(
          baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
          highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Hero image shimmer
              Container(
                height: 380,
                width: double.infinity,
                color: Colors.white,
              ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Rating badges
                    Row(
                      children: [
                        Container(
                          height: 24,
                          width: 80,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          height: 24,
                          width: 40,
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Title
                    Container(
                      height: 28,
                      width: 200,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 8),
                    // Year and duration
                    Container(
                      height: 16,
                      width: 120,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    // Action buttons
                    Row(
                      children: List.generate(3, (index) => Expanded(
                        child: Container(
                          height: 40,
                          margin: EdgeInsets.only(right: index < 2 ? 10 : 0),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(20),
                          ),
                        ),
                      )),
                    ),
                    const SizedBox(height: 20),
                    // Description
                    ...List.generate(3, (index) => Container(
                      height: 14,
                      width: double.infinity,
                      margin: const EdgeInsets.only(bottom: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    )),
                    const SizedBox(height: 20),
                    // Mood match card
                    Container(
                      height: 120,
                      width: double.infinity,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ImageSection extends StatelessWidget {
  final TitleDetail title;
  final bool isDark;
  final bool isFavorite;
  final bool isFavoriteLoading;
  final VoidCallback onFavoriteToggle;
  final VoidCallback onBack;

  const _ImageSection({
    required this.title,
    required this.isDark,
    required this.isFavorite,
    required this.isFavoriteLoading,
    required this.onFavoriteToggle,
    required this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        SizedBox(
          height: 380,
          width: double.infinity,
          child: title.posterUrl != null && title.posterUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: title.posterUrl!,
                  fit: BoxFit.cover,
                  placeholder: (_, __) => Container(
                    decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
                    child: const Center(
                      child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                    ),
                  ),
                  errorWidget: (_, __, ___) => _buildPlaceholder(),
                )
              : _buildPlaceholder(),
        ),
        // Gradient overlay at bottom
        Positioned(
          bottom: 0,
          left: 0,
          right: 0,
          height: 100,
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  (isDark ? AppColors.darkBackground : AppColors.lightBackground).withValues(alpha: 0.8),
                  isDark ? AppColors.darkBackground : AppColors.lightBackground,
                ],
              ),
            ),
          ),
        ),
        // Top navigation
        Positioned(
          top: MediaQuery.of(context).padding.top + 8,
          left: 16,
          right: 16,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _GlassCircleButton(icon: Icons.arrow_back_ios_new_rounded, onTap: onBack),
              if (title.isSeries)
                _GlassPill(label: 'SERIES'),
              isFavoriteLoading
                  ? _GlassCircleButton(
                      icon: Icons.hourglass_empty,
                      onTap: () {},
                    )
                  : _GlassCircleButton(
                      icon: isFavorite ? Icons.favorite : Icons.favorite_border,
                      onTap: onFavoriteToggle,
                      iconColor: isFavorite ? AppColors.accent : null,
                    ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildPlaceholder() => Container(
    width: double.infinity,
    height: double.infinity,
    decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
    child: const Center(
      child: Icon(Icons.movie, size: 60, color: Colors.white),
    ),
  );
}

class _GlassCircleButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final Color? iconColor;

  const _GlassCircleButton({required this.icon, required this.onTap, this.iconColor});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipOval(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.black.withValues(alpha: 0.3),
              border: Border.all(color: Colors.white.withValues(alpha: 0.2), width: 0.5),
            ),
            child: Icon(icon, size: 18, color: iconColor ?? Colors.white),
          ),
        ),
      ),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final String label;
  const _GlassPill({required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.primary.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: Colors.white,
              letterSpacing: 0.5,
            ),
          ),
        ),
      ),
    );
  }
}

class _TitleInfoSection extends StatelessWidget {
  final TitleDetail title;
  final bool isDark;

  const _TitleInfoSection({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            if (title.imdbRating != null && title.imdbRating!.isNotEmpty)
              _RatingBadge(label: 'IMDb - ${title.imdbRating}', isDark: isDark),
            if (title.imdbRating != null && title.ageRating != null)
              const SizedBox(width: 8),
            if (title.ageRating != null && title.ageRating!.isNotEmpty)
              _RatingBadge(label: title.ageRating!, isDark: isDark),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          title.title,
          style: TextStyle(
            fontSize: 26,
            fontWeight: FontWeight.w700,
            color: isDark ? AppColors.darkText : AppColors.lightText,
            height: 1.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '${title.yearString}, ${title.runtimeFormatted}',
          style: TextStyle(
            fontSize: 14,
            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
          ),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(6),
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

class _DescriptionText extends StatelessWidget {
  final String overview;
  final bool isDark;

  const _DescriptionText({required this.overview, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      overview,
      style: TextStyle(
        fontSize: 15,
        height: 1.6,
        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
      ),
    );
  }
}

class _MoodMatchCard extends StatelessWidget {
  final TitleDetail title;
  final bool isDark;
  final int? passedMatchScore;

  const _MoodMatchCard({required this.title, required this.isDark, this.passedMatchScore});

  @override
  Widget build(BuildContext context) {
    // Priority: 1. Passed matchScore from navigation, 2. Title's moodMatchPercent, 3. Default to 85
    final matchPercent = passedMatchScore ?? title.moodMatchPercent ?? 85;
    final vibeTags = title.vibeTags.isNotEmpty 
        ? title.vibeTags 
        : title.genres.take(3).toList();

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF4A90A4).withValues(alpha: 0.4), const Color(0xFF2D5A6B).withValues(alpha: 0.5)]
                  : [const Color(0xFF87CEEB).withValues(alpha: 0.5), const Color(0xFF6BB3D9).withValues(alpha: 0.6)],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: isDark ? 0.15 : 0.3), width: 0.5),
          ),
          child: Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$matchPercent%',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w700,
                      color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      height: 1,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Match',
                    style: TextStyle(
                      fontSize: 13,
                      color: isDark ? Colors.white.withValues(alpha: 0.7) : const Color(0xFF1A1A1A).withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Perfect Match for Your Mood',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white : const Color(0xFF1A1A1A),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: vibeTags.take(3).map((tag) => _MoodTag(label: tag, isDark: isDark)).toList(),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _MoodTag extends StatelessWidget {
  final String label;
  final bool isDark;

  const _MoodTag({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.15) : Colors.white.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isDark ? Colors.white : const Color(0xFF1A1A1A),
        ),
      ),
    );
  }
}

class _MoreSuggestionsSection extends StatelessWidget {
  final List<TitleDetail> suggestions;
  final bool isDark;

  const _MoreSuggestionsSection({required this.suggestions, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'More Suggestions',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
              ),
              child: Icon(
                Icons.arrow_outward,
                size: 18,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...suggestions.map((suggestion) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _SuggestionCard(title: suggestion, isDark: isDark),
        )),
      ],
    );
  }
}

class _SuggestionCard extends StatelessWidget {
  final TitleDetail title;
  final bool isDark;

  const _SuggestionCard({required this.title, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/title/${title.id}'),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              width: 90,
              height: 130,
              child: title.posterUrl != null && title.posterUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: title.posterUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => _buildPlaceholder(),
                      errorWidget: (_, __, ___) => _buildPlaceholder(),
                    )
                  : _buildPlaceholder(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Row(
                  children: [
                    if (title.imdbRating != null && title.imdbRating!.isNotEmpty)
                      _RatingBadge(label: 'IMDb - ${title.imdbRating}', isDark: isDark),
                    if (title.imdbRating != null && title.ageRating != null)
                      const SizedBox(width: 8),
                    if (title.ageRating != null && title.ageRating!.isNotEmpty)
                      _RatingBadge(label: title.ageRating!, isDark: isDark),
                  ],
                ),
                const SizedBox(height: 10),
                Text(
                  title.title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  '${title.yearString}, ${title.runtimeFormatted}',
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  title.genresString,
                  style: TextStyle(
                    fontSize: 13,
                    color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholder() => Container(
    decoration: BoxDecoration(
      gradient: AppColors.primaryGradient,
      borderRadius: BorderRadius.circular(8),
    ),
    child: const Center(child: Icon(Icons.movie, size: 30, color: Colors.white)),
  );
}

class _WhereToWatchSection extends StatelessWidget {
  final List<StreamingAvailability> providers;
  final String? watchProviderLink;
  final bool isDark;

  const _WhereToWatchSection({
    required this.providers,
    this.watchProviderLink,
    required this.isDark,
  });

  @override
  Widget build(BuildContext context) {
    // Group providers by availability type for better UX
    final flatrateProviders = providers.where((p) => p.isFlatrate).toList();
    final freeProviders = providers.where((p) => p.isFree).toList();
    final rentProviders = providers.where((p) => p.isRent).toList();
    final buyProviders = providers.where((p) => p.isBuy).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Where to Watch',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            if (watchProviderLink != null)
              GestureDetector(
                onTap: () => _launchUrl(watchProviderLink!),
                child: Text(
                  'See all options',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 12),
        
        // Subscription providers (flatrate)
        if (flatrateProviders.isNotEmpty) ...[
          _ProviderCategoryLabel(label: 'Streaming', isDark: isDark),
          const SizedBox(height: 8),
          ...flatrateProviders.map((provider) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _StreamingProviderRow(
              availability: provider,
              watchProviderLink: watchProviderLink,
              isDark: isDark,
            ),
          )),
          const SizedBox(height: 8),
        ],
        
        // Free providers
        if (freeProviders.isNotEmpty) ...[
          _ProviderCategoryLabel(label: 'Free', isDark: isDark),
          const SizedBox(height: 8),
          ...freeProviders.map((provider) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _StreamingProviderRow(
              availability: provider,
              watchProviderLink: watchProviderLink,
              isDark: isDark,
            ),
          )),
          const SizedBox(height: 8),
        ],
        
        // Rent providers
        if (rentProviders.isNotEmpty) ...[
          _ProviderCategoryLabel(label: 'Rent', isDark: isDark),
          const SizedBox(height: 8),
          ...rentProviders.map((provider) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _StreamingProviderRow(
              availability: provider,
              watchProviderLink: watchProviderLink,
              isDark: isDark,
            ),
          )),
          const SizedBox(height: 8),
        ],
        
        // Buy providers
        if (buyProviders.isNotEmpty) ...[
          _ProviderCategoryLabel(label: 'Buy', isDark: isDark),
          const SizedBox(height: 8),
          ...buyProviders.map((provider) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _StreamingProviderRow(
              availability: provider,
              watchProviderLink: watchProviderLink,
              isDark: isDark,
            ),
          )),
        ],
      ],
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    try {
      // Try external browser first
      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        // Fallback to in-app browser view
        final inAppLaunched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        if (!inAppLaunched) {
          // Final fallback to platform default
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        }
      }
    } catch (e) {
      debugPrint('Error launching URL: $e');
      // Fallback on error
      try {
        await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (_) {
        try {
          await launchUrl(uri, mode: LaunchMode.platformDefault);
        } catch (_) {
          debugPrint('All URL launch methods failed for: $url');
        }
      }
    }
  }
}

class _ProviderCategoryLabel extends StatelessWidget {
  final String label;
  final bool isDark;

  const _ProviderCategoryLabel({required this.label, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w600,
        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _StreamingProviderRow extends StatelessWidget {
  final StreamingAvailability availability;
  final String? watchProviderLink;
  final bool isDark;

  const _StreamingProviderRow({
    required this.availability,
    this.watchProviderLink,
    required this.isDark,
  });

  String get _name => availability.provider?.name ?? 'Unknown';
  String? get _logoUrl => availability.provider?.logoUrl;

  String get _actionText {
    switch (availability.availabilityType) {
      case 'flatrate': return 'Stream';
      case 'free': return 'Free';
      case 'ads': return 'Free with ads';
      case 'rent': return 'Rent';
      case 'buy': return 'Buy';
      default: return 'View';
    }
  }

  String get _subtitleText {
    switch (availability.availabilityType) {
      case 'flatrate': return 'Included with subscription';
      case 'free': return 'Watch for free';
      case 'ads': return 'Free with ads';
      case 'rent': return 'Available to rent';
      case 'buy': return 'Available to buy';
      default: return '';
    }
  }

  IconData get _fallbackIcon {
    final name = _name.toLowerCase();
    if (name.contains('netflix')) return Icons.play_circle_filled;
    if (name.contains('prime') || name.contains('amazon')) return Icons.play_circle_outline;
    if (name.contains('apple')) return Icons.apple;
    if (name.contains('hbo') || name.contains('max')) return Icons.live_tv;
    if (name.contains('disney')) return Icons.star;
    if (name.contains('hulu')) return Icons.play_arrow;
    return Icons.tv;
  }

  Color get _fallbackColor {
    final name = _name.toLowerCase();
    if (name.contains('netflix')) return const Color(0xFFE50914);
    if (name.contains('prime') || name.contains('amazon')) return const Color(0xFF00A8E1);
    if (name.contains('apple')) return Colors.grey.shade800;
    if (name.contains('hbo') || name.contains('max')) return const Color(0xFF5822B4);
    if (name.contains('disney')) return const Color(0xFF113CCF);
    if (name.contains('hulu')) return const Color(0xFF1CE783);
    return AppColors.primary;
  }

  Future<void> _handleTap() async {
    // Prefer individual watch link, fall back to general provider link
    final url = availability.watchLink ?? watchProviderLink;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.parse(url);
      try {
        // Try external browser first
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched) {
          // Fallback to in-app browser view
          final inAppLaunched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
          if (!inAppLaunched) {
            // Final fallback to platform default
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          }
        }
      } catch (e) {
        debugPrint('Error launching URL: $e');
        // Fallback on error
        try {
          await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
        } catch (_) {
          try {
            await launchUrl(uri, mode: LaunchMode.platformDefault);
          } catch (_) {
            debugPrint('All URL launch methods failed for: $url');
          }
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final hasLink = (availability.watchLink != null && availability.watchLink!.isNotEmpty) || 
                    (watchProviderLink != null && watchProviderLink!.isNotEmpty);

    return GestureDetector(
      onTap: hasLink ? _handleTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          children: [
            // Provider logo or fallback icon
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: SizedBox(
                width: 44,
                height: 44,
                child: _logoUrl != null && _logoUrl!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: _logoUrl!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => _buildFallbackIcon(),
                        errorWidget: (_, __, ___) => _buildFallbackIcon(),
                      )
                    : _buildFallbackIcon(),
              ),
            ),
            const SizedBox(width: 14),
            
            // Provider name and subtitle
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _name,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: isDark ? AppColors.darkText : AppColors.lightText,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _subtitleText,
                    style: TextStyle(
                      fontSize: 12,
                      color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            
            // Action button/indicator
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: hasLink 
                    ? AppColors.primary.withValues(alpha: 0.1)
                    : (isDark ? Colors.white.withValues(alpha: 0.1) : Colors.black.withValues(alpha: 0.06)),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _actionText,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: hasLink 
                          ? AppColors.primary
                          : (isDark ? AppColors.darkText : AppColors.lightText),
                    ),
                  ),
                  if (hasLink) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.open_in_new_rounded,
                      size: 14,
                      color: AppColors.primary,
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFallbackIcon() => Container(
    decoration: BoxDecoration(
      color: _fallbackColor.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Center(
      child: Icon(_fallbackIcon, size: 24, color: _fallbackColor),
    ),
  );
}

class _CastCrewSection extends StatelessWidget {
  final TitleDetail title;
  final bool isDark;

  const _CastCrewSection({required this.title, required this.isDark});

  String get _directorValue => title.director?.isNotEmpty == true ? title.director! : 'Unknown';
  String get _starringValue => title.starring.isNotEmpty ? title.starring.join(', ') : 'Unknown';
  String get _genresValue => title.genres.isNotEmpty ? title.genres.join(', ') : 'Unknown';

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Cast & Crew',
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: isDark ? AppColors.darkText : AppColors.lightText,
          ),
        ),
        const SizedBox(height: 16),
        _CastCrewRow(label: 'Director', value: _directorValue, isDark: isDark),
        const SizedBox(height: 12),
        _CastCrewRow(label: 'Starring', value: _starringValue, isDark: isDark),
        const SizedBox(height: 12),
        _CastCrewRow(label: 'Genre', value: _genresValue, isDark: isDark),
        const SizedBox(height: 12),
        _CastCrewRow(label: 'Runtime', value: title.runtimeFormatted, isDark: isDark),
      ],
    );
  }
}

class _CastCrewRow extends StatelessWidget {
  final String label;
  final String value;
  final bool isDark;

  const _CastCrewRow({required this.label, required this.value, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 14,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              color: isDark ? AppColors.darkText : AppColors.lightText,
            ),
          ),
        ),
      ],
    );
  }
}
