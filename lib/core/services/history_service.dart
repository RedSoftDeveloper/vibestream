import 'package:flutter/foundation.dart';
import 'package:vibestream/supabase/supabase_config.dart';
import 'package:vibestream/features/profiles/data/profile_service.dart';

/// Service to clear user discovery history.
/// 
/// This clears:
/// - recommendation_sessions (and cascades to recommendation_items)
/// - profile_title_interactions (feedback, likes, dislikes, etc.)
/// 
/// This does NOT clear:
/// - profile_favorites (explicit user saves)
/// - profiles (account settings)
/// - profile_preferences (onboarding answers)
class HistoryService {
  final ProfileService _profileService = ProfileService();

  /// Clears all discovery history for the currently active profile.
  /// Returns true if successful, false otherwise.
  Future<bool> clearDiscoveryHistory() async {
    try {
      final profile = await _profileService.getActiveProfile();
      if (profile == null) {
        debugPrint('HistoryService: No active profile found');
        return false;
      }

      final profileId = profile.id;
      debugPrint('HistoryService: Clearing history for profile $profileId');

      // 1. Delete recommendation_items first (they reference sessions)
      // Note: We need to get session IDs first, then delete items
      final sessions = await SupabaseConfig.client
          .from('recommendation_sessions')
          .select('id')
          .eq('profile_id', profileId);

      if ((sessions as List).isNotEmpty) {
        final sessionIds = sessions.map((s) => s['id'] as String).toList();
        
        // Delete recommendation_items for these sessions
        await SupabaseConfig.client
            .from('recommendation_items')
            .delete()
            .inFilter('session_id', sessionIds);
        
        debugPrint('HistoryService: Deleted recommendation items for ${sessionIds.length} sessions');
      }

      // 2. Delete recommendation_sessions
      await SupabaseConfig.client
          .from('recommendation_sessions')
          .delete()
          .eq('profile_id', profileId);
      
      debugPrint('HistoryService: Deleted recommendation sessions');

      // 3. Delete profile_title_interactions (feedback, likes, dislikes, etc.)
      await SupabaseConfig.client
          .from('profile_title_interactions')
          .delete()
          .eq('profile_id', profileId);
      
      debugPrint('HistoryService: Deleted profile title interactions');

      debugPrint('HistoryService: Successfully cleared all discovery history');
      return true;
    } catch (e) {
      debugPrint('HistoryService.clearDiscoveryHistory error: $e');
      return false;
    }
  }

  /// Gets counts of items that will be cleared (for confirmation dialog).
  Future<HistoryCounts> getHistoryCounts() async {
    try {
      final profile = await _profileService.getActiveProfile();
      if (profile == null) {
        return HistoryCounts.empty();
      }

      final profileId = profile.id;

      // Count recommendation sessions
      final sessionsResult = await SupabaseConfig.client
          .from('recommendation_sessions')
          .select('id')
          .eq('profile_id', profileId);
      final sessionCount = (sessionsResult as List).length;

      // Count interactions
      final interactionsResult = await SupabaseConfig.client
          .from('profile_title_interactions')
          .select('id')
          .eq('profile_id', profileId);
      final interactionCount = (interactionsResult as List).length;

      return HistoryCounts(
        sessionCount: sessionCount,
        interactionCount: interactionCount,
      );
    } catch (e) {
      debugPrint('HistoryService.getHistoryCounts error: $e');
      return HistoryCounts.empty();
    }
  }
}

/// Holds counts of items that will be cleared.
class HistoryCounts {
  final int sessionCount;
  final int interactionCount;

  HistoryCounts({
    required this.sessionCount,
    required this.interactionCount,
  });

  factory HistoryCounts.empty() => HistoryCounts(sessionCount: 0, interactionCount: 0);

  bool get isEmpty => sessionCount == 0 && interactionCount == 0;
  int get total => sessionCount + interactionCount;
}
