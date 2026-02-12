import 'package:equatable/equatable.dart';

enum SubscriptionStatus { initial, loading, success, failure }

class SubscriptionState extends Equatable {
  final SubscriptionStatus status;
  final bool isPremium;
  final String? errorMessage;

  const SubscriptionState({
    this.status = SubscriptionStatus.initial,
    this.isPremium = false,
    this.errorMessage,
  });

  SubscriptionState copyWith({
    SubscriptionStatus? status,
    bool? isPremium,
    String? errorMessage,
  }) {
    return SubscriptionState(
      status: status ?? this.status,
      isPremium: isPremium ?? this.isPremium,
      errorMessage: errorMessage,
    );
  }

  @override
  List<Object?> get props => [status, isPremium, errorMessage];
}
