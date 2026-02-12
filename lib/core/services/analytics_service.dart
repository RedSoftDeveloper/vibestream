import 'package:flutter/foundation.dart';
import 'package:mixpanel_flutter/mixpanel_flutter.dart';

/// Lightweight analytics wrapper to keep Mixpanel out of feature code.
///
/// Usage:
/// - Initialize once during app bootstrap: `await AnalyticsService.initialize();`
/// - Track: `AnalyticsService.instance.track('event_name', properties: {...});`
/// - Identify after auth: `AnalyticsService.instance.identify(userId);`
class AnalyticsService {
  AnalyticsService._(this._mixpanel);

  final Mixpanel? _mixpanel;

  static AnalyticsService? _instance;

  static bool get isInitialized => _instance != null;

  static AnalyticsService get instance {
    final value = _instance;
    if (value == null) {
      throw StateError('AnalyticsService not initialized. Call AnalyticsService.initialize() first.');
    }
    return value;
  }

  /// Mixpanel tokens are not secrets, but we still prefer dart-define so
  /// environments (dev/stage/prod) can differ.
  static const String _tokenFromEnv = String.fromEnvironment(
    'MIXPANEL_PROJECT_TOKEN',
    defaultValue: 'edcc59ac49fa5ae54b55a7f9f9b209cd',
  );

  static Future<void> initialize() async {
    if (_instance != null) return;

    // Dreamflow runs the preview on Web. Mixpanel's Flutter plugin currently
    // relies on a JS SDK initialization that isn't available in this project,
    // which causes runtime errors like:
    // "TypeError: Cannot read properties of undefined (reading 'init')".
    // Since this app targets mobile, we keep analytics as a no-op on Web.
    if (kIsWeb) {
      _instance = AnalyticsService._(null);
      return;
    }

    final token = _tokenFromEnv.trim();
    if (token.isEmpty) {
      debugPrint('Mixpanel token missing. Set --dart-define=MIXPANEL_PROJECT_TOKEN=...');
      // Still create a no-op instance by skipping initialization.
      _instance = AnalyticsService._(null);
      return;
    }

    try {
      final mixpanel = await Mixpanel.init(
        token,
        trackAutomaticEvents: true,
        optOutTrackingDefault: false,
      );
      _instance = AnalyticsService._(mixpanel);
      debugPrint('Mixpanel initialized');
    } catch (e) {
      debugPrint('Failed to initialize Mixpanel: $e');
      // Ensure we still have a usable no-op instance so callers don't crash.
      _instance = AnalyticsService._(null);
    }
  }

  void track(String eventName, {Map<String, dynamic>? properties}) {
    final mixpanel = _mixpanel;
    if (mixpanel == null) return;
    try {
      mixpanel.track(eventName, properties: properties);
    } catch (e) {
      debugPrint('Mixpanel track failed ($eventName): $e');
    }
  }

  void identify(String distinctId) {
    final mixpanel = _mixpanel;
    if (mixpanel == null) return;
    try {
      mixpanel.identify(distinctId);
    } catch (e) {
      debugPrint('Mixpanel identify failed: $e');
    }
  }

  void setUserProperties(Map<String, dynamic> properties) {
    final mixpanel = _mixpanel;
    if (mixpanel == null) return;
    try {
      final people = mixpanel.getPeople();
      for (final entry in properties.entries) {
        people.set(entry.key, entry.value);
      }
    } catch (e) {
      debugPrint('Mixpanel people.set failed: $e');
    }
  }

  void reset() {
    final mixpanel = _mixpanel;
    if (mixpanel == null) return;
    try {
      mixpanel.reset();
    } catch (e) {
      debugPrint('Mixpanel reset failed: $e');
    }
  }
}
