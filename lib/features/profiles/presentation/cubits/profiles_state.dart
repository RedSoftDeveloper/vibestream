import 'package:equatable/equatable.dart';
import 'package:vibestream/features/profiles/domain/entities/user_profile.dart';

enum ProfilesStatus { initial, loading, loaded, error }

class ProfilesState extends Equatable {
  final ProfilesStatus status;
  final List<UserProfile> profiles;
  final String? selectedProfileId;
  final String? errorMessage;

  const ProfilesState({
    this.status = ProfilesStatus.initial,
    this.profiles = const [],
    this.selectedProfileId,
    this.errorMessage,
  });

  bool get isLoading => status == ProfilesStatus.loading;

  UserProfile? get selectedProfile {
    if (selectedProfileId == null) return null;
    try {
      return profiles.firstWhere((p) => p.id == selectedProfileId);
    } catch (_) {
      return null;
    }
  }

  ProfilesState copyWith({
    ProfilesStatus? status,
    List<UserProfile>? profiles,
    String? selectedProfileId,
    String? errorMessage,
  }) {
    return ProfilesState(
      status: status ?? this.status,
      profiles: profiles ?? this.profiles,
      selectedProfileId: selectedProfileId ?? this.selectedProfileId,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, profiles, selectedProfileId, errorMessage];
}
