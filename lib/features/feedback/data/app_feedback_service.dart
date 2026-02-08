import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AppFeedbackService {
  static final _supabase = Supabase.instance.client;

  /// Submits app feedback from the current user
  /// Returns true if successful, false otherwise
  static Future<bool> submitFeedback(String feedbackText, {required String profileId}) async {
    try {
      final userId = _supabase.auth.currentUser?.id;
      
      if (userId == null) {
        debugPrint('AppFeedbackService: No authenticated user');
        return false;
      }

      if (profileId.isEmpty) {
        debugPrint('AppFeedbackService: No profile ID provided');
        return false;
      }

      if (feedbackText.trim().isEmpty) {
        debugPrint('AppFeedbackService: Feedback text is empty');
        return false;
      }

      // Enforce max 400 characters
      final sanitizedText = feedbackText.trim().length > 400 
          ? feedbackText.trim().substring(0, 400) 
          : feedbackText.trim();

      await _supabase.from('app_feedback').insert({
        'user_id': userId,
        'profile_id': profileId,
        'feedback_text': sanitizedText,
      });

      debugPrint('AppFeedbackService: Feedback submitted successfully');
      return true;
    } catch (e) {
      debugPrint('AppFeedbackService.submitFeedback error: $e');
      return false;
    }
  }
}
