import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:vibestream/features/auth/presentation/pages/login_page.dart';
import 'package:vibestream/features/auth/presentation/pages/register_page.dart';
import 'package:vibestream/features/auth/presentation/pages/forgot_password_page.dart';
import 'package:vibestream/features/auth/presentation/pages/otp_verification_page.dart';
import 'package:vibestream/features/auth/presentation/pages/create_new_password_page.dart';
import 'package:vibestream/features/auth/presentation/pages/delete_account_page.dart';
import 'package:vibestream/features/auth/data/auth_service.dart';
import 'package:vibestream/features/home/presentation/pages/home_page.dart';
import 'package:vibestream/features/home/presentation/pages/main_shell.dart';
import 'package:vibestream/features/onboarding/presentation/pages/onboarding_page.dart';
import 'package:vibestream/features/onboarding/presentation/pages/splash_page.dart';
import 'package:vibestream/features/profile/presentation/pages/profile_page.dart';
import 'package:vibestream/features/profile/presentation/pages/my_profile_page.dart';
import 'package:vibestream/features/settings/presentation/pages/settings_page.dart';
import 'package:vibestream/features/favorites/presentation/pages/favorites_page.dart';
import 'package:vibestream/features/chat/presentation/pages/chat_page.dart';
import 'package:vibestream/features/title_details/presentation/pages/title_details_page.dart';
import 'package:vibestream/features/mood_quiz/presentation/pages/mood_quiz_page.dart';
import 'package:vibestream/features/feedback/presentation/pages/share_experience_page.dart';
import 'package:vibestream/features/feedback/presentation/pages/feedback_page.dart';
import 'package:vibestream/features/feedback/presentation/pages/app_feedback_page.dart';
import 'package:vibestream/features/recommendations/presentation/pages/recommendation_results_page.dart';
import 'package:vibestream/features/recommendations/domain/entities/recommendation_card.dart';
import 'package:vibestream/features/recommendations/data/interaction_service.dart';
import 'package:vibestream/features/home/presentation/pages/all_recent_vibes_page.dart';
import 'package:vibestream/core/routing/analytics_route_observer.dart';

class AppRoutes {
  static const String splash = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/auth/login';
  static const String register = '/auth/register';
  static const String forgotPassword = '/auth/forgot-password';
  static const String otpVerification = '/auth/otp-verification';
  static const String createNewPassword = '/auth/create-new-password';
  static const String deleteAccount = '/auth/delete-account';
  static const String home = '/home';
  static const String favorites = '/favorites';
  static const String chat = '/chat';
  static const String profile = '/profile';
  static const String settings = '/settings';
  static const String feedback = '/feedback';
  static const String appFeedback = '/app-feedback';
  static const String titleDetails = '/title/:id';
  static const String moodQuiz = '/mood-quiz';
  static const String shareExperience = '/share-experience/:id';
  static const String myProfile = '/my-profile';
  static const String recommendations = '/recommendations';
  static const String allRecentVibes = '/recent-vibes';
  
  static String titleDetailsPath(String id, {int? matchScore}) {
    if (matchScore != null) {
      return '/title/$id?matchScore=$matchScore';
    }
    return '/title/$id';
  }
  static String shareExperiencePath(String id, {String? sessionId}) {
    if (sessionId != null) {
      return '/share-experience/$id?sessionId=$sessionId';
    }
    return '/share-experience/$id';
  }
  
  /// Navigate to feedback page from recommendation results with remaining titles to cycle through
  static String shareExperienceFromRecommendationsPath(String id, {String? sessionId, required List<String> remainingTitleIds}) {
    final params = <String>[];
    if (sessionId != null) params.add('sessionId=$sessionId');
    params.add('fromRecommendations=true');
    params.add('remainingTitles=${remainingTitleIds.join(',')}');
    return '/share-experience/$id?${params.join('&')}';
  }
}

final _rootNavigatorKey = GlobalKey<NavigatorState>();
final _shellNavigatorKey = GlobalKey<NavigatorState>();

final appRouter = GoRouter(
  navigatorKey: _rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  observers: [AnalyticsRouteObserver()],
  routes: [
    GoRoute(
      path: AppRoutes.splash,
      name: 'splash',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const SplashPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      name: 'onboarding',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const OnboardingPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.login,
      name: 'login',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const LoginPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.register,
      name: 'register',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const RegisterPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      name: 'forgotPassword',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const ForgotPasswordPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.otpVerification,
      name: 'otpVerification',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final email = extra['email'] as String? ?? '';
        final flowType = extra['flowType'] as AuthFlowType? ?? AuthFlowType.signIn;
        return NoTransitionPage(
          key: state.pageKey,
          child: OtpVerificationPage(email: email, flowType: flowType),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.createNewPassword,
      name: 'createNewPassword',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const CreateNewPasswordPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.deleteAccount,
      name: 'deleteAccount',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const DeleteAccountPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.myProfile,
      name: 'myProfile',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const MyProfilePage(),
      ),
    ),
    ShellRoute(
      navigatorKey: _shellNavigatorKey,
      builder: (context, state, child) => MainShell(child: child),
      routes: [
        GoRoute(
          path: AppRoutes.home,
          name: 'home',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const HomePage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.favorites,
          name: 'favorites',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const FavoritesPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.chat,
          name: 'chat',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const ChatPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.profile,
          name: 'profile',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const ProfilePage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.settings,
          name: 'settings',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const SettingsPage(),
          ),
        ),
        GoRoute(
          path: AppRoutes.feedback,
          name: 'feedback',
          pageBuilder: (context, state) => NoTransitionPage(
            key: state.pageKey,
            child: const FeedbackPage(),
          ),
        ),
      ],
    ),
    GoRoute(
      path: AppRoutes.appFeedback,
      name: 'appFeedback',
      pageBuilder: (context, state) => MaterialPage(
        key: state.pageKey,
        child: const AppFeedbackPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.titleDetails,
      name: 'titleDetails',
      pageBuilder: (context, state) {
        final id = state.pathParameters['id'] ?? '';
        final matchScoreStr = state.uri.queryParameters['matchScore'];
        final matchScore = matchScoreStr != null ? int.tryParse(matchScoreStr) : null;
        return NoTransitionPage(
          key: state.pageKey,
          child: TitleDetailsPage(titleId: id, matchScore: matchScore),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.moodQuiz,
      name: 'moodQuiz',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const MoodQuizPage(),
      ),
    ),
    GoRoute(
      path: AppRoutes.shareExperience,
      name: 'shareExperience',
      pageBuilder: (context, state) {
        final titleId = state.pathParameters['id'] ?? '';
        final sessionId = state.uri.queryParameters['sessionId'];
        final fromRecommendations = state.uri.queryParameters['fromRecommendations'] == 'true';
        final remainingTitlesParam = state.uri.queryParameters['remainingTitles'];
        final remainingTitleIds = remainingTitlesParam?.isNotEmpty == true 
            ? remainingTitlesParam!.split(',') 
            : <String>[];
        return NoTransitionPage(
          key: state.pageKey,
          child: ShareExperiencePage(
            titleId: titleId, 
            sessionId: sessionId,
            fromRecommendations: fromRecommendations,
            remainingTitleIds: remainingTitleIds,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.recommendations,
      name: 'recommendations',
      pageBuilder: (context, state) {
        final extra = state.extra as Map<String, dynamic>? ?? {};
        final session = extra['session'] as RecommendationSession?;
        final source = extra['source'] as InteractionSource? ?? InteractionSource.moodResults;
        
        // Streaming parameters (used when session is null)
        final profileId = extra['profileId'] as String?;
        final viewingStyle = extra['viewingStyle'] as String?;
        final sliders = extra['sliders'] as Map<String, double>?;
        final selectedGenres = extra['selectedGenres'] as List<String>?;
        final freeText = extra['freeText'] as String?;
        final contentTypes = extra['contentTypes'] as List<String>?;
        final quickMatchTag = extra['quickMatchTag'] as String?;
        
        return NoTransitionPage(
          key: state.pageKey,
          child: RecommendationResultsPage(
            session: session,
            source: source,
            profileId: profileId,
            viewingStyle: viewingStyle,
            sliders: sliders,
            selectedGenres: selectedGenres,
            freeText: freeText,
            contentTypes: contentTypes,
            quickMatchTag: quickMatchTag,
          ),
        );
      },
    ),
    GoRoute(
      path: AppRoutes.allRecentVibes,
      name: 'allRecentVibes',
      pageBuilder: (context, state) => NoTransitionPage(
        key: state.pageKey,
        child: const AllRecentVibesPage(),
      ),
    ),
  ],
);
