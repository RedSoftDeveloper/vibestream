import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:shimmer/shimmer.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/utils/snackbar_utils.dart';
import 'package:vibestream/features/favorites/data/favorite_service.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';

class FavoritesPage extends StatefulWidget {
  const FavoritesPage({super.key});

  @override
  State<FavoritesPage> createState() => _FavoritesPageState();
}

class _FavoritesPageState extends State<FavoritesPage> {
  final ProfileService _profileService = ProfileService();
  List<FavoriteTitle> _favorites = [];
  bool _isLoading = true;
  bool _hasError = false;
  bool _isRefreshing = false;

  @override
  void initState() {
    super.initState();
    FavoriteService.addListener(_onFavoritesChanged);
    _loadFavorites();
  }

  @override
  void dispose() {
    FavoriteService.removeListener(_onFavoritesChanged);
    super.dispose();
  }

  /// Called when favorites are modified elsewhere
  void _onFavoritesChanged() {
    if (mounted) {
      _loadFavorites(forceRefresh: true);
    }
  }

  Future<void> _loadFavorites({bool forceRefresh = false}) async {
    final profileId = _profileService.selectedProfileId;
    if (profileId == null) {
      setState(() {
        _isLoading = false;
        _favorites = [];
      });
      return;
    }

    // Check for cached data first
    final cached = FavoriteService.getCachedFavorites(profileId);
    final hasCache = cached != null && cached.isNotEmpty;
    
    // If we have cached data, show it immediately without loading state
    if (hasCache && !forceRefresh) {
      setState(() {
        _favorites = cached;
        _isLoading = false;
        _hasError = false;
      });
      
      // Background refresh if cache is stale
      if (FavoriteService.isCacheStale(profileId)) {
        _backgroundRefresh(profileId);
      }
      return;
    }

    // Show loading only if no cached data
    if (!hasCache) {
      setState(() {
        _isLoading = true;
        _hasError = false;
      });
    }

    try {
      final favorites = await FavoriteService.getFavorites(
        profileId: profileId,
        forceRefresh: forceRefresh,
      );
      
      if (mounted) {
        setState(() {
          _favorites = favorites;
          _isLoading = false;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint('FavoritesPage: Error loading favorites: $e');
      if (mounted) {
        // Only show error if we don't have cached data
        if (!hasCache) {
          setState(() {
            _hasError = true;
            _isLoading = false;
          });
        } else {
          setState(() {
            _isRefreshing = false;
          });
        }
      }
    }
  }

  /// Refresh data in background without showing loading state
  Future<void> _backgroundRefresh(String profileId) async {
    if (_isRefreshing) return;
    
    setState(() => _isRefreshing = true);
    
    try {
      final favorites = await FavoriteService.getFavorites(
        profileId: profileId,
        forceRefresh: true,
      );
      
      if (mounted) {
        setState(() {
          _favorites = favorites;
          _isRefreshing = false;
        });
      }
    } catch (e) {
      debugPrint('FavoritesPage: Background refresh failed: $e');
      if (mounted) {
        setState(() => _isRefreshing = false);
      }
    }
  }

  Future<void> _removeFavorite(FavoriteTitle favorite) async {
    final profileId = _profileService.selectedProfileId;
    if (profileId == null) return;

    // Optimistically remove from UI and cache
    setState(() {
      _favorites.removeWhere((f) => f.id == favorite.id);
    });
    FavoriteService.removeFavoriteFromCache(favorite.titleId);

    final success = await FavoriteService.removeFavorite(
      profileId: profileId,
      titleId: favorite.titleId,
    );

    if (!success && mounted) {
      // Revert if failed - force refresh to get accurate data
      _loadFavorites(forceRefresh: true);
      SnackbarUtils.showError(context, 'Failed to remove from favorites');
    }
  }

  Future<void> _onRefresh() async {
    final profileId = _profileService.selectedProfileId;
    if (profileId == null) return;
    
    await FavoriteService.getFavorites(
      profileId: profileId,
      forceRefresh: true,
    );
    
    if (mounted) {
      final cached = FavoriteService.getCachedFavorites(profileId);
      if (cached != null) {
        setState(() => _favorites = cached);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: isDark ? AppColors.darkBackground : AppColors.lightBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _FavoritesHeader(isDark: isDark, isRefreshing: _isRefreshing),
            Expanded(
              child: _isLoading
                  ? _FavoritesShimmer(isDark: isDark)
                  : _hasError
                      ? _ErrorState(isDark: isDark, onRetry: () => _loadFavorites(forceRefresh: true))
                      : _favorites.isEmpty
                          ? _EmptyState(isDark: isDark)
                          : RefreshIndicator(
                              onRefresh: _onRefresh,
                              color: AppColors.primary,
                              child: ListView.builder(
                                padding: EdgeInsets.only(
                                  left: 16,
                                  right: 16,
                                  top: 8,
                                  bottom: bottomPadding + 100,
                                ),
                                itemCount: _favorites.length,
                                itemBuilder: (context, index) {
                                  final favorite = _favorites[index];
                                  return _FavoriteCard(
                                    favorite: favorite,
                                    isDark: isDark,
                                    onRemove: () => _removeFavorite(favorite),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesHeader extends StatelessWidget {
  final bool isDark;
  final bool isRefreshing;

  const _FavoritesHeader({required this.isDark, this.isRefreshing = false});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Icon(
                  Icons.favorite_rounded,
                  color: Colors.white,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'My Favorites',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkText : AppColors.lightText,
                          ),
                        ),
                        if (isRefreshing) ...[
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      'Your saved movies & shows',
                      style: TextStyle(
                        fontSize: 14,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Divider(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            height: 1,
          ),
        ],
      ),
    );
  }
}

class _FavoriteCard extends StatelessWidget {
  final FavoriteTitle favorite;
  final bool isDark;
  final VoidCallback onRemove;

  const _FavoriteCard({
    required this.favorite,
    required this.isDark,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final title = favorite.title;
    if (title == null) return const SizedBox.shrink();

    return GestureDetector(
      onTap: () => context.push(AppRoutes.titleDetailsPath(title.id)),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurface : AppColors.lightSurface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isDark ? AppColors.darkBorder : AppColors.lightBorder,
            width: 0.5,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Poster
            ClipRRect(
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(16),
                bottomLeft: Radius.circular(16),
              ),
              child: SizedBox(
                width: 100,
                height: 150,
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
            // Info
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: Text(
                            title.title,
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkText : AppColors.lightText,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        _RemoveButton(onTap: onRemove, isDark: isDark),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${title.yearString} • ${title.runtimeFormatted}',
                      style: TextStyle(
                        fontSize: 13,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (title.genres.isNotEmpty)
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: title.genres.take(2).map((genre) {
                          return Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: isDark 
                                  ? Colors.white.withValues(alpha: 0.08)
                                  : Colors.black.withValues(alpha: 0.05),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              genre,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: isDark ? AppColors.darkText : AppColors.lightText,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    const SizedBox(height: 8),
                    if (title.imdbRating != null && title.imdbRating!.isNotEmpty)
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 16,
                            color: Colors.amber.shade600,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            title.imdbRating!,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: isDark ? AppColors.darkText : AppColors.lightText,
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'IMDb',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                            ),
                          ),
                        ],
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

  Widget _buildPlaceholder() => Container(
    decoration: const BoxDecoration(gradient: AppColors.primaryGradient),
    child: const Center(child: Icon(Icons.movie, size: 30, color: Colors.white)),
  );
}

class _RemoveButton extends StatelessWidget {
  final VoidCallback onTap;
  final bool isDark;

  const _RemoveButton({required this.onTap, required this.isDark});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: Colors.red.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          Icons.favorite_rounded,
          size: 18,
          color: Colors.red.shade400,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final bool isDark;

  const _EmptyState({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: isDark 
                    ? Colors.white.withValues(alpha: 0.05)
                    : Colors.black.withValues(alpha: 0.03),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Icon(
                Icons.favorite_border_rounded,
                size: 40,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No favorites yet',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Start adding movies and shows you love\nby tapping the heart icon',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            GestureDetector(
              onTap: () => context.go(AppRoutes.home),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                decoration: BoxDecoration(
                  gradient: AppColors.accentGradient,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: const Text(
                  'Discover Titles',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final bool isDark;
  final VoidCallback onRetry;

  const _ErrorState({required this.isDark, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              size: 48,
              color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
            ),
            const SizedBox(height: 16),
            Text(
              'Something went wrong',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w600,
                color: isDark ? AppColors.darkText : AppColors.lightText,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Could not load your favorites',
              style: TextStyle(
                fontSize: 14,
                color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            GestureDetector(
              onTap: onRetry,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark 
                      ? Colors.white.withValues(alpha: 0.1)
                      : Colors.black.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Try Again',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.darkText : AppColors.lightText,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FavoritesShimmer extends StatelessWidget {
  final bool isDark;

  const _FavoritesShimmer({required this.isDark});

  @override
  Widget build(BuildContext context) {
    return Shimmer.fromColors(
      baseColor: isDark ? Colors.grey[800]! : Colors.grey[300]!,
      highlightColor: isDark ? Colors.grey[700]! : Colors.grey[100]!,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: 5,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 150,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
          );
        },
      ),
    );
  }
}
