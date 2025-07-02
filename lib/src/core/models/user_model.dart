import 'package:equatable/equatable.dart';
import 'package:hive/hive.dart';

part 'user_model.g.dart';

@HiveType(typeId: 2)
class UserModel extends Equatable {
  @HiveField(0)
  final int id;

  @HiveField(1)
  final String username;

  @HiveField(2)
  final String? firstName;

  @HiveField(3)
  final String? lastName;

  @HiveField(4)
  final String? phoneNumber;

  @HiveField(5)
  final String? token;

  @HiveField(6)
  final bool isOnline;

  @HiveField(7)
  final DateTime? lastActive;

  const UserModel({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.token,
    required this.isOnline,
    this.lastActive,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      token: json['token'] as String?,
      isOnline: json['isOnline'] as bool,
      lastActive: json['lastActive'] != null
          ? DateTime.parse(json['lastActive'] as String).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'phoneNumber': phoneNumber,
      'token': token,
      'isOnline': isOnline,
      'lastActive': lastActive?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    username,
    firstName,
    lastName,
    phoneNumber,
    token,
    isOnline,
    lastActive,
  ];
}
