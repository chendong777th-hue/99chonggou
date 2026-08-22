import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/official_account_article_card.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/official_account_article_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
/// 公众号会话内文本/自定义消息的图文卡片气泡。
class OfficialAccountMessageItem extends StatelessWidget {
  final V2TimMessage message;
  final OfficialAccountArticleMessage article;
  final bool isShowJump;

  const OfficialAccountMessageItem({
    super.key,
    required this.message,
    required this.article,
    this.isShowJump = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final isFromSelf = message.isSelf ?? false;
    final borderRadius = isFromSelf
        ? const BorderRadius.only(
            topLeft: Radius.circular(10),
            topRight: Radius.circular(2),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(2),
            topRight: Radius.circular(10),
            bottomLeft: Radius.circular(10),
            bottomRight: Radius.circular(10),
          );

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: isFromSelf
            ? theme.lightPrimaryMaterialColor.shade50
            : theme.weakBackgroundColor,
        borderRadius: borderRadius,
      ),
      constraints: const BoxConstraints(maxWidth: 300),
      child: OfficialAccountArticleCard(
        article: article,
        theme: theme,
      ),
    );
  }
}

/// 若可解析为图文卡片则返回对应 Widget，否则返回 null 走默认渲染。
Widget? tryBuildOfficialAccountMessageItem(
  V2TimMessage message, {
  required bool isShowJump,
}) {
  final article = parseOfficialAccountArticleFromMessage(message);
  if (article == null || !article.shouldRenderAsArticleCard) {
    return null;
  }
  return OfficialAccountMessageItem(
    message: message,
    article: article,
    isShowJump: isShowJump,
  );
}
