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

    test('contiguous group seqs (newest 100, incoming 102..101) → true', () {
      // incoming newest-first: 102, 101 — oldest edge 101 abuts existing 100.
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

    test('gap (existing 100, incoming starts at 150) → false', () {
      expect(
        HistoryPaginationContinuity.canPrependNewerBatch(
          existingNewestFirst: [(seq: 100, timestamp: 10)],
          incomingNewerNewestFirst: [
            (seq: 152, timestamp: 50),
            (seq: 150, timestamp: 40),
          ],
        ),
        isFalse,
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

    test('C2C timestamps within abut window → true', () {
      expect(
        HistoryPaginationContinuity.canPrependNewerBatch(
          existingNewestFirst: [(seq: null, timestamp: 1000)],
          incomingNewerNewestFirst: [
            (seq: null, timestamp: 1050),
            (seq: null, timestamp: 1030),
          ],
        ),
        isTrue,
      );
    });

    test('C2C large time hole → false', () {
      expect(
        HistoryPaginationContinuity.canPrependNewerBatch(
          existingNewestFirst: [(seq: null, timestamp: 1000)],
          incomingNewerNewestFirst: [
            (seq: null, timestamp: 5000),
            (seq: null, timestamp: 4000),
          ],
        ),
        isFalse,
      );
    });
  });
}
