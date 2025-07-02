import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:solvix/src/core/models/chat_model.dart';
import 'package:solvix/src/core/models/message_model.dart';
import 'package:solvix/src/core/services/storage_service.dart';

const String _chatBaseUrl = "https://api.solvix.ir/api/chat";

class ChatService {
  final StorageService _storageService = StorageService();

  Future<List<ChatModel>> getUserChats() async {
    final token = await _storageService.getToken();
    if (token == null) {
      throw Exception('توکن احراز هویت یافت نشد.');
    }
    final url = Uri.parse(_chatBaseUrl);
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
        final List<dynamic> chatListData = responseBody['data'];
        return chatListData
            .map(
              (chatJson) =>
                  ChatModel.fromJson(chatJson as Map<String, dynamic>),
            )
            .toList();
      } else {
        String errorMessage = 'خطا در دریافت لیست چت‌ها';
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['message'] ?? errorMessage;
        } catch (_) {}
        throw Exception('$errorMessage (کد: ${response.statusCode})');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains("خطا")) rethrow;
      throw Exception('خطای شبکه هنگام دریافت چت‌ها: ${e.toString()}');
    }
  }

  Future<List<MessageModel>> getChatMessages(
    String chatId, {
    int skip = 0,
    int take = 50,
  }) async {
    final token = await _storageService.getToken();
    if (token == null) {
      throw Exception('توکن احراز هویت یافت نشد.');
    }

    final url = Uri.parse(
      '$_chatBaseUrl/$chatId/messages?skip=$skip&take=$take',
    );
    try {
      final response = await http.get(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
      );

      final Map<String, dynamic> responseBody = jsonDecode(response.body);

      if (response.statusCode == 200) {
        final List<dynamic> messagesData = responseBody['data'];
        return messagesData
            .map(
              (messageJson) =>
                  MessageModel.fromJson(messageJson as Map<String, dynamic>),
            )
            .toList();
      } else {
        String errorMessage =
            responseBody['message'] ?? 'خطا در دریافت پیام‌های چت';
        if (response.statusCode == 403) {
          // Forbidden
          errorMessage =
              responseBody['message'] ?? "شما دسترسی به این چت ندارید.";
        }
        throw Exception('$errorMessage (کد: ${response.statusCode})');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains("خطا")) rethrow;
      throw Exception('خطای شبکه هنگام دریافت پیام‌ها: ${e.toString()}');
    }
  }

  Future<MessageModel> editMessage(int messageId, String newContent) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن یافت نشد.');

    final url = Uri.parse('$_chatBaseUrl/messages/$messageId');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(
        newContent,
      ), // محتوای جدید مستقیماً به عنوان string ارسال می‌شود
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      return MessageModel.fromJson(responseBody['data']);
    } else {
      throw Exception('خطا در ویرایش پیام');
    }
  }

  Future<void> deleteMessage(int messageId) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن یافت نشد.');

    final url = Uri.parse('$_chatBaseUrl/messages/$messageId');
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode != 200) {
      throw Exception('خطا در حذف پیام');
    }
  }

  Future<ChatModel> createGroupChat(String title, List<int> participantIds) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن یافت نشد.');

    final url = Uri.parse('$_chatBaseUrl/create-group');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        'title': title,
        'participantIds': participantIds,
      }),
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      return ChatModel.fromJson(responseBody['data']);
    } else {
      String errorMessage = 'خطا در ساخت گروه';
      try {
        final errorBody = jsonDecode(response.body);
        errorMessage = errorBody['message'] ?? errorMessage;
      } catch (_) {}
      throw Exception('$errorMessage (کد: ${response.statusCode})');
    }
  }

  // متد جدید برای شروع چت با یک کاربر
  // POST /api/chat/start با body recipientUserId
  Future<Map<String, dynamic>> startChatWithUser(int recipientUserId) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن احراز هویت یافت نشد.');

    final url = Uri.parse('$_chatBaseUrl/start');
    try {
      final response = await http.post(
        url,
        headers: {
          'Content-Type': 'application/json; charset=UTF-8',
          'Authorization': 'Bearer $token',
        },
        // سرور شما recipientUserId را مستقیماً در body می‌خواهد، نه به عنوان بخشی از یک آبجکت JSON
        // و recipientUserId از نوع long است.
        body: jsonEncode(recipientUserId),
      );

      if (response.statusCode == 200) {
        final responseBody = jsonDecode(response.body);
        // سرور یک آبجکت با فیلد data برمی‌گرداند که شامل chatId و alreadyExists است
        return responseBody['data'] as Map<String, dynamic>;
      } else {
        String errorMessage = 'خطا در شروع چت';
        try {
          final errorBody = jsonDecode(response.body);
          errorMessage = errorBody['message'] ?? errorMessage;
        } catch (_) {}
        if (response.statusCode == 400 &&
            errorMessage.contains("امکان شروع چت با خودتان وجود ندارد")) {
          // خطای خاص
        } else if (response.statusCode == 404 &&
            errorMessage.contains("کاربر مورد نظر یافت نشد")) {
          // خطای خاص
        }
        throw Exception('$errorMessage (کد: ${response.statusCode})');
      }
    } catch (e) {
      if (e is Exception && e.toString().contains("خطا")) rethrow;
      throw Exception('خطای شبکه هنگام شروع چت: ${e.toString()}');
    }
  }
}
