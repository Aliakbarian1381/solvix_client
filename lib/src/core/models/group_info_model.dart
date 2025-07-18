import 'package:equatable/equatable.dart';

enum GroupRole { owner, admin, member }

class GroupInfoModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? avatarUrl;
  final String ownerName;
  final int ownerId;
  final DateTime createdAt;
  final int membersCount;
  final List<GroupMemberModel> members;
  final GroupSettingsModel settings;

  const GroupInfoModel({
    required this.id,
    required this.title,
    this.description,
    this.avatarUrl,
    required this.ownerName,
    required this.ownerId,
    required this.createdAt,
    required this.membersCount,
    required this.members,
    required this.settings,
  });

  factory GroupInfoModel.fromJson(Map<String, dynamic> json) {
    return GroupInfoModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      avatarUrl: json['avatarUrl'] as String?,
      ownerName: json['ownerName'] as String,
      ownerId: json['ownerId'] as int,
      createdAt: DateTime.parse(json['createdAt'] as String).toLocal(),
      membersCount: json['membersCount'] as int,
      members:
          (json['members'] as List<dynamic>?)
              ?.map(
                (memberJson) => GroupMemberModel.fromJson(
                  memberJson as Map<String, dynamic>,
                ),
              )
              .toList() ??
          [],
      settings: GroupSettingsModel.fromJson(
        json['settings'] as Map<String, dynamic>,
      ),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'avatarUrl': avatarUrl,
      'ownerName': ownerName,
      'ownerId': ownerId,
      'createdAt': createdAt.toIso8601String(),
      'membersCount': membersCount,
      'members': members.map((member) => member.toJson()).toList(),
      'settings': settings.toJson(),
    };
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    avatarUrl,
    ownerName,
    ownerId,
    createdAt,
    membersCount,
    members,
    settings,
  ];
}

class GroupMemberModel extends Equatable {
  final int id;
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

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      id: json['id'] as int,
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

  factory GroupSettingsModel.fromJson(Map<String, dynamic> json) {
    return GroupSettingsModel(
      maxMembers: json['maxMembers'] as int? ?? 256,
      onlyAdminsCanSendMessages:
          json['onlyAdminsCanSendMessages'] as bool? ?? false,
      onlyAdminsCanAddMembers:
          json['onlyAdminsCanAddMembers'] as bool? ?? false,
      onlyAdminsCanEditInfo: json['onlyAdminsCanEditInfo'] as bool? ?? true,
      onlyAdminsCanDeleteMessages:
          json['onlyAdminsCanDeleteMessages'] as bool? ?? true,
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
