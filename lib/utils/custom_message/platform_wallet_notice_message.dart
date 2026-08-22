import 'dart:convert';

import 'package:tencent_cloud_chat_demo/src/widgets/platform_notice/platform_wallet_notice_card.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// IM 自定义消息识别：`customType` / `businessID` 均为 `platform_wallet_notice`。
const String kPlatformWalletNoticeCustomType = 'platform_wallet_notice';

bool isPlatformWalletNoticePayload(Map<String, dynamic> data) {
  final customType = data['customType']?.toString() ?? '';
  final businessID = data['businessID']?.toString() ?? '';
  final legacyType = data['type']?.toString() ?? '';
  return customType == kPlatformWalletNoticeCustomType ||
      businessID == kPlatformWalletNoticeCustomType ||
      legacyType == kPlatformWalletNoticeCustomType;
}

PlatformWalletNoticeType _parseNoticeType(String? raw) {
  switch (raw?.trim().toLowerCase()) {
    case 'withdraw':
      return PlatformWalletNoticeType.withdraw;
    case 'deposit':
      return PlatformWalletNoticeType.deposit;
    case 'flash_exchange':
    case 'flashExchange':
    case 'exchange':
      return PlatformWalletNoticeType.flashExchange;
    case 'set_trade_password':
    case 'setTradePassword':
      return PlatformWalletNoticeType.setTradePassword;
    case 'change_trade_password':
    case 'changeTradePassword':
      return PlatformWalletNoticeType.changeTradePassword;
    case 'red_packet_refund':
    case 'redPacketRefund':
      return PlatformWalletNoticeType.redPacketRefund;
    case 'lifepayment':
    case 'life_payment':
    case 'lifePayment':
      return PlatformWalletNoticeType.lifePayment;
    case 'general':
    default:
      return PlatformWalletNoticeType.general;
  }
}

List<PlatformWalletNoticeRow> _parseRows(dynamic raw) {
  if (raw is! List) return const [];
  final rows = <PlatformWalletNoticeRow>[];
  for (final item in raw) {
    if (item is! Map) continue;
    final map = Map<String, dynamic>.from(item);
    final label = map['label']?.toString().trim() ?? '';
    final value = map['value']?.toString().trim() ?? '';
    if (label.isEmpty && value.isEmpty) continue;
    rows.add(
      PlatformWalletNoticeRow(
        label: label,
        value: value,
        emphasize: map['emphasize'] == true || map['highlight'] == true,
      ),
    );
  }
  return rows;
}

Map<String, dynamic>? _decodeCustomData(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final decoded = jsonDecode(raw);
    if (decoded is Map) {
      return Map<String, dynamic>.from(decoded);
    }
  } catch (_) {}
  return null;
}

/// 从自定义消息 `data` JSON 解析钱包通知卡片数据。
PlatformWalletNoticeData? parsePlatformWalletNoticeData(
  Map<String, dynamic> data,
) {
  if (!isPlatformWalletNoticePayload(data)) {
    return null;
  }
  final title = data['title']?.toString().trim() ?? '';
  if (title.isEmpty) {
    return null;
  }
  final noticeType = _parseNoticeType(
    data['noticeType']?.toString() ??
        data['notice_type']?.toString() ??
        data['category']?.toString(),
  );
  return PlatformWalletNoticeData(
    type: noticeType,
    title: title,
    serviceName: data['serviceName']?.toString() ??
        data['service_name']?.toString(),
    statusLabel: data['statusLabel']?.toString() ??
        data['status_label']?.toString() ??
        data['status']?.toString(),
    summary: data['summary']?.toString() ?? data['desc']?.toString(),
    rows: _parseRows(data['rows'] ?? data['fields'] ?? data['details']),
    actionLabel: data['actionLabel']?.toString() ??
        data['action_label']?.toString(),
    actionUrl: data['actionUrl']?.toString() ??
        data['action_url']?.toString() ??
        data['link']?.toString(),
    orderId: data['orderId']?.toString() ?? data['order_id']?.toString(),
  );
}

PlatformWalletNoticeData? parsePlatformWalletNoticeMessage(
  V2TimCustomElem? customElem,
) {
  final data = _decodeCustomData(customElem?.data);
  if (data == null) return null;
  return parsePlatformWalletNoticeData(data);
}

PlatformWalletNoticeData? parsePlatformWalletNoticeFromMessage(
  V2TimMessage message,
) {
  return parsePlatformWalletNoticeMessage(message.customElem);
}

/// 会话列表摘要：优先 `title`，否则 `[支付助手]`.
String? platformWalletNoticeConversationPreview(V2TimMessage message) {
  final notice = parsePlatformWalletNoticeFromMessage(message);
  if (notice == null) return null;
  final service = notice.serviceName?.trim() ?? '';
  if (notice.title.isNotEmpty) {
    if (service.isNotEmpty) {
      return '[$service] ${notice.title}';
    }
    return notice.title;
  }
  return service.isNotEmpty ? '[$service]' : '[通知]';
}
