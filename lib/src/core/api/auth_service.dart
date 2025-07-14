// lib/src/core/api/auth_service.dart
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:solvix/src/core/models/otp_register_model.dart';
import 'package:solvix/src/core/models/otp_request_model.dart';
import 'package:solvix/src/core/models/otp_verify_model.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/core/services/storage_service.dart';

class AuthService {
  final String _baseUrl = "https://api.solvix.ir/api/auth";
  final StorageService _storageService;

  AuthService(this._storageService);

  String _extractErrorMessage(http.Response response, String defaultMessage) {
    try {
      final responseBody = jsonDecode(response.body);
      if (responseBody is Map<String, dynamic>) {
        return responseBody['message'] ??
            responseBody['error'] ??
            responseBody['errors']?.toString() ??
            defaultMessage;
      }
      return defaultMessage;
    } catch (e) {
      return defaultMessage;
    }
  }

  // Helper method to parse user response
  UserModel _parseUserResponse(Map<String, dynamic> responseBody) {
    dynamic userData = responseBody;

    // Check for common response wrapper patterns
    if (userData.containsKey('data')) {
      userData = userData['data'];
    } else if (userData.containsKey('user')) {
      userData = userData['user'];
    } else if (userData.containsKey('result')) {
      userData = userData['result'];
    }

    return UserModel.fromJson(userData);
  }

  Future<bool> checkPhoneExists(String phoneNumber) async {
    final url = Uri.parse('$_baseUrl/check-phone/$phoneNumber');
    try {
      final response = await http.get(url).timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        // Handle different response formats
        if (responseBody is Map<String, dynamic>) {
          if (responseBody.containsKey('data') && responseBody['data'] is Map) {
            return responseBody['data']['exists'] as bool? ?? false;
          } else if (responseBody.containsKey('exists')) {
            return responseBody['exists'] as bool? ?? false;
          } else if (responseBody.containsKey('userExists')) {
            return responseBody['userExists'] as bool? ?? false;
          }
        }

        // Default to false if format is unexpected
        return false;
      } else {
        throw Exception(
          _extractErrorMessage(response, 'خطا در بررسی شماره تلفن'),
        );
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('خطای شبکه در بررسی شماره: ${e.toString()}');
    }
  }

  Future<void> requestOtp(OtpRequestModel model) async {
    final url = Uri.parse('$_baseUrl/request-otp');
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(model.toJson()),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception(
          _extractErrorMessage(response, 'خطا در ارسال کد تأیید'),
        );
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('خطای شبکه در ارسال کد: ${e.toString()}');
    }
  }

  Future<UserModel> verifyOtp(OtpVerifyModel model) async {
    final url = Uri.parse('$_baseUrl/verify-otp');
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(model.toJson()),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final user = _parseUserResponse(responseBody);

        if (user.token != null) {
          await _storageService.saveToken(
            user.token!,
            expiresIn: Duration(days: 7),
          );
          await _storageService.saveUserId(user.id);
        }

        return user;
      } else {
        throw Exception(_extractErrorMessage(response, 'کد تأیید نامعتبر است'));
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('خطای شبکه در تأیید کد: ${e.toString()}');
    }
  }

  Future<UserModel> registerWithOtp(OtpRegisterModel model) async {
    final url = Uri.parse('$_baseUrl/register-with-otp');
    try {
      final response = await http
          .post(
            url,
            headers: {'Content-Type': 'application/json; charset=UTF-8'},
            body: jsonEncode(model.toJson()),
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final user = _parseUserResponse(responseBody);

        if (user.token != null) {
          await _storageService.saveToken(
            user.token!,
            expiresIn: Duration(days: 7),
          );
          await _storageService.saveUserId(user.id);
        }

        return user;
      } else {
        throw Exception(
          _extractErrorMessage(response, 'خطا در فرآیند ثبت نام'),
        );
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('خطای شبکه در ثبت نام: ${e.toString()}');
    }
  }

  Future<UserModel> getCurrentUser() async {
    final token = await _storageService.getToken();
    if (token == null) {
      throw Exception('توکن یافت نشد. لطفاً دوباره وارد شوید.');
    }

    final url = Uri.parse('$_baseUrl/current-user');
    try {
      final response = await http
          .get(
            url,
            headers: {
              'Content-Type': 'application/json; charset=UTF-8',
              'Authorization': 'Bearer $token',
            },
          )
          .timeout(Duration(seconds: 30));

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return _parseUserResponse(responseBody);
      } else if (response.statusCode == 401) {
        await _storageService.deleteToken();
        throw Exception('نشست شما منقضی شده. لطفاً دوباره وارد شوید.');
      } else {
        throw Exception(
          _extractErrorMessage(response, 'خطا در دریافت اطلاعات کاربر'),
        );
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('خطای شبکه در دریافت اطلاعات: ${e.toString()}');
    }
  }

  Future<void> logout() async {
    try {
      final token = await _storageService.getToken();
      if (token != null) {
        final url = Uri.parse('$_baseUrl/logout');
        await http
            .post(
              url,
              headers: {
                'Content-Type': 'application/json; charset=UTF-8',
                'Authorization': 'Bearer $token',
              },
            )
            .timeout(Duration(seconds: 10));
      }
    } catch (e) {
      print('Error calling logout endpoint: $e');
    } finally {
      await _storageService.deleteToken();
    }
  }

  Future<bool> isLoggedIn() async {
    return await _storageService.hasValidToken();
  }
}
