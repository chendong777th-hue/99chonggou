import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_role_crown_icon.dart';
import 'package:tencent_cloud_chat_demo/utils/group_create_limit_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/group_type.dart';
import 'package:tencent_cloud_chat_uikit/theme/tui_theme.dart';

bool groupProfileShowsTypeCategory(String? groupType) {
  final normalized = groupType?.trim();
  return normalized == GroupType.Community ||
      normalized == GroupType.Public ||
      normalized == GroupType.Work ||
      normalized == GroupType.Meeting;
}

bool groupProfileIsSuperLargeGroup(String? groupType) {
  return groupType?.trim() == GroupType.Community;
}

String groupProfileTypeLabel(String? groupType) {
  final normalized = groupType?.trim();
  if (normalized == null || normalized.isEmpty) {
    return '';
  }
  return GroupCreateLimitMessage.typeDisplayName(normalized);
}

void showGroupProfileCapacityInfo(BuildContext context, String groupType) {
  final normalized = groupType.trim();
  if (normalized.isEmpty) {
    return;
  }
  final i18n = AppI18n.of(context);
  final memberHint = GroupCreateLimitMessage.memberCapacityHint(normalized);
  final description = GroupCreateLimitMessage.selectedTypeDescription(
    groupType: normalized,
    limitsEnabled: false,
    info: null,
    joinInfo: null,
  );
  AppDialog.alert(
    title: i18n.t(
      zhHans: '支持更多成员',
      zhHant: '支援更多成員',
      en: 'More Members',
      ja: 'より多くのメンバー',
      ko: '더 많은 멤버',
    ),
    message: '$memberHint\n$description',
    buttonText: i18n.t(
      zhHans: '知道了',
      zhHant: '知道了',
      en: 'OK',
      ja: 'OK',
      ko: '확인',
    ),
  );
}

/// 群名右侧：仅超级大群显示蓝色徽章。
class GroupProfileTypeNameBadge extends StatelessWidget {
  final String? groupType;
  final TUITheme theme;

  const GroupProfileTypeNameBadge({
    super.key,
    required this.groupType,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (!groupProfileIsSuperLargeGroup(groupType)) {
      return const SizedBox.shrink();
    }
    final primary = theme.primaryColor ?? const Color(0xFF1E90FF);
    return _SuperGroupBadge(
      label: groupProfileTypeLabel(groupType),
      primaryColor: primary,
    );
  }
}

/// 群 ID 右侧：普通群徽章，或超级大群的「支持更多成员」。
class GroupProfileTypeIdBadge extends StatelessWidget {
  final String? groupType;
  final TUITheme theme;

  const GroupProfileTypeIdBadge({
    super.key,
    required this.groupType,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    if (!groupProfileShowsTypeCategory(groupType)) {
      return const SizedBox.shrink();
    }
    if (groupProfileIsSuperLargeGroup(groupType)) {
      return _MoreMembersBadge(
        theme: theme,
        onTap: () => showGroupProfileCapacityInfo(context, groupType!.trim()),
      );
    }
    return _StandardGroupBadge(label: groupProfileTypeLabel(groupType));
  }
}

class _SuperGroupBadge extends StatelessWidget {
  final String label;
  final Color primaryColor;

  const _SuperGroupBadge({
    required this.label,
    required this.primaryColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: primaryColor,
        borderRadius: BorderRadius.circular(999),
      ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            GroupRoleCrownIcon(color: Colors.white, size: 13),
            const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _StandardGroupBadge extends StatelessWidget {
  static const Color _orange = Color(0xFFFF9500);

  final String label;

  const _StandardGroupBadge({
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _orange,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.groups_rounded,
            size: 13,
            color: Colors.white,
          ),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              fontSize: 11,
              height: 1.2,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _MoreMembersBadge extends StatelessWidget {
  final TUITheme theme;
  final VoidCallback onTap;

  const _MoreMembersBadge({
    required this.theme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = theme.weakDividerColor ?? const Color(0xFFE5E5E5);
    final textColor = theme.darkTextColor ?? Colors.black87;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: theme.conversationItemBgColor ??
                theme.wideBackgroundColor ??
                Colors.white,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: borderColor),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                AppI18n.of(context).t(
                  zhHans: '支持更多成员',
                  zhHant: '支援更多成員',
                  en: 'More members',
                  ja: 'より多くのメンバー',
                  ko: '더 많은 멤버',
                ),
                style: TextStyle(
                  fontSize: 11,
                  height: 1.2,
                  color: textColor,
                ),
              ),
              const SizedBox(width: 2),
              Icon(
                Icons.info_outline_rounded,
                size: 12,
                color: theme.weakTextColor ?? const Color(0xFF999999),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
