import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:vibestream/core/services/history_service.dart';
import 'package:vibestream/core/services/home_refresh_service.dart';
import 'package:vibestream/features/auth/data/app_user_service.dart';
import 'package:vibestream/features/auth/data/auth_service.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';
import 'package:vibestream/features/settings/presentation/cubits/settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  final AppUserService _appUserService;
  final AuthService _authService;
  final HistoryService _historyService;
  final ProfileService _profileService;

  SettingsCubit({
    AppUserService? appUserService,
    AuthService? authService,
    HistoryService? historyService,
    ProfileService? profileService,
  })  : _appUserService = appUserService ?? AppUserService(),
        _authService = authService ?? AuthService(),
        _historyService = historyService ?? HistoryService(),
        _profileService = profileService ?? ProfileService(),
        super(const SettingsState());

  /// Initialize settings - load user and package info
  Future<void> init() async {
    await Future.wait([
      _loadAppUser(),
      _loadPackageInfo(),
      _loadActiveProfile(),
    ]);
  }

  Future<void> _loadActiveProfile() async {
    try {
      final activeProfile = await _profileService.getActiveProfile();
      emit(state.copyWith(activeProfile: activeProfile, isLoadingProfile: false));
    } catch (e) {
      debugPrint('SettingsCubit._loadActiveProfile error: $e');
      emit(state.copyWith(isLoadingProfile: false));
    }
  }

  Future<void> _loadAppUser() async {
    try {
      final user = await _appUserService.getCurrentAppUser();
      emit(state.copyWith(appUser: user, isLoadingUser: false));
    } catch (e) {
      debugPrint('SettingsCubit._loadAppUser error: $e');
      emit(state.copyWith(isLoadingUser: false));
    }
  }

  Future<void> _loadPackageInfo() async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      emit(state.copyWith(
        appVersion: packageInfo.version,
        buildNumber: packageInfo.buildNumber,
      ));
    } catch (e) {
      debugPrint('SettingsCubit._loadPackageInfo error: $e');
    }
  }

  /// Toggle hide spoilers setting
  void toggleHideSpoilers() {
    emit(state.copyWith(hideSpoilers: !state.hideSpoilers));
  }

  /// Clear discovery history
  Future<bool> clearHistory() async {
    emit(state.copyWith(isClearingHistory: true, clearError: true));

    try {
      final success = await _historyService.clearDiscoveryHistory();

      if (success) {
        // Notify home page to refresh
        HomeRefreshService().requestRefresh(reason: HomeRefreshReason.manual);
        emit(state.copyWith(
          isClearingHistory: false,
          status: SettingsStatus.success,
        ));
        return true;
      } else {
        emit(state.copyWith(
          isClearingHistory: false,
          status: SettingsStatus.failure,
          errorMessage: 'Failed to clear history',
        ));
        return false;
      }
    } catch (e) {
      debugPrint('SettingsCubit.clearHistory error: $e');
      emit(state.copyWith(
        isClearingHistory: false,
        status: SettingsStatus.failure,
        errorMessage: 'An error occurred while clearing history',
      ));
      return false;
    }
  }

  /// Sign out the user
  Future<void> signOut() async {
    emit(state.copyWith(status: SettingsStatus.loading));

    try {
      await _authService.signOut();
      emit(state.copyWith(
        status: SettingsStatus.success,
        clearUser: true,
      ));
    } catch (e) {
      debugPrint('SettingsCubit.signOut error: $e');
      emit(state.copyWith(
        status: SettingsStatus.failure,
        errorMessage: 'Failed to sign out',
      ));
    }
  }

  /// Refresh user data
  Future<void> refreshUser() async {
    emit(state.copyWith(isLoadingUser: true));
    await _loadAppUser();
  }

  Future<void> refreshProfile() async {
    emit(state.copyWith(isLoadingProfile: true));
    await _profileService.refresh();
    await _loadActiveProfile();
  }

  Future<bool> updateCountry({required String countryCode, required String countryName}) async {
    emit(state.copyWith(isUpdatingCountry: true, clearError: true));
    try {
      // Keep app-level region in sync (used for provider availability, etc.)
      await _appUserService.updateRegion(region: countryCode);

      final success = await _profileService.updateActiveProfileCountry(countryCode: countryCode, countryName: countryName);
      if (!success) {
        emit(state.copyWith(
          isUpdatingCountry: false,
          status: SettingsStatus.failure,
          errorMessage: 'Failed to update country',
        ));
        return false;
      }

      await _loadActiveProfile();
      emit(state.copyWith(isUpdatingCountry: false, status: SettingsStatus.success));
      return true;
    } catch (e) {
      debugPrint('SettingsCubit.updateCountry error: $e');
      emit(state.copyWith(
        isUpdatingCountry: false,
        status: SettingsStatus.failure,
        errorMessage: 'Failed to update country',
      ));
      return false;
    }
  }

  /// Clear any error messages
  void clearError() {
    emit(state.copyWith(clearError: true, status: SettingsStatus.initial));
  }
}
