import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:vibestream/supabase/supabase_config.dart';
import 'package:vibestream/features/profiles/domain/entities/user_profile.dart';

class ProfileService extends ChangeNotifier {
  static final ProfileService _instance = ProfileService._internal();
  factory ProfileService() => _instance;
  ProfileService._internal();

  List<UserProfile> _profiles = [];
  String? _selectedProfileId;
  bool _initialized = false;
  bool _isLoading = false;

  List<UserProfile> get profiles => _profiles;
  bool get isLoading => _isLoading;
  
  UserProfile? get selectedProfile => 
      _profiles.where((p) => p.id == _selectedProfileId).firstOrNull;

  String? get selectedProfileId => _selectedProfileId;

  static const List<String> availableEmojis = [
    '👤', '👨', '👩', '👦', '👧', '👴', '👵',
    '👨‍👩‍👧', '👨‍👩‍👦', '👪', '💑', '👫', '👬', '👭',
    '🎬', '🍿', '🎮', '📺', '🎵', '🎸', '🎭',
    '❤️', '💜', '💙', '💚', '💛', '🧡', '🖤',
    '🌟', '⭐', '🔥', '✨', '🎯', '🎪', '🎨',
  ];

  static String getRandomEmoji() {
    final random = Random();
    return availableEmojis[random.nextInt(availableEmojis.length)];
  }

  String? get _currentUserId => SupabaseConfig.auth.currentUser?.id;

  Future<void> init() async {
    if (_initialized) return;
    await _loadProfiles();
    _initialized = true;
  }

  Future<void> refresh() async {
    _initialized = false;
    await _loadProfiles();
    _initialized = true;
  }

  Future<void> _loadProfiles() async {
    try {
      _isLoading = true;
      notifyListeners();

      final userId = _currentUserId;
      if (userId == null) {
        debugPrint('ProfileService: No authenticated user');
        _profiles = [];
        _selectedProfileId = null;
        return;
      }

      // Load profiles from Supabase
      final profilesData = await SupabaseConfig.client
          .from('profiles')
          .select()
          .eq('user_id', userId)
          .order('created_at', ascending: true);

      _profiles = (profilesData as List<dynamic>)
          .map((p) => UserProfile.fromJson(p as Map<String, dynamic>))
          .toList();

      // Get the active profile from app_users
      final appUserData = await SupabaseConfig.client
          .from('app_users')
          .select('last_active_profile_id')
          .eq('id', userId)
          .maybeSingle();

      if (appUserData != null) {
        _selectedProfileId = appUserData['last_active_profile_id'] as String?;
      }

      // If no active profile set but profiles exist, select the first one
      if (_selectedProfileId == null && _profiles.isNotEmpty) {
        _selectedProfileId = _profiles.first.id;
        await _updateLastActiveProfile(_selectedProfileId!);
      }

      debugPrint('ProfileService: Loaded ${_profiles.length} profiles, selected: $_selectedProfileId');
    } catch (e) {
      debugPrint('ProfileService._loadProfiles error: $e');
      _profiles = [];
      _selectedProfileId = null;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Gets profiles for the current user
  Future<List<UserProfile>> getProfilesForCurrentUser() async {
    if (!_initialized) await init();
    return _profiles;
  }

  /// Gets the active profile, creating one if needed during onboarding
  Future<UserProfile?> getActiveProfile() async {
    if (!_initialized) await init();
    return selectedProfile;
  }

  /// Creates a new profile for the current user
  Future<UserProfile?> createProfile(String name, {String emoji = '👤'}) async {
    try {
      final userId = _currentUserId;
      if (userId == null) {
        debugPrint('ProfileService.createProfile: No user ID available');
        return null;
      }

      debugPrint('ProfileService.createProfile: Creating profile for user $userId');

      final now = DateTime.now().toUtc();
      final newProfileData = {
        'user_id': userId,
        'name': name,
        'emoji': emoji,
        'created_at': now.toIso8601String(),
        'updated_at': now.toIso8601String(),
      };

      final result = await SupabaseConfig.client
          .from('profiles')
          .insert(newProfileData)
          .select()
          .single();

      final newProfile = UserProfile.fromJson(result);
      _profiles.add(newProfile);
      
      // If this is the first profile, set it as active
      if (_profiles.length == 1) {
        await setActiveProfile(newProfile.id);
      }

      notifyListeners();
      debugPrint('ProfileService: Created profile ${newProfile.id}');
      return newProfile;
    } catch (e) {
      debugPrint('ProfileService.createProfile error: $e');
      debugPrint('ProfileService: Check RLS policies on "profiles" table - ensure INSERT is allowed for authenticated users');
      return null;
    }
  }

  /// Creates the first profile during onboarding if none exists
  /// Includes retry logic to handle race condition with DB triggers
  Future<UserProfile?> ensureProfileExists({String defaultName = 'Solo', int maxRetries = 5}) async {
    // Reset initialized flag to force fresh load
    _initialized = false;
    
    for (int attempt = 0; attempt < maxRetries; attempt++) {
      await _loadProfiles();
      _initialized = true;
      
      if (_profiles.isNotEmpty) {
        debugPrint('ProfileService.ensureProfileExists: Found profile on attempt ${attempt + 1}');
        return selectedProfile;
      }
      
      // Wait before retrying (exponential backoff: 500ms, 1s, 2s, 4s, 8s)
      if (attempt < maxRetries - 1) {
        final waitMs = 500 * (1 << attempt);
        debugPrint('ProfileService.ensureProfileExists: No profile found, retrying in ${waitMs}ms (attempt ${attempt + 1}/$maxRetries)');
        await Future.delayed(Duration(milliseconds: waitMs));
        _initialized = false; // Reset to force fresh load
      }
    }
    
    // If still no profile after retries, create one
    debugPrint('ProfileService.ensureProfileExists: No profile found after $maxRetries retries, creating new profile');
    return await createProfile(defaultName, emoji: '👤');
  }

  /// Sets the active profile and updates app_users
  Future<void> setActiveProfile(String profileId) async {
    _selectedProfileId = profileId;
    await _updateLastActiveProfile(profileId);
    notifyListeners();
  }

  Future<void> _updateLastActiveProfile(String profileId) async {
    try {
      final userId = _currentUserId;
      if (userId == null) return;

      await SupabaseConfig.client
          .from('app_users')
          .update({'last_active_profile_id': profileId})
          .eq('id', userId);
    } catch (e) {
      debugPrint('ProfileService._updateLastActiveProfile error: $e');
    }
  }

  /// Saves taste preferences to profile_preferences table
  Future<bool> savePreferences(String profileId, Map<String, dynamic> answers) async {
    try {
      final now = DateTime.now().toUtc().toIso8601String();
      
      // Check if preferences already exist
      final existing = await SupabaseConfig.client
          .from('profile_preferences')
          .select('id')
          .eq('profile_id', profileId)
          .maybeSingle();

      if (existing != null) {
        // Update existing
        await SupabaseConfig.client
            .from('profile_preferences')
            .update({
              'answers': answers,
              'updated_at': now,
            })
            .eq('profile_id', profileId);
      } else {
        // Insert new
        await SupabaseConfig.client
            .from('profile_preferences')
            .insert({
              'profile_id': profileId,
              'answers': answers,
              'created_at': now,
              'updated_at': now,
            });
      }

      debugPrint('ProfileService: Saved preferences for profile $profileId');
      return true;
    } catch (e) {
      debugPrint('ProfileService.savePreferences error: $e');
      return false;
    }
  }

  /// Gets preferences for a profile
  Future<Map<String, dynamic>?> getPreferences(String profileId) async {
    try {
      final result = await SupabaseConfig.client
          .from('profile_preferences')
          .select('answers')
          .eq('profile_id', profileId)
          .maybeSingle();

      if (result != null) {
        return result['answers'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('ProfileService.getPreferences error: $e');
      return null;
    }
  }

  /// Check if the current user has completed onboarding
  /// Onboarding is considered complete if profile_preferences exists for any profile
  Future<bool> hasCompletedOnboarding() async {
    try {
      final userId = _currentUserId;
      if (userId == null) return false;

      // First get user's profiles
      final profilesData = await SupabaseConfig.client
          .from('profiles')
          .select('id')
          .eq('user_id', userId)
          .limit(1);

      if (profilesData == null || (profilesData as List).isEmpty) {
        debugPrint('ProfileService.hasCompletedOnboarding: No profiles found');
        return false;
      }

      final profileId = profilesData[0]['id'] as String;

      // Check if profile_preferences exists for this profile
      final prefsData = await SupabaseConfig.client
          .from('profile_preferences')
          .select('id')
          .eq('profile_id', profileId)
          .maybeSingle();

      final hasPreferences = prefsData != null;
      debugPrint('ProfileService.hasCompletedOnboarding: $hasPreferences');
      return hasPreferences;
    } catch (e) {
      debugPrint('ProfileService.hasCompletedOnboarding error: $e');
      return false;
    }
  }

  // Legacy method - now calls Supabase
  Future<void> selectProfile(String profileId) async {
    await setActiveProfile(profileId);
  }

  // Legacy method - now calls Supabase
  Future<void> addProfile(String name, {String emoji = '👤'}) async {
    await createProfile(name, emoji: emoji);
  }

  Future<void> updateProfile(String id, String name, {String? emoji}) async {
    try {
      final updateData = {
        'name': name,
        'updated_at': DateTime.now().toUtc().toIso8601String(),
      };
      if (emoji != null) {
        updateData['emoji'] = emoji;
      }

      await SupabaseConfig.client
          .from('profiles')
          .update(updateData)
          .eq('id', id);

      final index = _profiles.indexWhere((p) => p.id == id);
      if (index != -1) {
        _profiles[index] = _profiles[index].copyWith(
          name: name,
          emoji: emoji,
          updatedAt: DateTime.now(),
        );
        notifyListeners();
      }
    } catch (e) {
      debugPrint('ProfileService.updateProfile error: $e');
    }
  }

  Future<void> deleteProfile(String id) async {
    try {
      await SupabaseConfig.client
          .from('profiles')
          .delete()
          .eq('id', id);

      _profiles.removeWhere((p) => p.id == id);
      
      if (_selectedProfileId == id && _profiles.isNotEmpty) {
        await setActiveProfile(_profiles.first.id);
      }
      
      notifyListeners();
    } catch (e) {
      debugPrint('ProfileService.deleteProfile error: $e');
    }
  }

  void clearCache() {
    _profiles = [];
    _selectedProfileId = null;
    _initialized = false;
    notifyListeners();
  }
}
