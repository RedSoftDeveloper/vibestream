import 'package:equatable/equatable.dart';
import 'package:vibestream/features/auth/data/auth_service.dart';

enum AuthStatus { initial, loading, success, failure }

class AuthState extends Equatable {
  // Common state
  final AuthStatus status;
  final String? errorMessage;
  final AuthFlowType flowType;

  // Login state
  final bool loginObscurePassword;

  // Register state
  final bool registerObscurePassword;
  final bool registerObscureConfirmPassword;
  final bool agreeToTerms;

  // Forgot password - no additional state needed

  // OTP state
  final bool isResending;
  final int resendCooldown;

  // Create new password state
  final bool createPasswordObscure;
  final bool createPasswordConfirmObscure;

  // Navigation flags
  final bool needsVerification;
  final bool userAlreadyExists;
  final bool passwordUpdateSuccess;

  // OAuth state
  final bool isGoogleLoading;
  final bool isAppleLoading;

  const AuthState({
    this.status = AuthStatus.initial,
    this.errorMessage,
    this.flowType = AuthFlowType.signIn,
    this.loginObscurePassword = true,
    this.registerObscurePassword = true,
    this.registerObscureConfirmPassword = true,
    this.agreeToTerms = false,
    this.isResending = false,
    this.resendCooldown = 0,
    this.createPasswordObscure = true,
    this.createPasswordConfirmObscure = true,
    this.needsVerification = false,
    this.userAlreadyExists = false,
    this.passwordUpdateSuccess = false,
    this.isGoogleLoading = false,
    this.isAppleLoading = false,
  });

  bool get isLoading => status == AuthStatus.loading;
  bool get isSuccess => status == AuthStatus.success;
  bool get isFailure => status == AuthStatus.failure;
  bool get isOAuthLoading => isGoogleLoading || isAppleLoading;

  AuthState copyWith({
    AuthStatus? status,
    String? errorMessage,
    AuthFlowType? flowType,
    bool? loginObscurePassword,
    bool? registerObscurePassword,
    bool? registerObscureConfirmPassword,
    bool? agreeToTerms,
    bool? isResending,
    int? resendCooldown,
    bool? createPasswordObscure,
    bool? createPasswordConfirmObscure,
    bool? needsVerification,
    bool? userAlreadyExists,
    bool? passwordUpdateSuccess,
    bool? isGoogleLoading,
    bool? isAppleLoading,
    bool clearError = false,
  }) {
    return AuthState(
      status: status ?? this.status,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      flowType: flowType ?? this.flowType,
      loginObscurePassword: loginObscurePassword ?? this.loginObscurePassword,
      registerObscurePassword: registerObscurePassword ?? this.registerObscurePassword,
      registerObscureConfirmPassword: registerObscureConfirmPassword ?? this.registerObscureConfirmPassword,
      agreeToTerms: agreeToTerms ?? this.agreeToTerms,
      isResending: isResending ?? this.isResending,
      resendCooldown: resendCooldown ?? this.resendCooldown,
      createPasswordObscure: createPasswordObscure ?? this.createPasswordObscure,
      createPasswordConfirmObscure: createPasswordConfirmObscure ?? this.createPasswordConfirmObscure,
      needsVerification: needsVerification ?? this.needsVerification,
      userAlreadyExists: userAlreadyExists ?? this.userAlreadyExists,
      passwordUpdateSuccess: passwordUpdateSuccess ?? this.passwordUpdateSuccess,
      isGoogleLoading: isGoogleLoading ?? this.isGoogleLoading,
      isAppleLoading: isAppleLoading ?? this.isAppleLoading,
    );
  }

  @override
  List<Object?> get props => [
        status,
        errorMessage,
        flowType,
        loginObscurePassword,
        registerObscurePassword,
        registerObscureConfirmPassword,
        agreeToTerms,
        isResending,
        resendCooldown,
        createPasswordObscure,
        createPasswordConfirmObscure,
        needsVerification,
        userAlreadyExists,
        passwordUpdateSuccess,
        isGoogleLoading,
        isAppleLoading,
      ];
}
