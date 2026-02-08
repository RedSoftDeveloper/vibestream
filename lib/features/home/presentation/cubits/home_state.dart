import 'package:equatable/equatable.dart';
import 'package:vibestream/features/recommendations/data/recommendation_service.dart';

enum HomeStatus { initial, loading, loaded, error }

class HomeState extends Equatable {
  final HomeStatus status;
  final List<RecentVibe> recentVibes;
  final List<TopTitle> topTitles;
  final Set<String> titlesWithFeedback;
  final String? errorMessage;
  final DateTime? lastLoadTime;

  const HomeState({
    this.status = HomeStatus.initial,
    this.recentVibes = const [],
    this.topTitles = const [],
    this.titlesWithFeedback = const {},
    this.errorMessage,
    this.lastLoadTime,
  });

  bool get isLoading => status == HomeStatus.loading;
  bool get isLoadingVibes => status == HomeStatus.loading || status == HomeStatus.initial;
  bool get isLoadingTopTitles => status == HomeStatus.loading || status == HomeStatus.initial;

  HomeState copyWith({
    HomeStatus? status,
    List<RecentVibe>? recentVibes,
    List<TopTitle>? topTitles,
    Set<String>? titlesWithFeedback,
    String? errorMessage,
    DateTime? lastLoadTime,
  }) {
    return HomeState(
      status: status ?? this.status,
      recentVibes: recentVibes ?? this.recentVibes,
      topTitles: topTitles ?? this.topTitles,
      titlesWithFeedback: titlesWithFeedback ?? this.titlesWithFeedback,
      errorMessage: errorMessage,
      lastLoadTime: lastLoadTime ?? this.lastLoadTime,
    );
  }

  @override
  List<Object?> get props => [status, recentVibes, topTitles, titlesWithFeedback, errorMessage, lastLoadTime];
}
