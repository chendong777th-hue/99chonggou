import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_list_result.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_history_peek_loader.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';

V2TimMessage _msg(int seq, {String prefix = 'm'}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': 100000 + seq,
    'message_msg_id': '$prefix$seq',
    'message_seq': '$seq',
    'message_rand': seq,
    'message_is_from_self': true,
    'message_status': 2,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
  message.msgID = '$prefix$seq';
  message.seq = '$seq';
  message.timestamp = 100000 + seq;
  return message;
}

List<V2TimMessage> _range(int from, int to, {String prefix = 'm'}) {
  return [for (var i = to; i >= from; i--) _msg(i, prefix: prefix)];
}

class _FakeHistoryService extends Fake implements MessageService {
  _FakeHistoryService({
    required this.localPages,
    required this.cloudPages,
  });

  final Map<String, V2TimMessageListResult> localPages;
  final Map<String, V2TimMessageListResult> cloudPages;
  int cloudCalls = 0;
  int localCalls = 0;
  Duration? delay;

  String _key(String? lastMsgID) => lastMsgID ?? '';

  @override
  Future<V2TimMessageListResult?> getHistoryMessageListWithComplete({
    HistoryMsgGetTypeEnum getType =
        HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
    String? userID,
    String? groupID,
    int lastMsgSeq = 0,
    required int count,
    String? lastMsgID,
    V2TimMessage? lastMsg,
    List<int>? messageTypeList,
    List<int>? messageSeqList,
    int? timeBegin,
    int? timePeriod,
  }) async {
    final wait = delay;
    if (wait != null && wait > Duration.zero) {
      await Future<void>.delayed(wait);
    }
    final key = _key(lastMsgID);
    if (getType == HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG) {
      cloudCalls += 1;
      return cloudPages[key] ??
          V2TimMessageListResult(isFinished: true, messageList: const []);
    }
    localCalls += 1;
    return localPages[key] ??
        V2TimMessageListResult(isFinished: true, messageList: const []);
  }
}

void main() {
  test('fills a short first cloud page by paging older cloud messages', () async {
    final localHead = _range(1, 40, prefix: 'old_');
    final cloudHead = _range(5000, 5009);
    final cloudOlder = _range(4970, 4999);
    final service = _FakeHistoryService(
      localPages: {
        '': V2TimMessageListResult(isFinished: false, messageList: localHead),
        'm5000': V2TimMessageListResult(
          isFinished: true,
          messageList: localHead,
        ),
      },
      cloudPages: {
        '': V2TimMessageListResult(isFinished: true, messageList: cloudHead),
        'm5000': V2TimMessageListResult(
          isFinished: true,
          messageList: cloudOlder,
        ),
      },
    );

    final result = await MessageHistoryPeekLoader.loadOlderLocalThenCloudResult(
      messageService: service,
      count: 40,
      groupID: 'g1',
    );

    expect(service.cloudCalls, greaterThanOrEqualTo(2));
    expect(result.messageList, hasLength(40));
    expect(result.messageList.first.msgID, 'm4970');
    expect(result.messageList.last.msgID, 'm5009');
    expect(
      result.messageList.every((m) => m.msgID?.startsWith('old_') != true),
      isTrue,
    );
  });

  test('does not pad with stale local when older cloud is empty', () async {
    final localHead = _range(1, 40, prefix: 'old_');
    final cloudHead = _range(5000, 5009);
    final service = _FakeHistoryService(
      localPages: {
        '': V2TimMessageListResult(isFinished: false, messageList: localHead),
        'm5000': V2TimMessageListResult(
          isFinished: true,
          messageList: localHead,
        ),
      },
      cloudPages: {
        '': V2TimMessageListResult(isFinished: true, messageList: cloudHead),
        'm5000': V2TimMessageListResult(
          isFinished: true,
          messageList: const [],
        ),
      },
    );

    final result = await MessageHistoryPeekLoader.loadOlderLocalThenCloudResult(
      messageService: service,
      count: 40,
      groupID: 'g1',
    );

    expect(result.messageList, hasLength(10));
    expect(result.messageList.first.msgID, 'm5000');
    expect(result.messageList.last.msgID, 'm5009');
    expect(result.isFinished, isFalse);
  });

  test('fills the hole from cloud then merges connecting local', () async {
    final localHead = _range(1, 40, prefix: 'old_');
    final service = _FakeHistoryService(
      localPages: {
        '': V2TimMessageListResult(isFinished: false, messageList: localHead),
        'm50': V2TimMessageListResult(
          isFinished: true,
          messageList: localHead,
        ),
      },
      cloudPages: {
        '': V2TimMessageListResult(
          isFinished: false,
          messageList: _range(50, 59),
        ),
        'm50': V2TimMessageListResult(
          isFinished: true,
          messageList: _range(41, 49),
        ),
      },
    );

    final result = await MessageHistoryPeekLoader.loadOlderLocalThenCloudResult(
      messageService: service,
      count: 20,
      groupID: 'g1',
    );

    expect(service.cloudCalls, greaterThanOrEqualTo(2));
    expect(result.messageList, hasLength(20));
    expect(result.messageList.first.msgID, 'old_40');
    expect(result.messageList.last.msgID, 'm59');
  });

  test('pagination after cloud exhausts returns leftover local', () async {
    final localHead = _range(1, 40, prefix: 'old_');
    final service = _FakeHistoryService(
      localPages: {
        'm5000': V2TimMessageListResult(
          isFinished: true,
          messageList: localHead,
        ),
      },
      cloudPages: {
        'm5000': V2TimMessageListResult(
          isFinished: true,
          messageList: const [],
        ),
      },
    );

    final result = await MessageHistoryPeekLoader.loadOlderLocalThenCloudResult(
      messageService: service,
      count: 40,
      groupID: 'g1',
      lastMsgID: 'm5000',
      lastMsgSeq: 5000,
    );

    expect(result.messageList, hasLength(40));
    expect(result.messageList.first.msgID, 'old_1');
    expect(result.messageList.last.msgID, 'old_40');
  });

  test('concurrent peeks of the same window share one in-flight fetch', () async {
    final cloudHead = _range(1, 40);
    final service = _FakeHistoryService(
      localPages: {
        '': V2TimMessageListResult(isFinished: true, messageList: cloudHead),
      },
      cloudPages: {
        '': V2TimMessageListResult(isFinished: true, messageList: cloudHead),
      },
    )..delay = const Duration(milliseconds: 20);

    final results = await Future.wait(<Future<V2TimMessageListResult>>[
      MessageHistoryPeekLoader.loadOlderLocalThenCloudResult(
        messageService: service,
        count: 40,
        userID: 'u1',
      ),
      MessageHistoryPeekLoader.loadOlderLocalThenCloudResult(
        messageService: service,
        count: 40,
        userID: 'u1',
      ),
    ]);

    expect(service.localCalls, 1);
    expect(service.cloudCalls, 1);
    expect(results[0].messageList, hasLength(40));
    expect(results[1].messageList, hasLength(40));
  });

  test('C2C local-only keeps seq-gapped messages for cold first paint', () async {
    V2TimMessage c2c(String id, {required int seq, required int ts}) {
      final message = _msg(seq, prefix: id);
      message.msgID = id;
      message.timestamp = ts;
      return message;
    }

    final local = [
      c2c('n1', seq: 1981123733, ts: 4000),
      c2c('n2', seq: 1981123715, ts: 3900),
      c2c('n3', seq: 3443731460, ts: 2000),
      c2c('n4', seq: 4222408938, ts: 1000),
    ];
    final service = _FakeHistoryService(
      localPages: {
        '': V2TimMessageListResult(isFinished: true, messageList: local),
      },
      cloudPages: const {},
    );

    final result = await MessageHistoryPeekLoader.loadOlderLocalOnlyResult(
      messageService: service,
      count: 40,
      userID: 'qlahmd3uis',
    );

    expect(service.cloudCalls, 0);
    expect(result.messageList.map((m) => m.msgID), ['n4', 'n3', 'n2', 'n1']);
  });

  test('group local-only still trims a real seq hole', () async {
    final newest = _range(98, 100);
    final stale = _range(49, 50);
    final service = _FakeHistoryService(
      localPages: {
        '': V2TimMessageListResult(
          isFinished: true,
          messageList: [...newest, ...stale],
        ),
      },
      cloudPages: const {},
    );

    final result = await MessageHistoryPeekLoader.loadOlderLocalOnlyResult(
      messageService: service,
      count: 40,
      groupID: '@TGS#_mc2SX4NMM62CZ',
    );

    expect(result.messageList.map((m) => m.seq), ['98', '99', '100']);
  });

  test('C2C cloud older page keeps dual-seq previous 20', () async {
    V2TimMessage c2cOlder(int i) {
      final even = i.isEven;
      final seq = even ? 2220862940 + i : 3347538000 + i;
      final message = _msg(seq, prefix: 'p$i');
      message.msgID = 'prev_$i';
      message.timestamp = 19000 + i;
      return message;
    }

    final olderPage = [for (var i = 0; i < 20; i++) c2cOlder(i)];
    final anchor = _msg(3347538100, prefix: 'anchor');
    anchor.msgID = 'anchor_tip';
    anchor.timestamp = 20020;

    final service = _FakeHistoryService(
      localPages: {
        'anchor_tip': V2TimMessageListResult(
          isFinished: true,
          messageList: olderPage,
        ),
      },
      cloudPages: {
        'anchor_tip': V2TimMessageListResult(
          isFinished: true,
          messageList: olderPage.take(12).toList(growable: false),
        ),
      },
    );

    final result = await MessageHistoryPeekLoader.loadOlderLocalThenCloudResult(
      messageService: service,
      count: 20,
      userID: 'alice',
      lastMsgID: 'anchor_tip',
      lastMsgSeq: 3347538100,
      lastMsg: anchor,
    );

    expect(result.messageList, hasLength(20));
    expect(
      result.messageList.map((m) => m.msgID).toSet(),
      {for (var i = 0; i < 20; i++) 'prev_$i'},
    );
  });

  test('C2C cloud-only returns the SDK page and ignores local extras', () async {
    final cloudPage = _range(80, 99, prefix: 'cloud_');
    final localExtras = _range(1, 20, prefix: 'local_');
    final service = _FakeHistoryService(
      localPages: {
        '': V2TimMessageListResult(
          isFinished: false,
          messageList: localExtras,
        ),
      },
      cloudPages: {
        '': V2TimMessageListResult(
          isFinished: false,
          messageList: cloudPage,
        ),
      },
    );

    final result = await MessageHistoryPeekLoader.loadOlderCloudOnlyResult(
      messageService: service,
      count: 20,
      userID: 'alice',
    );

    expect(service.localCalls, 0);
    expect(service.cloudCalls, 1);
    expect(result.messageList, hasLength(20));
    expect(
      result.messageList.map((m) => m.msgID).toSet(),
      {for (var i = 80; i <= 99; i++) 'cloud_$i'},
    );
  });
}
