import 'package:equatable/equatable.dart';

enum GroupRole { member, admin, owner }

class GroupInfoModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? avatarUrl;
  final int membersCount;
  final List<GroupMemberModel> members;
  final GroupSettingsModel settings;
  final DateTime createdAt;
  final int? ownerId;
  final String? ownerName; // اضافه شد

  const GroupInfoModel({
    required this.id,
    required this.title,
    this.description,
    this.avatarUrl,
    required this.membersCount,
    required this.members,
    required this.settings,
    required this.createdAt,
    this.ownerId,
    this.ownerName, // اضافه شد
  });

  // اضافه کردن getter برای پیدا کردن owner از بین members
  GroupMemberModel? get owner {
    try {
      return members.firstWhere((member) => member.role == GroupRole.owner);
    } catch (e) {
      return null;
    }
  }

  // اضافه کردن getter برای نام مالک
  String get displayOwnerName {
    if (ownerName != null) return ownerName!;
    final ownerMember = owner;
    if (ownerMember != null) return ownerMember.displayName;
    return 'نامشخص';
  }

  factory GroupInfoModel.fromJson(Map<String, dynamic> json) {
    return GroupInfoModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      membersCount: json['membersCount'] as int,
      members:
          (json['members'] as List<dynamic>?)
              ?.map(
                (member) =>
                    GroupMemberModel.fromJson(member as Map<String, dynamic>),
              )
              .toList() ??
          [],
      settings: GroupSettingsModel.fromJson(
        json['settings'] as Map<String, dynamic>,
      ),
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      ownerId: json['ownerId'] as int?,
      ownerName: json['ownerName'] as String?, // اضافه شد
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'avatarUrl': avatarUrl,
      'membersCount': membersCount,
      'members': members.map((member) => member.toJson()).toList(),
      'settings': settings.toJson(),
      'createdAt': createdAt.toIso8601String(),
      'ownerId': ownerId,
      'ownerName': ownerName, // اضافه شد
    };
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    avatarUrl,
    membersCount,
    members,
    settings,
    createdAt,
    ownerId,
    ownerName, // اضافه شد
  ];
}

class GroupMemberModel extends Equatable {
  final int id;
  final int userId;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? profilePictureUrl;
  final GroupRole role;
  final DateTime joinedAt;
  final bool isOnline;
  final DateTime? lastActive;

  const GroupMemberModel({
    required this.id,
    required this.userId,
    required this.username,
    this.firstName,
    this.lastName,
    this.profilePictureUrl,
    required this.role,
    required this.joinedAt,
    required this.isOnline,
    this.lastActive,
  });

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName';
    }
    return username;
  }

  DateTime? get lastSeen => lastActive;

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      id: json['id'] as int,
      userId: json['userId'] as int? ?? json['id'] as int,
      username: json['username'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      role: GroupRole.values.firstWhere(
        (e) => e.toString().split('.').last == json['role'],
        orElse: () => GroupRole.member,
      ),
      joinedAt: DateTime.parse(json['joinedAt'] as String).toLocal(),
      isOnline: json['isOnline'] as bool? ?? false,
      lastActive: json['lastActive'] != null
          ? DateTime.parse(json['lastActive'] as String).toLocal()
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'username': username,
      'firstName': firstName,
      'lastName': lastName,
      'profilePictureUrl': profilePictureUrl,
      'role': role.toString().split('.').last,
      'joinedAt': joinedAt.toIso8601String(),
      'isOnline': isOnline,
      'lastActive': lastActive?.toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    userId,
    username,
    firstName,
    lastName,
    profilePictureUrl,
    role,
    joinedAt,
    isOnline,
    lastActive,
  ];
}

class GroupSettingsModel extends Equatable {
  final int maxMembers;
  final bool onlyAdminsCanSendMessages;
  final bool onlyAdminsCanAddMembers;
  final bool onlyAdminsCanEditInfo;
  final bool onlyAdminsCanDeleteMessages;
  final bool allowMemberToLeave;
  final bool isPublic;
  final String? joinLink;

  const GroupSettingsModel({
    required this.maxMembers,
    required this.onlyAdminsCanSendMessages,
    required this.onlyAdminsCanAddMembers,
    required this.onlyAdminsCanEditInfo,
    required this.onlyAdminsCanDeleteMessages,
    required this.allowMemberToLeave,
    required this.isPublic,
    this.joinLink,
  });

  bool get onlyAdminsCanEditGroupInfo => onlyAdminsCanEditInfo;

  factory GroupSettingsModel.fromJson(Map<String, dynamic> json) {
    return GroupSettingsModel(
      maxMembers: json['maxMembers'] as int? ?? 256,
      onlyAdminsCanSendMessages:
          json['onlyAdminsCanSendMessages'] as bool? ?? false,
      onlyAdminsCanAddMembers:
          json['onlyAdminsCanAddMembers'] as bool? ?? false,
      onlyAdminsCanEditInfo: json['onlyAdminsCanEditInfo'] as bool? ?? true,
      onlyAdminsCanDeleteMessages:
          json['onlyAdminsCanDeleteMessages'] as bool? ?? false,
      allowMemberToLeave: json['allowMemberToLeave'] as bool? ?? true,
      isPublic: json['isPublic'] as bool? ?? false,
      joinLink: json['joinLink'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'maxMembers': maxMembers,
      'onlyAdminsCanSendMessages': onlyAdminsCanSendMessages,
      'onlyAdminsCanAddMembers': onlyAdminsCanAddMembers,
      'onlyAdminsCanEditInfo': onlyAdminsCanEditInfo,
      'onlyAdminsCanDeleteMessages': onlyAdminsCanDeleteMessages,
      'allowMemberToLeave': allowMemberToLeave,
      'isPublic': isPublic,
      'joinLink': joinLink,
    };
  }

  // اضافه کردن copyWith method
  GroupSettingsModel copyWith({
    int? maxMembers,
    bool? onlyAdminsCanSendMessages,
    bool? onlyAdminsCanAddMembers,
    bool? onlyAdminsCanEditInfo,
    bool? onlyAdminsCanDeleteMessages,
    bool? allowMemberToLeave,
    bool? isPublic,
    String? joinLink,
  }) {
    return GroupSettingsModel(
      maxMembers: maxMembers ?? this.maxMembers,
      onlyAdminsCanSendMessages:
          onlyAdminsCanSendMessages ?? this.onlyAdminsCanSendMessages,
      onlyAdminsCanAddMembers:
          onlyAdminsCanAddMembers ?? this.onlyAdminsCanAddMembers,
      onlyAdminsCanEditInfo:
          onlyAdminsCanEditInfo ?? this.onlyAdminsCanEditInfo,
      onlyAdminsCanDeleteMessages:
          onlyAdminsCanDeleteMessages ?? this.onlyAdminsCanDeleteMessages,
      allowMemberToLeave: allowMemberToLeave ?? this.allowMemberToLeave,
      isPublic: isPublic ?? this.isPublic,
      joinLink: joinLink ?? this.joinLink,
    );
  }

  @override
  List<Object?> get props => [
    maxMembers,
    onlyAdminsCanSendMessages,
    onlyAdminsCanAddMembers,
    onlyAdminsCanEditInfo,
    onlyAdminsCanDeleteMessages,
    allowMemberToLeave,
    isPublic,
    joinLink,
  ];
}
