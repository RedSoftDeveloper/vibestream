import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

// VibeStream Color Palette - Entertainment/Streaming App Style
class AppColors {
  // Primary: Vibrant Purple/Violet for entertainment vibe
  static const Color primary = Color(0xFF8B5CF6);
  static const Color primaryLight = Color(0xFFA78BFA);
  static const Color primaryDark = Color(0xFF7C3AED);
  
  // Accent: Coral/Pink for energy
  static const Color accent = Color(0xFFFF6B6B);
  static const Color accentLight = Color(0xFFFF8E8E);
  
  // Mood colors for vibe tags
  static const Color moodHappy = Color(0xFFFFD93D);
  static const Color moodSad = Color(0xFF6B7FD7);
  static const Color moodExcited = Color(0xFFFF6B6B);
  static const Color moodRelaxed = Color(0xFF4ECDC4);
  static const Color moodTense = Color(0xFFE63946);
  static const Color moodRomantic = Color(0xFFFF69B4);
  static const Color moodInspired = Color(0xFFFFA726);
  static const Color moodNostalgic = Color(0xFFB39DDB);
  
  // Rating badge colors
  static const Color ratingImdb = Color(0xFFF5C518);
  static const Color ratingRotten = Color(0xFFFA320A);
  static const Color ratingMeta = Color(0xFFFFCC33);
  
  // Neutral colors - Light mode
  static const Color lightBackground = Color(0xFFF8F9FA);
  static const Color lightSurface = Color(0xFFFFFFFF);
  static const Color lightSurfaceVariant = Color(0xFFF1F3F5);
  static const Color lightText = Color(0xFF1A1A2E);
  static const Color lightTextSecondary = Color(0xFF6C757D);
  static const Color lightBorder = Color(0xFFE9ECEF);
  
  // Neutral colors - Dark mode
  static const Color darkBackground = Color(0xFF0D0D0D);
  static const Color darkSurface = Color(0xFF1A1A1A);
  static const Color darkSurfaceVariant = Color(0xFF2D2D2D);
  static const Color darkText = Color(0xFFF8F9FA);
  static const Color darkTextSecondary = Color(0xFFADB5BD);
  static const Color darkBorder = Color(0xFF3D3D3D);
  
  // Snackbar semantic colors
  static const Color snackbarSuccess = Color(0xFF10B981); // Green
  static const Color snackbarError = Color(0xFFEF4444);   // Red
  static const Color snackbarWarning = Color(0xFFF59E0B); // Amber
  static const Color snackbarInfo = Color(0xFF3B82F6);    // Blue
  
  // Gradient colors
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [primary, Color(0xFF6366F1)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  
  static const LinearGradient accentGradient = LinearGradient(
    colors: [accent, Color(0xFFFF8E53)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

class AppSpacing {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 16.0;
  static const double lg = 24.0;
  static const double xl = 32.0;
  static const double xxl = 48.0;

  static const EdgeInsets paddingXs = EdgeInsets.all(xs);
  static const EdgeInsets paddingSm = EdgeInsets.all(sm);
  static const EdgeInsets paddingMd = EdgeInsets.all(md);
  static const EdgeInsets paddingLg = EdgeInsets.all(lg);
  static const EdgeInsets paddingXl = EdgeInsets.all(xl);

  static const EdgeInsets horizontalSm = EdgeInsets.symmetric(horizontal: sm);
  static const EdgeInsets horizontalMd = EdgeInsets.symmetric(horizontal: md);
  static const EdgeInsets horizontalLg = EdgeInsets.symmetric(horizontal: lg);

  static const EdgeInsets verticalSm = EdgeInsets.symmetric(vertical: sm);
  static const EdgeInsets verticalMd = EdgeInsets.symmetric(vertical: md);
  static const EdgeInsets verticalLg = EdgeInsets.symmetric(vertical: lg);
  
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(horizontal: md);
}

class AppRadius {
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double lg = 16.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double full = 100.0;
  
  static BorderRadius get borderRadiusSm => BorderRadius.circular(sm);
  static BorderRadius get borderRadiusMd => BorderRadius.circular(md);
  static BorderRadius get borderRadiusLg => BorderRadius.circular(lg);
  static BorderRadius get borderRadiusXl => BorderRadius.circular(xl);
}

TextTheme _buildTextTheme(Brightness brightness) {
  final baseColor = brightness == Brightness.light 
      ? AppColors.lightText 
      : AppColors.darkText;
  final secondaryColor = brightness == Brightness.light
      ? AppColors.lightTextSecondary
      : AppColors.darkTextSecondary;
      
  return TextTheme(
    displayLarge: GoogleFonts.inter(fontSize: 57, fontWeight: FontWeight.w700, color: baseColor),
    displayMedium: GoogleFonts.inter(fontSize: 45, fontWeight: FontWeight.w700, color: baseColor),
    displaySmall: GoogleFonts.inter(fontSize: 36, fontWeight: FontWeight.w600, color: baseColor),
    headlineLarge: GoogleFonts.inter(fontSize: 32, fontWeight: FontWeight.w700, color: baseColor),
    headlineMedium: GoogleFonts.inter(fontSize: 28, fontWeight: FontWeight.w600, color: baseColor),
    headlineSmall: GoogleFonts.inter(fontSize: 24, fontWeight: FontWeight.w600, color: baseColor),
    titleLarge: GoogleFonts.inter(fontSize: 22, fontWeight: FontWeight.w600, color: baseColor),
    titleMedium: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600, color: baseColor),
    titleSmall: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600, color: baseColor),
    labelLarge: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w500, color: baseColor),
    labelMedium: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w500, color: secondaryColor),
    labelSmall: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w500, color: secondaryColor),
    bodyLarge: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w400, color: baseColor),
    bodyMedium: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w400, color: baseColor),
    bodySmall: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.w400, color: secondaryColor),
  );
}

ThemeData get lightTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.light,
  colorScheme: ColorScheme.light(
    primary: AppColors.primary,
    onPrimary: Colors.white,
    primaryContainer: AppColors.primaryLight.withValues(alpha: 0.2),
    onPrimaryContainer: AppColors.primaryDark,
    secondary: AppColors.accent,
    onSecondary: Colors.white,
    surface: AppColors.lightSurface,
    onSurface: AppColors.lightText,
    surfaceContainerHighest: AppColors.lightSurfaceVariant,
    onSurfaceVariant: AppColors.lightTextSecondary,
    outline: AppColors.lightBorder,
    error: Colors.red.shade700,
    onError: Colors.white,
  ),
  scaffoldBackgroundColor: AppColors.lightBackground,
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.lightBackground,
    foregroundColor: AppColors.lightText,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.lightText,
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.lightSurface,
    selectedItemColor: AppColors.primary,
    unselectedItemColor: AppColors.lightTextSecondary,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: AppColors.lightSurface,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusMd),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.lightSurfaceVariant,
    selectedColor: AppColors.primary.withValues(alpha: 0.15),
    labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusSm),
    side: BorderSide.none,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.lightSurfaceVariant,
    border: OutlineInputBorder(
      borderRadius: AppRadius.borderRadiusMd,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.borderRadiusMd,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.borderRadiusMd,
      borderSide: BorderSide(color: AppColors.primary, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: GoogleFonts.inter(color: AppColors.lightTextSecondary),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusMd),
      textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.accent,
      side: BorderSide(color: AppColors.accent),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusMd),
      textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.accent,
      textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  ),
  iconTheme: IconThemeData(color: AppColors.lightText),
  textTheme: _buildTextTheme(Brightness.light),
  dividerTheme: DividerThemeData(color: AppColors.lightBorder, thickness: 1),
);

ThemeData get darkTheme => ThemeData(
  useMaterial3: true,
  brightness: Brightness.dark,
  colorScheme: ColorScheme.dark(
    primary: AppColors.primaryLight,
    onPrimary: AppColors.darkBackground,
    primaryContainer: AppColors.primary.withValues(alpha: 0.3),
    onPrimaryContainer: AppColors.primaryLight,
    secondary: AppColors.accentLight,
    onSecondary: AppColors.darkBackground,
    surface: AppColors.darkSurface,
    onSurface: AppColors.darkText,
    surfaceContainerHighest: AppColors.darkSurfaceVariant,
    onSurfaceVariant: AppColors.darkTextSecondary,
    outline: AppColors.darkBorder,
    error: Colors.red.shade400,
    onError: Colors.white,
  ),
  scaffoldBackgroundColor: AppColors.darkBackground,
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.darkBackground,
    foregroundColor: AppColors.darkText,
    elevation: 0,
    scrolledUnderElevation: 0,
    centerTitle: false,
    titleTextStyle: GoogleFonts.inter(
      fontSize: 20,
      fontWeight: FontWeight.w700,
      color: AppColors.darkText,
    ),
  ),
  bottomNavigationBarTheme: BottomNavigationBarThemeData(
    backgroundColor: AppColors.darkSurface,
    selectedItemColor: AppColors.primaryLight,
    unselectedItemColor: AppColors.darkTextSecondary,
    type: BottomNavigationBarType.fixed,
    elevation: 0,
  ),
  cardTheme: CardThemeData(
    elevation: 0,
    color: AppColors.darkSurface,
    shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusMd),
  ),
  chipTheme: ChipThemeData(
    backgroundColor: AppColors.darkSurfaceVariant,
    selectedColor: AppColors.primary.withValues(alpha: 0.3),
    labelStyle: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w500, color: AppColors.darkText),
    shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusSm),
    side: BorderSide.none,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  ),
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: AppColors.darkSurfaceVariant,
    border: OutlineInputBorder(
      borderRadius: AppRadius.borderRadiusMd,
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: AppRadius.borderRadiusMd,
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: AppRadius.borderRadiusMd,
      borderSide: BorderSide(color: AppColors.primaryLight, width: 2),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    hintStyle: GoogleFonts.inter(color: AppColors.darkTextSecondary),
  ),
  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: AppColors.accent,
      foregroundColor: Colors.white,
      elevation: 0,
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusMd),
      textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  outlinedButtonTheme: OutlinedButtonThemeData(
    style: OutlinedButton.styleFrom(
      foregroundColor: AppColors.accentLight,
      side: BorderSide(color: AppColors.accentLight),
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      shape: RoundedRectangleBorder(borderRadius: AppRadius.borderRadiusMd),
      textStyle: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.w600),
    ),
  ),
  textButtonTheme: TextButtonThemeData(
    style: TextButton.styleFrom(
      foregroundColor: AppColors.accentLight,
      textStyle: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.w600),
    ),
  ),
  iconTheme: IconThemeData(color: AppColors.darkText),
  textTheme: _buildTextTheme(Brightness.dark),
  dividerTheme: DividerThemeData(color: AppColors.darkBorder, thickness: 1),
);
