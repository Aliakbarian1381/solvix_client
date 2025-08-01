// lib/src/core/api/auth_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:logging/logging.dart';
import 'package:solvix/src/core/models/otp_register_model.dart';
import 'package:solvix/src/core/models/otp_request_model.dart';
import 'package:solvix/src/core/models/otp_verify_model.dart';
import 'package:solvix/src/core/models/user_model.dart';
import 'package:solvix/src/core/services/storage_service.dart';

// ✅ Fix 1: Constants
class AuthConstants {
  static const String baseUrl = "https://api.solvix.ir/api/auth";
  static const Duration requestTimeout = Duration(seconds: 30);
  static const Duration tokenValidityDuration = Duration(days: 7);
}

class AuthService {
  final StorageService _storageService;
  final Logger _logger = Logger('AuthService');
  final http.Client _httpClient;

  // ✅ Fix 2: بهتر dependency injection
  AuthService(this._storageService, {http.Client? httpClient})
    : _httpClient = httpClient ?? http.Client();

  // ✅ Fix 3: بهتر error message extraction
  String _extractErrorMessage(http.Response response, String defaultMessage) {
    try {
      final responseBody = jsonDecode(response.body);
      if (responseBody is Map<String, dynamic>) {
        // چک کردن message patterns مختلف
        final message =
            responseBody['message'] ??
            responseBody['error'] ??
            responseBody['Error'] ??
            responseBody['errorMessage'];

        if (message != null) {
          return message.toString();
        }

        // چک کردن errors array
        if (responseBody['errors'] != null) {
          final errors = responseBody['errors'];
          if (errors is List && errors.isNotEmpty) {
            return errors.first.toString();
          } else if (errors is Map) {
            final firstKey = errors.keys.first;
            final firstError = errors[firstKey];
            if (firstError is List && firstError.isNotEmpty) {
              return firstError.first.toString();
            }
            return firstError.toString();
          }
          return errors.toString();
        }
      }
      return defaultMessage;
    } catch (e) {
      _logger.warning('Error parsing error message: $e');
      return defaultMessage;
    }
  }

  // ✅ Fix 4: بهتر user response parsing
  UserModel _parseUserResponse(Map<String, dynamic> responseBody) {
    try {
      dynamic userData = responseBody;

      // چک کردن wrapper patterns مختلف
      const wrapperKeys = ['data', 'user', 'result', 'payload'];
      for (final key in wrapperKeys) {
        if (userData.containsKey(key) &&
            userData[key] is Map<String, dynamic>) {
          userData = userData[key];
          break;
        }
      }

      final user = UserModel.fromJson(userData as Map<String, dynamic>);
      _logger.info('User parsed successfully: ${user.username}');
      return user;
    } catch (e, stack) {
      _logger.severe('Error parsing user response: $e', e, stack);
      throw Exception('خطا در پردازش اطلاعات کاربر: $e');
    }
  }

  // ✅ Fix 5: بهتر HTTP request helper
  Future<http.Response> _makeRequest(
    String method,
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, String>? headers,
    Duration? timeout,
  }) async {
    final uri = Uri.parse('${AuthConstants.baseUrl}$endpoint');
    final requestTimeout = timeout ?? AuthConstants.requestTimeout;

    final defaultHeaders = {
      'Content-Type': 'application/json; charset=UTF-8',
      'Accept': 'application/json',
      'User-Agent': 'Solvix-Mobile/1.0.0',
    };

    final requestHeaders = {...defaultHeaders, ...?headers};

    _logger.info('Making $method request to: $endpoint');

    try {
      http.Response response;

      switch (method.toUpperCase()) {
        case 'GET':
          response = await _httpClient
              .get(uri, headers: requestHeaders)
              .timeout(requestTimeout);
          break;
        case 'POST':
          final requestBody = body != null ? jsonEncode(body) : null;
          response = await _httpClient
              .post(uri, headers: requestHeaders, body: requestBody)
              .timeout(requestTimeout);
          break;
        case 'PUT':
          final requestBody = body != null ? jsonEncode(body) : null;
          response = await _httpClient
              .put(uri, headers: requestHeaders, body: requestBody)
              .timeout(requestTimeout);
          break;
        case 'DELETE':
          response = await _httpClient
              .delete(uri, headers: requestHeaders)
              .timeout(requestTimeout);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      _logger.fine('Response status: ${response.statusCode}');
      return response;
    } on TimeoutException {
      _logger.severe('Request timeout for $method $endpoint');
      throw Exception(
        'درخواست از زمان مجاز تجاوز کرد. لطفاً دوباره تلاش کنید.',
      );
    } on SocketException {
      _logger.severe('Network error for $method $endpoint');
      throw Exception('خطای شبکه. لطفاً اتصال اینترنت خود را بررسی کنید.');
    } catch (e, stack) {
      _logger.severe('Request error for $method $endpoint: $e', e, stack);
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('خطای شبکه: ${e.toString()}');
    }
  }

  // ✅ Fix 6: بهبود checkPhoneExists
  Future<bool> checkPhoneExists(String phoneNumber) async {
    try {
      _logger.info('Checking phone existence: $phoneNumber');

      final response = await _makeRequest('GET', '/check-phone/$phoneNumber');

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);

        if (responseBody is Map<String, dynamic>) {
          // چک کردن patterns مختلف response
          final patterns = [
            'exists',
            'userExists',
            'phoneExists',
            ['data', 'exists'],
            ['result', 'exists'],
            ['payload', 'exists'],
          ];

          for (final pattern in patterns) {
            bool? exists;

            if (pattern is String) {
              exists = responseBody[pattern] as bool?;
            } else if (pattern is List) {
              dynamic current = responseBody;
              for (final key in pattern) {
                if (current is Map<String, dynamic> &&
                    current.containsKey(key)) {
                  current = current[key];
                } else {
                  current = null;
                  break;
                }
              }
              exists = current as bool?;
            }

            if (exists != null) {
              _logger.info('Phone exists result: $exists');
              return exists;
            }
          }
        }

        // اگر هیچ pattern پیدا نشد، default false
        _logger.warning(
          'Unexpected response format for phone check, defaulting to false',
        );
        return false;
      } else {
        final errorMessage = _extractErrorMessage(
          response,
          'خطا در بررسی شماره تلفن',
        );
        throw Exception(errorMessage);
      }
    } catch (e, stack) {
      _logger.severe('Error checking phone existence: $e', e, stack);
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('خطای شبکه در بررسی شماره: ${e.toString()}');
    }
  }

  // ✅ Fix 7: بهبود requestOtp
  Future<void> requestOtp(OtpRequestModel model) async {
    try {
      _logger.info('Requesting OTP for: ${model.phoneNumber}');

      final response = await _makeRequest(
        'POST',
        '/request-otp',
        body: model.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        _logger.info('OTP request successful');
      } else {
        final errorMessage = _extractErrorMessage(
          response,
          'خطا در ارسال کد تأیید',
        );
        throw Exception(errorMessage);
      }
    } catch (e, stack) {
      _logger.severe('Error requesting OTP: $e', e, stack);
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('خطای شبکه در ارسال کد: ${e.toString()}');
    }
  }

  // ✅ Fix 8: بهبود verifyOtp
  Future<UserModel> verifyOtp(OtpVerifyModel model) async {
    try {
      _logger.info('Verifying OTP for: ${model.phoneNumber}');

      final response = await _makeRequest(
        'POST',
        '/verify-otp',
        body: model.toJson(),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final user = _parseUserResponse(responseBody);

        // ذخیره token و user info
        if (user.token != null && user.token!.isNotEmpty) {
          await _storageService.saveToken(
            user.token!,
            expiresIn: AuthConstants.tokenValidityDuration,
          );
          await _storageService.saveUserId(user.id);
          _logger.info('User tokens saved successfully');
        } else {
          _logger.warning('No token received from server');
        }

        return user;
      } else {
        final errorMessage = _extractErrorMessage(
          response,
          'کد تأیید نامعتبر است',
        );
        throw Exception(errorMessage);
      }
    } catch (e, stack) {
      _logger.severe('Error verifying OTP: $e', e, stack);
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('خطای شبکه در تأیید کد: ${e.toString()}');
    }
  }

  // ✅ Fix 9: بهبود registerWithOtp
  Future<UserModel> registerWithOtp(OtpRegisterModel model) async {
    try {
      _logger.info('Registering with OTP for: ${model.phoneNumber}');

      final response = await _makeRequest(
        'POST',
        '/register-with-otp',
        body: model.toJson(),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        final responseBody = jsonDecode(response.body);
        final user = _parseUserResponse(responseBody);

        // ذخیره token و user info
        if (user.token != null && user.token!.isNotEmpty) {
          await _storageService.saveToken(
            user.token!,
            expiresIn: AuthConstants.tokenValidityDuration,
          );
          await _storageService.saveUserId(user.id);
          _logger.info('New user registered and tokens saved');
        } else {
          _logger.warning('No token received from registration');
        }

        return user;
      } else {
        final errorMessage = _extractErrorMessage(response, 'خطا در ثبت‌نام');
        throw Exception(errorMessage);
      }
    } catch (e, stack) {
      _logger.severe('Error registering with OTP: $e', e, stack);
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('خطای شبکه در ثبت‌نام: ${e.toString()}');
    }
  }

  // ✅ Fix 10: بهبود getCurrentUser
  Future<UserModel> getCurrentUser() async {
    try {
      final token = await _storageService.getToken();
      if (token == null || token.isEmpty) {
        throw Exception('کاربر وارد نشده است');
      }

      _logger.info('Fetching current user');

      final response = await _makeRequest(
        'GET',
        '/me',
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final user = _parseUserResponse(responseBody);

        // آپدیت user info در cache
        await _storageService.saveUserId(user.id);
        _logger.info('Current user fetched successfully');

        return user;
      } else if (response.statusCode == 401) {
        // Token expired یا invalid
        await _storageService.deleteToken();
        throw Exception('نشست شما منقضی شده است. لطفاً دوباره وارد شوید.');
      } else {
        final errorMessage = _extractErrorMessage(
          response,
          'خطا در دریافت اطلاعات کاربر',
        );
        throw Exception(errorMessage);
      }
    } catch (e, stack) {
      _logger.severe('Error getting current user: $e', e, stack);
      if (e is Exception && e.toString().contains('خطا')) rethrow;
      throw Exception('خطای شبکه در دریافت اطلاعات: ${e.toString()}');
    }
  }

  // ✅ Fix 11: اضافه کردن logout method
  Future<void> logout() async {
    try {
      final token = await _storageService.getToken();

      if (token != null && token.isNotEmpty) {
        _logger.info('Logging out user');

        try {
          // سعی در logout از سرور (non-blocking)
          await _makeRequest(
            'POST',
            '/logout',
            headers: {'Authorization': 'Bearer $token'},
            timeout: Duration(seconds: 10), // کوتاه‌تر برای logout
          );
          _logger.info('Server logout successful');
        } catch (e) {
          _logger.warning(
            'Server logout failed (continuing with local logout): $e',
          );
          // ادامه با local logout حتی اگر server logout fail شد
        }
      }

      // همیشه local cleanup انجام بده
      await _storageService.deleteToken();
      _logger.info('Local logout completed');
    } catch (e, stack) {
      _logger.warning('Error during logout: $e', e, stack);
      // حتی در صورت خطا، local cleanup انجام بده
      await _storageService.deleteToken();
    }
  }

  // ✅ Fix 12: اضافه کردن refresh token method
  Future<UserModel?> refreshToken() async {
    try {
      final token = await _storageService.getToken();
      if (token == null || token.isEmpty) {
        return null;
      }

      _logger.info('Refreshing token');

      final response = await _makeRequest(
        'POST',
        '/refresh-token',
        headers: {'Authorization': 'Bearer $token'},
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        final user = _parseUserResponse(responseBody);

        if (user.token != null && user.token!.isNotEmpty) {
          await _storageService.saveToken(
            user.token!,
            expiresIn: AuthConstants.tokenValidityDuration,
          );
          _logger.info('Token refreshed successfully');
          return user;
        }
      }

      return null;
    } catch (e, stack) {
      _logger.warning('Error refreshing token: $e', e, stack);
      return null;
    }
  }

  // ✅ Fix 13: اضافه کردن helper methods
  Future<bool> isLoggedIn() async {
    final token = await _storageService.getToken();
    return token != null && token.isNotEmpty;
  }

  Future<int?> getCurrentUserId() async {
    return await _storageService.getUserId();
  }

  // ✅ Fix 14: dispose method
  void dispose() {
    _logger.info('Disposing AuthService');
    _httpClient.close();
  }

  // ✅ Debug methods
  Map<String, dynamic> getDebugInfo() {
    return {
      'baseUrl': AuthConstants.baseUrl,
      'requestTimeout': AuthConstants.requestTimeout.inSeconds,
      'tokenValidity': AuthConstants.tokenValidityDuration.inDays,
    };
  }
}
