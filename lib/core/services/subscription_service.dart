import 'dart:async';
import 'dart:io';

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
  static const _apiKeyAndroid = 'goog_YOUR_ANDROID_API_KEY';
  static const _apiKeyIOS = 'appl_YOUR_IOS_API_KEY';
  
  // The entitlement ID configured in RevenueCat dashboard
  static const _entitlementID = 'premium'; 

  final _premiumStatusController = StreamController<bool>.broadcast();
  Stream<bool> get premiumStatusStream => _premiumStatusController.stream;

  bool _isPremium = false;
  bool get isPremium => _isPremium;

  Future<void> initialize() async {
    await Purchases.setLogLevel(LogLevel.debug);

    PurchasesConfiguration? configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_apiKeyAndroid);
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration(_apiKeyIOS);
    }

    if (configuration != null) {
      await Purchases.configure(configuration);
      await _checkSubscriptionStatus();
      
      // Listen for updates
      Purchases.addCustomerInfoUpdateListener((customerInfo) {
        _updateCustomerStatus(customerInfo);
      });
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
    try {
      // You can use presentPaywallIfNeeded if you only want to show it to non-subscribers
      // But usually "Get Premium" button implies force showing it.
      final paywallResult = await RevenueCatUI.presentPaywall();
      debugPrint('Paywall result: $paywallResult');
    } catch (e) {
      debugPrint('Error showing paywall: $e');
    }
  }
  
  /// Restore purchases
  Future<void> restorePurchases() async {
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
