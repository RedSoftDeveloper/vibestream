import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ThemeCubit manages the app's theme mode (Light, Dark, System)
/// Persists the user's preference to shared_preferences
class ThemeCubit extends Cubit<ThemeMode> {
  static const String _themeKey = 'theme_mode';
  
  ThemeCubit() : super(ThemeMode.system) {
    _loadTheme();
  }

  /// Load saved theme preference from storage
  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString(_themeKey);
      if (themeString != null) {
        emit(_themeModeFromString(themeString));
      }
    } catch (e) {
      // Default to system theme on error
      emit(ThemeMode.system);
    }
  }

  /// Set the theme mode and persist it
  Future<void> setTheme(ThemeMode mode) async {
    emit(mode);
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, _themeModeToString(mode));
    } catch (e) {
      // Theme is already set in state, just log the persistence error
      debugPrint('Failed to persist theme preference: $e');
    }
  }

  /// Convert string to ThemeMode
  ThemeMode _themeModeFromString(String value) {
    switch (value) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  /// Convert ThemeMode to string for storage
  String _themeModeToString(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }

  /// Get display string for current theme
  String get themeDisplayName {
    switch (state) {
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
      case ThemeMode.system:
        return 'System';
    }
  }
}
