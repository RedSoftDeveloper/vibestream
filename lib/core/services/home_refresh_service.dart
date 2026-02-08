import 'package:flutter/foundation.dart';

/// The reason for requesting a home page refresh
enum HomeRefreshReason {
  moodQuizCompleted,
  quickMatchCompleted,
  profileSwitched,
  manual,
}

/// A singleton service that notifies when the home page should refresh its data.
/// This is used to refresh the home page after completing a mood quiz, quick match, or search.
class HomeRefreshService extends ChangeNotifier {
  static final HomeRefreshService _instance = HomeRefreshService._internal();
  factory HomeRefreshService() => _instance;
  HomeRefreshService._internal();

  DateTime? _lastRefreshRequest;
  HomeRefreshReason? _lastRefreshReason;

  /// Request a refresh of the home page data
  void requestRefresh({HomeRefreshReason reason = HomeRefreshReason.manual}) {
    _lastRefreshRequest = DateTime.now();
    _lastRefreshReason = reason;
    debugPrint('HomeRefreshService: Refresh requested (${reason.name}) at $_lastRefreshRequest');
    notifyListeners();
  }

  /// Get the timestamp of the last refresh request
  DateTime? get lastRefreshRequest => _lastRefreshRequest;
  
  /// Get the reason for the last refresh request
  HomeRefreshReason? get lastRefreshReason => _lastRefreshReason;
}
