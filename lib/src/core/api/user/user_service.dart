// lib/src/core/api/user/user_service.dart
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/core/services/storage_service.dart';

// اضافه کردن base URL مثل سایر service ها
const String _userBaseUrl = "https://api.solvix.ir/api/user";

class UserService {
  final Dio _dio;
  final StorageService _storageService;

  UserService(this._dio, this._storageService) {
    // تنظیم base URL برای این service
    _setupDio();
  }

  void _setupDio() {
    // اضافه کردن interceptor برای authentication
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest:
            (RequestOptions options, RequestInterceptorHandler handler) async {
              final token = await _storageService.getToken();
              if (token != null) {
                options.headers['Authorization'] = 'Bearer $token';
              }
              options.headers['Content-Type'] =
                  'application/json; charset=UTF-8';
              handler.next(options);
            },
      ),
    );
  }

  // ===== متدهای موجود =====

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        '$_userBaseUrl/search', // استفاده از full URL
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
        '$_userBaseUrl/sync-contacts', // استفاده از full URL
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
      final response = await _dio.get(
        '$_userBaseUrl/saved-contacts',
      ); // استفاده از full URL

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
      final response = await _dio.get(
        '$_userBaseUrl/saved-contacts-with-chat',
      ); // استفاده از full URL

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
      final response = await _dio.get(
        '$_userBaseUrl/$userId',
      ); // استفاده از full URL

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
      final response = await _dio.get(
        '$_userBaseUrl/online',
      ); // استفاده از full URL

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
        '$_userBaseUrl/update-fcm-token', // استفاده از full URL
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
        '$_userBaseUrl/contacts/search', // استفاده از full URL
        queryParameters: {'query': query, 'limit': limit},
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
      final response = await _dio.get(
        '$_userBaseUrl/contacts/favorites',
      ); // استفاده از full URL

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
        '$_userBaseUrl/contacts/recent', // استفاده از full URL
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
        '$_userBaseUrl/contacts/$contactId/favorite', // استفاده از full URL
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
        '$_userBaseUrl/contacts/$contactId/block', // استفاده از full URL
        data: {'isBlocked': isBlocked},
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('خطا در تغییر وضعیت مسدودیت: ${e.message}');
    }
  }

  Future<bool> updateContactDisplayName(
    int contactId,
    String? displayName,
  ) async {
    try {
      final response = await _dio.put(
        '$_userBaseUrl/contacts/$contactId/display-name', // استفاده از full URL
        data: {'displayName': displayName},
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('خطا در به‌روزرسانی نام نمایشی: ${e.message}');
    }
  }

  Future<bool> removeContact(int contactId) async {
    try {
      final response = await _dio.delete(
        '$_userBaseUrl/contacts/$contactId',
      ); // استفاده از full URL
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('خطا در حذف مخاطب: ${e.message}');
    }
  }

  Future<bool> updateLastInteraction(int contactId) async {
    try {
      final response = await _dio.post(
        '$_userBaseUrl/contacts/$contactId/interaction',
      ); // استفاده از full URL
      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('خطا در به‌روزرسانی آخرین تعامل: ${e.message}');
    }
  }

  // ===== متدهای کمکی =====

  Future<Map<String, dynamic>> getContactsStatistics() async {
    try {
      final response = await _dio.get(
        '$_userBaseUrl/contacts/statistics',
      ); // استفاده از full URL

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
        '$_userBaseUrl/contacts/filtered', // استفاده از full URL
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
  Future<bool> batchUpdateContacts(
    List<int> contactIds,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _dio.patch(
        '$_userBaseUrl/contacts/batch', // استفاده از full URL
        data: {'contactIds': contactIds, 'updates': updates},
      );

      return response.statusCode == 200;
    } on DioException catch (e) {
      throw Exception('خطا در به‌روزرسانی گروهی مخاطبین: ${e.message}');
    }
  }
}
