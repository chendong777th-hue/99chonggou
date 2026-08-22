import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/platform_notice/platform_wallet_notice_card.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/custom_message_element.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/platform_wallet_notice_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 公众号会话内的「支付助手」风格钱包通知气泡。
class PlatformWalletNoticeMessageItem extends StatelessWidget {
  final PlatformWalletNoticeData data;

  const PlatformWalletNoticeMessageItem({
    super.key,
    required this.data,
  });

  @override
  Widget build(BuildContext context) {
    final url = data.actionUrl?.trim() ?? '';
    return PlatformWalletNoticeCard(
      data: PlatformWalletNoticeData(
        type: data.type,
        title: data.title,
        serviceName: data.serviceName,
        statusLabel: data.statusLabel,
        summary: data.summary,
        rows: data.rows,
        actionLabel: data.actionLabel,
        actionUrl: data.actionUrl,
        orderId: data.orderId,
        onAction: url.isNotEmpty
            ? () => CustomMessageElem.launchWebURL(context, url)
            : data.onAction,
      ),
    );
  }
}

Widget? tryBuildPlatformWalletNoticeMessageItem(V2TimMessage message) {
  final notice = parsePlatformWalletNoticeFromMessage(message);
  if (notice == null) return null;
  return PlatformWalletNoticeMessageItem(data: notice);
}
