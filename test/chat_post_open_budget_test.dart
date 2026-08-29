import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_post_open_scheduler.dart';

void main() {
  test('post-open scheduler bounds concurrency and single-flights keys',
      () async {
    final scheduler = ChatPostOpenScheduler(maxConcurrent: 2);
    final generation = scheduler.beginRun();
    final releases = <Completer<void>>[];
    var running = 0;
    var peak = 0;
    var started = 0;

    Future<void> task() async {
      started++;
      running++;
      if (running > peak) peak = running;
      final release = Completer<void>();
      releases.add(release);
      await release.future;
      running--;
    }

    for (var i = 0; i < 4; i++) {
      scheduler.schedule(
        generation: generation,
        delay: Duration.zero,
        canRun: () => true,
        key: i == 3 ? 'task_2' : 'task_$i',
        task: task,
      );
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(started, 2);
    expect(peak, 2);
    for (final release in releases.toList()) {
      release.complete();
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
    for (final release in releases.toList()) {
      if (!release.isCompleted) release.complete();
    }
    await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(started, 3);
    expect(peak, 2);
    scheduler.dispose();
  });

  test('cancel drops not-started work and timeout releases the budget',
      () async {
    final scheduler = ChatPostOpenScheduler(maxConcurrent: 1);
    final generation = scheduler.beginRun();
    var cancelledStarted = false;
    scheduler.schedule(
      generation: generation,
      delay: const Duration(milliseconds: 40),
      canRun: () => true,
      key: 'cancelled',
      task: () {
        cancelledStarted = true;
      },
    );
    scheduler.cancelPending();
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(cancelledStarted, isFalse);

    final timeoutGeneration = scheduler.beginRun();
    var followUpStarted = false;
    scheduler.schedule(
      generation: timeoutGeneration,
      delay: Duration.zero,
      timeout: const Duration(milliseconds: 20),
      canRun: () => true,
      key: 'timeout',
      task: () => Completer<void>().future,
    );
    scheduler.schedule(
      generation: timeoutGeneration,
      delay: Duration.zero,
      canRun: () => true,
      key: 'follow_up',
      task: () {
        followUpStarted = true;
      },
    );
    await Future<void>.delayed(const Duration(milliseconds: 60));
    expect(followUpStarted, isTrue);
    scheduler.dispose();
  });

  test('covered activity holds background work but keeps essential work',
      () async {
    final scheduler = ChatPostOpenScheduler(maxConcurrent: 1);
    final generation = scheduler.beginRun();
    var backgroundStarted = false;
    var essentialStarted = false;
    scheduler.setActivity(ChatActivityState.covered);
    scheduler.schedule(
      generation: generation,
      delay: Duration.zero,
      canRun: () => true,
      key: 'essential',
      task: () => essentialStarted = true,
    );
    scheduler.schedule(
      generation: generation,
      delay: Duration.zero,
      priority: ChatTaskPriority.background,
      canRun: () => true,
      key: 'background',
      task: () => backgroundStarted = true,
    );
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(backgroundStarted, isFalse);
    expect(essentialStarted, isTrue);
    scheduler.setActivity(ChatActivityState.active);
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(backgroundStarted, isTrue);
    scheduler.dispose();
  });
}
