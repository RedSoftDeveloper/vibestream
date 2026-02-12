import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/services/analytics_service.dart';
import 'package:vibestream/core/services/subscription_service.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/theme/theme_cubit.dart';
import 'package:vibestream/features/subscription/presentation/cubits/subscription_cubit.dart';
import 'package:vibestream/supabase/supabase_config.dart';

/// VibeStream - Discover movies and series based on your mood
/// 
/// Main entry point for the application.
/// This sets up:
/// - Routing via go_router
/// - Theming with light/dark mode support
/// - Supabase initialization for auth and database
/// - RevenueCat subscription service
void main() {
  WidgetsFlutterBinding.ensureInitialized();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    debugPrint('FlutterError: ${details.exceptionAsString()}');
    debugPrint('FlutterError stack: ${details.stack}');
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    debugPrint('Uncaught zone error: $error');
    debugPrint('Uncaught zone stack: $stack');
    return true;
  };

  runApp(const _Bootstrapper());
}

class _Bootstrapper extends StatefulWidget {
  const _Bootstrapper();

  @override
  State<_Bootstrapper> createState() => _BootstrapperState();
}

class _BootstrapperState extends State<_Bootstrapper> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    try {
      await SupabaseConfig.initialize();
    } catch (e) {
      debugPrint('Failed to initialize Supabase: $e');
    }

    try {
      await AnalyticsService.initialize();
    } catch (e) {
      debugPrint('Failed to initialize AnalyticsService: $e');
    }

    // RevenueCat is mobile-only; SubscriptionService is web-safe and no-ops on web.
    try {
      await SubscriptionService.instance.initialize();
    } catch (e) {
      debugPrint('Failed to initialize SubscriptionService: $e');
    }

    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) {
      // Minimal, theme-agnostic loader while bootstrapping.
      return const MaterialApp(home: Scaffold(body: Center(child: CircularProgressIndicator())));
    }
    return const VibeStreamApp();
  }
}

class VibeStreamApp extends StatelessWidget {
  const VibeStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => ThemeCubit()),
        BlocProvider(create: (_) => SubscriptionCubit()),
      ],
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) => MaterialApp.router(
          title: 'VibeStream',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: themeMode,
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
