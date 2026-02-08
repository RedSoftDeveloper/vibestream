import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:vibestream/core/routing/app_router.dart';
import 'package:vibestream/core/theme/app_theme.dart';
import 'package:vibestream/core/theme/theme_cubit.dart';
import 'package:vibestream/supabase/supabase_config.dart';

/// VibeStream - Discover movies and series based on your mood
/// 
/// Main entry point for the application.
/// This sets up:
/// - Routing via go_router
/// - Theming with light/dark mode support
/// - Supabase initialization for auth and database
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Supabase
  await SupabaseConfig.initialize();
  
  runApp(const VibeStreamApp());
}

class VibeStreamApp extends StatelessWidget {
  const VibeStreamApp({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ThemeCubit(),
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
