import 'dart:convert';
import 'dart:math';
import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:vibestream/supabase/supabase_config.dart';
import 'package:vibestream/features/auth/data/app_user_service.dart';

enum AuthFlowType { signIn, signUp, resetPassword, emailChange }

class AuthResult {
  final bool success;
  final String? errorMessage;
  final bool needsVerification;
  final bool userAlreadyExists;
  final User? user;

  AuthResult({
    required this.success,
    this.errorMessage,
    this.needsVerification = false,
    this.userAlreadyExists = false,
    this.user,
  });
}

class AuthService {
  static final AuthService _instance = AuthService._internal();
  factory AuthService() => _instance;
  AuthService._internal();

  GoTrueClient get _auth => SupabaseConfig.auth;

  User? get currentUser => _auth.currentUser;
  bool get isLoggedIn => currentUser != null;
  bool get isEmailVerified => currentUser?.emailConfirmedAt != null;

  /// Sign in with email and password
  Future<AuthResult> signIn(String email, String password) async {
    try {
      final response = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (response.user == null) {
        return AuthResult(success: false, errorMessage: 'Sign in failed. Please try again.');
      }

      // Check if email is verified
      if (response.user!.emailConfirmedAt == null) {
        // User exists but email not verified - resend OTP
        await _auth.resend(type: OtpType.signup, email: email.trim());
        return AuthResult(
          success: true,
          needsVerification: true,
          user: response.user,
        );
      }

      return AuthResult(success: true, user: response.user);
    } on AuthException catch (e) {
      debugPrint('AuthService signIn error: ${e.message}');
      return AuthResult(success: false, errorMessage: _getReadableError(e.message));
    } catch (e) {
      debugPrint('AuthService signIn unexpected error: $e');
      return AuthResult(success: false, errorMessage: 'An unexpected error occurred. Please try again.');
    }
  }

  /// Sign up with email, password, and full name
  Future<AuthResult> signUp(String email, String password, String fullName) async {
    try {
      final response = await _auth.signUp(
        email: email.trim(),
        password: password,
        data: {'full_name': fullName.trim()},
      );

      if (response.user == null) {
        return AuthResult(success: false, errorMessage: 'Sign up failed. Please try again.');
      }

      // Check if user already exists - Supabase returns empty identities for existing users
      // This is to prevent email enumeration attacks (Supabase doesn't throw error for existing emails)
      final identities = response.user!.identities ?? [];
      if (identities.isEmpty) {
        debugPrint('AuthService signUp: User already exists (empty identities)');
        return AuthResult(
          success: false,
          userAlreadyExists: true,
          errorMessage: 'This email is already registered. Please sign in instead.',
        );
      }

      // Email verification is required from Supabase settings
      return AuthResult(
        success: true,
        needsVerification: true,
        user: response.user,
      );
    } on AuthException catch (e) {
      debugPrint('AuthService signUp error: ${e.message}');
      return AuthResult(success: false, errorMessage: _getReadableError(e.message));
    } catch (e) {
      debugPrint('AuthService signUp unexpected error: $e');
      return AuthResult(success: false, errorMessage: 'An unexpected error occurred. Please try again.');
    }
  }

  /// Verify OTP code
  Future<AuthResult> verifyOtp(String email, String otpCode, AuthFlowType flowType) async {
    try {
      final OtpType otpType;
      switch (flowType) {
        case AuthFlowType.resetPassword:
          otpType = OtpType.recovery;
          break;
        case AuthFlowType.emailChange:
          otpType = OtpType.emailChange;
          break;
        default:
          otpType = OtpType.signup;
      }
      
      final response = await _auth.verifyOTP(
        email: email.trim(),
        token: otpCode.trim(),
        type: otpType,
      );

      if (response.user == null) {
        return AuthResult(success: false, errorMessage: 'Invalid verification code.');
      }

      // Ensure session is established after OTP verification
      await _ensureSessionEstablished();
      
      debugPrint('AuthService verifyOtp success - user: ${response.user?.id}');
      debugPrint('AuthService verifyOtp - session exists: ${_auth.currentSession != null}');
      if (_auth.currentSession != null) {
        debugPrint('AuthService verifyOtp - token preview: ${_auth.currentSession!.accessToken.substring(0, 20)}...');
      }

      return AuthResult(success: true, user: response.user);
    } on AuthException catch (e) {
      debugPrint('AuthService verifyOtp error: ${e.message}');
      return AuthResult(success: false, errorMessage: _getReadableError(e.message));
    } catch (e) {
      debugPrint('AuthService verifyOtp unexpected error: $e');
      return AuthResult(success: false, errorMessage: 'Verification failed. Please try again.');
    }
  }
  
  /// Ensure session is established and refreshed if needed
  Future<void> _ensureSessionEstablished() async {
    try {
      final session = _auth.currentSession;
      if (session == null) {
        debugPrint('AuthService: No session after verification, attempting refresh...');
        await _auth.refreshSession();
        debugPrint('AuthService: Session refreshed - exists: ${_auth.currentSession != null}');
      } else {
        // Check if token is expired or about to expire
        final expiresAt = session.expiresAt;
        if (expiresAt != null) {
          final expiresAtDate = DateTime.fromMillisecondsSinceEpoch(expiresAt * 1000);
          final now = DateTime.now();
          // Refresh if expires in less than 60 seconds
          if (expiresAtDate.difference(now).inSeconds < 60) {
            debugPrint('AuthService: Token expiring soon, refreshing...');
            await _auth.refreshSession();
          }
        }
      }
    } catch (e) {
      debugPrint('AuthService: Error ensuring session: $e');
    }
  }

  /// Send password reset OTP to email
  Future<AuthResult> sendPasswordResetOtp(String email) async {
    try {
      await _auth.resetPasswordForEmail(email.trim());
      return AuthResult(success: true);
    } on AuthException catch (e) {
      debugPrint('AuthService sendPasswordResetOtp error: ${e.message}');
      return AuthResult(success: false, errorMessage: _getReadableError(e.message));
    } catch (e) {
      debugPrint('AuthService sendPasswordResetOtp unexpected error: $e');
      return AuthResult(success: false, errorMessage: 'Failed to send reset email. Please try again.');
    }
  }

  /// Update password (used after OTP verification for reset password flow)
  Future<AuthResult> updatePassword(String newPassword) async {
    try {
      final response = await _auth.updateUser(
        UserAttributes(password: newPassword),
      );

      if (response.user == null) {
        return AuthResult(success: false, errorMessage: 'Failed to update password.');
      }

      return AuthResult(success: true, user: response.user);
    } on AuthException catch (e) {
      debugPrint('AuthService updatePassword error: ${e.message}');
      return AuthResult(success: false, errorMessage: _getReadableError(e.message));
    } catch (e) {
      debugPrint('AuthService updatePassword unexpected error: $e');
      return AuthResult(success: false, errorMessage: 'Failed to update password. Please try again.');
    }
  }

  /// Update email (sends verification to new email)
  Future<AuthResult> updateEmail(String newEmail) async {
    try {
      final response = await _auth.updateUser(
        UserAttributes(email: newEmail.trim()),
      );

      if (response.user == null) {
        return AuthResult(success: false, errorMessage: 'Failed to update email.');
      }

      // Supabase sends verification email to the new address
      return AuthResult(success: true, needsVerification: true, user: response.user);
    } on AuthException catch (e) {
      debugPrint('AuthService updateEmail error: ${e.message}');
      return AuthResult(success: false, errorMessage: _getReadableError(e.message));
    } catch (e) {
      debugPrint('AuthService updateEmail unexpected error: $e');
      return AuthResult(success: false, errorMessage: 'Failed to update email. Please try again.');
    }
  }

  /// Resend OTP code
  Future<AuthResult> resendOtp(String email, AuthFlowType flowType) async {
    try {
      if (flowType == AuthFlowType.resetPassword) {
        await _auth.resetPasswordForEmail(email.trim());
      } else if (flowType == AuthFlowType.emailChange) {
        await _auth.resend(type: OtpType.emailChange, email: email.trim());
      } else {
        await _auth.resend(type: OtpType.signup, email: email.trim());
      }
      return AuthResult(success: true);
    } on AuthException catch (e) {
      debugPrint('AuthService resendOtp error: ${e.message}');
      return AuthResult(success: false, errorMessage: _getReadableError(e.message));
    } catch (e) {
      debugPrint('AuthService resendOtp unexpected error: $e');
      return AuthResult(success: false, errorMessage: 'Failed to resend code. Please try again.');
    }
  }

  /// Sign out the current user
  Future<void> signOut() async {
    try {
      AppUserService().clearCache();
      await _auth.signOut();
    } catch (e) {
      debugPrint('AuthService signOut error: $e');
    }
  }

  /// Check if current user signed up with OAuth (Google, Apple, etc.)
  bool get isOAuthUser {
    final user = currentUser;
    if (user == null) return false;
    final identities = user.identities ?? [];
    // If any identity has a provider other than 'email', it's OAuth
    return identities.any((identity) => 
      identity.provider != 'email' && identity.provider != null
    );
  }

  /// Get the OAuth provider name if user logged in with OAuth
  String? get oauthProvider {
    final user = currentUser;
    if (user == null) return null;
    final identities = user.identities ?? [];
    for (final identity in identities) {
      if (identity.provider != 'email' && identity.provider != null) {
        return identity.provider;
      }
    }
    return null;
  }

  /// Verify password for current user (for account deletion)
  Future<AuthResult> verifyPassword(String password) async {
    try {
      final user = currentUser;
      if (user == null || user.email == null) {
        return AuthResult(success: false, errorMessage: 'No user logged in.');
      }

      // Try to sign in with current email and provided password
      final response = await _auth.signInWithPassword(
        email: user.email!,
        password: password,
      );

      if (response.user != null) {
        return AuthResult(success: true, user: response.user);
      }
      return AuthResult(success: false, errorMessage: 'Invalid password.');
    } on AuthException catch (e) {
      debugPrint('AuthService verifyPassword error: ${e.message}');
      return AuthResult(success: false, errorMessage: _getReadableError(e.message));
    } catch (e) {
      debugPrint('AuthService verifyPassword unexpected error: $e');
      return AuthResult(success: false, errorMessage: 'Verification failed. Please try again.');
    }
  }

  /// Deep link redirect URL for OAuth callbacks
  static const String _oauthRedirectUrl = 'vibestream://login-callback';

  /// Web client ID for Google Sign-In (from Supabase Google OAuth config)
  /// This is the web client ID from your Google Cloud Console OAuth credentials
  static const String _googleWebClientId = '333255258998-q3dod9tohr2blinq3r07v6s5f67ctqda.apps.googleusercontent.com';
  
  /// iOS client ID for Google Sign-In (optional, required for iOS native)
  static const String _googleiOSClientId = '333255258998-ghv2vtpoqb7unkdbiog828a1ksovkgnl.apps.googleusercontent.com';

  /// Sign in with Google OAuth
  /// Uses native Google Sign-In on Android/iOS, falls back to web OAuth on web
  Future<AuthResult> signInWithGoogle() async {
    try {
      debugPrint('AuthService: Starting Google Sign In...');
      
      // Use native Google Sign-In on Android and iOS
      if (!kIsWeb) {
        debugPrint('AuthService: Using Native Google Sign In...');
        return await _signInWithGoogleNative();
      }

      // Fallback for web platform
      debugPrint('AuthService: Using Web OAuth for Google Sign In...');
      final response = await _auth.signInWithOAuth(
        OAuthProvider.google,
        redirectTo: _oauthRedirectUrl,
      );

      if (response) {
        debugPrint('AuthService: Google OAuth initiated successfully');
        return AuthResult(success: true);
      }
      debugPrint('AuthService: Google OAuth returned false');
      return AuthResult(success: false, errorMessage: 'Google sign in was cancelled.');
    } on AuthException catch (e) {
      debugPrint('AuthService signInWithGoogle error: ${e.message}');
      return AuthResult(success: false, errorMessage: _getReadableError(e.message));
    } catch (e) {
      debugPrint('AuthService signInWithGoogle unexpected error: $e');
      return AuthResult(success: false, errorMessage: 'Google sign in failed. Please try again.');
    }
  }

  /// GoogleSignIn instance (created once, reused)
  GoogleSignIn? _googleSignIn;

  /// Helper for Native Google Sign In (Android & iOS)
  /// Using google_sign_in 6.x API (instance-based, not static)
  Future<AuthResult> _signInWithGoogleNative() async {
    try {
      debugPrint('[Google] Starting native sign-in flow...');
      debugPrint('[Google] Platform: $defaultTargetPlatform');
      
      // Step 1: Create GoogleSignIn instance (lazy initialization)
      _googleSignIn ??= GoogleSignIn(
        clientId: defaultTargetPlatform == TargetPlatform.iOS ? _googleiOSClientId : null,
        serverClientId: _googleWebClientId,
        scopes: ['email', 'profile'],
      );
      debugPrint('[Google] GoogleSignIn instance ready');
      debugPrint('[Google] clientId (iOS): ${defaultTargetPlatform == TargetPlatform.iOS ? _googleiOSClientId : "null"}');
      debugPrint('[Google] serverClientId: $_googleWebClientId');

      // Step 2: Sign out first to ensure fresh account picker
      await _googleSignIn!.signOut();
      debugPrint('[Google] Signed out previous session');

      // Step 3: Sign in with Google
      debugPrint('[Google] Calling signIn()...');
      final GoogleSignInAccount? googleUser = await _googleSignIn!.signIn();
      
      if (googleUser == null) {
        debugPrint('[Google] User cancelled sign-in (signIn returned null)');
        return AuthResult(success: false, errorMessage: 'Google sign in was cancelled.');
      }
      
      debugPrint('[Google] Got GoogleSignInAccount: ${googleUser.email}');

      // Step 4: Get authentication tokens - MUST await googleUser.authentication
      debugPrint('[Google] Getting authentication tokens...');
      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      
      final idToken = googleAuth.idToken;
      final accessToken = googleAuth.accessToken;
      
      debugPrint('[Google] idToken present: ${idToken != null}');
      debugPrint('[Google] accessToken present: ${accessToken != null}');

      // Step 5: Validate ID token (required for Supabase)
      if (idToken == null) {
        debugPrint('[Google] ERROR - No ID token received');
        return AuthResult(
          success: false, 
          errorMessage: 'Google: No ID token received. Check serverClientId in Google Cloud Console.',
        );
      }

      // Step 6: Sign in to Supabase with Google tokens
      debugPrint('[Google] Signing in to Supabase with tokens...');
      final response = await _auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (response.user == null) {
        debugPrint('[Google] ERROR - Supabase returned null user');
        return AuthResult(
          success: false, 
          errorMessage: 'Supabase: signInWithIdToken returned null user',
        );
      }

      debugPrint('[Google] SUCCESS - User signed in: ${response.user?.email}');
      return AuthResult(success: true, user: response.user);
      
    } on AuthException catch (e) {
      debugPrint('[Google] AuthException: ${e.message} (code: ${e.statusCode})');
      return AuthResult(
        success: false, 
        errorMessage: 'Auth Error [${e.statusCode}]: ${e.message}',
      );
    } on PlatformException catch (e) {
      debugPrint('[Google] PlatformException: code=${e.code}, message=${e.message}, details=${e.details}');
      return AuthResult(
        success: false, 
        errorMessage: 'Platform Error [${e.code}]: ${e.message}',
      );
    } catch (e, stackTrace) {
      debugPrint('[Google] Unexpected error: $e');
      debugPrint('[Google] Error type: ${e.runtimeType}');
      debugPrint('[Google] StackTrace: $stackTrace');
      return AuthResult(
        success: false, 
        errorMessage: 'Google Error [${e.runtimeType}]: $e',
      );
    }
  }

  /// Sign in with Apple OAuth
  Future<AuthResult> signInWithApple() async {
    try {
      debugPrint('AuthService: Starting Apple Sign In...');
      
      // Use native Apple Sign In on iOS/macOS
      if (defaultTargetPlatform == TargetPlatform.iOS || 
          defaultTargetPlatform == TargetPlatform.macOS) {
        debugPrint('AuthService: Using Native Apple Sign In...');
        return await _signInWithAppleNative();
      }

      // Fallback for other platforms
      final response = await _auth.signInWithOAuth(
        OAuthProvider.apple,
        redirectTo: _oauthRedirectUrl,
      );

      if (response) {
        debugPrint('AuthService: Apple OAuth initiated successfully');
        return AuthResult(success: true);
      }
      debugPrint('AuthService: Apple OAuth returned false');
      return AuthResult(success: false, errorMessage: 'Apple sign in was cancelled.');
    } on AuthException catch (e) {
      debugPrint('AuthService signInWithApple error: ${e.message}');
      return AuthResult(success: false, errorMessage: _getReadableError(e.message));
    } catch (e) {
      debugPrint('AuthService signInWithApple unexpected error: $e');
      return AuthResult(success: false, errorMessage: 'Apple sign in failed. Please try again.');
    }
  }

  /// Helper for Native Apple Sign In
  Future<AuthResult> _signInWithAppleNative() async {
    try {
      final rawNonce = _generateRandomString();
      final hashedNonce = sha256.convert(utf8.encode(rawNonce)).toString();

      final credential = await SignInWithApple.getAppleIDCredential(
        scopes: [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
        nonce: hashedNonce,
      );

      final idToken = credential.identityToken;
      if (idToken == null) {
        return AuthResult(success: false, errorMessage: 'Could not get identity token from Apple.');
      }

      // Sign in with Supabase using the ID token
      final response = await _auth.signInWithIdToken(
        provider: OAuthProvider.apple,
        idToken: idToken,
        nonce: rawNonce,
      );
      
      debugPrint('AuthService: Native Apple Sign In successful');
      return AuthResult(success: true, user: response.user);
    } on SignInWithAppleAuthorizationException catch (e) {
      debugPrint('AuthService Apple Sign In Native Authorization error: $e');
      if (e.code == AuthorizationErrorCode.canceled) {
        return AuthResult(success: false, errorMessage: 'Apple sign in cancelled.');
      }
      return AuthResult(success: false, errorMessage: 'Apple sign in failed.');
    } catch (e) {
      debugPrint('AuthService _signInWithAppleNative error: $e');
      return AuthResult(success: false, errorMessage: 'Apple sign in failed.');
    }
  }

  String _generateRandomString() {
    const chars = 'AaBbCcDdEeFfGgHhIiJjKkLlMmNnOoPpQqRrSsTtUuVvWwXxYyZz1234567890';
    final random = Random.secure();
    return String.fromCharCodes(Iterable.generate(
      32, (_) => chars.codeUnitAt(random.nextInt(chars.length))));
  }

  /// Re-authenticate with OAuth provider
  /// Uses native sign-in on mobile platforms for better UX
  Future<AuthResult> reAuthenticateWithOAuth(String provider) async {
    try {
      debugPrint('AuthService: Starting OAuth re-auth for provider: $provider');
      
      // IMPORTANT: Sign out first to ensure OAuth opens the provider directly
      // Without this, Supabase might try to link accounts or send email verification
      debugPrint('AuthService: Signing out before OAuth re-auth...');
      await _auth.signOut(scope: SignOutScope.local);
      
      // Small delay to ensure sign out completes
      await Future.delayed(const Duration(milliseconds: 100));

      switch (provider.toLowerCase()) {
        case 'google':
          // Use native Google Sign-In on mobile platforms
          if (!kIsWeb) {
            debugPrint('AuthService: Initiating Native Google Sign In re-auth...');
            return await _signInWithGoogleNative();
          }
          // Fallback to OAuth for web
          debugPrint('AuthService: Initiating Google OAuth flow...');
          final googleResponse = await _auth.signInWithOAuth(
            OAuthProvider.google,
            redirectTo: _oauthRedirectUrl,
          );
          if (googleResponse) {
            debugPrint('AuthService: Google OAuth re-auth initiated successfully');
            return AuthResult(success: true);
          }
          return AuthResult(success: false, errorMessage: 'Google authentication failed.');

        case 'apple':
          // Use native Apple Sign-In on iOS/macOS
          if (defaultTargetPlatform == TargetPlatform.iOS || 
              defaultTargetPlatform == TargetPlatform.macOS) {
            debugPrint('AuthService: Initiating Native Apple Sign In re-auth...');
            return await _signInWithAppleNative();
          }
          // Fallback to OAuth for other platforms
          debugPrint('AuthService: Initiating Apple OAuth flow...');
          final appleResponse = await _auth.signInWithOAuth(
            OAuthProvider.apple,
            redirectTo: _oauthRedirectUrl,
          );
          if (appleResponse) {
            debugPrint('AuthService: Apple OAuth re-auth initiated successfully');
            return AuthResult(success: true);
          }
          return AuthResult(success: false, errorMessage: 'Apple authentication failed.');

        default:
          return AuthResult(success: false, errorMessage: 'Unsupported OAuth provider.');
      }
    } on AuthException catch (e) {
      debugPrint('AuthService reAuthenticateWithOAuth error: ${e.message}');
      return AuthResult(success: false, errorMessage: _getReadableError(e.message));
    } catch (e) {
      debugPrint('AuthService reAuthenticateWithOAuth unexpected error: $e');
      return AuthResult(success: false, errorMessage: 'Re-authentication failed. Please try again.');
    }
  }

  /// Delete user account
  /// Uses edge function with service role key to delete from Supabase Auth
  Future<AuthResult> deleteAccount() async {
    try {
      final user = currentUser;
      if (user == null) {
        return AuthResult(success: false, errorMessage: 'No user logged in.');
      }

      debugPrint('AuthService: Calling delete-user edge function for user: ${user.id}');

      // Call the edge function to delete the user
      final response = await SupabaseConfig.client.functions.invoke(
        'delete-user',
        method: HttpMethod.post,
      );

      if (response.status != 200) {
        final error = response.data?['error'] ?? 'Failed to delete account';
        debugPrint('AuthService deleteAccount edge function error: $error');
        return AuthResult(success: false, errorMessage: error.toString());
      }

      debugPrint('AuthService: delete-user edge function successful');

      // Clear cache and sign out locally
      AppUserService().clearCache();
      await _auth.signOut();

      return AuthResult(success: true);
    } on FunctionException catch (e) {
      debugPrint('AuthService deleteAccount function error: ${e.details}');
      return AuthResult(success: false, errorMessage: e.details?.toString() ?? 'Failed to delete account.');
    } on AuthException catch (e) {
      debugPrint('AuthService deleteAccount auth error: ${e.message}');
      return AuthResult(success: false, errorMessage: _getReadableError(e.message));
    } catch (e) {
      debugPrint('AuthService deleteAccount unexpected error: $e');
      return AuthResult(success: false, errorMessage: 'Failed to delete account. Please try again.');
    }
  }

  /// Get readable error message
  String _getReadableError(String message) {
    final lowerMessage = message.toLowerCase();
    if (lowerMessage.contains('invalid login credentials') || lowerMessage.contains('invalid credentials')) {
      return 'Invalid email or password. Please try again.';
    }
    if (lowerMessage.contains('email not confirmed')) {
      return 'Please verify your email address first.';
    }
    if (lowerMessage.contains('user already registered')) {
      return 'This email is already registered. Please sign in instead.';
    }
    if (lowerMessage.contains('invalid otp') || lowerMessage.contains('token has expired')) {
      return 'Invalid or expired verification code. Please request a new one.';
    }
    if (lowerMessage.contains('email rate limit exceeded')) {
      return 'Too many requests. Please wait a moment and try again.';
    }
    if (lowerMessage.contains('same_password') || (lowerMessage.contains('password') && lowerMessage.contains('different'))) {
      return 'New password must be different from your current password.';
    }
    if (lowerMessage.contains('password') && (lowerMessage.contains('length') || lowerMessage.contains('short') || lowerMessage.contains('characters'))) {
      return 'Password must be at least 8 characters long.';
    }
    return message;
  }
}
