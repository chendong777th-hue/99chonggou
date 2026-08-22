import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/models/me_group_record.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_add_source.dart';
import 'package:tencent_cloud_chat_demo/utils/group_member_join_meta.dart';
import 'package:tencent_cloud_chat_demo/utils/profile_page_nav.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitProfile/widget/tim_uikit_profile_widget.dart';

/// 资料页：入群时间 / 入群方式（邀请人可点）。
class GroupMemberJoinMetaSection extends StatelessWidget {
  const GroupMemberJoinMetaSection({
    super.key,
    required this.groupId,
    required this.record,
    this.compact = false,
    this.titleColor,
    this.valueColor,
    this.linkColor,
    this.backgroundColor,
    this.dividerColor,
    this.showTopDivider = false,
  });

  final String groupId;
  final GroupMemberRecord record;
  final bool compact;
  final Color? titleColor;
  final Color? valueColor;
  final Color? linkColor;
  final Color? backgroundColor;
  final Color? dividerColor;
  final bool showTopDivider;

  @override
  Widget build(BuildContext context) {
    if (!GroupMemberJoinMeta.hasAnyDisplayRow(record)) {
      return const SizedBox.shrink();
    }
    final i18n = AppI18n.of(context);
    final joined = GroupMemberJoinMeta.formatJoinedAt(
      record.joinedAt,
      i18n: i18n,
    );
    final source = GroupMemberJoinMeta.formatJoinSource(record, i18n: i18n);
    final tColor = titleColor ?? Colors.black87;
    final vColor = valueColor ?? Colors.black54;
    final lColor = linkColor ?? (Theme.of(context).primaryColor);
    final bg = backgroundColor ?? Colors.white;
    final div = dividerColor ?? AppColors.lightLine.withValues(alpha: 0.65);

    final children = <Widget>[];
    if (showTopDivider) {
      children.add(Container(height: 0.5, color: div));
    }
    if (joined != null) {
      children.add(
        _row(
          title: i18n.t(
            zhHans: '入群时间',
            zhHant: '入群時間',
            en: 'Joined at',
            ja: '参加日時',
            ko: '가입 시간',
          ),
          value: joined,
          titleColor: tColor,
          valueColor: vColor,
          backgroundColor: bg,
          compact: compact,
        ),
      );
    }
    if (source != null) {
      if (children.isNotEmpty || showTopDivider) {
        children.add(Container(height: 0.5, color: div));
      }
      final tappable = GroupMemberJoinMeta.inviterTappable(record);
      children.add(
        _row(
          title: i18n.t(
            zhHans: '入群方式',
            zhHant: '入群方式',
            en: 'Join method',
            ja: '参加方法',
            ko: '가입 방식',
          ),
          value: source,
          titleColor: tColor,
          valueColor: tappable ? lColor : vColor,
          backgroundColor: bg,
          compact: compact,
          onTap: tappable
              ? () {
                  ProfilePageNav.openUserProfileOrAddFriend(
                    context,
                    userID: record.invitedByUserId,
                    nickname: record.invitedByNickname,
                    addSource: FriendAddSource.card,
                    groupId: groupId,
                  );
                }
              : null,
        ),
      );
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }

  Widget _row({
    required String title,
    required String value,
    required Color titleColor,
    required Color valueColor,
    required Color backgroundColor,
    required bool compact,
    VoidCallback? onTap,
  }) {
    final content = Container(
      color: backgroundColor,
      constraints: BoxConstraints(minHeight: compact ? 48 : 52),
      padding: EdgeInsets.symmetric(
        horizontal: 16,
        vertical: compact ? 12 : 14,
      ),
      child: Row(
        children: [
          Text(title, style: TextStyle(fontSize: 16, color: titleColor)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 16,
                color: valueColor,
                decoration: onTap != null ? TextDecoration.underline : null,
                decorationColor: valueColor,
              ),
            ),
          ),
          if (onTap != null) ...[
            const SizedBox(width: 4),
            Icon(Icons.chevron_right, size: 18, color: valueColor),
          ],
        ],
      ),
    );
    if (onTap == null) {
      return content;
    }
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// UIKit operationItem 风格包装（好友资料列表）。
class GroupMemberJoinMetaOperationBlock extends StatelessWidget {
  const GroupMemberJoinMetaOperationBlock({
    super.key,
    required this.groupId,
    required this.record,
    this.smallCardMode = false,
  });

  final String groupId;
  final GroupMemberRecord record;
  final bool smallCardMode;

  @override
  Widget build(BuildContext context) {
    if (!GroupMemberJoinMeta.hasAnyDisplayRow(record)) {
      return const SizedBox.shrink();
    }
    final i18n = AppI18n.of(context);
    final joined = GroupMemberJoinMeta.formatJoinedAt(
      record.joinedAt,
      i18n: i18n,
    );
    final source = GroupMemberJoinMeta.formatJoinSource(record, i18n: i18n);
    final tappable = GroupMemberJoinMeta.inviterTappable(record);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (joined != null)
          TIMUIKitProfileWidget.operationItem(
            operationName: i18n.t(
              zhHans: '入群时间',
              zhHant: '入群時間',
              en: 'Joined at',
              ja: '参加日時',
              ko: '가입 시간',
            ),
            operationText: joined,
            type: 'text',
            isEmpty: false,
            smallCardMode: smallCardMode,
          ),
        if (source != null)
          InkWell(
            onTap: tappable
                ? () {
                    ProfilePageNav.openUserProfileOrAddFriend(
                      context,
                      userID: record.invitedByUserId,
                      nickname: record.invitedByNickname,
                      addSource: FriendAddSource.card,
                      groupId: groupId,
                    );
                  }
                : null,
            child: TIMUIKitProfileWidget.operationItem(
              operationName: i18n.t(
                zhHans: '入群方式',
                zhHant: '入群方式',
                en: 'Join method',
                ja: '参加方法',
                ko: '가입 방식',
              ),
              operationText: source,
              type: 'text',
              isEmpty: false,
              smallCardMode: smallCardMode,
            ),
          ),
      ],
    );
  }
}
