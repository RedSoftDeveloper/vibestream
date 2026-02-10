import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:vibestream/core/services/analytics_service.dart';

/// Opinionated Mixpanel tracker for the onboarding funnel.
///
/// Goals:
/// - Every time the user is routed to onboarding, we start a new funnel session.
/// - Each step view and action is tracked with consistent properties so you can
///   build a Mixpanel funnel with drop-off + time-to-complete.
///
/// Event naming is intentionally stable and human readable.
class OnboardingFunnelTracker {
  static const String funnelName = 'onboarding_v1';

  static String? _flowId;
  static DateTime? _startedAt;
  static int? _lastStepIndex;

  static bool get hasActiveFlow => _flowId != null;
  static String? get flowId => _flowId;

  static String _newFlowId() {
    final ts = DateTime.now().microsecondsSinceEpoch;
    // IMPORTANT (web): Avoid `Random().nextInt(1 << 32)`.
    // Depending on JS bit-ops lowering, `1 << 32` can become 0, which triggers:
    // RangeError: max must be in range 0 < max <= 2^32, was 0
    final random = Random();
    final hi = random.nextInt(1 << 16);
    final lo = random.nextInt(1 << 16);
    final rand32 = (hi << 16) | lo;
    return 'ob_${ts}_${rand32.toRadixString(16)}';
  }

  static Map<String, dynamic> _baseProps({int? stepIndex, String? stepName}) {
    final now = DateTime.now();
    final started = _startedAt;
    final durationMs = started == null ? null : now.difference(started).inMilliseconds;
    return {
      'funnel': funnelName,
      if (_flowId != null) 'onboarding_flow_id': _flowId,
      if (started != null) 'onboarding_started_at': started.toIso8601String(),
      if (durationMs != null) 'onboarding_elapsed_ms': durationMs,
      if (stepIndex != null) 'step_index': stepIndex,
      if (stepName != null) 'step_name': stepName,
    };
  }

  static void start({required int stepIndex, required int totalSteps, required String stepName}) {
    _flowId = _newFlowId();
    _startedAt = DateTime.now();
    _lastStepIndex = stepIndex;

    _track('onboarding_started', props: {
      ..._baseProps(stepIndex: stepIndex, stepName: stepName),
      'total_steps': totalSteps,
    });
    stepViewed(stepIndex: stepIndex, totalSteps: totalSteps, stepName: stepName, isFirstViewInFlow: true);
  }

  static void stepViewed({required int stepIndex, required int totalSteps, required String stepName, bool isFirstViewInFlow = false}) {
    // Avoid double-fire when the same step re-builds.
    if (!isFirstViewInFlow && _lastStepIndex == stepIndex) return;
    _lastStepIndex = stepIndex;

    _track('onboarding_step_viewed', props: {
      ..._baseProps(stepIndex: stepIndex, stepName: stepName),
      'total_steps': totalSteps,
    });
  }

  static void action({required String actionName, required int stepIndex, required int totalSteps, required String stepName, Map<String, dynamic>? extra}) {
    _track('onboarding_action', props: {
      ..._baseProps(stepIndex: stepIndex, stepName: stepName),
      'total_steps': totalSteps,
      'action': actionName,
      if (extra != null) ...extra,
    });
  }

  static void blocked({required String reason, required int stepIndex, required int totalSteps, required String stepName}) {
    _track('onboarding_blocked', props: {
      ..._baseProps(stepIndex: stepIndex, stepName: stepName),
      'total_steps': totalSteps,
      'reason': reason,
    });
  }

  static void skipped({required int stepIndex, required int totalSteps, required String stepName}) {
    _track('onboarding_skipped', props: {
      ..._baseProps(stepIndex: stepIndex, stepName: stepName),
      'total_steps': totalSteps,
    });
  }

  static void completed({required int stepIndex, required int totalSteps, required String stepName}) {
    _track('onboarding_completed', props: {
      ..._baseProps(stepIndex: stepIndex, stepName: stepName),
      'total_steps': totalSteps,
    });
  }

  static void reset() {
    _flowId = null;
    _startedAt = null;
    _lastStepIndex = null;
  }

  static void _track(String event, {required Map<String, dynamic> props}) {
    if (!AnalyticsService.isInitialized) return;
    try {
      AnalyticsService.instance.track(event, properties: props);
    } catch (e) {
      debugPrint('OnboardingFunnelTracker track failed ($event): $e');
    }
  }
}
