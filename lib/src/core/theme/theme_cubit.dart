// lib/src/core/theme/theme_cubit.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:logging/logging.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeCubit extends Cubit<ThemeData> {
  static const String _themeKey = 'app_theme';
  static const Duration _saveDebounceDuration = Duration(milliseconds: 500);

  final Logger _logger = Logger('ThemeCubit');
  Timer? _saveTimer;
  SharedPreferences? _prefs;
  AppTheme _currentTheme = AppTheme.light;

  ThemeCubit() : super(AppThemes.getThemeData(AppTheme.light)) {
    _initializeTheme();
  }

  // ✅ Fix 1: بهبود initialization با proper error handling
  Future<void> _initializeTheme() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      await _loadSavedTheme();
      _logger.info(
        'ThemeCubit initialized successfully with theme: $_currentTheme',
      );
    } catch (e, stack) {
      _logger.severe('Error initializing ThemeCubit: $e', e, stack);
      // در صورت خطا، از تم پیش‌فرض استفاده می‌کنیم
      await _setDefaultTheme();
    }
  }

  // ✅ Fix 2: بهبود theme loading
  Future<void> _loadSavedTheme() async {
    if (_prefs == null) {
      _logger.warning('SharedPreferences not initialized');
      return;
    }

    try {
      // بررسی وجود کلید
      if (!_prefs!.containsKey(_themeKey)) {
        _logger.info('No saved theme found, using default');
        await _setDefaultTheme();
        return;
      }

      // خواندن تم ذخیره شده
      final themeName = _prefs!.getString(_themeKey);
      if (themeName == null || themeName.isEmpty) {
        _logger.warning('Invalid theme name saved, using default');
        await _setDefaultTheme();
        return;
      }

      // پیدا کردن تم از enum
      final savedTheme = AppTheme.values.firstWhere(
        (theme) => theme.name == themeName,
        orElse: () => AppTheme.light,
      );

      if (savedTheme.name != themeName) {
        _logger.warning('Unknown theme name: $themeName, using default');
        await _setDefaultTheme();
        return;
      }

      // اعمال تم
      _currentTheme = savedTheme;
      emit(AppThemes.getThemeData(savedTheme));
      _logger.info('Loaded saved theme: $savedTheme');
    } catch (e, stack) {
      _logger.severe('Error loading saved theme: $e', e, stack);
      await _cleanupCorruptedData();
    }
  }

  // ✅ Fix 3: بهبود theme changing با debouncing
  Future<void> changeTheme(AppTheme theme) async {
    try {
      // بررسی تغییر واقعی
      if (_currentTheme == theme) {
        _logger.fine('Theme already set to: $theme');
        return;
      }

      _logger.info('Changing theme from $_currentTheme to $theme');

      // تغییر فوری UI
      _currentTheme = theme;
      emit(AppThemes.getThemeData(theme));

      // ذخیره با debouncing (جلوگیری از writes متعدد)
      _scheduleSave();
    } catch (e, stack) {
      _logger.severe('Error changing theme: $e', e, stack);
      // در صورت خطا، به تم قبلی برمی‌گردیم
      emit(AppThemes.getThemeData(_currentTheme));
    }
  }

  // ✅ Fix 4: Debounced save mechanism
  void _scheduleSave() {
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDebounceDuration, () async {
      await _saveThemeToStorage();
    });
  }

  Future<void> _saveThemeToStorage() async {
    if (_prefs == null) {
      _logger.warning('Cannot save theme: SharedPreferences not initialized');
      return;
    }

    try {
      await _prefs!.setString(_themeKey, _currentTheme.name);
      _logger.fine('Theme saved to storage: $_currentTheme');
    } catch (e, stack) {
      _logger.severe('Error saving theme to storage: $e', e, stack);
    }
  }

  // ✅ Fix 5: بهبود default theme setting
  Future<void> _setDefaultTheme() async {
    try {
      _currentTheme = AppTheme.light;
      emit(AppThemes.getThemeData(AppTheme.light));

      if (_prefs != null) {
        await _prefs!.setString(_themeKey, AppTheme.light.name);
      }

      _logger.info('Default theme set and saved');
    } catch (e, stack) {
      _logger.severe('Error setting default theme: $e', e, stack);
    }
  }

  // ✅ Fix 6: Cleanup corrupted data
  Future<void> _cleanupCorruptedData() async {
    try {
      _logger.info('Cleaning up corrupted theme data');

      if (_prefs != null) {
        await _prefs!.remove(_themeKey);
      }

      await _setDefaultTheme();
      _logger.info('Corrupted data cleaned up successfully');
    } catch (e, stack) {
      _logger.severe('Error cleaning up corrupted data: $e', e, stack);
    }
  }

  // ✅ Fix 7: Reset theme to default
  Future<void> resetToDefault() async {
    try {
      _logger.info('Resetting theme to default');
      await changeTheme(AppTheme.light);
    } catch (e, stack) {
      _logger.severe('Error resetting theme: $e', e, stack);
    }
  }

  // ✅ Fix 8: Cycle through available themes
  Future<void> cycleTheme() async {
    try {
      final currentIndex = AppTheme.values.indexOf(_currentTheme);
      final nextIndex = (currentIndex + 1) % AppTheme.values.length;
      final nextTheme = AppTheme.values[nextIndex];

      _logger.info('Cycling theme: $_currentTheme -> $nextTheme');
      await changeTheme(nextTheme);
    } catch (e, stack) {
      _logger.severe('Error cycling theme: $e', e, stack);
    }
  }

  // ✅ Fix 9: Check if theme is available
  bool isThemeAvailable(AppTheme theme) {
    return AppTheme.values.contains(theme);
  }

  // ✅ Fix 10: Get current theme info
  AppTheme get currentTheme => _currentTheme;

  String get currentThemeName => _currentTheme.name;

  List<AppTheme> get availableThemes => AppTheme.values;

  // ✅ Fix 11: Force refresh theme
  Future<void> refreshTheme() async {
    try {
      _logger.info('Refreshing current theme: $_currentTheme');
      emit(AppThemes.getThemeData(_currentTheme));
    } catch (e, stack) {
      _logger.severe('Error refreshing theme: $e', e, stack);
    }
  }

  // ✅ Fix 12: Improved close method
  @override
  Future<void> close() async {
    _logger.info('Closing ThemeCubit');

    // Cancel pending save operations
    _saveTimer?.cancel();
    _saveTimer = null;

    // Force save current theme before closing
    if (_prefs != null) {
      try {
        await _saveThemeToStorage();
        _logger.info('Final theme save completed');
      } catch (e) {
        _logger.warning('Error in final theme save: $e');
      }
    }

    _prefs = null;
    _logger.info('ThemeCubit closed successfully');

    return super.close();
  }

  // ✅ Debug methods
  Map<String, dynamic> getDebugInfo() {
    return {
      'currentTheme': _currentTheme.name,
      'hasPendingSave': _saveTimer != null,
      'prefsInitialized': _prefs != null,
      'availableThemes': AppTheme.values.map((t) => t.name).toList(),
    };
  }

  void logDebugInfo() {
    final info = getDebugInfo();
    _logger.info('ThemeCubit Debug Info: $info');
  }
}
