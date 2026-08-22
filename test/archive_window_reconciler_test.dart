import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/archive_window_reconciler.dart';

ArchiveMessageProbe _msg({
  required String id,
  required int tsSec,
  int seq = -1,
  bool isLocalTip = false,
}) {
  return ArchiveMessageProbe(
    id: id,
    timestampSec: tsSec,
    seq: seq,
    isLocalTip: isLocalTip,
  );
}

void main() {
  group('ArchiveWindowReconciler.detectGaps', () {
    test('group seq+1 is not a gap', () {
      final list = [
        _msg(id: 'a', tsSec: 100, seq: 10),
        _msg(id: 'b', tsSec: 101, seq: 11),
      ];
      expect(
        ArchiveWindowReconciler.detectGaps(list, isGroup: true),
        isEmpty,
      );
    });

    test('group seq+2 is a gap', () {
      final list = [
        _msg(id: 'a', tsSec: 100, seq: 10),
        _msg(id: 'b', tsSec: 110, seq: 12),
      ];
      final gaps = ArchiveWindowReconciler.detectGaps(list, isGroup: true);
      expect(gaps, hasLength(1));
      expect(gaps.first.reason, 'seq_10_12');
    });

    test('rizhi-like bottom-up holes produce multiple gaps', () {
      // IM_RENDER_ORDER bottomUp seq=26,25,23,21,20,18,16,15 → ascending:
      final list = [
        _msg(id: 's15', tsSec: 1785680954, seq: 15),
        _msg(id: 's16', tsSec: 1785680955, seq: 16),
        _msg(id: 's18', tsSec: 1785680958, seq: 18),
        _msg(id: 's20', tsSec: 1785680959, seq: 20),
        _msg(id: 's21', tsSec: 1785680961, seq: 21),
        _msg(id: 's23', tsSec: 1785680962, seq: 23),
        _msg(id: 's25', tsSec: 1785680963, seq: 25),
        _msg(id: 's26', tsSec: 1785680975, seq: 26),
      ];
      final gaps = ArchiveWindowReconciler.detectGaps(list, isGroup: true);
      expect(gaps, hasLength(3)); // maxGapsPerOpen default
      expect(gaps.map((g) => g.reason).toList(), [
        'seq_16_18',
        'seq_18_20',
        'seq_21_23',
      ]);
    });

    test('skips local tips as anchors', () {
      final list = [
        _msg(id: 'a', tsSec: 100, seq: 10),
        _msg(id: 'local_gt_1', tsSec: 105, seq: 11, isLocalTip: true),
        _msg(id: 'b', tsSec: 110, seq: 12),
      ];
      final gaps = ArchiveWindowReconciler.detectGaps(list, isGroup: true);
      expect(gaps, hasLength(1));
      expect(gaps.first.olderId, 'a');
      expect(gaps.first.newerId, 'b');
    });

    test('c2c time threshold', () {
      expect(
        ArchiveWindowReconciler.detectGaps(
          [
            _msg(id: 'a', tsSec: 100),
            _msg(id: 'b', tsSec: 400),
          ],
          isGroup: false,
        ),
        hasLength(1),
      );
      expect(
        ArchiveWindowReconciler.detectGaps(
          [
            _msg(id: 'a', tsSec: 100),
            _msg(id: 'b', tsSec: 200),
          ],
          isGroup: false,
        ),
        isEmpty,
      );
    });
  });

  group('WarmOpenReconcilePlan.decide', () {
    test('gaps trigger cloud merge and always archive', () {
      final plan = WarmOpenReconcilePlan.decide(gapCount: 3);
      expect(plan.willCloudMerge, isTrue);
      expect(plan.willArchiveReconcile, isTrue);
      expect(plan.gapCount, 3);
    });

    test('no gaps still schedules archive only', () {
      final plan = WarmOpenReconcilePlan.decide(gapCount: 0);
      expect(plan.willCloudMerge, isFalse);
      expect(plan.willArchiveReconcile, isTrue);
    });
  });

  group('ArchiveWindowReconciler.missingGroupSeqs', () {
    test('seq 10..15 yields 11..14', () {
      expect(
        ArchiveWindowReconciler.missingGroupSeqs(olderSeq: 10, newerSeq: 15),
        [11, 12, 13, 14],
      );
    });

    test('adjacent seq empty', () {
      expect(
        ArchiveWindowReconciler.missingGroupSeqs(olderSeq: 10, newerSeq: 11),
        isEmpty,
      );
    });
  });

  group('ArchiveWindowReconciler.cloudTimeRangeForGap', () {
    test('maps older/newer to CLOUD_OLDER window', () {
      final range = ArchiveWindowReconciler.cloudTimeRangeForGap(
        olderSec: 1000,
        newerSec: 1600,
      );
      expect(range.timeBegin, 1600);
      expect(range.timePeriod, 600);
    });
  });

  group('ArchiveWindowReconciler.filterForWindowReconcile', () {
    test('keeps in-window and older-than-oldest', () {
      final filtered = ArchiveWindowReconciler.filterForWindowReconcile(
        [
          _msg(id: 'older', tsSec: 50),
          _msg(id: 'in', tsSec: 150),
          _msg(id: 'edge', tsSec: 200),
          _msg(id: 'after', tsSec: 250),
        ],
        oldestSec: 100,
        newestSec: 200,
        timestampSecOf: (m) => m.timestampSec,
      );
      expect(filtered.map((m) => m.id).toList(), ['older', 'in', 'edge']);
    });
  });

  group('ArchiveWindowReconciler.filterStrictlyBetweenSec', () {
    test('open interval', () {
      final filtered = ArchiveWindowReconciler.filterStrictlyBetweenSec(
        [
          _msg(id: 'a', tsSec: 100),
          _msg(id: 'b', tsSec: 150),
          _msg(id: 'c', tsSec: 200),
        ],
        olderSec: 100,
        newerSec: 200,
        timestampSecOf: (m) => m.timestampSec,
      );
      expect(filtered.map((m) => m.id).toList(), ['b']);
    });
  });
}
