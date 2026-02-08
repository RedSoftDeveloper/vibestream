import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibestream/features/mood_quiz/presentation/cubits/mood_quiz_state.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';
import 'package:vibestream/features/recommendations/data/recommendation_service.dart';
import 'package:vibestream/core/services/home_refresh_service.dart';

class MoodQuizCubit extends Cubit<MoodQuizState> {
  final ProfileService _profileService;
  final HomeRefreshService _homeRefreshService;

  MoodQuizCubit({
    ProfileService? profileService,
    HomeRefreshService? homeRefreshService,
  })  : _profileService = profileService ?? ProfileService(),
        _homeRefreshService = homeRefreshService ?? HomeRefreshService(),
        super(const MoodQuizState());

  void selectViewingStyle(int index) {
    emit(state.copyWith(selectedViewingStyle: index));
  }

  void updateSlider(String name, double value) {
    final updatedSliders = Map<String, double>.from(state.moodSliders);
    updatedSliders[name] = value;
    emit(state.copyWith(moodSliders: updatedSliders));
  }

  void toggleGenre(String genre) {
    final updatedGenres = Set<String>.from(state.selectedGenres);
    if (updatedGenres.contains(genre)) {
      updatedGenres.remove(genre);
    } else if (updatedGenres.length < 3) {
      updatedGenres.add(genre);
    }
    emit(state.copyWith(selectedGenres: updatedGenres));
  }

  void updateFreeText(String text) {
    emit(state.copyWith(freeText: text));
  }

  Future<bool> findMovies() async {
    final profileId = _profileService.selectedProfileId;
    if (profileId == null) {
      emit(state.copyWith(
        status: MoodQuizStatus.error,
        errorMessage: 'Please select a profile first',
      ));
      return false;
    }

    emit(state.copyWith(status: MoodQuizStatus.submitting));

    try {
      final session = await RecommendationService.createMoodSession(
        profileId: profileId,
        viewingStyle: state.viewingStyleKey,
        sliders: state.slidersForApi,
        selectedGenres: state.selectedGenres.toList(),
        freeText: state.freeText.trim(),
      );

      // Request home page refresh after quiz completion
      _homeRefreshService.requestRefresh(reason: HomeRefreshReason.moodQuizCompleted);

      emit(state.copyWith(
        status: MoodQuizStatus.success,
        session: session,
      ));

      return true;
    } catch (e) {
      debugPrint('MoodQuizCubit error: $e');
      emit(state.copyWith(
        status: MoodQuizStatus.error,
        errorMessage: 'Failed to get recommendations. Please try again.',
      ));
      return false;
    }
  }

  void resetStatus() {
    emit(state.copyWith(status: MoodQuizStatus.initial));
  }
}
