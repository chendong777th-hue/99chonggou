import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/chat_thermal_perf.dart';

void main() {
  setUp(() {
    ChatThermalPerf.debugForceEnabled = true;
    ChatThermalPerf.reset();
  });

  tearDown(() {
    ChatThermalPerf.debugForceEnabled = false;
    ChatThermalPerf.debugSink = null;
    ChatThermalPerf.reset();
  });

  test('counters are aggregate and snapshot is immutable', () {
    ChatThermalPerf.increment('task_started', amount: 2);
    ChatThermalPerf.increment('task_completed');
    final snapshot = ChatThermalPerf.snapshot();
    expect(snapshot['task_started'], 2);
    expect(snapshot['task_completed'], 1);
    expect(() => snapshot['task_started'] = 9, throwsUnsupportedError);
  });

  test('labels are sanitized before emission', () {
    final lines = <String>[];
    ChatThermalPerf.debugSink = lines.add;
    ChatThermalPerf.record('message merge/ms', 1.5);
    expect(lines.single, contains('metric=message_merge_ms'));
  });
}
