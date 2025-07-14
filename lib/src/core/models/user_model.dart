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

  @HiveField(8)
  final bool? isContact;

  // اطلاعات چت
  @HiveField(9)
  final bool hasChat;

  @HiveField(10)
  final String? lastMessage;

  @HiveField(11)
  final DateTime? lastMessageTime;

  @HiveField(12)
  final int unreadCount;

  // اطلاعات مخاطب
  @HiveField(13)
  final bool isFavorite;

  @HiveField(14)
  final bool isBlocked;

  @HiveField(15)
  final String? displayName;

  @HiveField(16)
  final DateTime? contactCreatedAt;

  @HiveField(17)
  final DateTime? lastInteractionAt;

  const UserModel({
    required this.id,
    required this.username,
    this.firstName,
    this.lastName,
    this.phoneNumber,
    this.token,
    required this.isOnline,
    this.lastActive,
    this.isContact,
    this.hasChat = false,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isFavorite = false,
    this.isBlocked = false,
    this.displayName,
    this.contactCreatedAt,
    this.lastInteractionAt,
  });

  // Computed properties
  String get fullName {
    if (displayName != null && displayName!.isNotEmpty) {
      return displayName!;
    }
    final name = "${firstName ?? ''} ${lastName ?? ''}".trim();
    return name.isEmpty ? username : name;
  }

  String get initialName {
    return fullName.isEmpty ? username : fullName;
  }

  String get avatarInitials {
    final name = fullName;
    if (name.isEmpty) return "?";

    final words = name.split(' ').where((s) => s.isNotEmpty).toList();
    if (words.length > 1 && words[0].isNotEmpty && words[1].isNotEmpty) {
      return (words[0][0] + words[1][0]).toUpperCase();
    } else if (words.isNotEmpty && words[0].isNotEmpty) {
      return words[0][0].toUpperCase();
    }
    return "?";
  }

  String get lastSeenText {
    if (isOnline) return 'آنلاین';
    if (lastActive == null) return 'نامشخص';

    final now = DateTime.now();
    final difference = now.difference(lastActive!);

    if (difference.inMinutes < 1) {
      return 'همین الان';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes} دقیقه پیش';
    } else if (difference.inHours < 24) {
      return '${difference.inHours} ساعت پیش';
    } else if (difference.inDays < 7) {
      return '${difference.inDays} روز پیش';
    } else {
      return 'مدت زمان زیادی پیش';
    }
  }

  UserModel copyWith({
    int? id,
    String? username,
    String? firstName,
    String? lastName,
    String? phoneNumber,
    String? token,
    bool? isOnline,
    DateTime? lastActive,
    bool? isContact,
    bool? hasChat,
    String? lastMessage,
    DateTime? lastMessageTime,
    int? unreadCount,
    bool? isFavorite,
    bool? isBlocked,
    String? displayName,
    DateTime? contactCreatedAt,
    DateTime? lastInteractionAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      token: token ?? this.token,
      isOnline: isOnline ?? this.isOnline,
      lastActive: lastActive ?? this.lastActive,
      isContact: isContact ?? this.isContact,
      hasChat: hasChat ?? this.hasChat,
      lastMessage: lastMessage ?? this.lastMessage,
      lastMessageTime: lastMessageTime ?? this.lastMessageTime,
      unreadCount: unreadCount ?? this.unreadCount,
      isFavorite: isFavorite ?? this.isFavorite,
      isBlocked: isBlocked ?? this.isBlocked,
      displayName: displayName ?? this.displayName,
      contactCreatedAt: contactCreatedAt ?? this.contactCreatedAt,
      lastInteractionAt: lastInteractionAt ?? this.lastInteractionAt,
    );
  }

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as int,
      username: json['username'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      token: json['token'] as String?,
      isOnline: json['isOnline'] as bool,
      lastActive: json['lastActiveAt'] != null
          ? DateTime.parse(json['lastActiveAt'] as String).toLocal()
          : null,
      hasChat: json['hasChat'] as bool? ?? false,
      lastMessage: json['lastMessage'] as String?,
      lastMessageTime: json['lastMessageTime'] != null
          ? DateTime.parse(json['lastMessageTime'] as String).toLocal()
          : null,
      unreadCount: json['unreadCount'] as int? ?? 0,
      isFavorite: json['isFavorite'] as bool? ?? false,
      isBlocked: json['isBlocked'] as bool? ?? false,
      displayName: json['displayName'] as String?,
      contactCreatedAt: json['contactCreatedAt'] != null
          ? DateTime.parse(json['contactCreatedAt'] as String).toLocal()
          : null,
      lastInteractionAt: json['lastInteractionAt'] != null
          ? DateTime.parse(json['lastInteractionAt'] as String).toLocal()
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
      'lastActiveAt': lastActive?.toIso8601String(),
      'hasChat': hasChat,
      'lastMessage': lastMessage,
      'lastMessageTime': lastMessageTime?.toIso8601String(),
      'unreadCount': unreadCount,
      'isFavorite': isFavorite,
      'isBlocked': isBlocked,
      'displayName': displayName,
      'contactCreatedAt': contactCreatedAt?.toIso8601String(),
      'lastInteractionAt': lastInteractionAt?.toIso8601String(),
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
    isContact,
    hasChat,
    lastMessage,
    lastMessageTime,
    unreadCount,
    isFavorite,
    isBlocked,
    displayName,
    contactCreatedAt,
    lastInteractionAt,
  ];
}
