import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibestream/features/profiles/presentation/cubits/profiles_state.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';
import 'package:vibestream/features/profiles/domain/entities/user_profile.dart';

class ProfilesCubit extends Cubit<ProfilesState> {
  final ProfileService _profileService;

  ProfilesCubit({ProfileService? profileService})
      : _profileService = profileService ?? ProfileService(),
        super(const ProfilesState());

  void init() {
    _profileService.addListener(_onProfilesChanged);
    _syncWithService();
  }

  @override
  Future<void> close() {
    _profileService.removeListener(_onProfilesChanged);
    return super.close();
  }

  void _onProfilesChanged() {
    _syncWithService();
  }

  void _syncWithService() {
    emit(state.copyWith(
      status: ProfilesStatus.loaded,
      profiles: _profileService.profiles,
      selectedProfileId: _profileService.selectedProfileId,
    ));
  }

  Future<void> loadProfiles() async {
    emit(state.copyWith(status: ProfilesStatus.loading));
    
    try {
      await _profileService.init();
      _syncWithService();
    } catch (e) {
      debugPrint('ProfilesCubit: Error loading profiles: $e');
      emit(state.copyWith(
        status: ProfilesStatus.error,
        errorMessage: e.toString(),
      ));
    }
  }

  Future<bool> addProfile(String name, String emoji) async {
    try {
      await _profileService.addProfile(name, emoji: emoji);
      return true;
    } catch (e) {
      debugPrint('ProfilesCubit: Error adding profile: $e');
      return false;
    }
  }

  Future<bool> updateProfile(UserProfile profile) async {
    try {
      await _profileService.updateProfile(profile.id, profile.name, emoji: profile.emoji);
      return true;
    } catch (e) {
      debugPrint('ProfilesCubit: Error updating profile: $e');
      return false;
    }
  }

  Future<bool> deleteProfile(String profileId) async {
    try {
      await _profileService.deleteProfile(profileId);
      return true;
    } catch (e) {
      debugPrint('ProfilesCubit: Error deleting profile: $e');
      return false;
    }
  }

  void selectProfile(String profileId) {
    _profileService.selectProfile(profileId);
  }
}
