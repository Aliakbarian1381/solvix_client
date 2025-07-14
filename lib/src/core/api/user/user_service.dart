import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/core/services/storage_service.dart';

class UserService {
  final Dio _dio;
  final StorageService _storageService;

  UserService(this._dio, this._storageService);

  // ===== متدهای موجود =====

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

  Future<void> updateFcmToken(String token) async {
    try {
      await _dio.post(
        '/api/user/update-fcm-token',
        data: {'token': token},
      );
    } on DioException catch (e) {
      throw Exception('خطا در به‌روزرسانی FCM token: ${e.message}');
    }
  }

  // ===== متدهای جدید برای مدیریت مخاطبین =====

  Future<List<UserModel>> searchContacts(String query, {int limit = 20}) async {
    try {
      final response = await _dio.get(
        '/api/user/contacts/search',
        queryParameters: {
          'query': query,
          'limit': limit,
        },
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('خطا در جستجوی مخاطبین: ${e.message}');
    }
  }

  Future<List<UserModel>> getFavoriteContacts() async {
    try {
      final response = await _dio.get('/api/user/contacts/favorites');

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('خطا در دریافت مخاطبین مورد علاقه: ${e.message}');
    }
  }

  Future<List<UserModel>> getRecentContacts({int limit = 10}) async {
    try {
      final response = await _dio.get(
        '/api/user/contacts/recent',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('خطا در دریافت مخاطبین اخیر: ${e.message}');
    }
  }

  Future<bool> toggleFavoriteContact(int contactId, bool isFavorite) async {
    try {
      final response = await _dio.put(
        '/api/user/contacts/$contactId/favorite',
        data: {'isFavorite': isFavorite},
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('خطا در تغییر وضعیت علاقه‌مندی: ${e.message}');
    }
  }

  Future<bool> toggleBlockContact(int contactId, bool isBlocked) async {
    try {
      final response = await _dio.put(
        '/api/user/contacts/$contactId/block',
        data: {'isBlocked': isBlocked},
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('خطا در تغییر وضعیت مسدودیت: ${e.message}');
    }
  }

  Future<bool> updateContactDisplayName(int contactId, String? displayName) async {
    try {
      final response = await _dio.put(
        '/api/user/contacts/$contactId/display-name',
        data: {'displayName': displayName},
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('خطا در به‌روزرسانی نام نمایشی: ${e.message}');
    }
  }

  Future<bool> removeContact(int contactId) async {
    try {
      final response = await _dio.delete('/api/user/contacts/$contactId');
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('خطا در حذف مخاطب: ${e.message}');
    }
  }

  Future<bool> updateLastInteraction(int contactId) async {
    try {
      final response = await _dio.post('/api/user/contacts/$contactId/interaction');
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('خطا در به‌روزرسانی آخرین تعامل: ${e.message}');
    }
  }

  // ===== متدهای کمکی =====

  Future<Map<String, dynamic>> getContactsStatistics() async {
    try {
      final response = await _dio.get('/api/user/contacts/statistics');

      if (response.statusCode == 200) {
        return response.data as Map<String, dynamic>;
      }
      return {};
    } on DioException catch (e) {
      throw Exception('خطا در دریافت آمار مخاطبین: ${e.message}');
    }
  }

  Future<List<UserModel>> getFilteredContacts({
    bool? isFavorite,
    bool? isBlocked,
    bool? hasChat,
    String sortBy = 'name',
    String sortDirection = 'asc',
  }) async {
    try {
      final queryParams = <String, dynamic>{
        'sortBy': sortBy,
        'sortDirection': sortDirection,
      };

      if (isFavorite != null) queryParams['isFavorite'] = isFavorite;
      if (isBlocked != null) queryParams['isBlocked'] = isBlocked;
      if (hasChat != null) queryParams['hasChat'] = hasChat;

      final response = await _dio.get(
        '/api/user/contacts/filtered',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = response.data;
        return data.map((json) => UserModel.fromJson(json)).toList();
      }
      return [];
    } on DioException catch (e) {
      throw Exception('خطا در دریافت مخاطبین فیلتر شده: ${e.message}');
    }
  }

  // متد کمکی برای batch operations
  Future<bool> batchUpdateContacts(List<int> contactIds, Map<String, dynamic> updates) async {
    try {
      final response = await _dio.patch(
        '/api/user/contacts/batch',
        data: {
          'contactIds': contactIds,
          'updates': updates,
        },
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('خطا در به‌روزرسانی گروهی مخاطبین: ${e.message}');
    }
  }
}