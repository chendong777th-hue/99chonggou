import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_main_thread_perf.dart';

void main() {
  setUp(() {
    ChatMainThreadPerf.debugForceEnabled = true;
    ChatMainThreadPerf.resetCounters();
  });

  tearDown(() {
    ChatMainThreadPerf.debugForceEnabled = false;
    ChatMainThreadPerf.resetCounters();
  });

  test('captures aggregate list commit counters only when enabled', () {
    ChatMainThreadPerf.increment('message_list_noop_commit', amount: 2);
    ChatMainThreadPerf.increment('message_list_structural_commit');
    expect(
      ChatMainThreadPerf.countersSnapshot(),
      containsPair('message_list_noop_commit', 2),
    );
    expect(
      ChatMainThreadPerf.countersSnapshot(),
      containsPair('message_list_structural_commit', 1),
    );
  });
}
