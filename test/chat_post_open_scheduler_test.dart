import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_post_open_scheduler.dart';

void main() {
  testWidgets('beginRun cancels pending delayed tasks from previous run',
      (tester) async {
    final scheduler = ChatPostOpenScheduler();
    var count = 0;
    final first = scheduler.beginRun();
    scheduler.schedule(
      generation: first,
      delay: const Duration(milliseconds: 10),
      canRun: () => true,
      task: () => count++,
    );

    final second = scheduler.beginRun();
    scheduler.schedule(
      generation: second,
      delay: const Duration(milliseconds: 10),
      canRun: () => true,
      task: () => count += 10,
    );

    await tester.pump(const Duration(milliseconds: 10));
    expect(count, 10);
    scheduler.dispose();
  });

  testWidgets('schedule skips task when canRun is false', (tester) async {
    final scheduler = ChatPostOpenScheduler();
    var ran = false;
    final generation = scheduler.beginRun();
    scheduler.schedule(
      generation: generation,
      delay: const Duration(milliseconds: 10),
      canRun: () => false,
      task: () => ran = true,
    );

    await tester.pump(const Duration(milliseconds: 10));
    expect(ran, isFalse);
    scheduler.dispose();
  });
}
