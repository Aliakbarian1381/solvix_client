/*
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeCubit extends Cubit<ThemeData> {
  static const String _themeKey = 'app_theme';

  ThemeCubit() : super(AppThemes.getThemeData(AppTheme.light)) {
    _loadTheme();
  }

  // بارگذاری تم ذخیره شده از حافظه
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final themeName = prefs.getString(_themeKey) ?? AppTheme.light.name;
    final appTheme = AppTheme.values.firstWhere(
      (e) => e.name == themeName,
      orElse: () => AppTheme.light,
    );
    emit(AppThemes.getThemeData(appTheme));
  }

  // تغییر و ذخیره تم جدید
  Future<void> changeTheme(AppTheme theme) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, theme.name);
    emit(AppThemes.getThemeData(theme));
  }
}
*/


import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_theme.dart';

class ThemeCubit extends Cubit<ThemeData> {
  static const String _themeKey = 'app_theme';

  ThemeCubit() : super(AppThemes.getThemeData(AppTheme.light)) {
    _loadThemeAsync();
  }

  // async method که خطاها رو handle میکنه
  void _loadThemeAsync() async {
    try {
      await _loadTheme();
    } catch (e) {
      print('Error loading theme, using default: $e');
      // اگر خطا بود، cleanup کن و default theme رو استفاده کن
      await _cleanupCorruptedData();
    }
  }

  // بارگذاری تم ذخیره شده از حافظه
  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();

    // اول چک کن که آیا key وجود داره یا نه
    if (!prefs.containsKey(_themeKey)) {
      // اگر key وجود نداره، default رو ذخیره کن
      await prefs.setString(_themeKey, AppTheme.light.name);
      return;
    }

    // value رو با try-catch بگیر
    String? themeName;
    try {
      themeName = prefs.getString(_themeKey);
    } catch (e) {
      print('Error getting theme string: $e');
      // اگر getString fail کرد، cleanup کن
      await _cleanupCorruptedData();
      return;
    }

    // اگر themeName null یا empty بود
    if (themeName == null || themeName.isEmpty) {
      await prefs.setString(_themeKey, AppTheme.light.name);
      return;
    }

    // سعی کن theme رو پیدا کنی
    try {
      final appTheme = AppTheme.values.firstWhere(
            (e) => e.name == themeName,
        orElse: () => AppTheme.light,
      );
      emit(AppThemes.getThemeData(appTheme));
    } catch (e) {
      print('Error finding theme enum: $e');
      await _cleanupCorruptedData();
    }
  }

  // پاک کردن داده‌های خراب
  Future<void> _cleanupCorruptedData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // تمام key های مرتبط با theme رو حذف کن
      await prefs.remove(_themeKey);

      // اگر key های دیگه ای هم هست که ممکنه مشکل ساز باشه
      // مثلاً اگر قبلاً theme رو به صورت bool یا int ذخیره کرده باشه
      final keys = prefs.getKeys();
      for (String key in keys) {
        if (key.contains('theme') || key.contains('Theme')) {
          try {
            // چک کن که value چه نوعیه
            final value = prefs.get(key);
            if (value is! String) {
              print('Found non-string theme value: $key = $value (${value.runtimeType})');
              await prefs.remove(key);
            }
          } catch (e) {
            print('Error checking key $key: $e');
            await prefs.remove(key);
          }
        }
      }

      // default theme رو ذخیره کن
      await prefs.setString(_themeKey, AppTheme.light.name);

      print('Theme cleanup completed, using default light theme');
    } catch (e) {
      print('Error during cleanup: $e');
    }
  }

  // تغییر و ذخیره تم جدید
  Future<void> changeTheme(AppTheme theme) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, theme.name);
      emit(AppThemes.getThemeData(theme));
    } catch (e) {
      print('Error saving theme: $e');
      // حتی اگر save نشه، theme رو عوض کن
      emit(AppThemes.getThemeData(theme));
    }
  }

  // یه method برای debug کردن تمام shared preferences
  Future<void> debugSharedPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final keys = prefs.getKeys();

      print('=== SharedPreferences Debug ===');
      for (String key in keys) {
        try {
          final value = prefs.get(key);
          print('$key: $value (${value.runtimeType})');
        } catch (e) {
          print('$key: ERROR - $e');
        }
      }
      print('=== End Debug ===');
    } catch (e) {
      print('Error debugging SharedPreferences: $e');
    }
  }
}
