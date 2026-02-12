import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:purchases_ui_flutter/purchases_ui_flutter.dart';

/// Service to handle RevenueCat subscriptions.
/// 
/// This service is responsible for:
/// - Initializing RevenueCat SDK
/// - Checking subscription status
/// - Restoring purchases
/// - Displaying paywalls
class SubscriptionService {
  SubscriptionService._();

  static final SubscriptionService _instance = SubscriptionService._();
  static SubscriptionService get instance => _instance;

  // TODO: Replace with your actual RevenueCat API keys
  static const _apiKeyAndroid = 'goog_jlONPShzXtMrvNcVuNZtPQBaFjl';
  static const _apiKeyIOS = 'appl_BUTtPvMIHwXzkOWsUtqTHrRgyVu';
  
  // The entitlement ID configured in RevenueCat dashboard
  static const _entitlementID = 'VibeStream Premium'; 

  final _premiumStatusController = StreamController<bool>.broadcast();
  Stream<bool> get premiumStatusStream => _premiumStatusController.stream;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  Future<void> initialize() async {
    if (kIsWeb) {
      // RevenueCat does not support Flutter Web. Keep this service as a no-op.
      debugPrint('SubscriptionService: skipped initialization on Web.');
      return;
    }

    try {
      await Purchases.setLogLevel(LogLevel.debug);

      PurchasesConfiguration? configuration;
      if (defaultTargetPlatform == TargetPlatform.android) {
        configuration = PurchasesConfiguration(_apiKeyAndroid);
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        configuration = PurchasesConfiguration(_apiKeyIOS);
      }

      if (configuration == null) {
        debugPrint('SubscriptionService: unsupported platform: $defaultTargetPlatform');
        return;
      }

      await Purchases.configure(configuration);
      _isInitialized = true;
      await _checkSubscriptionStatus();

      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updateCustomerStatus(customerInfo);
      });
    } catch (e) {
      // On some platforms/environments (e.g. web preview, tests) plugins may not be registered.
      debugPrint('SubscriptionService: failed to initialize RevenueCat: $e');
      _isInitialized = false;
    }
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      _updateCustomerStatus(customerInfo);
    } catch (e) {
      debugPrint('Error checking subscription status: $e');
    }
  }

  void _updateCustomerStatus(CustomerInfo customerInfo) {
    final wasPremium = _isPremium;
    _isPremium = customerInfo.entitlements.all[_entitlementID]?.isActive ?? false;
    
    if (wasPremium != _isPremium) {
      debugPrint('Subscription status changed: $_isPremium');
      _premiumStatusController.add(_isPremium);
    }
  }

  /// Shows the paywall.
  /// 
  /// If [offerings] is provided, it will show the paywall for that offering.
  /// Otherwise it uses the default offering.
  Future<void> showPaywall() async {
    if (kIsWeb) {
      debugPrint('SubscriptionService: showPaywall is not supported on Web.');
      throw StateError('Subscriptions are not available on Web.');
    }
    if (!_isInitialized) {
      debugPrint('SubscriptionService: showPaywall requested before initialization.');
      throw StateError('Subscriptions are not initialized yet.');
    }
    try {
      // You can use presentPaywallIfNeeded if you only want to show it to non-subscribers
      // But usually "Get Premium" button implies force showing it.
      final paywallResult = await RevenueCatUI.presentPaywall();
      debugPrint('Paywall result: $paywallResult');
    } catch (e) {
      debugPrint('Error showing paywall: $e');
      rethrow;
    }
  }
  
  /// Restore purchases
  Future<void> restorePurchases() async {
    if (kIsWeb || !_isInitialized) {
      debugPrint('SubscriptionService: restorePurchases skipped (not initialized / web).');
      return;
    }
    try {
      final customerInfo = await Purchases.restorePurchases();
      _updateCustomerStatus(customerInfo);
    } catch (e) {
      debugPrint('Error restoring purchases: $e');
      rethrow;
    }
  }

  /// Manually dispose the stream controller
  void dispose() {
    _premiumStatusController.close();
  }
}
