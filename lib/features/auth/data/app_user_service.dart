import 'package:flutter/foundation.dart';
import 'package:vibestream/supabase/supabase_config.dart';

class AppUser {
  final String id;
  final DateTime createdAt;
  final String? displayName;
  final String? avatarUrl;
  final String region;
  final String locale;
  final String? lastActiveProfileId;

  AppUser({
    required this.id,
    required this.createdAt,
    this.displayName,
    this.avatarUrl,
    required this.region,
    required this.locale,
    this.lastActiveProfileId,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'] as String,
    createdAt: DateTime.parse(json['created_at'] as String),
    displayName: json['display_name'] as String?,
    avatarUrl: json['avatar_url'] as String?,
    region: json['region'] as String? ?? 'SE',
    locale: json['locale'] as String? ?? 'en',
    lastActiveProfileId: json['last_active_profile_id'] as String?,
  );

  String get displayNameOrDefault => displayName ?? 'Movie Lover';
  
  int get memberSinceYear => createdAt.year;
}

class AppUserService {
  static final AppUserService _instance = AppUserService._internal();
  factory AppUserService() => _instance;
  AppUserService._internal();

  AppUser? _cachedUser;

  Future<AppUser?> getCurrentAppUser() async {
    try {
      final authUser = SupabaseConfig.auth.currentUser;
      if (authUser == null) return null;

      // Return cached user if available
      if (_cachedUser != null && _cachedUser!.id == authUser.id) {
        return _cachedUser;
      }

      final response = await SupabaseConfig.client
          .from('app_users')
          .select()
          .eq('id', authUser.id)
          .maybeSingle();

      if (response == null) return null;

      _cachedUser = AppUser.fromJson(response);
      return _cachedUser;
    } catch (e) {
      debugPrint('AppUserService getCurrentAppUser error: $e');
      return null;
    }
  }

  void clearCache() {
    _cachedUser = null;
  }

  Future<bool> updateDisplayName(String displayName) async {
    try {
      final authUser = SupabaseConfig.auth.currentUser;
      if (authUser == null) return false;

      await SupabaseConfig.client
          .from('app_users')
          .update({'display_name': displayName})
          .eq('id', authUser.id);

      clearCache();
      return true;
    } catch (e) {
      debugPrint('AppUserService updateDisplayName error: $e');
      return false;
    }
  }
}
