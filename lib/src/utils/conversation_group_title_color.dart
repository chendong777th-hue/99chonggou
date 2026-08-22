import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/group_profile_type_indicators.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/official_account_name_label.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/super_large_group_flame_icon.dart';

/// 会话/群列表/资料页：超级大群（Community）群名用警示红，其它沿用 [fallback]。
Color conversationGroupTitleColor({
  required Color? fallback,
  String? groupType,
}) {
  if (groupProfileIsSuperLargeGroup(groupType)) {
    return AppTokens.danger;
  }
  return fallback ?? AppTokens.textPrimaryLight;
}

/// 群名 +（超级大群时）尾随火焰图标。
Widget buildGroupTitleWithOptionalFlame({
  required String name,
  required TextStyle style,
  String? groupType,
  double flameSize = 14,
  int maxLines = 1,
}) {
  final text = Text(
    name,
    maxLines: maxLines,
    overflow: TextOverflow.ellipsis,
    softWrap: maxLines > 1,
    style: style,
  );
  if (!groupProfileIsSuperLargeGroup(groupType)) {
    return text;
  }
  return Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(child: text),
      const SizedBox(width: 4),
      SuperLargeGroupFlameIcon(size: flameSize),
    ],
  );
}

/// 会话列表标题：公众号 V 标优先；Community 红字+火焰；否则 null 走 UIKit 默认色。
Widget? buildConversationListNickName({
  required String? userId,
  required String name,
  required Color? fallbackTitleColor,
  String? groupType,
  double fontSize = 16,
  double badgeSize = 16,
  double flameSize = 14,
}) {
  final titleColor = conversationGroupTitleColor(
    fallback: fallbackTitleColor,
    groupType: groupType,
  );
  final official = buildOfficialAccountConversationNickName(
    userId: userId,
    name: name,
    titleColor: titleColor,
    fontSize: fontSize,
    badgeSize: badgeSize,
  );
  if (official != null) {
    return official;
  }
  if (!groupProfileIsSuperLargeGroup(groupType)) {
    return null;
  }
  return buildGroupTitleWithOptionalFlame(
    name: name,
    groupType: groupType,
    flameSize: flameSize,
    style: TextStyle(
      height: 1.2,
      color: titleColor,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
    ),
  );
}

/// 群聊会话列表标题：与单聊一致（直播徽标改在头像下方展示）。
Widget? buildGroupConversationListNickName({
  required String? userId,
  required String name,
  required Color? fallbackTitleColor,
  String? groupType,
  String? groupId,
  double fontSize = 16,
  double badgeSize = 16,
  double flameSize = 14,
}) {
  return buildConversationListNickName(
    userId: userId,
    name: name,
    fallbackTitleColor: fallbackTitleColor,
    groupType: groupType,
    fontSize: fontSize,
    badgeSize: badgeSize,
    flameSize: flameSize,
  );
}
