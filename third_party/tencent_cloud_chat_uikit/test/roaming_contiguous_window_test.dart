import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/roaming_contiguous_window.dart';

class _Msg {
  const _Msg(this.id, {this.seq = 0, this.ts = 0});

  final String id;
  final int seq;
  final int ts;
}

List<_Msg> _merge({
  required List<_Msg> local,
  required List<_Msg> cloud,
  int count = 40,
}) {
  return RoamingContiguousWindow.mergeLocalCloudTakeNewest(
    local: local,
    cloud: cloud,
    count: count,
    idOf: (m) => m.id,
    seqOf: (m) => m.seq,
    timestampSecOf: (m) => m.ts,
  );
}

void main() {
  group('RoamingContiguousWindow.mergeLocalCloudTakeNewest', () {
    test('drops stale local when cloud has the newest 40', () {
      final local = [
        for (var i = 1; i <= 40; i++) _Msg('old_$i', seq: i, ts: 1000 + i),
      ];
      final cloud = [
        for (var i = 5000; i <= 5039; i++)
          _Msg('new_$i', seq: i, ts: 90000 + i),
      ];
      final window = _merge(local: local, cloud: cloud);
      expect(window, hasLength(40));
      expect(window.first.id, 'new_5000');
      expect(window.last.id, 'new_5039');
    });

    test('does not pad a short cloud page with months-old local', () {
      final local = [
        for (var i = 1; i <= 40; i++) _Msg('old_$i', seq: i, ts: 1000 + i),
      ];
      final cloud = [
        for (var i = 5000; i <= 5009; i++)
          _Msg('new_$i', seq: i, ts: 90000 + i),
      ];
      final window = _merge(local: local, cloud: cloud);
      expect(window.map((m) => m.id).toList(), [
        for (var i = 5000; i <= 5009; i++) 'new_$i',
      ]);
    });

    test('keeps local-only consecutive window when cloud is empty', () {
      final local = [
        for (var i = 10; i <= 49; i++) _Msg('l_$i', seq: i, ts: 2000 + i),
      ];
      final window = _merge(local: local, cloud: const []);
      expect(window, hasLength(40));
      expect(window.first.id, 'l_10');
      expect(window.last.id, 'l_49');
    });

    test('C2C local-only seq holes stay when all ids are trusted', () {
      final local = [
        _Msg('n4', seq: 4222408938, ts: 1000),
        _Msg('n3', seq: 3443731460, ts: 2000),
        _Msg('n2', seq: 1981123715, ts: 3900),
        _Msg('n1', seq: 1981123733, ts: 4000),
      ];
      final trusted = {for (final m in local) m.id};
      final union = RoamingContiguousWindow.unionSorted(
        local,
        const <_Msg>[],
        idOf: (m) => m.id,
        seqOf: (m) => m.seq,
        timestampSecOf: (m) => m.ts,
      );
      final spine = RoamingContiguousWindow.keepNewestContiguousSpine(
        ascending: union,
        trustedIds: trusted,
        idOf: (m) => m.id,
        seqOf: (m) => m.seq,
        timestampSecOf: (m) => m.ts,
      );
      expect(spine.map((m) => m.id).toList(), ['n4', 'n3', 'n2', 'n1']);
    });

    test('C2C without seq keeps cloud spine and drops older local', () {
      final local = [
        _Msg('old_a', ts: 100),
        _Msg('old_b', ts: 110),
      ];
      final cloud = [
        _Msg('c1', ts: 80000),
        _Msg('c2', ts: 80010),
        _Msg('c3', ts: 80020),
      ];
      final window = _merge(local: local, cloud: cloud);
      expect(window.map((m) => m.id).toList(), ['c1', 'c2', 'c3']);
    });

    test('keeps trusted cloud messages across a deleted seq hole', () {
      final local = [
        for (var i = 1; i <= 40; i++) _Msg('old_$i', seq: i, ts: 1000 + i),
      ];
      final cloud = [
        for (var i = 5000; i <= 5019; i++)
          _Msg('new_$i', seq: i, ts: 90000 + i),
        for (var i = 5025; i <= 5044; i++)
          _Msg('new_$i', seq: i, ts: 90000 + i),
      ];
      final window = _merge(local: local, cloud: cloud);
      expect(window, hasLength(40));
      expect(window.first.id, 'new_5000');
      expect(window.last.id, 'new_5044');
      expect(window.any((m) => m.id.startsWith('old_')), isFalse);
    });
  });

  group('RoamingContiguousWindow.unionSorted / shouldMergeOlderPage', () {
    test('unionSorted keeps disconnected old local for later hole fill', () {
      final local = [
        for (var i = 1; i <= 40; i++) _Msg('old_$i', seq: i, ts: 1000 + i),
      ];
      final cloud = [
        for (var i = 5000; i <= 5009; i++)
          _Msg('new_$i', seq: i, ts: 90000 + i),
      ];
      final union = RoamingContiguousWindow.unionSorted(
        local,
        cloud,
        idOf: (m) => m.id,
        seqOf: (m) => m.seq,
        timestampSecOf: (m) => m.ts,
      );
      expect(union, hasLength(50));
      expect(union.first.id, 'old_1');
      expect(union.last.id, 'new_5009');
    });

    test('shouldMergeOlderPage accepts a near cloud page and rejects months-old local', () {
      final newer = [
        for (var i = 5000; i <= 5009; i++)
          _Msg('n_$i', seq: i, ts: 90000 + i),
      ];
      final cloudOlder = [
        for (var i = 4960; i <= 4999; i++)
          _Msg('c_$i', seq: i, ts: 89000 + i),
      ];
      final staleLocal = [
        for (var i = 1; i <= 40; i++) _Msg('old_$i', seq: i, ts: 1000 + i),
      ];
      expect(
        RoamingContiguousWindow.shouldMergeOlderPage(
          newer: newer,
          older: cloudOlder,
          pageSize: 40,
          idOf: (m) => m.id,
          seqOf: (m) => m.seq,
          timestampSecOf: (m) => m.ts,
        ),
        isTrue,
      );
      expect(
        RoamingContiguousWindow.shouldMergeOlderPage(
          newer: newer,
          older: staleLocal,
          pageSize: 40,
          idOf: (m) => m.id,
          seqOf: (m) => m.seq,
          timestampSecOf: (m) => m.ts,
        ),
        isFalse,
      );
    });

    test('C2C dual seq spaces merge by time, not group seq', () {
      final newer = [
        for (var i = 0; i < 20; i++)
          _Msg('n_$i', seq: 3347538080 + i, ts: 20000 + i),
      ];
      final older = [
        for (var i = 0; i < 20; i++)
          _Msg('o_$i', seq: 2220862940 + i, ts: 19980 + i),
      ];
      expect(
        RoamingContiguousWindow.shouldMergeOlderPage(
          newer: newer,
          older: older,
          pageSize: 20,
          idOf: (m) => m.id,
          seqOf: (m) => m.seq,
          timestampSecOf: (m) => m.ts,
        ),
        isFalse,
      );
      expect(
        RoamingContiguousWindow.shouldMergeOlderPage(
          newer: newer,
          older: older,
          pageSize: 20,
          idOf: (m) => m.id,
          seqOf: (m) => m.seq,
          timestampSecOf: (m) => m.ts,
          useSeqContiguity: false,
        ),
        isTrue,
      );
    });

    test('C2C lastMsg page accepts adjacent dual-seq and rejects overlap weld',
        () {
      final newer = [
        for (var i = 0; i < 20; i++)
          _Msg('n_$i', seq: 3347538080 + i, ts: 20000 + i),
      ];
      final older = [
        for (var i = 0; i < 20; i++)
          _Msg('o_$i', seq: 2220862940 + i, ts: 19980 + i),
      ];
      expect(
        RoamingContiguousWindow.shouldMergeC2cOlderPageByLastMsg(
          newer: newer,
          older: older,
          lastMsgId: 'n_0',
          lastMsgTs: 20000,
          idOf: (m) => m.id,
          timestampSecOf: (m) => m.ts,
        ),
        isTrue,
      );
      final overlapWeld = [
        for (var i = 0; i < 20; i++)
          _Msg('w_$i', seq: 2220862940 + i, ts: 20005 + i),
      ];
      expect(
        RoamingContiguousWindow.shouldMergeC2cOlderPageByLastMsg(
          newer: newer,
          older: overlapWeld,
          lastMsgId: 'n_0',
          lastMsgTs: 20000,
          idOf: (m) => m.id,
          timestampSecOf: (m) => m.ts,
        ),
        isFalse,
      );
    });

    test('C2C dual seq spaces reject a months-old page', () {
      const newerBase =
          (RoamingContiguousWindow.roamingCoverageDays + 2) * 86400;
      final newer = [
        for (var i = 0; i < 20; i++)
          _Msg('n_$i', seq: 3347538080 + i, ts: newerBase + i),
      ];
      final stale = [
        for (var i = 0; i < 20; i++)
          _Msg('old_$i', seq: 2220862940 + i, ts: 1000 + i),
      ];
      expect(
        RoamingContiguousWindow.shouldMergeOlderPage(
          newer: newer,
          older: stale,
          pageSize: 20,
          idOf: (m) => m.id,
          seqOf: (m) => m.seq,
          timestampSecOf: (m) => m.ts,
          useSeqContiguity: false,
        ),
        isFalse,
      );
    });
  });

  group('RoamingContiguousWindow.absorbOlderBatch', () {
    test('prepends a connecting cloud previous page', () {
      final newer = [
        for (var i = 100; i <= 109; i++) _Msg('n_$i', seq: i, ts: 5000 + i),
      ];
      final older = [
        for (var i = 60; i <= 99; i++) _Msg('o_$i', seq: i, ts: 4000 + i),
      ];
      final merged = RoamingContiguousWindow.absorbOlderBatch(
        newerSpine: newer,
        olderBatch: older,
        olderCloudBacked: true,
        idOf: (m) => m.id,
        seqOf: (m) => m.seq,
        timestampSecOf: (m) => m.ts,
      );
      expect(merged.first.seq, 60);
      expect(merged.last.seq, 109);
      expect(merged, hasLength(50));
    });

    test('rejects disconnected local older page', () {
      final newer = [
        for (var i = 5000; i <= 5009; i++)
          _Msg('n_$i', seq: i, ts: 90000 + i),
      ];
      final older = [
        for (var i = 1; i <= 40; i++) _Msg('old_$i', seq: i, ts: 1000 + i),
      ];
      final merged = RoamingContiguousWindow.absorbOlderBatch(
        newerSpine: newer,
        olderBatch: older,
        olderCloudBacked: false,
        idOf: (m) => m.id,
        seqOf: (m) => m.seq,
        timestampSecOf: (m) => m.ts,
      );
      expect(merged.map((m) => m.seq).toList(), [
        for (var i = 5000; i <= 5009; i++) i,
      ]);
    });

    test('C2C cloud previous page connects across a long silence', () {
      final newer = [_Msg('n1', ts: 80000), _Msg('n2', ts: 80010)];
      final older = [_Msg('o1', ts: 10000), _Msg('o2', ts: 10020)];
      final merged = RoamingContiguousWindow.absorbOlderBatch(
        newerSpine: newer,
        olderBatch: older,
        olderCloudBacked: true,
        idOf: (m) => m.id,
        seqOf: (m) => m.seq,
        timestampSecOf: (m) => m.ts,
      );
      expect(merged.map((m) => m.id).toList(), ['o1', 'o2', 'n1', 'n2']);
    });

    test('prepends a cloud previous page across a deleted seq hole', () {
      final newer = [
        for (var i = 5000; i <= 5009; i++)
          _Msg('n_$i', seq: i, ts: 90000 + i),
      ];
      final older = [
        for (var i = 4960; i <= 4998; i++)
          _Msg('o_$i', seq: i, ts: 89000 + i),
      ];
      final merged = RoamingContiguousWindow.absorbOlderBatch(
        newerSpine: newer,
        olderBatch: older,
        olderCloudBacked: true,
        idOf: (m) => m.id,
        seqOf: (m) => m.seq,
        timestampSecOf: (m) => m.ts,
      );
      expect(merged.first.seq, 4960);
      expect(merged.last.seq, 5009);
      expect(merged, hasLength(49));
    });
  });
}
