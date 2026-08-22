import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/custom_message/red_packet_claim_notice_message.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_custom_elem.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_custom_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

V2TimMessage _claimMessage({
  required String noticeId,
  required String msgID,
  String claimerName = '甲',
  String claimerUserId = 'u1',
  String? senderName,
  String? senderUserId,
  String? source,
  String? messageSender,
  bool isSelf = false,
  String packetId = 'p1',
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': 1700000000,
    'message_msg_id': msgID,
    'message_is_from_self': isSelf,
    'message_status': 2,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
  message.msgID = msgID;
  message.sender = messageSender ?? claimerUserId;
  message.isSelf = isSelf;
  final payload = buildRedPacketClaimNoticePayload(
    claimerUserId: claimerUserId,
    claimerName: claimerName,
    packetId: packetId,
    showFinishedSuffix: false,
    noticeId: noticeId,
    senderName: senderName,
    senderUserId: senderUserId,
  );
  if (source != null) {
    if (source.isEmpty) {
      payload.remove('source');
    } else {
      payload['source'] = source;
    }
  }
  message.customElem = V2TimCustomElem(
    data: jsonEncode(payload),
  );
  return message;
}

void main() {
  test('buildRedPacketClaimNoticePayload sets noticeId and dual-name text', () {
    final payload = buildRedPacketClaimNoticePayload(
      claimerUserId: 'u9',
      claimerName: '秋',
      packetId: '88',
      showFinishedSuffix: true,
      senderName: '阿伦',
    );
    expect(payload['businessID'], kRedPacketClaimNoticeBusinessID);
    expect(payload['source'], kRedPacketClaimNoticeSourceApp);
    expect(payload['noticeId'], 'claim_88_u9');
    expect(payload['showFinishedSuffix'], isTrue);
    expect(payload['senderName'], '阿伦');
    final text = payload['text']?.toString() ?? '';
    expect(text, contains('秋'));
    expect(text, contains('阿伦'));
    expect(text, isNot(contains('「')));
    expect(text, isNot(contains('」')));
    expect(text, isNot(contains('好友')));
    expect(
      text.toLowerCase(),
      anyOf(contains('领'), contains('claim'), contains('受け取り'), contains('받았')),
    );
    expect(text, isNot(contains('领取了你的红包')));
    expect(text.toLowerCase(), isNot(contains('claimed your red packet')));
  });

  test('display never falls back to 好友; uses userId instead', () {
    final text = redPacketClaimNoticeDisplayText(<String, dynamic>{
      'businessID': kRedPacketClaimNoticeBusinessID,
      'source': 'app',
      'claimerName': '京东财务',
      'claimerUserId': 'c1',
      'senderName': '好友',
      'senderUserId': 'sender_99',
      'showFinishedSuffix': false,
    });
    expect(text, isNot(contains('好友')));
    expect(text, contains('京东财务'));
    expect(text, contains('sender_99'));
    expect(text, isNot(contains('「')));
  });

  test('filterDuplicateRedPacketClaimNotices keeps richer notice', () {
    final weak = _claimMessage(
      noticeId: 'server-random',
      msgID: 'm-weak',
      senderName: '阿伦',
      senderUserId: 's1',
      source: 'app',
      packetId: '88',
    );
    // 模拟后端占位：payload 里仍是「好友」
    final weakData = Map<String, dynamic>.from(
      jsonDecode(weak.customElem!.data!) as Map,
    );
    weakData['senderName'] = '好友';
    weak.customElem = V2TimCustomElem(data: jsonEncode(weakData));

    final rich = _claimMessage(
      noticeId: 'claim_88_u1',
      msgID: 'm-rich',
      senderName: '阿伦',
      senderUserId: 's1',
      source: 'app',
      packetId: '88',
    );
    final filtered = filterDuplicateRedPacketClaimNotices([weak, rich]);
    expect(filtered.map((m) => m.msgID).toList(), ['m-rich']);
  });

  test('filterDuplicateRedPacketClaimNotices keeps first noticeId', () {
    final a = _claimMessage(
      noticeId: 'claim_88_u1',
      msgID: 'm1',
      senderName: '发包人',
      packetId: '88',
    );
    final b = _claimMessage(
      noticeId: 'claim_88_u1',
      msgID: 'm2',
      senderName: '发包人',
      packetId: '88',
    );
    final c = _claimMessage(
      noticeId: 'claim_88_u2',
      msgID: 'm3',
      claimerUserId: 'u2',
      senderName: '发包人',
      packetId: '88',
    );
    final filtered = filterDuplicateRedPacketClaimNotices([a, b, c]);
    expect(filtered.map((m) => m.msgID).toList(), ['m1', 'm3']);
  });

  test('filterDuplicateRedPacketClaimNotices drops tcp/backend tips', () {
    final app = _claimMessage(
      noticeId: 'claim_88_u1',
      msgID: 'm-app',
      senderName: '发包人',
      source: 'app',
      messageSender: 'u1',
      packetId: '88',
    );
    final tcp = _claimMessage(
      noticeId: 'claim_88_u1_tcp',
      msgID: 'm-tcp',
      claimerName: '阿伦_99CHAT六合彩在用',
      source: 'tcp',
      messageSender: 'admin',
      packetId: '88',
    );
    final backendNoSource = _claimMessage(
      noticeId: 'server-tip-1',
      msgID: 'm-backend',
      claimerName: '阿伦_99CHAT六合彩在用',
      source: '',
      messageSender: 'admin_bot',
      packetId: '88',
    );
    final filtered =
        filterDuplicateRedPacketClaimNotices([tcp, backendNoSource, app]);
    expect(filtered.map((m) => m.msgID).toList(), ['m-app']);
  });
}
