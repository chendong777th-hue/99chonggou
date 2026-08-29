import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/message_cloud_catch_up.dart';

void main() {
  test('concurrent reconnect triggers share one bounded flight', () async {
    final gate = Completer<void>();
    var calls = 0;
    final controller = BoundedMessageCloudCatchUp(
      retryDelays: const <Duration>[Duration.zero],
    );

    Future<MessageCloudCatchUpDisposition> operation(
      MessageCloudCatchUpAttempt attempt,
    ) async {
      calls++;
      await gate.future;
      return MessageCloudCatchUpDisposition.complete;
    }

    final first = controller.run(
      conversationID: 'group_room',
      operation: operation,
    );
    final second = controller.run(
      conversationID: 'group_room',
      operation: operation,
    );
    expect(identical(first, second), isTrue);
    gate.complete();
    expect((await first).completed, isTrue);
    expect(calls, 1);
  });

  test('retry stops at hard attempt limit', () async {
    var calls = 0;
    final controller = BoundedMessageCloudCatchUp(
      maxAttempts: 3,
      retryDelays: const <Duration>[
        Duration.zero,
        Duration.zero,
        Duration.zero,
      ],
    );
    final result = await controller.run(
      conversationID: 'group_room',
      operation: (_) async {
        calls++;
        return MessageCloudCatchUpDisposition.retry;
      },
    );
    expect(result.completed, isFalse);
    expect(result.attempts, 3);
    expect(calls, 3);
  });

  test('continuation consumes the current budget and remains explicit',
      () async {
    var calls = 0;
    final controller = BoundedMessageCloudCatchUp(
      maxAttempts: 3,
      retryDelays: const <Duration>[
        Duration.zero,
        Duration.zero,
        Duration.zero,
      ],
    );

    final result = await controller.run(
      conversationID: 'c2c_peer',
      operation: (_) async {
        calls++;
        return MessageCloudCatchUpDisposition.continuation;
      },
    );

    expect(result.disposition, MessageCloudCatchUpDisposition.continuation);
    expect(result.needsContinuation, isTrue);
    expect(result.attempts, 3);
    expect(calls, 3);
  });

  test('late timed-out completion cannot claim current attempt', () async {
    final firstGate = Completer<void>();
    final firstWasCurrentAfterTimeout = Completer<bool>();
    var calls = 0;
    var invalidations = 0;
    final controller = BoundedMessageCloudCatchUp(
      maxAttempts: 2,
      attemptTimeout: const Duration(milliseconds: 10),
      maxDuration: const Duration(seconds: 1),
      retryDelays: const <Duration>[Duration.zero, Duration.zero],
    );
    final resultFuture = controller.run(
      conversationID: 'group_room',
      operation: (attempt) async {
        calls++;
        if (calls == 1) {
          attempt.onInvalidated(() {
            invalidations++;
          });
          await firstGate.future;
          firstWasCurrentAfterTimeout.complete(attempt.isCurrent);
          return MessageCloudCatchUpDisposition.complete;
        }
        return MessageCloudCatchUpDisposition.complete;
      },
    );
    final result = await resultFuture;
    expect(result.completed, isTrue);
    expect(result.attempts, 2);
    expect(invalidations, 1);
    firstGate.complete();
    expect(await firstWasCurrentAfterTimeout.future, isFalse);
  });

  test('offline result waits for a future reconnect instead of looping',
      () async {
    var calls = 0;
    final controller = BoundedMessageCloudCatchUp();
    final result = await controller.run(
      conversationID: 'c2c_peer',
      operation: (_) async {
        calls++;
        return MessageCloudCatchUpDisposition.offline;
      },
    );
    expect(result.disposition, MessageCloudCatchUpDisposition.offline);
    expect(calls, 1);
  });

  test('stalled result stops the bounded loop immediately', () async {
    var calls = 0;
    final controller = BoundedMessageCloudCatchUp(
      maxAttempts: 3,
      retryDelays: const <Duration>[Duration.zero],
    );
    final result = await controller.run(
      conversationID: 'c2c_peer',
      operation: (_) async {
        calls++;
        return MessageCloudCatchUpDisposition.stalled;
      },
    );
    expect(result.disposition, MessageCloudCatchUpDisposition.stalled);
    expect(result.completed, isFalse);
    expect(result.needsContinuation, isFalse);
    expect(result.attempts, 1);
    expect(calls, 1);

    final nextLifecycleResult = await controller.run(
      conversationID: 'c2c_peer',
      operation: (_) async {
        calls++;
        return MessageCloudCatchUpDisposition.settled;
      },
    );
    expect(nextLifecycleResult.settled, isTrue);
    expect(calls, 2);
  });

  test('settled transport result stops without claiming continuity', () async {
    var calls = 0;
    final controller = BoundedMessageCloudCatchUp(
      maxAttempts: 3,
      retryDelays: const <Duration>[Duration.zero],
    );
    final result = await controller.run(
      conversationID: 'c2c_peer',
      operation: (_) async {
        calls++;
        return MessageCloudCatchUpDisposition.settled;
      },
    );

    expect(result.settled, isTrue);
    expect(result.completed, isFalse);
    expect(result.needsContinuation, isFalse);
    expect(result.attempts, 1);
    expect(calls, 1);
  });
}
