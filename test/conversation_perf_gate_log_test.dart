import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_gate_log.dart';

void main() {
  test('ConvPerfGateLog counts events for acceptance checks', () {
    ConversationPerfGateLog.resetCountsForTest();
    final prev = ConversationPerfGateLog.enabled;
    ConversationPerfGateLog.enabled = false;
    try {
      ConversationPerfGateLog.log(
        'ui_apply_deferred',
        extras: <String, Object?>{'cause': 'scroll', 'count': 1},
      );
      ConversationPerfGateLog.log(
        'ui_apply_flush',
        extras: <String, Object?>{'reason': 'scroll_end', 'pendingCount': 1},
      );
      expect(ConversationPerfGateLog.eventCountsForTest['ui_apply_deferred'], 1);
      expect(ConversationPerfGateLog.eventCountsForTest['ui_apply_flush'], 1);
    } finally {
      ConversationPerfGateLog.enabled = prev;
    }
  });
}
