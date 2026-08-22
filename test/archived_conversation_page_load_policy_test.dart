import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_perf_flags.dart';

void main() {
  group('archive list load policy flags', () {
    test('true page and defer probe defaults match plan', () {
      expect(ConversationPerfFlags.archiveTruePageEnabled, isTrue);
      expect(ConversationPerfFlags.archiveDeferFullMissingProbe, isTrue);
      expect(ConversationPerfFlags.archiveColdHydrateBatchSize, greaterThan(0));
      expect(ConversationPerfFlags.archiveListEmergencyCap, greaterThan(0));
      expect(ConversationPerfFlags.archiveIdIndexPersistent, isFalse);
    });
  });
}
