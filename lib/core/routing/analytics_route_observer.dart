import 'package:flutter/material.dart';
import 'package:vibestream/core/services/analytics_service.dart';

/// Tracks screen views via the Navigator stack.
///
/// With go_router, attaching this observer to `GoRouter(observers: [...])`
/// gives us consistent, automatic screen_view events.
class AnalyticsRouteObserver extends NavigatorObserver {
  void _track(Route<dynamic>? route) {
    if (route == null) return;
    if (!AnalyticsService.isInitialized) return;
    final name = route.settings.name;
    final location = route.settings.arguments;

    // Prefer route name when available; fall back to runtimeType.
    final screenName = (name?.isNotEmpty == true) ? name! : route.runtimeType.toString();
    AnalyticsService.instance.track('screen_view', properties: {
      'screen_name': screenName,
      if (location != null) 'route_arguments': location.toString(),
    });
  }

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    _track(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    super.didReplace(newRoute: newRoute, oldRoute: oldRoute);
    _track(newRoute);
  }
}
