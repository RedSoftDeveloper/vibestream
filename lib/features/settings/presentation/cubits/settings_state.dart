import 'package:equatable/equatable.dart';
import 'package:vibestream/features/auth/data/app_user_service.dart';
import 'package:vibestream/features/profiles/domain/entities/user_profile.dart';

enum SettingsStatus { initial, loading, success, failure }

class SettingsState extends Equatable {
  final SettingsStatus status;
  final String? errorMessage;
  final AppUser? appUser;
  final bool isLoadingUser;
  final UserProfile? activeProfile;
  final bool isLoadingProfile;
  final bool isUpdatingCountry;
  final bool hideSpoilers;
  final bool isClearingHistory;
  final String appVersion;
  final String buildNumber;

  const SettingsState({
    this.status = SettingsStatus.initial,
    this.errorMessage,
    this.appUser,
    this.isLoadingUser = true,
    this.activeProfile,
    this.isLoadingProfile = true,
    this.isUpdatingCountry = false,
    this.hideSpoilers = true,
    this.isClearingHistory = false,
    this.appVersion = '',
    this.buildNumber = '',
  });

  bool get isLoading => status == SettingsStatus.loading;

  SettingsState copyWith({
    SettingsStatus? status,
    String? errorMessage,
    AppUser? appUser,
    bool? isLoadingUser,
    UserProfile? activeProfile,
    bool? isLoadingProfile,
    bool? isUpdatingCountry,
    bool? hideSpoilers,
    bool? isClearingHistory,
    String? appVersion,
    String? buildNumber,
    bool clearError = false,
    bool clearUser = false,
  }) {
    return SettingsState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      appUser: clearUser ? null : (appUser ?? this.appUser),
      isLoadingUser: isLoadingUser ?? this.isLoadingUser,
      activeProfile: activeProfile ?? this.activeProfile,
      isLoadingProfile: isLoadingProfile ?? this.isLoadingProfile,
      isUpdatingCountry: isUpdatingCountry ?? this.isUpdatingCountry,
      hideSpoilers: hideSpoilers ?? this.hideSpoilers,
      isClearingHistory: isClearingHistory ?? this.isClearingHistory,
      appVersion: appVersion ?? this.appVersion,
      buildNumber: buildNumber ?? this.buildNumber,
    );
  }

  @override
  List<Object?> get props => [
        status,
        errorMessage,
        appUser,
        isLoadingUser,
        activeProfile,
        isLoadingProfile,
        isUpdatingCountry,
        hideSpoilers,
        isClearingHistory,
        appVersion,
        buildNumber,
      ];
}
