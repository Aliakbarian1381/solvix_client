import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/core/services/storage_service.dart';

const String _userBaseUrl = "https://api.solvix.ir/api/user";

class UserService {
  final Dio _dio;
  final StorageService _storageService;

  UserService(this._dio, this._storageService) {
    _setupDio();
  }

  void _setupDio() {
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
        onError: (DioException e, ErrorInterceptorHandler handler) {
          print('DioError: ${e.type}');
          print('Status: ${e.response?.statusCode}');
          print('Data: ${e.response?.data}');
          handler.next(e);
        },
      ),
    );
  }

  // Helper method برای پردازش response
  List<UserModel> _parseUserListResponse(dynamic responseData) {
    if (responseData is Map<String, dynamic>) {
      // اگر response یک Map بود، دنبال key های معمول بگرد
      if (responseData.containsKey('data')) {
        responseData = responseData['data'];
      } else if (responseData.containsKey('result')) {
        responseData = responseData['result'];
      } else if (responseData.containsKey('users')) {
        responseData = responseData['users'];
      }
    }

    if (responseData is List) {
      return responseData.map((json) => UserModel.fromJson(json)).toList();
    } else {
      print('Unexpected response format: $responseData');
      return [];
    }
  }

  Future<List<UserModel>> searchUsers(String query) async {
    try {
      final response = await _dio.get(
        '$_userBaseUrl/search',
        queryParameters: {'query': query},
      );

      if (response.statusCode == 200) {
        return _parseUserListResponse(response.data);
      }
      return [];
    } on DioException catch (e) {
      print('DioException in searchUsers: ${e.message}');
      throw Exception('خطا در جستجوی کاربران: ${e.message}');
    } catch (e) {
      print('General exception in searchUsers: $e');
      throw Exception('خطا در جستجوی کاربران: $e');
    }
  }

  Future<List<UserModel>> syncContacts(List<String> phoneNumbers) async {
    try {
      final response = await _dio.post(
        '$_userBaseUrl/sync-contacts',
        data: phoneNumbers,
      );

      if (response.statusCode == 200) {
        return _parseUserListResponse(response.data);
      }
      return [];
    } on DioException catch (e) {
      print('DioException in syncContacts: ${e.message}');
      print('Response data: ${e.response?.data}');
      throw Exception('خطا در همگام‌سازی مخاطبین: ${e.message}');
    } catch (e) {
      print('General exception in syncContacts: $e');
      throw Exception('خطا در همگام‌سازی مخاطبین: $e');
    }
  }

  Future<List<UserModel>> getSavedContacts() async {
    try {
      final response = await _dio.get('$_userBaseUrl/saved-contacts');

      if (response.statusCode == 200) {
        return _parseUserListResponse(response.data);
      }
      return [];
    } on DioException catch (e) {
      print('DioException in getSavedContacts: ${e.message}');
      throw Exception('خطا در دریافت مخاطبین: ${e.message}');
    } catch (e) {
      print('General exception in getSavedContacts: $e');
      throw Exception('خطا در دریافت مخاطبین: $e');
    }
  }

  Future<List<UserModel>> getSavedContactsWithChat() async {
    try {
      final response = await _dio.get('$_userBaseUrl/saved-contacts-with-chat');

      if (response.statusCode == 200) {
        return _parseUserListResponse(response.data);
      }
      return [];
    } on DioException catch (e) {
      print('DioException in getSavedContactsWithChat: ${e.message}');
      throw Exception('خطا در دریافت مخاطبین با اطلاعات چت: ${e.message}');
    } catch (e) {
      print('General exception in getSavedContactsWithChat: $e');
      throw Exception('خطا در دریافت مخاطبین با اطلاعات چت: $e');
    }
  }

  Future<UserModel?> getUserById(int userId) async {
    try {
      final response = await _dio.get('$_userBaseUrl/$userId');

      if (response.statusCode == 200) {
        dynamic responseData = response.data;

        // اگر response یک Map بود که داخلش data هست
        if (responseData is Map<String, dynamic>) {
          if (responseData.containsKey('data')) {
            responseData = responseData['data'];
          } else if (responseData.containsKey('user')) {
            responseData = responseData['user'];
          }
        }

        return UserModel.fromJson(responseData);
      }
      return null;
    } on DioException catch (e) {
      print('DioException in getUserById: ${e.message}');
      throw Exception('خطا در دریافت کاربر: ${e.message}');
    } catch (e) {
      print('General exception in getUserById: $e');
      throw Exception('خطا در دریافت کاربر: $e');
    }
  }

  Future<List<UserModel>> getOnlineUsers() async {
    try {
      final response = await _dio.get('$_userBaseUrl/online');

      if (response.statusCode == 200) {
        return _parseUserListResponse(response.data);
      }
      return [];
    } on DioException catch (e) {
      print('DioException in getOnlineUsers: ${e.message}');
      throw Exception('خطا در دریافت کاربران آنلاین: ${e.message}');
    } catch (e) {
      print('General exception in getOnlineUsers: $e');
      throw Exception('خطا در دریافت کاربران آنلاین: $e');
    }
  }

  Future<void> updateFcmToken(String token) async {
    try {
      await _dio.post('$_userBaseUrl/update-fcm-token', data: {'token': token});
    } on DioException catch (e) {
      print('DioException in updateFcmToken: ${e.message}');
      throw Exception('خطا در به‌روزرسانی FCM token: ${e.message}');
    } catch (e) {
      print('General exception in updateFcmToken: $e');
      throw Exception('خطا در به‌روزرسانی FCM token: $e');
    }
  }

  // متدهای جدید برای مدیریت مخاطبین
  Future<List<UserModel>> searchContacts(String query, {int limit = 20}) async {
    try {
      final response = await _dio.get(
        '$_userBaseUrl/contacts/search',
        queryParameters: {'query': query, 'limit': limit},
      );

      if (response.statusCode == 200) {
        return _parseUserListResponse(response.data);
      }
      return [];
    } on DioException catch (e) {
      print('DioException in searchContacts: ${e.message}');
      throw Exception('خطا در جستجوی مخاطبین: ${e.message}');
    } catch (e) {
      print('General exception in searchContacts: $e');
      throw Exception('خطا در جستجوی مخاطبین: $e');
    }
  }

  Future<List<UserModel>> getFavoriteContacts() async {
    try {
      final response = await _dio.get('$_userBaseUrl/contacts/favorites');

      if (response.statusCode == 200) {
        return _parseUserListResponse(response.data);
      }
      return [];
    } on DioException catch (e) {
      print('DioException in getFavoriteContacts: ${e.message}');
      throw Exception('خطا در دریافت مخاطبین مورد علاقه: ${e.message}');
    } catch (e) {
      print('General exception in getFavoriteContacts: $e');
      throw Exception('خطا در دریافت مخاطبین مورد علاقه: $e');
    }
  }

  Future<List<UserModel>> getRecentContacts({int limit = 10}) async {
    try {
      final response = await _dio.get(
        '$_userBaseUrl/contacts/recent',
        queryParameters: {'limit': limit},
      );

      if (response.statusCode == 200) {
        return _parseUserListResponse(response.data);
      }
      return [];
    } on DioException catch (e) {
      print('DioException in getRecentContacts: ${e.message}');
      throw Exception('خطا در دریافت مخاطبین اخیر: ${e.message}');
    } catch (e) {
      print('General exception in getRecentContacts: $e');
      throw Exception('خطا در دریافت مخاطبین اخیر: $e');
    }
  }

  Future<bool> toggleFavoriteContact(int contactId, bool isFavorite) async {
    try {
      final response = await _dio.put(
        '$_userBaseUrl/contacts/$contactId/favorite',
        data: {'isFavorite': isFavorite},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      print('DioException in toggleFavoriteContact: ${e.message}');
      throw Exception('خطا در تغییر وضعیت علاقه‌مندی: ${e.message}');
    } catch (e) {
      print('General exception in toggleFavoriteContact: $e');
      throw Exception('خطا در تغییر وضعیت علاقه‌مندی: $e');
    }
  }

  Future<bool> toggleBlockContact(int contactId, bool isBlocked) async {
    try {
      final response = await _dio.put(
        '$_userBaseUrl/contacts/$contactId/block',
        data: {'isBlocked': isBlocked},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      print('DioException in toggleBlockContact: ${e.message}');
      throw Exception('خطا در تغییر وضعیت مسدودیت: ${e.message}');
    } catch (e) {
      print('General exception in toggleBlockContact: $e');
      throw Exception('خطا در تغییر وضعیت مسدودیت: $e');
    }
  }

  Future<bool> updateContactDisplayName(
    int contactId,
    String? displayName,
  ) async {
    try {
      final response = await _dio.put(
        '$_userBaseUrl/contacts/$contactId/display-name',
        data: {'displayName': displayName},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      print('DioException in updateContactDisplayName: ${e.message}');
      throw Exception('خطا در به‌روزرسانی نام نمایشی: ${e.message}');
    } catch (e) {
      print('General exception in updateContactDisplayName: $e');
      throw Exception('خطا در به‌روزرسانی نام نمایشی: $e');
    }
  }

  Future<bool> removeContact(int contactId) async {
    try {
      final response = await _dio.delete('$_userBaseUrl/contacts/$contactId');
      return response.statusCode == 200;
    } on DioException catch (e) {
      print('DioException in removeContact: ${e.message}');
      throw Exception('خطا در حذف مخاطب: ${e.message}');
    } catch (e) {
      print('General exception in removeContact: $e');
      throw Exception('خطا در حذف مخاطب: $e');
    }
  }

  Future<bool> updateLastInteraction(int contactId) async {
    try {
      final response = await _dio.post(
        '$_userBaseUrl/contacts/$contactId/interaction',
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      print('DioException in updateLastInteraction: ${e.message}');
      throw Exception('خطا در به‌روزرسانی آخرین تعامل: ${e.message}');
    } catch (e) {
      print('General exception in updateLastInteraction: $e');
      throw Exception('خطا در به‌روزرسانی آخرین تعامل: $e');
    }
  }

  Future<Map<String, dynamic>> getContactsStatistics() async {
    try {
      final response = await _dio.get('$_userBaseUrl/contacts/statistics');

      if (response.statusCode == 200) {
        dynamic responseData = response.data;
        if (responseData is Map<String, dynamic>) {
          return responseData;
        }
        return {};
      }
      return {};
    } on DioException catch (e) {
      print('DioException in getContactsStatistics: ${e.message}');
      throw Exception('خطا در دریافت آمار مخاطبین: ${e.message}');
    } catch (e) {
      print('General exception in getContactsStatistics: $e');
      throw Exception('خطا در دریافت آمار مخاطبین: $e');
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
        '$_userBaseUrl/contacts/filtered',
        queryParameters: queryParams,
      );

      if (response.statusCode == 200) {
        return _parseUserListResponse(response.data);
      }
      return [];
    } on DioException catch (e) {
      print('DioException in getFilteredContacts: ${e.message}');
      throw Exception('خطا در دریافت مخاطبین فیلتر شده: ${e.message}');
    } catch (e) {
      print('General exception in getFilteredContacts: $e');
      throw Exception('خطا در دریافت مخاطبین فیلتر شده: $e');
    }
  }

  Future<bool> batchUpdateContacts(
    List<int> contactIds,
    Map<String, dynamic> updates,
  ) async {
    try {
      final response = await _dio.patch(
        '$_userBaseUrl/contacts/batch',
        data: {'contactIds': contactIds, 'updates': updates},
      );
      return response.statusCode == 200;
    } on DioException catch (e) {
      print('DioException in batchUpdateContacts: ${e.message}');
      throw Exception('خطا در به‌روزرسانی گروهی مخاطبین: ${e.message}');
    } catch (e) {
      print('General exception in batchUpdateContacts: $e');
      throw Exception('خطا در به‌روزرسانی گروهی مخاطبین: $e');
    }
  }
}
