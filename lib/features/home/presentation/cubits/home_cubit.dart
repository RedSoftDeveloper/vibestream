import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibestream/features/home/presentation/cubits/home_state.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';
import 'package:vibestream/features/recommendations/data/recommendation_service.dart';
import 'package:vibestream/features/recommendations/data/interaction_service.dart';
import 'package:vibestream/core/services/home_refresh_service.dart';

class HomeCubit extends Cubit<HomeState> {
  final ProfileService _profileService;
  final HomeRefreshService _homeRefreshService;
  final InteractionService _interactionService;
  
  String? _lastProfileId;
  
  /// Stale threshold: 5 minutes (300 seconds)
  static const int _staleThresholdSeconds = 300;

  HomeCubit({
    ProfileService? profileService,
    HomeRefreshService? homeRefreshService,
    InteractionService? interactionService,
  })  : _profileService = profileService ?? ProfileService(),
        _homeRefreshService = homeRefreshService ?? HomeRefreshService(),
        _interactionService = interactionService ?? InteractionService(),
        super(const HomeState());

  void init() {
    _profileService.addListener(_onProfilesChanged);
    _homeRefreshService.addListener(_onRefreshRequested);
    loadData();
  }

  @override
  Future<void> close() {
    _profileService.removeListener(_onProfilesChanged);
    _homeRefreshService.removeListener(_onRefreshRequested);
    return super.close();
  }

  void _onRefreshRequested() {
    debugPrint('HomeCubit: Received refresh request from HomeRefreshService');
    loadData();
  }

  void _onProfilesChanged() {
    final currentProfileId = _profileService.selectedProfileId;
    if (currentProfileId != _lastProfileId) {
      loadData();
    }
  }

  /// Check if data needs refresh (app resume scenario)
  void refreshIfNeeded() {
    final lastLoad = state.lastLoadTime;
    if (lastLoad == null) return;
    
    final timeSinceLastLoad = DateTime.now().difference(lastLoad);
    if (timeSinceLastLoad.inSeconds > _staleThresholdSeconds) {
      debugPrint('HomeCubit: Data is stale (${timeSinceLastLoad.inSeconds}s > ${_staleThresholdSeconds}s threshold), refreshing silently...');
      loadDataSilently();
    }
  }

  Future<void> loadData() async {
    final profileId = _profileService.selectedProfileId;
    if (profileId == null) return;

    _lastProfileId = profileId;
    emit(state.copyWith(status: HomeStatus.loading));

    try {
      final results = await Future.wait([
        RecommendationService.getRecentVibes(profileId),
        RecommendationService.getTopTitles(profileId),
      ]);

      final recentVibes = results[0] as List<RecentVibe>;
      final topTitles = results[1] as List<TopTitle>;

      // Check which titles already have feedback
      final feedbackSet = <String>{};
      for (final vibe in recentVibes) {
        final hasFeedback = await _interactionService.hasTitleFeedback(
          profileId: profileId,
          titleId: vibe.titleId,
        );
        if (hasFeedback) {
          feedbackSet.add(vibe.titleId);
        }
      }

      emit(state.copyWith(
        status: HomeStatus.loaded,
        recentVibes: recentVibes,
        topTitles: topTitles,
        titlesWithFeedback: feedbackSet,
        lastLoadTime: DateTime.now(),
      ));

      debugPrint('HomeCubit: Loaded ${recentVibes.length} vibes and ${topTitles.length} top titles, ${feedbackSet.length} have feedback');
    } catch (e) {
      debugPrint('HomeCubit: Error loading data: $e');
      emit(state.copyWith(
        status: HomeStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  /// Silent refresh: Updates data without showing loading state
  Future<void> loadDataSilently() async {
    final profileId = _profileService.selectedProfileId;
    if (profileId == null) return;

    _lastProfileId = profileId;
    debugPrint('HomeCubit: Starting silent background refresh...');

    try {
      final results = await Future.wait([
        RecommendationService.getRecentVibes(profileId),
        RecommendationService.getTopTitles(profileId),
      ]);

      final recentVibes = results[0] as List<RecentVibe>;
      final topTitles = results[1] as List<TopTitle>;

      // Check which titles already have feedback
      final feedbackSet = <String>{};
      for (final vibe in recentVibes) {
        final hasFeedback = await _interactionService.hasTitleFeedback(
          profileId: profileId,
          titleId: vibe.titleId,
        );
        if (hasFeedback) {
          feedbackSet.add(vibe.titleId);
        }
      }

      emit(state.copyWith(
        status: HomeStatus.loaded,
        recentVibes: recentVibes,
        topTitles: topTitles,
        titlesWithFeedback: feedbackSet,
        lastLoadTime: DateTime.now(),
      ));

      debugPrint('HomeCubit: Silent refresh complete - ${recentVibes.length} vibes and ${topTitles.length} top titles');
    } catch (e) {
      debugPrint('HomeCubit: Silent refresh failed: $e');
      // On silent refresh failure, keep the cached data
    }
  }

  String? get selectedProfileName => _profileService.selectedProfile?.name;
  List<dynamic> get profiles => _profileService.profiles;
  String? get selectedProfileId => _profileService.selectedProfileId;
}
