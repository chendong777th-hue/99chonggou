import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/history_pagination_continuity.dart';

void main() {
  group('HistoryPaginationContinuity.canPrependNewerBatch', () {
    test('empty incoming → true', () {
      expect(
        HistoryPaginationContinuity.canPrependNewerBatch(
          existingNewestFirst: [(seq: 100, timestamp: 1)],
          incomingNewerNewestFirst: const [],
        ),
        isTrue,
      );
    });

    test('empty existing → true', () {
      expect(
        HistoryPaginationContinuity.canPrependNewerBatch(
          existingNewestFirst: const [],
          incomingNewerNewestFirst: [(seq: 101, timestamp: 2)],
        ),
        isTrue,
      );
    });

    test('contiguous group seqs (newest 100, incoming 102..101) → true', () {
      expect(
        HistoryPaginationContinuity.canPrependNewerBatch(
          existingNewestFirst: [(seq: 100, timestamp: 10)],
          incomingNewerNewestFirst: [
            (seq: 102, timestamp: 12),
            (seq: 101, timestamp: 11),
          ],
        ),
        isTrue,
      );
    });

    test(
        'group seq gap (existing 100, incoming starts at 150) → true '
        '(trust SDK lastMsg cursor, dedupe handles overlap)', () {
      expect(
        HistoryPaginationContinuity.canPrependNewerBatch(
          existingNewestFirst: [(seq: 100, timestamp: 10)],
          incomingNewerNewestFirst: [
            (seq: 152, timestamp: 50),
            (seq: 150, timestamp: 40),
          ],
        ),
        isTrue,
      );
    });

    test('overlap at edge seq → true', () {
      expect(
        HistoryPaginationContinuity.canPrependNewerBatch(
          existingNewestFirst: [(seq: 100, timestamp: 10)],
          incomingNewerNewestFirst: [
            (seq: 101, timestamp: 11),
            (seq: 100, timestamp: 10),
          ],
        ),
        isTrue,
      );
    });

    test(
        'C2C per-sender seq not contiguous but time direction correct → true '
        '(C2C seq has no global continuity)', () {
      // C2C: existing newest is from sender B (seq=3), incoming oldest is
      // from sender A (seq=50). Seq is per-sender, not comparable. But
      // incoming timestamp >= existing timestamp, so direction is correct.
      expect(
        HistoryPaginationContinuity.canPrependNewerBatch(
          existingNewestFirst: [(seq: 3, timestamp: 1000)],
          incomingNewerNewestFirst: [
            (seq: 52, timestamp: 1050),
            (seq: 50, timestamp: 1030),
          ],
        ),
        isTrue,
      );
    });

    test(
        'C2C large time gap but direction correct → true '
        '(no 120s time window check, trust SDK lastMsg)', () {
      expect(
        HistoryPaginationContinuity.canPrependNewerBatch(
          existingNewestFirst: [(seq: null, timestamp: 1000)],
          incomingNewerNewestFirst: [
            (seq: null, timestamp: 5000),
            (seq: null, timestamp: 4000),
          ],
        ),
        isTrue,
      );
    });

    test('incoming older than existing (direction error) → false', () {
      expect(
        HistoryPaginationContinuity.canPrependNewerBatch(
          existingNewestFirst: [(seq: 100, timestamp: 1000)],
          incomingNewerNewestFirst: [
            (seq: 50, timestamp: 500),
            (seq: 49, timestamp: 400),
          ],
        ),
        isFalse,
      );
    });

    test('C2C incoming older → false (direction error)', () {
      expect(
        HistoryPaginationContinuity.canPrependNewerBatch(
          existingNewestFirst: [(seq: null, timestamp: 1000)],
          incomingNewerNewestFirst: [
            (seq: null, timestamp: 900),
            (seq: null, timestamp: 800),
          ],
        ),
        isFalse,
      );
    });

    test('zero timestamps → true (no direction info, trust SDK)', () {
      expect(
        HistoryPaginationContinuity.canPrependNewerBatch(
          existingNewestFirst: [(seq: 100, timestamp: 0)],
          incomingNewerNewestFirst: [
            (seq: 200, timestamp: 0),
            (seq: 150, timestamp: 0),
          ],
        ),
        isTrue,
      );
    });

    test('equal timestamps → true (same second, allow merge)', () {
      expect(
        HistoryPaginationContinuity.canPrependNewerBatch(
          existingNewestFirst: [(seq: 100, timestamp: 500)],
          incomingNewerNewestFirst: [
            (seq: 102, timestamp: 500),
            (seq: 101, timestamp: 500),
          ],
        ),
        isTrue,
      );
    });
  });
}
