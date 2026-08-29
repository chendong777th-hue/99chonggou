import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html)
      'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/inbound_reorder_buffer.dart';

V2TimMessage _msg(int seq, {String msgID = '', int timestamp = 0}) {
  return V2TimMessage(
    msgID: msgID.isEmpty ? 'm$seq' : msgID,
    seq: '$seq',
    timestamp: timestamp == 0 ? seq * 10 : timestamp,
    isSelf: false,
    elemType: 1,
  );
}

void main() {
  group('InboundReorderBuffer', () {
    test('not activated: all messages pass through', () {
      final flushed = <List<V2TimMessage>>[];
      final timeouts = <int>[];
      final buffer = InboundReorderBuffer(
        onFlush: flushed.add,
        onGapTimeout: (seq, _) => timeouts.add(seq),
      );
      addTearDown(buffer.dispose);
      // Not activated yet.
      final result = buffer.accept(_msg(101));
      expect(result, isNotNull);
      expect(result, hasLength(1));
      expect(result!.first.seq, '101');
      expect(flushed, isEmpty);
      expect(timeouts, isEmpty);
    });

    test('contiguous seq: message accepted immediately, no buffering', () {
      final flushed = <List<V2TimMessage>>[];
      final timeouts = <int>[];
      final buffer = InboundReorderBuffer(
        onFlush: flushed.add,
        onGapTimeout: (seq, _) => timeouts.add(seq),
      );
      addTearDown(buffer.dispose);
      buffer.activate('group_g1', 100);
      expect(buffer.isActivated, isTrue);
      expect(buffer.expectedSeq, 101);

      final result = buffer.accept(_msg(101));
      expect(result, isNotNull);
      expect(result, hasLength(1));
      expect(result!.first.seq, '101');
      expect(buffer.expectedSeq, 102);
      expect(flushed, isEmpty);
      expect(timeouts, isEmpty);
    });

    test('older seq (< expected): silently dropped', () {
      final flushed = <List<V2TimMessage>>[];
      final buffer = InboundReorderBuffer(
        onFlush: flushed.add,
        onGapTimeout: (_, __) {},
      );
      addTearDown(buffer.dispose);
      buffer.activate('group_g1', 100);

      final result = buffer.accept(_msg(100));
      expect(result, isNotNull);
      expect(result, isEmpty);
      expect(flushed, isEmpty);
    });

    test('seq gap: message buffered, timeout triggers flush + catch-up',
        () async {
      final flushed = <List<V2TimMessage>>[];
      final timeouts = <int>[];
      final buffer = InboundReorderBuffer(
        onFlush: flushed.add,
        onGapTimeout: (seq, _) => timeouts.add(seq),
        timeout: const Duration(milliseconds: 50),
      );
      addTearDown(buffer.dispose);
      buffer.activate('group_g1', 100);

      // seq 103 arrives but 101, 102 missing → buffered.
      final result = buffer.accept(_msg(103));
      expect(result, isNull); // buffered
      expect(flushed, isEmpty);
      expect(timeouts, isEmpty);

      // Wait for timeout.
      await Future.delayed(const Duration(milliseconds: 80));

      expect(flushed, hasLength(1));
      expect(flushed.first, hasLength(1));
      expect(flushed.first.first.seq, '103');
      expect(timeouts, hasLength(1));
      expect(timeouts.first, 101);
    });

    test('out-of-order: 103 first, 101 arrives within timeout → both flush', () {
      final flushed = <List<V2TimMessage>>[];
      final timeouts = <int>[];
      final buffer = InboundReorderBuffer(
        onFlush: flushed.add,
        onGapTimeout: (seq, _) => timeouts.add(seq),
        timeout: const Duration(milliseconds: 200),
      );
      addTearDown(buffer.dispose);
      buffer.activate('group_g1', 100);

      // 103 arrives first (gap: 101, 102 missing) → buffered.
      final result103 = buffer.accept(_msg(103));
      expect(result103, isNull);

      // 101 arrives within timeout → contiguous from expected (101).
      final result101 = buffer.accept(_msg(101));
      expect(result101, isNotNull);
      expect(result101, hasLength(1));
      expect(result101!.first.seq, '101');
      expect(buffer.expectedSeq, 102);

      // 102 still missing, 103 still in buffer.
      // When 102 arrives, it should drain 102 and 103.
      final result102 = buffer.accept(_msg(102));
      expect(result102, isNotNull);
      expect(result102, hasLength(2));
      expect(result102![0].seq, '102');
      expect(result102[1].seq, '103');
      expect(buffer.expectedSeq, 104);

      // Buffer should be empty, timer cancelled.
      expect(timeouts, isEmpty);
    });

    test('maxPending overflow: forces flush immediately', () {
      final flushed = <List<V2TimMessage>>[];
      final timeouts = <int>[];
      final buffer = InboundReorderBuffer(
        onFlush: flushed.add,
        onGapTimeout: (seq, _) => timeouts.add(seq),
        timeout: const Duration(seconds: 10),
        maxPending: 3,
      );
      addTearDown(buffer.dispose);
      buffer.activate('group_g1', 100);

      // Gap: 101 missing. Buffer 102, 103, 104.
      buffer.accept(_msg(102));
      buffer.accept(_msg(103));
      expect(flushed, isEmpty);
      buffer.accept(_msg(104)); // 3rd pending → overflow
      expect(flushed, hasLength(1));
      expect(flushed.first, hasLength(3));
      expect(timeouts, hasLength(1));
      expect(timeouts.first, 101);
    });

    test('dispose cancels timer and clears pending', () {
      final flushed = <List<V2TimMessage>>[];
      final buffer = InboundReorderBuffer(
        onFlush: flushed.add,
        onGapTimeout: (_, __) {},
        timeout: const Duration(seconds: 10),
      );
      addTearDown(buffer.dispose);
      buffer.activate('group_g1', 100);
      buffer.accept(_msg(103)); // buffered

      buffer.dispose();
      expect(buffer.isActivated, isFalse);

      // After dispose, accept passes through.
      final result = buffer.accept(_msg(104));
      expect(result, isNotNull);
      expect(result, hasLength(1));
    });

    test('seq=0 (invalid): passes through without gap check', () {
      final flushed = <List<V2TimMessage>>[];
      final buffer = InboundReorderBuffer(
        onFlush: flushed.add,
        onGapTimeout: (_, __) {},
      );
      addTearDown(buffer.dispose);
      buffer.activate('group_g1', 100);

      final result = buffer.accept(_msg(0, msgID: 'tip'));
      expect(result, isNotNull);
      expect(result, hasLength(1));
    });

    test('timeout release is not emitted again after missing seqs arrive',
        () async {
      final flushed = <List<V2TimMessage>>[];
      final timeouts = <int>[];
      final buffer = InboundReorderBuffer(
        onFlush: flushed.add,
        onGapTimeout: (seq, _) => timeouts.add(seq),
        timeout: const Duration(milliseconds: 20),
      );
      addTearDown(buffer.dispose);
      buffer.activate('group_g1', 100);

      expect(buffer.accept(_msg(103)), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(flushed.single.map((message) => message.seq), ['103']);
      expect(buffer.releasedAheadCount, 1);

      expect(buffer.accept(_msg(101))!.map((message) => message.seq), ['101']);
      expect(buffer.accept(_msg(102))!.map((message) => message.seq), ['102']);
      expect(buffer.expectedSeq, 104);
      expect(buffer.releasedAheadCount, 0);
      expect(buffer.accept(_msg(103)), isEmpty);
      expect(timeouts, [101]);
    });

    test('same released Seq with a different msgID is preserved as a conflict',
        () async {
      final flushed = <List<V2TimMessage>>[];
      final buffer = InboundReorderBuffer(
        onFlush: flushed.add,
        onGapTimeout: (_, __) {},
        timeout: const Duration(milliseconds: 20),
      );
      addTearDown(buffer.dispose);
      buffer.activate('group_g1', 100);

      expect(buffer.accept(_msg(103, msgID: 'server-a')), isNull);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(flushed.single.single.msgID, 'server-a');

      final conflict = buffer.accept(_msg(103, msgID: 'server-b'));
      expect(conflict, isNotNull);
      expect(conflict!.single.msgID, 'server-b');
    });

    test('reactivate cancels the old conversation timeout', () async {
      final flushed = <List<V2TimMessage>>[];
      final timeoutConversations = <String>[];
      final buffer = InboundReorderBuffer(
        onFlush: flushed.add,
        onGapTimeout: (_, conversationID) {
          timeoutConversations.add(conversationID);
        },
        timeout: const Duration(milliseconds: 20),
      );
      addTearDown(buffer.dispose);
      buffer.activate('group_a', 100);
      expect(buffer.accept(_msg(103)), isNull);

      buffer.activate('group_b', 200);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(flushed, isEmpty);
      expect(timeoutConversations, isEmpty);
      expect(buffer.expectedSeq, 201);
      expect(buffer.accept(_msg(201))!.single.seq, '201');
    });
  });
}
