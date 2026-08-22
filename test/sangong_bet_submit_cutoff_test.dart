import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/sangong_bet_submit_cutoff.dart';

void main() {
  group('SangongBetSubmitCutoff', () {
    test('toJson prefers untilMessageId over seq', () {
      const cutoff = SangongBetSubmitCutoff(
        untilMessageId: 165,
        untilMsgSeq: 233,
      );
      expect(cutoff.toJson(), {'untilMessageId': 165});
    });

    test('toJson uses untilMsgSeq when alone', () {
      const cutoff = SangongBetSubmitCutoff(untilMsgSeq: 233);
      expect(cutoff.toJson(), {'untilMsgSeq': 233});
    });

    test('toJson includes excludeMessageId', () {
      const cutoff = SangongBetSubmitCutoff(excludeMessageId: 163);
      expect(cutoff.toJson(), {'excludeMessageId': 163});
    });

    test('toJson combines until and exclude', () {
      const cutoff = SangongBetSubmitCutoff(
        untilMessageId: 169,
        excludeMessageId: 163,
      );
      expect(
        cutoff.toJson(),
        {
          'untilMessageId': 169,
          'excludeMessageId': 163,
        },
      );
    });

    test('toJson dedupes multiple excludes into excludeMessageIds', () {
      const cutoff = SangongBetSubmitCutoff(
        excludeMessageId: 163,
        excludeMessageIds: [165, 163],
      );
      expect(
        cutoff.toJson(),
        {'excludeMessageIds': [163, 165]},
      );
    });

    test('empty cutoff serializes to empty body', () {
      expect(const SangongBetSubmitCutoff().toJson(), isEmpty);
      expect(const SangongBetSubmitCutoff().hasExplicitBoundary, isFalse);
      expect(const SangongBetSubmitCutoff().hasExclusions, isFalse);
    });

    test('withAdditionalExclude merges and dedupes ids', () {
      const cutoff = SangongBetSubmitCutoff(
        untilMessageId: 169,
        excludeMessageId: 163,
      );
      final next = cutoff.withAdditionalExclude(165);
      expect(
        next.toJson(),
        {
          'untilMessageId': 169,
          'excludeMessageIds': [163, 165],
        },
      );
      expect(next.withAdditionalExclude(163).toJson(), next.toJson());
    });
  });
}
