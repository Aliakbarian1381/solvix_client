import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:solvix/src/core/models/search_result_model.dart';
import 'package:solvix/src/core/services/storage_service.dart';

const String _searchBaseUrl = "https://api.solvix.ir/api/search";

class SearchService {
  final StorageService _storageService = StorageService();

  Future<List<SearchResultModel>> search(String query) async {
    final token = await _storageService.getToken();
    if (token == null) throw Exception('Token not found.');
    if (query.trim().isEmpty) return [];

    final url = Uri.parse(
      _searchBaseUrl,
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
        final List<dynamic> resultsData = responseBody['data'];
        return resultsData
            .map(
              (json) =>
                  SearchResultModel.fromJson(json as Map<String, dynamic>),
            )
            .toList();
      } else {
        throw Exception('Failed to load search results');
      }
    } catch (e) {
      throw Exception('Network error during search: ${e.toString()}');
    }
  }
}
