import 'package:flutter/material.dart';

// یک enum برای مدیریت راحت‌تر تم‌ها
enum AppTheme { light, dark, solvixAurora }

class AppThemes {
  // تعریف رنگ‌های اصلی برای دسترسی راحت‌تر
  static const Color _lightPrimaryColor = Colors.deepPurple;
  static const Color _darkPrimaryColor = Color(
    0xFF9B84E4,
  ); // کمی روشن‌تر از بنفش اصلی
  static const Color _auroraPrimaryColor = Color(0xFF00E5FF); // فیروزه‌ای نئونی

  static const Color _lightBackgroundColor = Color(0xFFF5F5F5);
  static const Color _darkBackgroundColor = Color(0xFF1C1B20);
  static const Color _auroraBackgroundColor = Color(
    0xFF0D1117,
  ); // رنگ پس‌زمینه گیت‌هاب

  static const Color _darkSurfaceColor = Color(0xFF242328);
  static const Color _auroraSurfaceColor = Color(0xFF161B22);

  // متد اصلی برای دریافت ThemeData بر اساس enum
  static ThemeData getThemeData(AppTheme appTheme) {
    switch (appTheme) {
      case AppTheme.light:
        return _lightTheme;
      case AppTheme.dark:
        return _darkTheme;
      case AppTheme.solvixAurora:
        return _solvixAuroraTheme;
    }
  }

  // --- تعریف تم روشن ---
  static final ThemeData _lightTheme = ThemeData(
    brightness: Brightness.light,
    primaryColor: _lightPrimaryColor,
    scaffoldBackgroundColor: _lightBackgroundColor,
    canvasColor: Colors.white,
    // برای AppBar, BottomNavBar, Card
    colorScheme: const ColorScheme.light(
      primary: _lightPrimaryColor,
      secondary: _lightPrimaryColor,
    ),
    fontFamily: 'Vazirmatn',
    appBarTheme: const AppBarTheme(
      elevation: 0.5,
      backgroundColor: Colors.white,
      foregroundColor: Colors.black87,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: _lightPrimaryColor,
      unselectedItemColor: Colors.grey,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _lightPrimaryColor,
      foregroundColor: Colors.white,
    ),
  );

  // --- تعریف تم دارک ---
  static final ThemeData _darkTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: _darkPrimaryColor,
    scaffoldBackgroundColor: _darkBackgroundColor,
    canvasColor: _darkSurfaceColor,
    // رنگ سطوح کمی روشن‌تر از پس‌زمینه
    colorScheme: const ColorScheme.dark(
      primary: _darkPrimaryColor,
      secondary: _darkPrimaryColor,
      surface: _darkSurfaceColor,
      background: _darkBackgroundColor,
    ),
    fontFamily: 'Vazirmatn',
    appBarTheme: const AppBarTheme(
      elevation: 0.5,
      backgroundColor: _darkSurfaceColor,
      foregroundColor: Colors.white,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: _darkPrimaryColor,
      unselectedItemColor: Colors.grey,
    ),
    floatingActionButtonTheme: const FloatingActionButtonThemeData(
      backgroundColor: _darkPrimaryColor,
      foregroundColor: _darkBackgroundColor, // متن تیره روی دکمه روشن
    ),
  );

  // --- تعریف تم اختصاصی "Solvix Aurora" ---
  static final ThemeData _solvixAuroraTheme = ThemeData(
    brightness: Brightness.dark,
    primaryColor: _auroraPrimaryColor,
    scaffoldBackgroundColor: _auroraBackgroundColor,
    canvasColor: _auroraSurfaceColor,
    colorScheme: const ColorScheme.dark(
      primary: _auroraPrimaryColor,
      secondary: _auroraPrimaryColor,
      surface: _auroraSurfaceColor,
      background: _auroraBackgroundColor,
    ),
    fontFamily: 'Vazirmatn',
    appBarTheme: const AppBarTheme(
      elevation: 0.5,
      backgroundColor: _auroraSurfaceColor,
      foregroundColor: Colors.white,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      selectedItemColor: _auroraPrimaryColor,
      unselectedItemColor: Colors.grey,
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      backgroundColor: _auroraPrimaryColor,
      foregroundColor: _auroraBackgroundColor,
      // افزودن افکت درخشش نئونی
      extendedSizeConstraints: const BoxConstraints.tightFor(
        height: 56,
        width: 56,
      ),
      shape: const CircleBorder(),
      elevation: 4.0,
      splashColor: Colors.white.withOpacity(0.3),
    ),
    // استایل خاص برای دکمه‌ها در این تم
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: _auroraPrimaryColor,
        foregroundColor: _auroraBackgroundColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        shadowColor: _auroraPrimaryColor.withOpacity(0.5),
        elevation: 5,
      ),
    ),
  );
}
