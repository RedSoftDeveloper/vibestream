import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibestream/features/favorites/presentation/cubits/favorites_state.dart';
import 'package:vibestream/features/favorites/data/favorite_service.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';

class FavoritesCubit extends Cubit<FavoritesState> {
  final ProfileService _profileService;

  FavoritesCubit({ProfileService? profileService})
      : _profileService = profileService ?? ProfileService(),
        super(const FavoritesState());

  Future<void> loadFavorites({bool forceRefresh = false}) async {
    final profileId = _profileService.selectedProfileId;
    if (profileId == null) {
      emit(state.copyWith(
        status: FavoritesStatus.loaded,
        favorites: [],
      ));
      return;
    }

    // Check cache first
    final cached = FavoriteService.getCachedFavorites(profileId);
    final hasCache = cached != null && cached.isNotEmpty;

    // If we have valid cached data and not forcing refresh, use it
    if (hasCache && !forceRefresh && !FavoriteService.isCacheStale(profileId)) {
      emit(state.copyWith(
        status: FavoritesStatus.loaded,
        favorites: cached,
      ));
      return;
    }

    // Only show loading if no cached data
    if (!hasCache) {
      emit(state.copyWith(status: FavoritesStatus.loading));
    }

    try {
      final favorites = await FavoriteService.getFavorites(
        profileId: profileId,
        forceRefresh: forceRefresh,
      );

      emit(state.copyWith(
        status: FavoritesStatus.loaded,
        favorites: favorites,
      ));
    } catch (e) {
      debugPrint('FavoritesCubit: Error loading favorites: $e');
      // If we have cached data, keep showing it even on error
      if (hasCache) {
        emit(state.copyWith(
          status: FavoritesStatus.loaded,
          favorites: cached,
        ));
      } else {
        emit(state.copyWith(
          status: FavoritesStatus.error,
          errorMessage: e.toString(),
        ));
      }
    }
  }

  Future<bool> removeFavorite(FavoriteTitle favorite) async {
    final profileId = _profileService.selectedProfileId;
    if (profileId == null) return false;

    // Optimistically update UI
    final previousFavorites = List<FavoriteTitle>.from(state.favorites);
    final updatedFavorites = state.favorites.where((f) => f.id != favorite.id).toList();
    emit(state.copyWith(favorites: updatedFavorites));

    // Also update cache
    FavoriteService.removeFavoriteFromCache(favorite.titleId);

    final success = await FavoriteService.removeFavorite(
      profileId: profileId,
      titleId: favorite.titleId,
    );

    if (!success) {
      // Revert on failure
      emit(state.copyWith(favorites: previousFavorites));
      debugPrint('FavoritesCubit: Failed to remove favorite');
    }

    return success;
  }
}
