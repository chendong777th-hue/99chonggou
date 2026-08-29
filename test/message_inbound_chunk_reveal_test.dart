import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message_inbound_chunk_reveal.dart';

void main() {
  V2TimMessage message(int index) => V2TimMessage.fromJson(<String, dynamic>{
        'message_msg_id': 'message_$index',
        'message_risk_type_identified': 0,
        'message_elem_array': const <dynamic>[],
        'elem_type': MessageElemType.V2TIM_ELEM_TYPE_TEXT,
      });

  MessageInboundChunkedReveal buildReveal() {
    return MessageInboundChunkedReveal(
      onRevealChunk: (_, __) {},
      onDrainRemaining: (_, __) {},
      onSessionBegin: (_) {},
      onSessionEnd: (_) {},
      alignToFrame: false,
    );
  }

  test('runtime pacing config is applied and safely clamped', () {
    final reveal = buildReveal();

    reveal.configure(
      interval: const Duration(milliseconds: 72),
      maxChunkSize: 6,
      alignToFrame: false,
      burstBoostChunk: 0,
    );

    expect(reveal.interval, const Duration(milliseconds: 72));
    expect(reveal.maxChunkSize, 6);
    expect(reveal.resolveChunkSizeForTesting(100), 6);
    expect(reveal.resolveChunkSizeForTesting(40), 6);
    expect(reveal.resolveChunkSizeForTesting(8), 6);
    expect(reveal.resolveChunkSizeForTesting(3), 3);
  });

  test('configured chunk size never drops below one', () {
    final reveal = buildReveal();

    reveal.configure(
      interval: Duration.zero,
      maxChunkSize: 0,
      alignToFrame: false,
      burstBoostChunk: -2,
    );

    expect(reveal.interval, const Duration(milliseconds: 1));
    expect(reveal.maxChunkSize, 1);
    expect(reveal.resolveChunkSizeForTesting(100), 1);
    expect(reveal.resolveChunkSizeForTesting(3), 1);
  });

  test('a burst reveals an adaptive group then waits for layout completion',
      () {
    final chunks = <List<V2TimMessage>>[];
    final reveal = MessageInboundChunkedReveal(
      onRevealChunk: (_, messages) => chunks.add(messages),
      onDrainRemaining: (_, __) {},
      onSessionBegin: (_) {},
      onSessionEnd: (_) {},
      interval: const Duration(seconds: 1),
      maxChunkSize: 6,
      alignToFrame: false,
      burstBoostChunk: 0,
    );
    final messages = List<V2TimMessage>.generate(
      12,
      message,
    );

    reveal.enqueueAll('conversation', messages);

    // queueLen=12 → adaptive maxChunk=6
    expect(chunks, hasLength(1));
    expect(chunks.single, hasLength(6));
    expect(reveal.pendingCountFor('conversation'), 6);
    expect(reveal.isWaitingForTransaction('conversation'), isTrue);
    expect(reveal.maxChunkSize, 6);
    expect(reveal.interval, const Duration(milliseconds: 80));
    reveal.dispose();
  });

  test('the next adaptive group waits for transaction acknowledgement',
      () async {
    final chunkSizes = <int>[];
    var ended = 0;
    final reveal = MessageInboundChunkedReveal(
      onRevealChunk: (_, messages) => chunkSizes.add(messages.length),
      onDrainRemaining: (_, __) {},
      onSessionBegin: (_) {},
      onSessionEnd: (_) => ended++,
      maxChunkSize: 4,
      alignToFrame: false,
    );
    final messages = List<V2TimMessage>.generate(
      14,
      message,
    );

    reveal.enqueueAll('conversation', messages);
    // queueLen=14 → adaptive maxChunk=6
    expect(chunkSizes, <int>[6]);

    reveal.completeCurrentReveal('conversation');
    expect(chunkSizes, <int>[6]);
    await Future<void>.delayed(const Duration(milliseconds: 100));

    expect(chunkSizes, <int>[6, 6]);
    expect(ended, 0);
    reveal.dispose();
  });

  test('one hundred mixed-height transactions drain in order without loss',
      () async {
    final revealed = <V2TimMessage>[];
    final reveal = MessageInboundChunkedReveal(
      onRevealChunk: (_, messages) => revealed.addAll(messages),
      onDrainRemaining: (_, __) {},
      onSessionBegin: (_) {},
      onSessionEnd: (_) {},
      interval: Duration.zero,
      maxChunkSize: 4,
      alignToFrame: false,
    );
    final messages = List<V2TimMessage>.generate(
      100,
      message,
    );

    reveal.enqueueAll('conversation', messages);
    for (var guard = 0;
        guard < 200 && reveal.isActiveFor('conversation');
        guard++) {
      reveal.completeCurrentReveal('conversation');
      await Future<void>.delayed(const Duration(milliseconds: 2));
    }

    expect(revealed, orderedEquals(messages));
    expect(reveal.pendingCountFor('conversation'), 0);
    expect(reveal.isActiveFor('conversation'), isFalse);
    reveal.dispose();
  });

  test(
      'silent cancellation drops presentation work without lifecycle callbacks',
      () {
    var ended = 0;
    var drained = 0;
    final reveal = MessageInboundChunkedReveal(
      onRevealChunk: (_, __) {},
      onDrainRemaining: (_, messages) => drained += messages.length,
      onSessionBegin: (_) {},
      onSessionEnd: (_) => ended++,
      interval: const Duration(seconds: 1),
      maxChunkSize: 1,
      alignToFrame: false,
    );
    final messages = List<V2TimMessage>.generate(
      3,
      message,
    );

    reveal.enqueueAll('conversation', messages);
    reveal.cancelAllSilently();

    expect(reveal.pendingCountFor('conversation'), 0);
    expect(reveal.isActiveFor('conversation'), isFalse);
    expect(drained, 0);
    expect(ended, 0);
    reveal.dispose();
  });

  test('gesture cancellation keeps the visible group and buffers the remainder',
      () {
    var visible = 0;
    var buffered = 0;
    var ended = 0;
    final reveal = MessageInboundChunkedReveal(
      onRevealChunk: (_, messages) => visible += messages.length,
      onDrainRemaining: (_, messages) => buffered += messages.length,
      onSessionBegin: (_) {},
      onSessionEnd: (_) => ended++,
      maxChunkSize: 4,
      alignToFrame: false,
    );
    final messages = List<V2TimMessage>.generate(
      10,
      message,
    );

    reveal.enqueueAll('conversation', messages);
    reveal.cancelToBuffer('conversation');

    // queueLen=10 → adaptive maxChunk=6 for the first visible group
    expect(visible, 6);
    expect(buffered, 4);
    expect(ended, 1);
    expect(reveal.isActiveFor('conversation'), isFalse);
    reveal.dispose();
  });

  test('authoritative replacement cancels presentation without buffering', () {
    var superseded = 0;
    var drained = 0;
    var ended = 0;
    final reveal = MessageInboundChunkedReveal(
      onRevealChunk: (_, __) {},
      onDrainRemaining: (_, messages) => drained += messages.length,
      onSupersede: (_) => superseded++,
      onSessionBegin: (_) {},
      onSessionEnd: (_) => ended++,
      interval: const Duration(seconds: 1),
      maxChunkSize: 1,
      alignToFrame: false,
    );

    reveal.enqueueAll('conversation', List<V2TimMessage>.generate(3, message));
    expect(reveal.isActiveFor('conversation'), isTrue);

    reveal.cancelForAuthoritativeReplace('conversation');

    expect(superseded, 1);
    expect(drained, 0);
    expect(ended, 0);
    expect(reveal.pendingCountFor('conversation'), 0);
    expect(reveal.isWaitingForTransaction('conversation'), isFalse);
    expect(reveal.isActiveFor('conversation'), isFalse);
    reveal.dispose();
  });

  test('missing UI acknowledgement is recovered by transaction watchdog',
      () async {
    final revealed = <V2TimMessage>[];
    var ended = 0;
    final reveal = MessageInboundChunkedReveal(
      onRevealChunk: (_, messages) => revealed.addAll(messages),
      onDrainRemaining: (_, __) {},
      onSessionBegin: (_) {},
      onSessionEnd: (_) => ended++,
      maxChunkSize: 1,
      alignToFrame: false,
      interval: Duration.zero,
      transactionTimeout: const Duration(milliseconds: 10),
    );
    final messages = List<V2TimMessage>.generate(2, message);

    reveal.enqueueAll('conversation', messages);
    expect(revealed, hasLength(1));
    expect(reveal.isWaitingForTransaction('conversation'), isTrue);

    await Future<void>.delayed(const Duration(milliseconds: 40));

    expect(revealed, orderedEquals(messages));
    expect(reveal.isActiveFor('conversation'), isFalse);
    expect(ended, 1);
    reveal.dispose();
  });

  test('high throughput fast-forwards old work and animates newest tail',
      () async {
    final fastForwarded = <V2TimMessage>[];
    final animated = <V2TimMessage>[];
    final messages = List<V2TimMessage>.generate(2000, message);
    final reveal = MessageInboundChunkedReveal(
      onRevealChunk: (_, chunk) => animated.addAll(chunk),
      onDrainRemaining: (_, __) {},
      onFastForward: (_, chunk) => fastForwarded.addAll(chunk),
      onSessionBegin: (_) {},
      onSessionEnd: (_) {},
      interval: Duration.zero,
      maxChunkSize: 1,
      maxAnimatedBacklog: 6,
      alignToFrame: false,
    );

    reveal.enqueueAll('conversation', messages);
    expect(fastForwarded, hasLength(1994));
    expect(animated, isEmpty);

    await Future<void>.delayed(Duration.zero);
    for (var guard = 0;
        guard < 20 && reveal.isActiveFor('conversation');
        guard++) {
      reveal.completeCurrentReveal('conversation');
      await Future<void>.delayed(Duration.zero);
    }

    expect(animated, orderedEquals(messages.sublist(1994)));
    expect(
      <V2TimMessage>[...fastForwarded, ...animated],
      orderedEquals(messages),
    );
    expect(reveal.isActiveFor('conversation'), isFalse);
    reveal.dispose();
  });
}
