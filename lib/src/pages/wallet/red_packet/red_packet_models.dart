import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

import '../wallet_repository.dart';

enum RpType {
  lucky,
  normal,
  exclusive,
}

extension RpTypeX on RpType {
  String get title {
    switch (this) {
      case RpType.lucky:
        return AppI18n.current.t(
          zhHans: '拼手气红包',
          zhHant: '拼手氣紅包',
          en: 'Lucky Red Packet',
          ja: 'ランダム紅包',
          ko: '랜덤 레드패킷',
        );
      case RpType.normal:
        return AppI18n.current.t(
          zhHans: '普通红包',
          zhHant: '普通紅包',
          en: 'Regular Red Packet',
          ja: '通常の紅包',
          ko: '일반 레드패킷',
        );
      case RpType.exclusive:
        return AppI18n.current.t(
          zhHans: '专属红包',
          zhHant: '專屬紅包',
          en: 'Exclusive Red Packet',
          ja: '専用紅包',
          ko: '전용 레드패킷',
        );
    }
  }

  String get amtLabel {
    switch (this) {
      case RpType.lucky:
        return AppI18n.current.t(
          zhHans: '总金额',
          zhHant: '總金額',
          en: 'Total Amount',
          ja: '合計金額',
          ko: '총액',
        );
      case RpType.normal:
        return AppI18n.current.t(
          zhHans: '单个金额',
          zhHant: '單個金額',
          en: 'Amount Per Packet',
          ja: '1件あたりの金額',
          ko: '개별 금액',
        );
      case RpType.exclusive:
        return AppI18n.current.t(
          zhHans: '金额',
          zhHant: '金額',
          en: 'Amount',
          ja: '金額',
          ko: '금액',
        );
    }
  }
}

/// 发红包 API / IM 卡片共用的 packetType 编码。
String redPacketPacketTypeCode(
  RpType type, {
  required bool isGroup,
}) {
  if (!isGroup) {
    return 'NORMAL_C2C';
  }
  switch (type) {
    case RpType.lucky:
      return 'LUCKY_GROUP';
    case RpType.normal:
      return 'NORMAL_GROUP';
    case RpType.exclusive:
      return 'EXCLUSIVE';
  }
}

/// 聊天卡片 / 会话预览展示用完整类型名。
String redPacketTypeLabel(
  String? packetType, {
  AppI18n? i18n,
}) {
  final lang = i18n ?? AppI18n.current;
  switch (packetType?.trim().toUpperCase() ?? '') {
    case 'LUCKY_GROUP':
      return lang.t(
        zhHans: '拼手气红包',
        zhHant: '拼手氣紅包',
        en: 'Lucky Red Packet',
        ja: 'ランダム紅包',
        ko: '랜덤 레드패킷',
      );
    case 'NORMAL_GROUP':
    case 'NORMAL_C2C':
      return lang.t(
        zhHans: '普通红包',
        zhHant: '普通紅包',
        en: 'Regular Red Packet',
        ja: '通常の紅包',
        ko: '일반 레드패킷',
      );
    case 'EXCLUSIVE':
      return lang.t(
        zhHans: '专属红包',
        zhHant: '專屬紅包',
        en: 'Exclusive Red Packet',
        ja: '専用紅包',
        ko: '전용 레드패킷',
      );
    case 'GROUP_TRANSFER':
      return lang.t(
        zhHans: '群转账',
        zhHant: '群轉帳',
        en: 'Group Transfer',
        ja: 'グループ送金',
        ko: '그룹 이체',
      );
    default:
      return lang.t(
        zhHans: '红包',
        zhHant: '紅包',
        en: 'Red Packet',
        ja: '紅包',
        ko: '레드패킷',
      );
  }
}

/// 客户端本地幂等键（`red_packet_{uuid}`）。
/// 读卡接口支持用它查卡；领取/明细等写操作仍需服务端红包 id。
bool isRedPacketClientOrderId(String? value) {
  final id = value?.trim() ?? '';
  return id.startsWith('red_packet_');
}

/// 服务端红包 id：数字主键或 publicId（非 clientOrderId）。
bool isRedPacketServerId(String? value) {
  final id = value?.trim() ?? '';
  if (id.isEmpty || isRedPacketClientOrderId(id)) return false;
  return true;
}

/// 从 IM 卡片 / 订单 payload 提取可用于红包 API 的数字主键。
String resolveRedPacketServerId(Map<String, dynamic> data) {
  for (final key in const [
    'orderId',
    'id',
    'packetId',
    'serverOrderId',
  ]) {
    final value = data[key]?.toString().trim() ?? '';
    if (isRedPacketServerId(value)) return value;
  }
  return '';
}

String resolveRedPacketClientOrderId(Map<String, dynamic> data) {
  final value = data['clientOrderId']?.toString().trim() ?? '';
  return isRedPacketClientOrderId(value) ? value : '';
}

/// TCP 推送 / 本地缓存可能携带服务端 id 或 clientOrderId，需同时匹配。
bool matchesRedPacketPacketKey(
  Map<String, dynamic> data, {
  required String packetId,
}) {
  final key = packetId.trim();
  if (key.isEmpty) return false;
  if (resolveRedPacketServerId(data) == key) return true;
  if (resolveRedPacketClientOrderId(data) == key) return true;
  return false;
}

enum RpFlow {
  none,
  loading,
  pending,
  success,
  failed,
}

class RpForm {
  final RpType type;
  final String cnt;
  final String amt;
  final String msg;
  final WalletPayMethodDto pay;

  const RpForm({
    required this.type,
    required this.cnt,
    required this.amt,
    required this.msg,
    required this.pay,
  });
}
