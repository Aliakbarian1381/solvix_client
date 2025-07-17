import 'package:equatable/equatable.dart';

enum GroupRole { member, admin, owner }

class GroupInfoModel extends Equatable {
  final String id;
  final String title;
  final String? description;
  final String? groupImageUrl;
  final int ownerId;
  final String ownerName;
  final DateTime createdAt;
  final int membersCount;
  final GroupSettingsModel settings;
  final List<GroupMemberModel> members;

  const GroupInfoModel({
    required this.id,
    required this.title,
    this.description,
    this.groupImageUrl,
    required this.ownerId,
    required this.ownerName,
    required this.createdAt,
    required this.membersCount,
    required this.settings,
    required this.members,
  });

  factory GroupInfoModel.fromJson(Map<String, dynamic> json) {
    return GroupInfoModel(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String?,
      groupImageUrl: json['groupImageUrl'] as String?,
      ownerId: json['ownerId'] as int,
      ownerName: json['ownerName'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      membersCount: json['membersCount'] as int,
      settings: GroupSettingsModel.fromJson(
        json['settings'] as Map<String, dynamic>,
      ),
      members: (json['members'] as List<dynamic>)
          .map(
            (member) =>
                GroupMemberModel.fromJson(member as Map<String, dynamic>),
          )
          .toList(),
    );
  }

  @override
  List<Object?> get props => [
    id,
    title,
    description,
    groupImageUrl,
    ownerId,
    ownerName,
    createdAt,
    membersCount,
    settings,
    members,
  ];

  GroupInfoModel copyWith({
    String? title,
    String? description,
    String? groupImageUrl,
    GroupSettingsModel? settings,
    List<GroupMemberModel>? members,
  }) {
    return GroupInfoModel(
      id: id,
      title: title ?? this.title,
      description: description ?? this.description,
      groupImageUrl: groupImageUrl ?? this.groupImageUrl,
      ownerId: ownerId,
      ownerName: ownerName,
      createdAt: createdAt,
      membersCount: members?.length ?? membersCount,
      settings: settings ?? this.settings,
      members: members ?? this.members,
    );
  }
}

class GroupMemberModel extends Equatable {
  final int userId;
  final String username;
  final String? firstName;
  final String? lastName;
  final String? profilePictureUrl;
  final GroupRole role;
  final DateTime joinedAt;
  final bool isOnline;
  final DateTime? lastSeen;

  const GroupMemberModel({
    required this.userId,
    required this.username,
    this.firstName,
    this.lastName,
    this.profilePictureUrl,
    required this.role,
    required this.joinedAt,
    required this.isOnline,
    this.lastSeen,
  });

  factory GroupMemberModel.fromJson(Map<String, dynamic> json) {
    return GroupMemberModel(
      userId: json['userId'] as int,
      username: json['username'] as String,
      firstName: json['firstName'] as String?,
      lastName: json['lastName'] as String?,
      profilePictureUrl: json['profilePictureUrl'] as String?,
      role: GroupRole.values[json['role'] as int],
      joinedAt: DateTime.parse(json['joinedAt'] as String),
      isOnline: json['isOnline'] as bool,
      lastSeen: json['lastSeen'] != null
          ? DateTime.parse(json['lastSeen'] as String)
          : null,
    );
  }

  String get displayName {
    if (firstName != null && lastName != null) {
      return '$firstName $lastName'.trim();
    }
    return username;
  }

  String get roleTitle {
    switch (role) {
      case GroupRole.owner:
        return 'مالک گروه';
      case GroupRole.admin:
        return 'ادمین';
      case GroupRole.member:
        return 'عضو';
    }
  }

  @override
  List<Object?> get props => [
    userId,
    username,
    firstName,
    lastName,
    profilePictureUrl,
    role,
    joinedAt,
    isOnline,
    lastSeen,
  ];
}

class GroupSettingsModel extends Equatable {
  final bool onlyAdminsCanSendMessages;
  final bool onlyAdminsCanAddMembers;
  final bool onlyAdminsCanEditGroupInfo;
  final int maxMembers;

  const GroupSettingsModel({
    required this.onlyAdminsCanSendMessages,
    required this.onlyAdminsCanAddMembers,
    required this.onlyAdminsCanEditGroupInfo,
    required this.maxMembers,
  });

  factory GroupSettingsModel.fromJson(Map<String, dynamic> json) {
    return GroupSettingsModel(
      onlyAdminsCanSendMessages: json['onlyAdminsCanSendMessages'] as bool,
      onlyAdminsCanAddMembers: json['onlyAdminsCanAddMembers'] as bool,
      onlyAdminsCanEditGroupInfo: json['onlyAdminsCanEditGroupInfo'] as bool,
      maxMembers: json['maxMembers'] as int,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'onlyAdminsCanSendMessages': onlyAdminsCanSendMessages,
      'onlyAdminsCanAddMembers': onlyAdminsCanAddMembers,
      'onlyAdminsCanEditGroupInfo': onlyAdminsCanEditGroupInfo,
      'maxMembers': maxMembers,
    };
  }

  @override
  List<Object> get props => [
    onlyAdminsCanSendMessages,
    onlyAdminsCanAddMembers,
    onlyAdminsCanEditGroupInfo,
    maxMembers,
  ];

  GroupSettingsModel copyWith({
    bool? onlyAdminsCanSendMessages,
    bool? onlyAdminsCanAddMembers,
    bool? onlyAdminsCanEditGroupInfo,
    int? maxMembers,
  }) {
    return GroupSettingsModel(
      onlyAdminsCanSendMessages:
          onlyAdminsCanSendMessages ?? this.onlyAdminsCanSendMessages,
      onlyAdminsCanAddMembers:
          onlyAdminsCanAddMembers ?? this.onlyAdminsCanAddMembers,
      onlyAdminsCanEditGroupInfo:
          onlyAdminsCanEditGroupInfo ?? this.onlyAdminsCanEditGroupInfo,
      maxMembers: maxMembers ?? this.maxMembers,
    );
  }
}
