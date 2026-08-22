import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';

/// 平台运营公众号昵称 + 认证 V 标。
class OfficialAccountNameLabel extends StatelessWidget {
  final String name;
  final TextStyle? style;
  final double badgeSize;
  final int maxLines;
  final TextOverflow overflow;

  const OfficialAccountNameLabel({
    super.key,
    required this.name,
    this.style,
    this.badgeSize = 16,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  static const String verifiedBadgeAsset =
      'assets/official_account_verified.png';

  @override
  Widget build(BuildContext context) {
    final text = Text(
      name,
      maxLines: maxLines,
      overflow: overflow,
      style: style,
    );

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Flexible(child: text),
        const SizedBox(width: 4),
        Image.asset(
          verifiedBadgeAsset,
          width: badgeSize,
          height: badgeSize,
          fit: BoxFit.contain,
        ),
      ],
    );
  }
}

/// 会话列表标题：公众号返回带 V 标的 Widget，其它返回 null 走默认 Text。
Widget? buildOfficialAccountConversationNickName({
  required String? userId,
  required String name,
  required Color? titleColor,
  double fontSize = 16,
  double badgeSize = 16,
}) {
  if (!PlatformOfficialAccountService.showsVerifiedBadge(
    userId,
    showName: name,
  )) {
    return null;
  }
  return OfficialAccountNameLabel(
    name: name,
    badgeSize: badgeSize,
    style: TextStyle(
      height: 1,
      color: titleColor,
      fontSize: fontSize,
      fontWeight: FontWeight.w500,
    ),
  );
}

/// 根据 userId 决定是否展示认证标。
class OfficialAccountNameLabelForUser extends StatelessWidget {
  final String? userId;
  final String name;
  final TextStyle? style;
  final double badgeSize;
  final int maxLines;
  final TextOverflow overflow;

  const OfficialAccountNameLabelForUser({
    super.key,
    required this.userId,
    required this.name,
    this.style,
    this.badgeSize = 16,
    this.maxLines = 1,
    this.overflow = TextOverflow.ellipsis,
  });

  @override
  Widget build(BuildContext context) {
    if (!PlatformOfficialAccountService.showsVerifiedBadge(
      userId,
      showName: name,
    )) {
      return Text(
        name,
        maxLines: maxLines,
        overflow: overflow,
        style: style,
      );
    }
    return OfficialAccountNameLabel(
      name: name,
      style: style,
      badgeSize: badgeSize,
      maxLines: maxLines,
      overflow: overflow,
    );
  }
}
