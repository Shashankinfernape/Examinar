import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class NoTransitionsBuilder extends PageTransitionsBuilder {
  const NoTransitionsBuilder();
  @override
  Widget buildTransitions<T>(PageRoute<T> route, BuildContext context,
      Animation<double> animation, Animation<double> secondaryAnimation, Widget child) {
    return child;
  }
}

class AppTheme {
  // --- Exact Samsung One UI Colors ---
  static const Color black = Color(0xFF121212);             // Deep Tonal Grey for depth
  static const Color sidebarSurface = Color(0xFF1A1A1C);    // Sidebar / Surface 1
  static const Color cardSurface = Color(0xFF252525);       // Elevated Card Surface
  static const Color selectedTile = Color(0xFF323234);      // Hover / Selection background
  static const Color samsungBlue = Color(0xFFFFFFFF);       // Primary Accent (Now White)
  static const Color premiumPurple = Color(0xFF1C54B2);     // Original Purple
  
  static const Color textPrimary = Color(0xFFE8EAED);       // High emphasis text
  static const Color textSecondary = Color(0xFF9AA0A6);     // Low emphasis text
  static const Color textOnAccent = Color(0xFF000000);      // Text on light backgrounds

  // --- Adaptive Status Colors ---
  static const Color completedColor = Color(0xFF81C995);    // One UI Green
  static const Color inProgressColor = Color(0xFFFDD663);   // One UI Yellow
  static const Color urgentColor = Color(0xFFF28B82);       // One UI Red

  // --- Normalized Radius Constants ---
  static const double cardRadius = 20.0;     
  static const double sidebarRadius = 24.0;  
  static const double buttonRadius = 16.0;   

  static ThemeData samsungDarkTheme() {
    final base = ThemeData.dark();
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: black,
      
      colorScheme: const ColorScheme.dark(
        primary: samsungBlue,
        secondary: samsungBlue,
        surface: cardSurface,
        onSurface: textPrimary,
        background: black,
        onBackground: textPrimary,
        outline: Color(0xFF3C4043),
        surfaceVariant: sidebarSurface,
      ),

      cardTheme: CardThemeData(
        color: cardSurface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(cardRadius)),
      ),

      textTheme: GoogleFonts.interTextTheme(base.textTheme).copyWith(
        displayLarge: const TextStyle(fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -1.0),
        displayMedium: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5),
        headlineLarge: const TextStyle(fontSize: 20, fontWeight: FontWeight.w600, color: textPrimary),
        bodyLarge: const TextStyle(fontSize: 16, color: textPrimary, height: 1.5),
        bodyMedium: const TextStyle(fontSize: 14, color: textSecondary, height: 1.5),
        labelLarge: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textSecondary, letterSpacing: 1.0),
      ),

      appBarTheme: const AppBarTheme(
        backgroundColor: black,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(fontSize: 20, fontWeight: FontWeight.w700, color: textPrimary),
        iconTheme: IconThemeData(color: textPrimary, size: 24),
      ),

      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: sidebarSurface,
        indicatorColor: selectedTile,
        elevation: 0,
        labelTextStyle: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: textPrimary);
          }
          return const TextStyle(fontSize: 11, color: textSecondary);
        }),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: samsungBlue, size: 24);
          }
          return const IconThemeData(color: textSecondary, size: 24);
        }),
      ),

      floatingActionButtonTheme: FloatingActionButtonThemeData(
        backgroundColor: samsungBlue,
        foregroundColor: Colors.white,
        elevation: 4,
        iconSize: 24,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),

      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: samsungBlue,
          foregroundColor: Colors.white,
          elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(buttonRadius)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
        ),
      ),

      tabBarTheme: TabBarThemeData(
        indicatorColor: samsungBlue,
        labelColor: samsungBlue,
        unselectedLabelColor: textSecondary,
        labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, letterSpacing: 0.5),
        unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: 0.5),
        indicatorSize: TabBarIndicatorSize.label,
      ),
      
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: NoTransitionsBuilder(),
          TargetPlatform.iOS: NoTransitionsBuilder(),
          TargetPlatform.windows: NoTransitionsBuilder(),
          TargetPlatform.macOS: NoTransitionsBuilder(),
          TargetPlatform.linux: NoTransitionsBuilder(),
        },
      ),

      dividerTheme: DividerThemeData(
        color: Colors.white.withOpacity(0.05),
        thickness: 1,
        space: 1,
      ),
    );
  }

  // Fallbacks
  static const primaryColor = samsungBlue;
  static const accentColor = samsungBlue;
  static ThemeData amoledTheme() => samsungDarkTheme();
  static ThemeData lightTheme() => samsungDarkTheme();
  static ThemeData darkTheme() => samsungDarkTheme();
}
