import 'package:solvix/src/core/models/chat_model.dart';
import 'package:solvix/src/core/models/user_model.dart';

class SearchResultModel {
  final String id;
  final String title;
  final String? subtitle;
  final String type; // "chat" or "user"
  final dynamic entity; // ChatModel or UserModel

  SearchResultModel({
    required this.id,
    required this.title,
    this.subtitle,
    required this.type,
    required this.entity,
  });

  factory SearchResultModel.fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    dynamic entity;
    if (type == 'chat') {
      entity = ChatModel.fromJson(json['entity']);
    } else {
      entity = UserModel.fromJson(json['entity']);
    }

    return SearchResultModel(
      id: json['id'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      type: type,
      entity: entity,
    );
  }
}
