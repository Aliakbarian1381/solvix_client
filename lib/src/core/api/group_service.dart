import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:solvix/src/core/models/group_info_model.dart';
import 'package:solvix/src/core/services/storage_service.dart';

class GroupService {
  final String _baseUrl = 'https://api.solvix.ir';
  final StorageService _storageService;

  GroupService(this._storageService);

  Future<GroupInfoModel?> getGroupInfo(String chatId) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن یافت نشد.');

    final url = Uri.parse('$_baseUrl/api/group/$chatId/info');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      return GroupInfoModel.fromJson(responseBody['data']);
    } else if (response.statusCode == 404) {
      return null;
    } else {
      throw Exception('خطا در دریافت اطلاعات گروه');
    }
  }

  Future<bool> updateGroupInfo(
    String chatId,
    String? title,
    String? description,
  ) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن یافت نشد.');

    final url = Uri.parse('$_baseUrl/api/group/$chatId/info');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({
        if (title != null) 'title': title,
        if (description != null) 'description': description,
      }),
    );

    return response.statusCode == 200;
  }

  Future<bool> updateGroupSettings(
    String chatId,
    GroupSettingsModel settings,
  ) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن یافت نشد.');

    final url = Uri.parse('$_baseUrl/api/group/$chatId/settings');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode(settings.toJson()),
    );

    return response.statusCode == 200;
  }

  Future<List<GroupMemberModel>> getGroupMembers(String chatId) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن یافت نشد.');

    final url = Uri.parse('$_baseUrl/api/group/$chatId/members');
    final response = await http.get(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    if (response.statusCode == 200) {
      final responseBody = jsonDecode(response.body);
      return (responseBody['data'] as List<dynamic>)
          .map(
            (member) =>
                GroupMemberModel.fromJson(member as Map<String, dynamic>),
          )
          .toList();
    } else {
      throw Exception('خطا در دریافت لیست اعضا');
    }
  }

  Future<bool> addMembers(String chatId, List<int> userIds) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن یافت نشد.');

    final url = Uri.parse('$_baseUrl/api/group/$chatId/members');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'userIds': userIds}),
    );

    return response.statusCode == 200;
  }

  Future<bool> removeMember(String chatId, int memberId) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن یافت نشد.');

    final url = Uri.parse('$_baseUrl/api/group/$chatId/members/$memberId');
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    return response.statusCode == 200;
  }

  Future<bool> updateMemberRole(
    String chatId,
    int memberId,
    GroupRole newRole,
  ) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن یافت نشد.');

    final url = Uri.parse('$_baseUrl/api/group/$chatId/members/$memberId/role');
    final response = await http.put(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'newRole': newRole.index}),
    );

    return response.statusCode == 200;
  }

  Future<bool> leaveGroup(String chatId) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن یافت نشد.');

    final url = Uri.parse('$_baseUrl/api/group/$chatId/leave');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    return response.statusCode == 200;
  }

  Future<bool> deleteGroup(String chatId) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن یافت نشد.');

    final url = Uri.parse('$_baseUrl/api/group/$chatId');
    final response = await http.delete(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
    );

    return response.statusCode == 200;
  }

  Future<bool> transferOwnership(String chatId, int newOwnerId) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('توکن یافت نشد.');

    final url = Uri.parse('$_baseUrl/api/group/$chatId/transfer-ownership');
    final response = await http.post(
      url,
      headers: {
        'Content-Type': 'application/json; charset=UTF-8',
        'Authorization': 'Bearer $token',
      },
      body: jsonEncode({'newOwnerId': newOwnerId}),
    );

    return response.statusCode == 200;
  }
}
