import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';

void main() {
  test('enables bounded local C2C warm on press', () {
    expect(ConversationPerfFlags.pressWarmOnTapDownEnabled, isTrue);

    final source = File('lib/src/conversation.dart').readAsStringSync();
    final start = source.indexOf('void _warmConversationOnPress(');
    final end = source.indexOf('\n  }', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(end, greaterThan(start));

    final body = source.substring(start, end);
    expect(body.contains("reason: 'c2c_press'"), isTrue);
    expect(body.contains('scheduleTargetLocalWarm('), isTrue);
    expect(body.contains('schedulePressWarm(conversation)'), isFalse);
  });
}
