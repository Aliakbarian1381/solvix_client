import 'package:solvix/src/core/models/group_info_model.dart';

class GroupPermissionManager {
  static bool canUserSendMessage(
    GroupMemberModel member,
    GroupSettingsModel settings,
  ) {
    if (settings.onlyAdminsCanSendMessages) {
      return member.role == GroupRole.admin || member.role == GroupRole.owner;
    }
    return true;
  }

  static bool canUserAddMembers(
    GroupMemberModel member,
    GroupSettingsModel settings,
  ) {
    if (settings.onlyAdminsCanAddMembers) {
      return member.role == GroupRole.admin || member.role == GroupRole.owner;
    }
    return true;
  }

  static bool canUserEditGroupInfo(
    GroupMemberModel member,
    GroupSettingsModel settings,
  ) {
    if (settings.onlyAdminsCanEditInfo) {
      return member.role == GroupRole.admin || member.role == GroupRole.owner;
    }
    return true;
  }

  static bool canUserDeleteMessages(
    GroupMemberModel member,
    GroupSettingsModel settings,
  ) {
    if (settings.onlyAdminsCanDeleteMessages) {
      return member.role == GroupRole.admin || member.role == GroupRole.owner;
    }
    return true;
  }

  static bool canUserRemoveMember(
    GroupMemberModel currentUser,
    GroupMemberModel targetMember,
  ) {
    // Owner can remove anyone except other owners
    if (currentUser.role == GroupRole.owner) {
      return targetMember.role != GroupRole.owner;
    }

    // Admin can remove members only
    if (currentUser.role == GroupRole.admin) {
      return targetMember.role == GroupRole.member;
    }

    // Members can't remove anyone
    return false;
  }

  static bool canUserPromoteMember(
    GroupMemberModel currentUser,
    GroupMemberModel targetMember,
    GroupRole newRole,
  ) {
    // Only owner can promote to admin or transfer ownership
    if (currentUser.role == GroupRole.owner) {
      return true;
    }

    // Admin can only promote members to admin (not to owner)
    if (currentUser.role == GroupRole.admin) {
      return targetMember.role == GroupRole.member &&
          newRole == GroupRole.admin;
    }

    return false;
  }

  static bool canUserLeaveGroup(
    GroupMemberModel member,
    GroupSettingsModel settings,
  ) {
    // Owner can always leave (but should transfer ownership first)
    if (member.role == GroupRole.owner) {
      return true;
    }

    return settings.allowMemberToLeave;
  }

  static bool canUserDeleteGroup(GroupMemberModel member) {
    // Only owner can delete group
    return member.role == GroupRole.owner;
  }

  static String getRoleDisplayName(GroupRole role) {
    switch (role) {
      case GroupRole.owner:
        return 'مالک';
      case GroupRole.admin:
        return 'مدیر';
      case GroupRole.member:
        return 'عضو';
    }
  }

  static List<GroupRole> getPromotableRoles(
    GroupMemberModel currentUser,
    GroupMemberModel targetMember,
  ) {
    final List<GroupRole> roles = [];

    if (currentUser.role == GroupRole.owner) {
      // Owner can promote to any role
      if (targetMember.role == GroupRole.member) {
        roles.addAll([GroupRole.admin, GroupRole.owner]);
      } else if (targetMember.role == GroupRole.admin) {
        roles.add(GroupRole.owner);
      }
    } else if (currentUser.role == GroupRole.admin) {
      // Admin can only promote members to admin
      if (targetMember.role == GroupRole.member) {
        roles.add(GroupRole.admin);
      }
    }

    return roles;
  }
}
