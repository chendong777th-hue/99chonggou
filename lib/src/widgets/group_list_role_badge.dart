import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_role_crown_icon.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_role_member_icon.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/group_role_policy.dart';

enum GroupListSelfRoleKind {
  owner,
  admin,
  member,
}

GroupListSelfRoleKind groupListSelfRoleKind(int? role) {
  switch (GroupRolePolicy.roleBadgeKey(role)) {
    case 'owner':
      return GroupListSelfRoleKind.owner;
    case 'admin':
      return GroupListSelfRoleKind.admin;
    default:
      return GroupListSelfRoleKind.member;
  }
}

/// 「我的群聊」列表右侧：群主 / 管理员 / 普通成员。
class GroupListSelfRoleBadge extends StatelessWidget {
  final int? role;

  const GroupListSelfRoleBadge({
    super.key,
    required this.role,
  });

  @override
  Widget build(BuildContext context) {
    final kind = groupListSelfRoleKind(role);
    final i18n = AppI18n.of(context);
    late final Color color;
    late final Widget leadingIcon;
    late final String label;
    switch (kind) {
      case GroupListSelfRoleKind.owner:
        color = const Color(0xFFFF9500);
        leadingIcon = GroupRoleCrownIcon(color: color, size: 13);
        label = i18n.t(
          zhHans: '群主',
          zhHant: '群主',
          en: 'Owner',
          ja: 'オーナー',
          ko: '그룹장',
        );
        break;
      case GroupListSelfRoleKind.admin:
        color = const Color(0xFF1E90FF);
        leadingIcon = Icon(Icons.shield_rounded, size: 13, color: color);
        label = i18n.t(
          zhHans: '管理员',
          zhHant: '管理員',
          en: 'Admin',
          ja: '管理者',
          ko: '관리자',
        );
        break;
      case GroupListSelfRoleKind.member:
        color = const Color(0xFF8E8E93);
        leadingIcon = GroupRoleMemberIcon(color: color, size: 13);
        label = i18n.t(
          zhHans: '普通成员',
          zhHant: '普通成員',
          en: 'Member',
          ja: 'メンバー',
          ko: '일반 멤버',
        );
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.45)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          leadingIcon,
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
