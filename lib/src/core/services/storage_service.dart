// lib/src/core/services/storage_service.dart
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String _tokenKey = 'auth_token';
  static const String _refreshTokenKey = 'refresh_token';
  static const String _tokenExpiryKey = 'token_expiry';
  static const String _userIdKey = 'user_id';

  Future<String?> getToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString(_tokenKey);
      final expiryStr = prefs.getString(_tokenExpiryKey);

      if (token == null) return null;

      // Check expiry
      if (expiryStr != null) {
        final expiry = DateTime.parse(expiryStr);
        if (DateTime.now().isAfter(expiry.subtract(Duration(minutes: 5)))) {
          // Token will expire in 5 minutes, consider it expired
          await deleteToken();
          return null;
        }
      }

      return token;
    } catch (e) {
      print('Error getting token: $e');
      return null;
    }
  }

  Future<void> saveToken(String token, {Duration? expiresIn}) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_tokenKey, token);

      if (expiresIn != null) {
        final expiry = DateTime.now().add(expiresIn);
        await prefs.setString(_tokenExpiryKey, expiry.toIso8601String());
      }
    } catch (e) {
      print('Error saving token: $e');
    }
  }

  Future<void> deleteToken() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_tokenKey);
      await prefs.remove(_refreshTokenKey);
      await prefs.remove(_tokenExpiryKey);
      await prefs.remove(_userIdKey);
    } catch (e) {
      print('Error deleting token: $e');
    }
  }

  Future<bool> hasValidToken() async {
    final token = await getToken();
    return token != null;
  }

  Future<void> saveUserId(int userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_userIdKey, userId);
    } catch (e) {
      print('Error saving user ID: $e');
    }
  }

  Future<int?> getUserId() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getInt(_userIdKey);
    } catch (e) {
      print('Error getting user ID: $e');
      return null;
    }
  }
}
