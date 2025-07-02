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
  final StorageService _storageService = StorageService();

  String _extractErrorMessage(http.Response response, String defaultMessage) {
    try {
      final responseBody = jsonDecode(response.body);
      return responseBody['message'] ?? defaultMessage;
    } catch (_) {
      return defaultMessage;
    }
  }

  Future<bool> checkPhoneExists(String phoneNumber) async {
    final url = Uri.parse('$_baseUrl/check-phone/$phoneNumber');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return responseBody['data']['exists'] as bool;
      } else {
        throw Exception(
          _extractErrorMessage(response, 'خطا در بررسی شماره تلفن'),
        );
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('خطای شبکه (checkPhoneExists): ${e.toString()}');
    }
  }

  Future<void> requestOtp(OtpRequestModel model) async {
    final url = Uri.parse('$_baseUrl/request-otp');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(model.toJson()),
      );
      if (response.statusCode != 200) {
        throw Exception(
          _extractErrorMessage(response, 'خطا در ارسال کد تایید'),
        );
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('خطای شبکه (requestOtp): ${e.toString()}');
    }
  }

  Future<UserModel> verifyOtp(OtpVerifyModel model) async {
    final url = Uri.parse('$_baseUrl/verify-otp');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(model.toJson()),
      );
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return UserModel.fromJson(responseBody['data']);
      } else {
        throw Exception(_extractErrorMessage(response, 'کد تایید نامعتبر است'));
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('کد تایید نامعتبر است!');
    }
  }

  Future<UserModel> registerWithOtp(OtpRegisterModel model) async {
    final url = Uri.parse('$_baseUrl/register-with-otp');
    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json; charset=UTF-8'},
        body: jsonEncode(model.toJson()),
      );
      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        return UserModel.fromJson(responseBody['data']);
      } else {
        throw Exception(
          _extractErrorMessage(response, 'خطا در فرآیند ثبت نام'),
        );
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('خطای شبکه (registerWithOtp): ${e.toString()}');
    }
  }

  Future<UserModel> getCurrentUser() async {
    final token = await _storageService.getToken();
    if (token == null) {
      throw Exception('توکن یافت نشد. لطفاً دوباره وارد شوید.');
    }
    final url = Uri.parse('$_baseUrl/current-user');
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
        return UserModel.fromJson(responseBody['data']);
      } else {
        if (response.statusCode == 401) {
          await _storageService.deleteToken();
          throw Exception('نشست شما منقضی شده. لطفاً دوباره وارد شوید.');
        }
        throw Exception(
          _extractErrorMessage(response, 'خطا در دریافت اطلاعات کاربر'),
        );
      }
    } catch (e) {
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('خطای شبکه (getCurrentUser): ${e.toString()}');
    }
  }
}
