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
