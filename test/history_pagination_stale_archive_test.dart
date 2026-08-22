import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_anchor.dart';

V2TimMessage _msg({required String msgID, required int ts, String? seq}) {
  final message = V2TimMessage.fromJson(<String, dynamic>{
    'message_server_time': ts,
    'message_msg_id': msgID,
    'message_seq': seq,
    'message_status': 2,
    'message_custom_str': '',
    'message_risk_type_identified': 0,
    'message_sender_group_member_info': <String, dynamic>{},
    'message_group_at_user_array': <String>[],
  });
  message.timestamp = ts;
  return message;
}

V2TimMessage _sdkMessage({required int ts, required int seq}) {
  return _msg(
    msgID: '144115267800000000-$ts-100000$seq',
    ts: ts,
    seq: '$seq',
  );
}

V2TimMessage _archiveMessage({required int ts, required int seq}) {
  return _msg(msgID: '@TGS#TESTGROUP:$seq', ts: ts, seq: '$seq');
}

V2TimMessage _localTip({required int ts}) {
  return _msg(msgID: 'local_gt_$ts', ts: ts);
}

void main() {
  // 参考时间 now，归档消息统一比它旧一大截（> staleGapSec）。
  const now = 1783785635;
  const oldTs = now - 100000;

  group('isStaleArchiveDominatedWindow', () {
    test('all-archive window much older than reference is stale', () {
      final window = [
        _archiveMessage(ts: oldTs, seq: 593),
        _archiveMessage(ts: oldTs - 10, seq: 592),
        _archiveMessage(ts: oldTs - 20, seq: 591),
      ];
      expect(
        HistoryPaginationAnchor.isStaleArchiveDominatedWindow(
          window,
          referenceTimestampSec: now,
        ),
        isTrue,
      );
    });

    test('archive window with fresh local tip on top is stale', () {
      // 清空后旧归档误灌 + 本地 tip：本地注入不算窗口新鲜度，仍判过期。
      final window = [
        _localTip(ts: now),
        _archiveMessage(ts: oldTs, seq: 593),
        _archiveMessage(ts: oldTs - 10, seq: 592),
      ];
      expect(
        HistoryPaginationAnchor.isStaleArchiveDominatedWindow(window),
        isTrue,
      );
    });

    test('fresh sdk messages on top of archive tail is NOT stale', () {
      // 合法分页窗口：顶部是最新 SDK 消息，下面是更早的归档历史。
      // 之前按「最新归档 vs 参考时间」误判过期，导致进页 62→3 闪变。
      final window = [
        _sdkMessage(ts: now, seq: 595),
        _sdkMessage(ts: now - 180, seq: 594),
        for (var i = 0; i < 20; i++)
          _archiveMessage(ts: oldTs - i * 10, seq: 593 - i),
      ];
      expect(
        HistoryPaginationAnchor.isStaleArchiveDominatedWindow(window),
        isFalse,
      );
      expect(
        HistoryPaginationAnchor.isStaleArchiveDominatedWindow(
          window,
          referenceTimestampSec: now,
        ),
        isFalse,
      );
    });

    test('window without archive messages is never stale', () {
      final window = [
        _sdkMessage(ts: oldTs, seq: 10),
        _sdkMessage(ts: oldTs - 10, seq: 9),
      ];
      expect(
        HistoryPaginationAnchor.isStaleArchiveDominatedWindow(
          window,
          referenceTimestampSec: now,
        ),
        isFalse,
      );
    });
  });

  group('oldestImSdkPaginationAnchor', () {
    test('skips archive rows and local tips', () {
      final imOldest = _sdkMessage(ts: now - 50, seq: 10);
      final window = [
        _sdkMessage(ts: now, seq: 12),
        imOldest,
        _archiveMessage(ts: now - 500, seq: 1),
        _localTip(ts: now - 800),
      ];
      expect(
        HistoryPaginationAnchor.oldestImSdkPaginationAnchor(window)?.msgID,
        imOldest.msgID,
      );
    });

    test('cloud older page tail is the last SDK row, not the newest', () {
      final newest = _sdkMessage(ts: now, seq: 12);
      final mid = _sdkMessage(ts: now - 10, seq: 11);
      final oldest = _sdkMessage(ts: now - 20, seq: 10);
      expect(
        HistoryPaginationAnchor.tailOfCloudOlderPage(
          <V2TimMessage>[newest, mid, oldest],
        )?.msgID,
        oldest.msgID,
      );
    });

    test('C2C official cursor prefers last SDK page tail over window oldest',
        () {
      final firstPageOldest = _sdkMessage(ts: now - 20, seq: 10);
      final weldedOlder = _sdkMessage(ts: now - 400, seq: 2);
      final window = <V2TimMessage>[
        _sdkMessage(ts: now, seq: 12),
        firstPageOldest,
        weldedOlder,
      ];
      expect(
        HistoryPaginationAnchor.c2cOfficialOlderCursor(
          newestFirstWindow: window,
          lastSdkPageTail: firstPageOldest,
        )?.msgID,
        firstPageOldest.msgID,
      );
      expect(
        HistoryPaginationAnchor.c2cOfficialOlderCursor(
          newestFirstWindow: window,
          lastSdkPageTail: null,
          firstScreenCount: 2,
        )?.msgID,
        firstPageOldest.msgID,
      );
    });

    test('skips C2C archiveHistory marker even with SDK-looking id', () {
      final im = _sdkMessage(ts: now - 10, seq: 8);
      final archive = _sdkMessage(ts: now - 400, seq: 2);
      archive.localCustomData = '{"archiveHistory":true}';
      expect(
        HistoryPaginationAnchor.oldestImSdkPaginationAnchor(
          <V2TimMessage>[im, archive],
        )?.msgID,
        im.msgID,
      );
    });
  });
}
