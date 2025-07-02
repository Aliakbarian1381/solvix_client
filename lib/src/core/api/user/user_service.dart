import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/core/services/storage_service.dart';

const String _userBaseUrl = "https://api.solvix.ir/api/user";

class UserService {
  final StorageService _storageService = StorageService();

  // متد برای جستجوی کاربران
  // GET /api/user/search?query={query}
  Future<List<UserModel>> searchUsers(String query) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن احراز هویت یافت نشد.');

    if (query.isEmpty) return []; // اگر کوئری خالی است، لیست خالی برگردان

    final url = Uri.parse(
      '$_userBaseUrl/search',
    ).replace(queryParameters: {'query': query});
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        // پاسخ این اندپوینت هم داخل فیلد 'data' است
        final List<dynamic> usersData = responseBody['data'];
        return usersData
            .map(
              (userJson) =>
                  UserModel.fromJson(userJson as Map<String, dynamic>),
            )
            .toList();
      } else {
        String errorMessage = 'خطا در جستجوی کاربران';
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['message'] ?? errorMessage;
        } catch (_) {}
        throw Exception('$errorMessage (کد: ${response.statusCode})');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains("خطا")) rethrow;
      throw Exception('خطای شبکه هنگام جستجوی کاربران: ${e.toString()}');
    }
  }

  Future<List<UserModel>> syncContacts(List<String> phoneNumbers) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن یافت نشد.');

    final url = Uri.parse('https://api.solvix.ir/api/user/sync-contacts');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(phoneNumbers),
    );

    if (response.statusCode == 200) {
      final List<dynamic> responseBody = jsonDecode(response.body)['data'];
      return responseBody.map((json) => UserModel.fromJson(json)).toList();
    } else {
      throw Exception('خطا در همگام سازی مخاطبین');
    }
  }

  // متد برای دریافت کاربران آنلاین
  // GET /api/user/online
  Future<List<UserModel>> getOnlineUsers() async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن احراز هویت یافت نشد.');

    final url = Uri.parse('$_userBaseUrl/online');
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        // پاسخ این اندپوینت هم داخل فیلد 'data' است
        final List<dynamic> usersData = responseBody['data'];
        return usersData
            .map(
              (userJson) =>
                  UserModel.fromJson(userJson as Map<String, dynamic>),
            )
            .toList();
      } else {
        String errorMessage = 'خطا در دریافت کاربران آنلاین';
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['message'] ?? errorMessage;
        } catch (_) {}
        throw Exception('$errorMessage (کد: ${response.statusCode})');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains("خطا")) rethrow;
      throw Exception('خطای شبکه هنگام دریافت کاربران آنلاین: ${e.toString()}');
    }
  }

  Future<void> updateFcmToken(String fcmToken) async {
    final token = await _storageService.getToken();
    if (token == null) {
      throw Exception('User not authenticated to update FCM token.');
    }

    final url = Uri.parse("https://api.solvix.ir/api/user/update-fcm-token");
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        body: jsonEncode({'Token': fcmToken}),
      );

      if (response.statusCode != 200) {
        throw Exception(
          'Failed to update FCM token on server: ${response.body}',
        );
      }
    } catch (e) {
      rethrow;
    }
  }
}
