import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_message_window.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_message_window_policy.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';

V2TimMessage _m(int i) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': 1700000000 + i,
    'message_msg_id': 'm$i',
    'message_seq': '$i',
    'message_rand': i,
    'message_is_from_self': true,
    'message_status': 2,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
  message.msgID = 'm$i';
  message.seq = '$i';
  message.timestamp = 1700000000 + i;
  return message;
}

/// newest-first：index0 = 最大序号。
List<V2TimMessage> _newestFirst(int newest, int oldest) {
  final list = <V2TimMessage>[];
  for (var i = newest; i >= oldest; i--) {
    list.add(_m(i));
  }
  return list;
}

void main() {
  setUp(() {
    ChatMessageWindowPolicy.enabled = true;
  });

  tearDown(() {
    ChatMessageWindowPolicy.enabled = true;
  });

  test('len <= softMax does not trim', () {
    final list = _newestFirst(160, 41); // 120
    final r = ChatMessageWindow.trimToWindow(list: list, preferLatest: true);
    expect(r.didTrim, isFalse);
    expect(r.list.length, 120);
  });

  test('preferLatest keeps newest targetSize and drops older tail', () {
    final list = _newestFirst(200, 1); // 200
    final r = ChatMessageWindow.trimToWindow(
      list: list,
      preferLatest: true,
      softMax: 160,
      targetSize: 120,
    );
    expect(r.didTrim, isTrue);
    expect(r.list.length, 120);
    expect(r.list.first.msgID, 'm200');
    expect(r.list.last.msgID, 'm81');
    expect(r.removedNewerCount, 0);
    expect(r.removedOlderCount, 80);
    expect(r.trimmedAwayLatest, isFalse);
    expect(r.trimmedAwayOldestInMemory, isTrue);
  });

  test('after older expand, trim drops newer head around anchor', () {
    // 上翻后超过 softMax：newest=1099 ... oldest=900（200 条），锚在 940
    final list = _newestFirst(1099, 900);
    expect(list.length, 200);
    final r = ChatMessageWindow.trimToWindow(
      list: list,
      preferLatest: false,
      anchorMsgID: 'm940',
      softMax: 160,
      targetSize: 120,
      keepNewerSide: 40,
      keepOlderSide: 40,
    );
    expect(r.didTrim, isTrue);
    expect(r.list.length, lessThanOrEqualTo(120));
    expect(r.list.any((m) => m.msgID == 'm940'), isTrue);
    expect(r.trimmedAwayLatest, isTrue);
    expect(r.list.first.msgID, isNot('m1099'));
  });

  test('trim older side when anchor near newest', () {
    final list = _newestFirst(1099, 900);
    final r = ChatMessageWindow.trimToWindow(
      list: list,
      preferLatest: false,
      anchorMsgID: 'm1090',
      softMax: 160,
      targetSize: 120,
    );
    expect(r.didTrim, isTrue);
    expect(r.list.any((m) => m.msgID == 'm1090'), isTrue);
    expect(r.trimmedAwayOldestInMemory, isTrue);
  });

  test('exactly softMax does not trim', () {
    final list = _newestFirst(1059, 900); // 160
    final r = ChatMessageWindow.trimToWindow(
      list: list,
      preferLatest: false,
      anchorMsgID: 'm940',
      softMax: 160,
      targetSize: 120,
    );
    expect(r.didTrim, isFalse);
    expect(r.list.length, 160);
  });

  test('anchor always retained', () {
    final list = _newestFirst(300, 1);
    final r = ChatMessageWindow.trimToWindow(
      list: list,
      preferLatest: false,
      anchorSeq: '150',
      softMax: 160,
      targetSize: 120,
    );
    expect(r.list.any((m) => m.seq == '150'), isTrue);
  });

  test('preferLatest false + anchorSeq keeps neighbors on both sides', () {
    final list = _newestFirst(300, 1);
    final r = ChatMessageWindow.trimToWindow(
      list: list,
      preferLatest: false,
      anchorSeq: '150',
      softMax: 160,
      targetSize: 120,
      keepNewerSide: 40,
      keepOlderSide: 40,
    );
    expect(r.didTrim, isTrue);
    expect(r.list.any((m) => m.seq == '150'), isTrue);
    // newer side (higher seq, toward list head) and older side both present
    expect(r.list.any((m) => (int.tryParse(m.seq ?? '') ?? 0) > 150), isTrue);
    expect(r.list.any((m) => (int.tryParse(m.seq ?? '') ?? 0) < 150), isTrue);
    expect(r.list.first.msgID, isNot('m300'));
  });

  test('enabled=false is no-op', () {
    ChatMessageWindowPolicy.enabled = false;
    final list = _newestFirst(300, 1);
    final r = ChatMessageWindow.trimToWindow(list: list, preferLatest: true);
    expect(r.didTrim, isFalse);
    expect(r.list.length, 300);
  });

  test('short list never padded', () {
    final list = _newestFirst(50, 1);
    final r = ChatMessageWindow.trimToWindow(list: list, preferLatest: true);
    expect(r.didTrim, isFalse);
    expect(r.list.length, 50);
  });

  test('short previous page never replaces an existing history window', () {
    final baseline = _newestFirst(40, 1);
    final shortPage = _newestFirst(3, 1);

    final merged = TUIChatGlobalModel.mergeHistoricalWithInMemory(
      existing: baseline,
      fetched: shortPage,
    );

    expect(merged.length, 40);
    expect(merged.any((message) => message.msgID == 'm1'), isTrue);
    expect(merged.any((message) => message.msgID == 'm40'), isTrue);
  });
}
