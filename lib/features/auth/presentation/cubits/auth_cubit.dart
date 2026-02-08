import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibestream/features/auth/data/auth_service.dart';
import 'package:vibestream/features/auth/presentation/cubits/auth_state.dart';

class AuthCubit extends Cubit<AuthState> {
  final AuthService _authService;
  Timer? _cooldownTimer;

  AuthCubit({AuthService? authService})
      : _authService = authService ?? AuthService(),
        super(const AuthState());

  @override
  Future<void> close() {
    _cooldownTimer?.cancel();
    return super.close();
  }

  // ─────────────────────────────────────────────────────────────────
  // COMMON ACTIONS
  // ─────────────────────────────────────────────────────────────────

  void clearError() {
    emit(state.copyWith(clearError: true, status: AuthStatus.initial));
  }

  void resetState() {
    _cooldownTimer?.cancel();
    emit(const AuthState());
  }

  // ─────────────────────────────────────────────────────────────────
  // LOGIN ACTIONS
  // ─────────────────────────────────────────────────────────────────

  void toggleLoginPasswordVisibility() {
    emit(state.copyWith(loginObscurePassword: !state.loginObscurePassword));
  }

  Future<void> login(String email, String password) async {
    emit(state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
      needsVerification: false,
    ));

    final result = await _authService.signIn(email, password);

    if (result.success) {
      if (result.needsVerification) {
        emit(state.copyWith(
          status: AuthStatus.success,
          needsVerification: true,
          flowType: AuthFlowType.signIn,
        ));
      } else {
        emit(state.copyWith(status: AuthStatus.success, needsVerification: false));
      }
    } else {
      debugPrint('AuthCubit.login error: ${result.errorMessage}');
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: result.errorMessage ?? 'Sign in failed',
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // REGISTER ACTIONS
  // ─────────────────────────────────────────────────────────────────

  void toggleRegisterPasswordVisibility() {
    emit(state.copyWith(registerObscurePassword: !state.registerObscurePassword));
  }

  void toggleRegisterConfirmPasswordVisibility() {
    emit(state.copyWith(registerObscureConfirmPassword: !state.registerObscureConfirmPassword));
  }

  void setAgreeToTerms(bool value) {
    emit(state.copyWith(agreeToTerms: value));
  }

  Future<void> register(String email, String password, String fullName) async {
    emit(state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
      needsVerification: false,
      userAlreadyExists: false,
    ));

    final result = await _authService.signUp(email, password, fullName);

    if (result.success) {
      if (result.needsVerification) {
        emit(state.copyWith(
          status: AuthStatus.success,
          needsVerification: true,
          flowType: AuthFlowType.signUp,
        ));
      } else {
        emit(state.copyWith(status: AuthStatus.success, needsVerification: false));
      }
    } else if (result.userAlreadyExists) {
      emit(state.copyWith(
        status: AuthStatus.failure,
        userAlreadyExists: true,
        errorMessage: result.errorMessage,
      ));
    } else {
      debugPrint('AuthCubit.register error: ${result.errorMessage}');
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: result.errorMessage ?? 'Sign up failed',
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // FORGOT PASSWORD ACTIONS
  // ─────────────────────────────────────────────────────────────────

  Future<void> sendPasswordResetOtp(String email) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));

    final result = await _authService.sendPasswordResetOtp(email);

    if (result.success) {
      emit(state.copyWith(
        status: AuthStatus.success,
        flowType: AuthFlowType.resetPassword,
      ));
    } else {
      debugPrint('AuthCubit.sendPasswordResetOtp error: ${result.errorMessage}');
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: result.errorMessage ?? 'Failed to send reset email',
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // OTP ACTIONS
  // ─────────────────────────────────────────────────────────────────

  void startResendCooldown() {
    emit(state.copyWith(resendCooldown: 60));
    _cooldownTimer?.cancel();
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (state.resendCooldown > 0) {
        emit(state.copyWith(resendCooldown: state.resendCooldown - 1));
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> verifyOtp(String email, String otpCode, AuthFlowType flowType) async {
    emit(state.copyWith(status: AuthStatus.loading, clearError: true));

    final result = await _authService.verifyOtp(email, otpCode, flowType);

    if (result.success) {
      emit(state.copyWith(status: AuthStatus.success, flowType: flowType));
    } else {
      debugPrint('AuthCubit.verifyOtp error: ${result.errorMessage}');
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: result.errorMessage ?? 'Verification failed',
      ));
    }
  }

  Future<void> resendOtp(String email, AuthFlowType flowType) async {
    if (state.resendCooldown > 0 || state.isResending) return;

    emit(state.copyWith(isResending: true));

    final result = await _authService.resendOtp(email, flowType);

    if (result.success) {
      startResendCooldown();
      emit(state.copyWith(isResending: false));
    } else {
      debugPrint('AuthCubit.resendOtp error: ${result.errorMessage}');
      emit(state.copyWith(
        isResending: false,
        status: AuthStatus.failure,
        errorMessage: result.errorMessage ?? 'Failed to resend code',
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // CREATE NEW PASSWORD ACTIONS
  // ─────────────────────────────────────────────────────────────────

  void toggleCreatePasswordVisibility() {
    emit(state.copyWith(createPasswordObscure: !state.createPasswordObscure));
  }

  void toggleCreatePasswordConfirmVisibility() {
    emit(state.copyWith(createPasswordConfirmObscure: !state.createPasswordConfirmObscure));
  }

  Future<void> updatePassword(String newPassword) async {
    emit(state.copyWith(
      status: AuthStatus.loading,
      clearError: true,
      passwordUpdateSuccess: false,
    ));

    final result = await _authService.updatePassword(newPassword);

    if (result.success) {
      await _authService.signOut();
      emit(state.copyWith(
        status: AuthStatus.success,
        passwordUpdateSuccess: true,
      ));
    } else {
      debugPrint('AuthCubit.updatePassword error: ${result.errorMessage}');
      emit(state.copyWith(
        status: AuthStatus.failure,
        errorMessage: result.errorMessage ?? 'Failed to update password',
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // OAUTH ACTIONS
  // ─────────────────────────────────────────────────────────────────

  Future<void> signInWithGoogle() async {
    emit(state.copyWith(isGoogleLoading: true, clearError: true));

    final result = await _authService.signInWithGoogle();

    if (result.success) {
      if (result.user != null) {
        // Native sign-in completed successfully - user is authenticated
        debugPrint('AuthCubit: Native Google Sign In completed successfully');
        emit(state.copyWith(
          isGoogleLoading: false,
          status: AuthStatus.success,
          needsVerification: false,
        ));
      } else {
        // Web OAuth flow initiated - the redirect will handle the rest
        // Keep loading state as user will be redirected
        debugPrint('AuthCubit: Google OAuth redirect flow initiated');
      }
    } else {
      debugPrint('AuthCubit.signInWithGoogle error: ${result.errorMessage}');
      emit(state.copyWith(
        isGoogleLoading: false,
        status: AuthStatus.failure,
        errorMessage: result.errorMessage ?? 'Google sign in failed',
      ));
    }
  }

  Future<void> signInWithApple() async {
    emit(state.copyWith(isAppleLoading: true, clearError: true));

    final result = await _authService.signInWithApple();

    if (result.success) {
      if (result.user != null) {
        // Native sign-in completed successfully - user is authenticated
        debugPrint('AuthCubit: Native Apple Sign In completed successfully');
        emit(state.copyWith(
          isAppleLoading: false,
          status: AuthStatus.success,
          needsVerification: false,
        ));
      } else {
        // Web OAuth flow initiated - the redirect will handle the rest
        // Keep loading state as user will be redirected
        debugPrint('AuthCubit: Apple OAuth redirect flow initiated');
      }
    } else {
      debugPrint('AuthCubit.signInWithApple error: ${result.errorMessage}');
      emit(state.copyWith(
        isAppleLoading: false,
        status: AuthStatus.failure,
        errorMessage: result.errorMessage ?? 'Apple sign in failed',
      ));
    }
  }

  // ─────────────────────────────────────────────────────────────────
  // SIGN OUT
  // ─────────────────────────────────────────────────────────────────

  Future<void> signOut() async {
    await _authService.signOut();
    resetState();
  }
}
