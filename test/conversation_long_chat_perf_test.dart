import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_history_warm_scheduler.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_unread_aggregate.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('unread aggregate treats ui_apply_deferred as bulk debounce', () {
    expect(
      ConversationUnreadAggregate.isBulkRefreshReason('ui_apply_deferred_scroll'),
      isTrue,
    );
    expect(
      ConversationUnreadAggregate.instance
          .debounceForReasonForTest('ui_apply_deferred_scroll'),
      const Duration(milliseconds: 800),
    );
    expect(
      ConversationUnreadAggregate.instance.debounceForReasonForTest('manual'),
      const Duration(milliseconds: 220),
    );
  });

  test('viewport local miss map respects hard cap', () {
    final warm = ConversationHistoryWarmScheduler.instance;
    warm.resetForTest();
    final cap = ConversationHistoryWarmScheduler.viewportLocalMissCap;
    for (var i = 0; i < cap + 40; i++) {
      warm.rememberViewportLocalMissForTest('miss_$i');
    }
    expect(warm.viewportLocalMissMapSizeForTest, lessThanOrEqualTo(cap));
  });
}
