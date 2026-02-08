import 'package:flutter/material.dart';
import 'package:vibestream/core/theme/app_theme.dart';

enum RatingSource { imdb, rottenTomatoes, metacritic }

class RatingBadge extends StatelessWidget {
  final RatingSource source;
  final dynamic rating;
  final String? votes;
  final bool isAudienceScore;
  final bool compact;

  const RatingBadge({
    super.key,
    required this.source,
    required this.rating,
    this.votes,
    this.isAudienceScore = false,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 10 : 14,
        vertical: compact ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: isDark ? AppColors.darkSurfaceVariant : AppColors.lightSurfaceVariant,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildSourceIcon(context),
          SizedBox(height: compact ? 6 : 8),
          Text(
            _formatRating(),
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              fontSize: compact ? 16 : 18,
            ),
          ),
          if (!compact && votes != null) ...[
            const SizedBox(height: 2),
            Text(
              votes!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSourceIcon(BuildContext context) {
    switch (source) {
      case RatingSource.imdb:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: AppColors.ratingImdb,
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'IMDb',
            style: TextStyle(
              color: Colors.black,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 10 : 12,
            ),
          ),
        );
      case RatingSource.rottenTomatoes:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isAudienceScore ? Icons.people : Icons.local_movies,
              size: compact ? 16 : 20,
              color: AppColors.ratingRotten,
            ),
            const SizedBox(width: 4),
            Text(
              isAudienceScore ? 'Audience' : 'Critics',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w600,
                fontSize: compact ? 9 : 10,
              ),
            ),
          ],
        );
      case RatingSource.metacritic:
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            color: _getMetacriticColor(),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text(
            'MC',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: compact ? 10 : 12,
            ),
          ),
        );
    }
  }

  String _formatRating() {
    if (rating == null) return 'N/A';
    if (source == RatingSource.imdb) {
      return rating.toString();
    }
    return '$rating%';
  }

  Color _getMetacriticColor() {
    if (rating == null) return Colors.grey;
    final score = rating as int;
    if (score >= 75) return const Color(0xFF66CC33);
    if (score >= 50) return const Color(0xFFFFCC33);
    return const Color(0xFFFF0000);
  }
}

class RatingsRow extends StatelessWidget {
  final double? imdbRating;
  final String? imdbVotes;
  final int? rottenCritics;
  final int? rottenAudience;
  final int? metacritic;

  const RatingsRow({
    super.key,
    this.imdbRating,
    this.imdbVotes,
    this.rottenCritics,
    this.rottenAudience,
    this.metacritic,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          if (imdbRating != null)
            RatingBadge(
              source: RatingSource.imdb,
              rating: imdbRating,
              votes: imdbVotes,
            ),
          if (rottenCritics != null) ...[
            const SizedBox(width: 12),
            RatingBadge(
              source: RatingSource.rottenTomatoes,
              rating: rottenCritics,
            ),
          ],
          if (rottenAudience != null) ...[
            const SizedBox(width: 12),
            RatingBadge(
              source: RatingSource.rottenTomatoes,
              rating: rottenAudience,
              isAudienceScore: true,
            ),
          ],
          if (metacritic != null) ...[
            const SizedBox(width: 12),
            RatingBadge(
              source: RatingSource.metacritic,
              rating: metacritic,
            ),
          ],
        ],
      ),
    );
  }
}
