import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

V2TimMessage _text({
  required String msgId,
  required int ts,
  int? seq,
}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': ts,
    'message_is_from_self': false,
    'message_status': 2,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
  message.msgID = msgId;
  message.timestamp = ts;
  message.seq = seq?.toString();
  message.sender = 'peer';
  message.userID = 'peer';
  message.isSelf = false;
  return message;
}

void main() {
  test(
      'peek replace with tip-only window drops older neighbor (gap-fill hazard)',
      () {
    final tip = _text(msgId: 'tip', ts: 200, seq: 4);
    final older = _text(msgId: 'older', ts: 100, seq: 1);
    final existing = <V2TimMessage>[tip, older];
    final merged = TUIChatGlobalModel.mergePeekWindowWithLiveMemory(
      existing: existing,
      fetched: <V2TimMessage>[tip],
    );
    final ids = merged.map((m) => m.msgID).toSet();
    expect(ids.contains('tip'), isTrue);
    expect(
      ids.contains('older'),
      isFalse,
      reason: 'peek replace must not be used for gap-only batches',
    );
  });

  test('historical merge keeps older neighbor when gap batch is tip-only', () {
    final tip = _text(msgId: 'tip', ts: 200, seq: 4);
    final older = _text(msgId: 'older', ts: 100, seq: 1);
    final existing = <V2TimMessage>[tip, older];
    final merged = TUIChatGlobalModel.mergeHistoricalWithInMemory(
      existing: existing,
      fetched: <V2TimMessage>[tip],
    );
    final ids = merged.map((m) => m.msgID).toSet();
    expect(ids.contains('tip'), isTrue);
    expect(ids.contains('older'), isTrue);
  });

  test(
      'pagination commit rebases on messages added while request was in flight',
      () {
    // The request started with a small snapshot. While it was awaiting the SDK,
    // hydration/inbound work expanded the live list. A pagination commit must
    // merge into that live list, never replace it with snapshot + page.
    final requestSnapshot = <V2TimMessage>[
      _text(msgId: 'm3', ts: 300, seq: 3),
      _text(msgId: 'm2', ts: 200, seq: 2),
    ];
    final liveAtCommit = <V2TimMessage>[
      _text(msgId: 'm5', ts: 500, seq: 5),
      _text(msgId: 'm4', ts: 400, seq: 4),
      ...requestSnapshot,
    ];
    final olderPage = <V2TimMessage>[
      _text(msgId: 'm1', ts: 100, seq: 1),
    ];

    final staleReplacement = TUIChatGlobalModel.mergeHistoricalWithInMemory(
      existing: requestSnapshot,
      fetched: olderPage,
    );
    expect(staleReplacement.map((m) => m.msgID), isNot(contains('m5')));

    final rebasedCommit = TUIChatGlobalModel.mergeHistoricalWithInMemory(
      existing: liveAtCommit,
      fetched: staleReplacement,
    );
    expect(rebasedCommit.map((m) => m.msgID).toList(),
        <String?>['m5', 'm4', 'm3', 'm2', 'm1']);
  });

  test('filled 120-row window stays when late peek is historically merged', () {
    final existing = <V2TimMessage>[
      for (var i = 120; i >= 1; i--)
        _text(msgId: 'm$i', ts: 1000 + i, seq: i),
    ];
    final peek = <V2TimMessage>[
      for (var i = 120; i >= 101; i--)
        _text(msgId: 'm$i', ts: 1000 + i, seq: i),
    ];
    final wiped = TUIChatGlobalModel.mergePeekWindowWithLiveMemory(
      existing: existing,
      fetched: peek,
    );
    expect(wiped.length, 20);

    final kept = TUIChatGlobalModel.mergeHistoricalWithInMemory(
      existing: existing,
      fetched: peek,
    );
    expect(kept.length, 120);
    expect(kept.first.msgID, 'm120');
    expect(kept.last.msgID, 'm1');
  });
}
