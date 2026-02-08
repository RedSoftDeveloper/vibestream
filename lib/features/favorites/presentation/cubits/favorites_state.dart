import 'package:equatable/equatable.dart';
import 'package:vibestream/features/favorites/data/favorite_service.dart';

enum FavoritesStatus { initial, loading, loaded, error }

class FavoritesState extends Equatable {
  final FavoritesStatus status;
  final List<FavoriteTitle> favorites;
  final String? errorMessage;

  const FavoritesState({
    this.status = FavoritesStatus.initial,
    this.favorites = const [],
    this.errorMessage,
  });

  bool get isLoading => status == FavoritesStatus.loading;
  bool get hasError => status == FavoritesStatus.error;
  bool get isEmpty => favorites.isEmpty && status == FavoritesStatus.loaded;

  FavoritesState copyWith({
    FavoritesStatus? status,
    List<FavoriteTitle>? favorites,
    String? errorMessage,
  }) {
    return FavoritesState(
      status: status ?? this.status,
      favorites: favorites ?? this.favorites,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, favorites, errorMessage];
}
