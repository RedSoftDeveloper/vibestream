import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibestream/core/services/subscription_service.dart';
import 'package:vibestream/features/subscription/presentation/cubits/subscription_state.dart';

class SubscriptionCubit extends Cubit<SubscriptionState> {
  final SubscriptionService _subscriptionService;

  SubscriptionCubit({SubscriptionService? subscriptionService})
      : _subscriptionService = subscriptionService ?? SubscriptionService.instance,
        super(const SubscriptionState()) {
    _init();
  }

  void _init() {
    emit(state.copyWith(status: SubscriptionStatus.loading));
    
    // Check initial status
    final isPremium = _subscriptionService.isPremium;
    emit(state.copyWith(
      status: SubscriptionStatus.success,
      isPremium: isPremium,
    ));

    // Listen for updates
    _subscriptionService.premiumStatusStream.listen((isPremium) {
      emit(state.copyWith(
        status: SubscriptionStatus.success,
        isPremium: isPremium,
      ));
    });
  }

  Future<void> showPaywall() async {
    try {
      await _subscriptionService.showPaywall();
    } catch (e) {
      emit(state.copyWith(
        status: SubscriptionStatus.failure,
        errorMessage: 'Failed to show paywall: $e',
      ));
    }
  }

  void clearError() {
    if (state.errorMessage == null) return;
    emit(state.copyWith(errorMessage: null));
  }

  Future<void> restorePurchases() async {
    emit(state.copyWith(status: SubscriptionStatus.loading));
    try {
      await _subscriptionService.restorePurchases();
      emit(state.copyWith(status: SubscriptionStatus.success));
    } catch (e) {
      emit(state.copyWith(
        status: SubscriptionStatus.failure,
        errorMessage: 'Failed to restore purchases: $e',
      ));
    }
  }
}
