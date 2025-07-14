import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/core/services/storage_service.dart';

class UserService {
  final Dio _dio;
  final StorageService _storageService;

  UserService(this._dio, this._storageService);

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        '/api/user/search',
        queryParameters: {'query': query},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('خطا در جستجوی کاربران: ${e.message}');
    }
  }

  Future<List<UserModel>> syncContacts(List<String> phoneNumbers) async {
    try {
      final response = await _dio.post(
        '/api/user/sync-contacts',
        data: phoneNumbers,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('خطا در همگام‌سازی مخاطبین: ${e.message}');
    }
  }

  Future<List<UserModel>> getSavedContacts() async {
    try {
      final response = await _dio.get('/api/user/saved-contacts');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('خطا در دریافت مخاطبین: ${e.message}');
    }
  }

  Future<List<UserModel>> getSavedContactsWithChat() async {
    try {
      final response = await _dio.get('/api/user/saved-contacts-with-chat');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('خطا در دریافت مخاطبین با اطلاعات چت: ${e.message}');
    }
  }

  Future<UserModel?> getUserById(int userId) async {
    try {
      final response = await _dio.get('/api/user/$userId');

      if (response.statusCode == 200) {
        return UserModel.fromJson(response.data);
      }
      return null;
    } on DioException catch (e) {
      throw Exception('خطا در دریافت کاربر: ${e.message}');
    }
  }

  Future<List<UserModel>> getOnlineUsers() async {
    try {
      final response = await _dio.get('/api/user/online');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('خطا در دریافت کاربران آنلاین: ${e.message}');
    }
  }

  Future<bool> updateFcmToken(String fcmToken) async {
    try {
      final response = await _dio.post(
        '/api/user/update-fcm-token',
        data: {'token': fcmToken},
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('خطا در بروزرسانی FCM Token: ${e.message}');
    }
  }

  Future<bool> setContactFavorite(int contactId, bool isFavorite) async {
    try {
      final response = await _dio.post(
        '/api/user/contacts/$contactId/favorite',
        data: isFavorite,
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('خطا در تنظیم علاقه‌مندی مخاطب: ${e.message}');
    }
  }

  Future<bool> blockContact(int contactId, bool isBlocked) async {
    try {
      final response = await _dio.post(
        '/api/user/contacts/$contactId/block',
        data: isBlocked,
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('خطا در مسدود کردن مخاطب: ${e.message}');
    }
  }

  Future<bool> updateLastActive() async {
    try {
      final response = await _dio.post('/api/user/update-last-active');
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('خطا در بروزرسانی آخرین فعالیت: ${e.message}');
    }
  }
}
