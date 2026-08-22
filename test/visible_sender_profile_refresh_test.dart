import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/visible_sender_profile_refresh.dart';

void main() {
  group('VisibleSenderProfileRefresh.selectIdsForFlush', () {
    test('filters self empty and ttl-fresh ids and respects max', () {
      final selected = VisibleSenderProfileRefresh.selectIdsForFlush(
        pending: <String>['', ' self ', 'a', 'b', 'c', 'd'],
        lastRefreshMs: <String, int>{
          'a': 1000,
          'b': 0,
        },
        nowMs: 1000 + VisibleSenderProfileRefresh.ttl.inMilliseconds - 1,
        ttlMs: VisibleSenderProfileRefresh.ttl.inMilliseconds,
        maxPerFlush: 2,
        selfUserId: 'self',
      );
      expect(selected, <String>['b', 'c']);
    });

    test('includes ttl-expired ids', () {
      final ttl = VisibleSenderProfileRefresh.ttl.inMilliseconds;
      final selected = VisibleSenderProfileRefresh.selectIdsForFlush(
        pending: <String>['a'],
        lastRefreshMs: <String, int>{'a': 0},
        nowMs: ttl + 1,
        ttlMs: ttl,
        maxPerFlush: 25,
        selfUserId: null,
      );
      expect(selected, <String>['a']);
    });
  });
}
