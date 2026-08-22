import 'dart:convert';

import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/friend_display_name.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

const String kRedPacketClaimNoticeBusinessID = 'red_packet_claim_notice';

/// App 领取端发出的灰字标记；后端/TCP 注入的同业务消息无此字段或为 tcp/server。
const String kRedPacketClaimNoticeSourceApp = 'app';

String buildRedPacketClaimNoticeId({
  required String packetId,
  required String claimerUserId,
}) {
  final packet = packetId.trim();
  final claimer = ChatIdFormat.rawUserUid(claimerUserId);
  return 'claim_${packet}_$claimer';
}

/// 语义去重键：同一红包 + 同一领取人只保留一条。
String redPacketClaimNoticeSemanticKey({
  required String packetId,
  required String claimerUserId,
}) {
  return buildRedPacketClaimNoticeId(
    packetId: packetId,
    claimerUserId: claimerUserId,
  );
}

Map<String, dynamic> buildRedPacketClaimNoticePayload({
  required String claimerUserId,
  required String claimerName,
  required String packetId,
  required bool showFinishedSuffix,
  String? senderUserId,
  String? senderName,
  String? noticeId,
  String? text,
}) {
  final claimer = ChatIdFormat.rawUserUid(claimerUserId);
  final packet = packetId.trim();
  final senderId = ChatIdFormat.rawUserUid(senderUserId);
  final claimerDisplay = resolveRedPacketClaimPartyName(
    name: claimerName,
    userId: claimer,
  );
  final senderDisplay = resolveRedPacketClaimPartyName(
    name: senderName,
    userId: senderId,
  );
  final id = (noticeId != null && noticeId.trim().isNotEmpty)
      ? noticeId.trim()
      : buildRedPacketClaimNoticeId(
          packetId: packet,
          claimerUserId: claimer,
        );
  final payload = <String, dynamic>{
    'businessID': kRedPacketClaimNoticeBusinessID,
    'source': kRedPacketClaimNoticeSourceApp,
    'claimerUserId': claimer,
    'claimerName': claimerDisplay,
    'packetId': packet,
    'showFinishedSuffix': showFinishedSuffix,
    'noticeId': id,
    if (senderId.isNotEmpty) 'senderUserId': senderId,
    if (senderDisplay.isNotEmpty) 'senderName': senderDisplay,
  };
  final preview = (text != null && text.trim().isNotEmpty)
      ? text.trim()
      : redPacketClaimNoticeDisplayText(payload);
  payload['text'] = preview;
  return payload;
}

Map<String, dynamic>? parseRedPacketClaimNoticePayload(
  V2TimCustomElem? customElem,
) {
  if (customElem == null) {
    return null;
  }
  try {
    final raw = customElem.data;
    if (raw == null || raw.isEmpty) {
      return null;
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      return null;
    }
    final data = Map<String, dynamic>.from(decoded);
    if (data['businessID']?.toString() != kRedPacketClaimNoticeBusinessID) {
      return null;
    }
    return data;
  } catch (_) {
    return null;
  }
}

bool isGenericFriendDisplayLabel(String? raw) {
  final t = (raw ?? '').trim();
  if (t.isEmpty) {
    return true;
  }
  final lower = t.toLowerCase();
  return t == '好友' ||
      t == '朋友' ||
      lower == 'a friend' ||
      lower == 'friend' ||
      lower == 'friends' ||
      t == '友達' ||
      t == '친구';
}

String _stripNameDecorators(String raw) {
  var t = raw.trim();
  if (t.length >= 2) {
    final pairs = <String, String>{
      '「': '」',
      '『': '』',
      '“': '”',
      '"': '"',
      "'": "'",
    };
    final open = t[0];
    final close = pairs[open];
    if (close != null && t.endsWith(close)) {
      t = t.substring(1, t.length - 1).trim();
    }
  }
  return t;
}

/// 展示名：拒绝「好友」类占位；优先真实昵称 → Store → userId。
String resolveRedPacketClaimPartyName({
  String? name,
  String? userId,
}) {
  final id = ChatIdFormat.rawUserUid(userId);
  final cleaned = _stripNameDecorators(name ?? '');
  if (cleaned.isNotEmpty && !isGenericFriendDisplayLabel(cleaned)) {
    return cleaned;
  }
  if (id.isNotEmpty) {
    final fromStore = FriendDisplayName.resolveC2C(userId: id).trim();
    if (fromStore.isNotEmpty && !isGenericFriendDisplayLabel(fromStore)) {
      return fromStore;
    }
    return id;
  }
  // 无 id 时仍不要输出「好友」：用中性「某人」避免旧占位词。
  return AppI18n.current.t(
    zhHans: '某人',
    zhHant: '某人',
    en: 'Someone',
    ja: '誰か',
    ko: '누군가',
  );
}

String redPacketClaimNoticeDisplayText(Map<String, dynamic> data) {
  final claimer = resolveRedPacketClaimPartyName(
    name: data['claimerName']?.toString(),
    userId: data['claimerUserId']?.toString(),
  );
  final senderId = data['senderUserId']?.toString() ?? '';
  final senderRaw = data['senderName']?.toString() ?? '';
  final sender = resolveRedPacketClaimPartyName(
    name: senderRaw,
    userId: senderId,
  );
  final finished = data['showFinishedSuffix'] == true;
  final source = data['source']?.toString().trim().toLowerCase() ?? '';
  final useDualNameFormat = source == kRedPacketClaimNoticeSourceApp ||
      !isGenericFriendDisplayLabel(senderRaw) ||
      ChatIdFormat.rawUserUid(senderId).isNotEmpty;

  // App 新灰字 / 已带发送人信息：双昵称模板（不加「」）。
  if (useDualNameFormat) {
    if (finished) {
      return AppI18n.current.format(
        zhHans: '{claimer}领取了{sender}的红包，红包已被领完',
        zhHant: '{claimer}領取了{sender}的紅包，紅包已被領完',
        en:
            '{claimer} claimed {sender}\'s red packet. The red packet has been fully claimed',
        ja: '{claimer}が{sender}の紅包を受け取り、すべて受け取られました',
        ko: '{claimer}님이 {sender}님의 레드패킷을 받았고, 모두 수령되었습니다',
        vars: {'claimer': claimer, 'sender': sender},
      );
    }
    return AppI18n.current.format(
      zhHans: '{claimer}领取了{sender}的红包',
      zhHant: '{claimer}領取了{sender}的紅包',
      en: '{claimer} claimed {sender}\'s red packet',
      ja: '{claimer}が{sender}の紅包を受け取りました',
      ko: '{claimer}님이 {sender}님의 레드패킷을 받았습니다',
      vars: {'claimer': claimer, 'sender': sender},
    );
  }

  final text = data['text']?.toString().trim() ?? '';
  if (text.isNotEmpty && !text.contains('好友') && !text.contains('「')) {
    return text;
  }

  // 旧版无发送人昵称时的兜底（仅历史消息）。
  if (finished) {
    return AppI18n.current.format(
      zhHans: '{who}领取了你的红包，你的红包已被领完',
      zhHant: '{who}領取了你的紅包，你的紅包已被領完',
      en: '{who} claimed your red packet. Your red packet has been fully claimed',
      ja: '{who} さんがあなたの紅包を受け取り、すべて受け取られました',
      ko: '{who}님이 당신의 레드패킷을 받았고, 모두 수령되었습니다',
      vars: {'who': claimer},
    );
  }
  return AppI18n.current.format(
    zhHans: '{who}领取了你的红包',
    zhHant: '{who}領取了你的紅包',
    en: '{who} claimed your red packet',
    ja: '{who} さんがあなたの紅包を受け取りました',
    ko: '{who}님이 당신의 레드패킷을 받았습니다',
    vars: {'who': claimer},
  );
}

String getRedPacketClaimNoticeDisplayText(V2TimCustomElem? customElem) {
  final payload = parseRedPacketClaimNoticePayload(customElem);
  if (payload == null) {
    return '';
  }
  return redPacketClaimNoticeDisplayText(payload);
}

bool isRedPacketClaimNoticeMessage(V2TimMessage message) {
  return parseRedPacketClaimNoticePayload(message.customElem) != null;
}

String? redPacketClaimNoticeId(V2TimMessage message) {
  final payload = parseRedPacketClaimNoticePayload(message.customElem);
  final noticeId = payload?['noticeId']?.toString().trim() ?? '';
  if (noticeId.isNotEmpty) {
    return noticeId;
  }
  return message.msgID?.trim().isNotEmpty == true
      ? message.msgID!.trim()
      : message.id?.trim();
}

String? redPacketClaimNoticeSemanticId(V2TimMessage message) {
  final payload = parseRedPacketClaimNoticePayload(message.customElem);
  if (payload == null) {
    return null;
  }
  final packet = payload['packetId']?.toString().trim() ?? '';
  final claimer = ChatIdFormat.rawUserUid(payload['claimerUserId']);
  if (packet.isNotEmpty && claimer.isNotEmpty) {
    return redPacketClaimNoticeSemanticKey(
      packetId: packet,
      claimerUserId: claimer,
    );
  }
  return redPacketClaimNoticeId(message);
}

/// 是否为领取端 App 发出的灰字（排除后端/TCP 注入，避免双发）。
bool isAppOriginRedPacketClaimNotice(V2TimMessage message) {
  final payload = parseRedPacketClaimNoticePayload(message.customElem);
  if (payload == null) {
    return false;
  }
  final source = payload['source']?.toString().trim().toLowerCase() ?? '';
  if (source == kRedPacketClaimNoticeSourceApp) {
    return true;
  }
  if (source == 'tcp' ||
      source == 'server' ||
      source == 'backend' ||
      source == 'admin') {
    return false;
  }

  // 历史 App 消息可能无 source：发送者应等于领取人。
  final claimer = ChatIdFormat.rawUserUid(payload['claimerUserId']);
  final sender = ChatIdFormat.rawUserUid(message.sender);
  if (claimer.isNotEmpty && sender.isNotEmpty && claimer == sender) {
    return true;
  }
  if (message.isSelf == true && claimer.isNotEmpty) {
    return true;
  }
  return false;
}

int _claimNoticeQualityScore(V2TimMessage message) {
  final payload = parseRedPacketClaimNoticePayload(message.customElem);
  if (payload == null) {
    return 0;
  }
  var score = 0;
  final source = payload['source']?.toString().trim().toLowerCase() ?? '';
  if (source == kRedPacketClaimNoticeSourceApp) {
    score += 100;
  }
  final senderName = payload['senderName']?.toString() ?? '';
  if (!isGenericFriendDisplayLabel(senderName)) {
    score += 50;
  }
  if (ChatIdFormat.rawUserUid(payload['senderUserId']).isNotEmpty) {
    score += 20;
  }
  final claimerName = payload['claimerName']?.toString() ?? '';
  if (!isGenericFriendDisplayLabel(claimerName)) {
    score += 10;
  }
  return score;
}

/// 去掉后端/TCP 注入的领取灰字，并按「红包+领取人」语义去重（保留质量更高的一条）。
List<V2TimMessage> filterDuplicateRedPacketClaimNotices(
  List<V2TimMessage> messages,
) {
  final bestByKey = <String, V2TimMessage>{};
  final bestScore = <String, int>{};
  final passthrough = <V2TimMessage>[];

  for (final message in messages) {
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_CUSTOM ||
        !isRedPacketClaimNoticeMessage(message)) {
      passthrough.add(message);
      continue;
    }
    // 后端/TCP 同业务灰字一律隐藏，只保留 App 领取端发出的。
    if (!isAppOriginRedPacketClaimNotice(message)) {
      continue;
    }
    final key = redPacketClaimNoticeSemanticId(message)?.trim() ?? '';
    if (key.isEmpty) {
      passthrough.add(message);
      continue;
    }
    final score = _claimNoticeQualityScore(message);
    final prev = bestByKey[key];
    if (prev == null || score > (bestScore[key] ?? 0)) {
      bestByKey[key] = message;
      bestScore[key] = score;
    }
  }

  if (bestByKey.isEmpty) {
    return passthrough;
  }

  final keep = bestByKey.values.toSet();
  final out = <V2TimMessage>[];
  final emitted = <String>{};
  for (final message in messages) {
    if (message.elemType != MessageElemType.V2TIM_ELEM_TYPE_CUSTOM ||
        !isRedPacketClaimNoticeMessage(message)) {
      out.add(message);
      continue;
    }
    if (!keep.contains(message)) {
      continue;
    }
    final key = redPacketClaimNoticeSemanticId(message)?.trim() ?? '';
    if (key.isNotEmpty && !emitted.add(key)) {
      continue;
    }
    out.add(message);
  }
  return out;
}
