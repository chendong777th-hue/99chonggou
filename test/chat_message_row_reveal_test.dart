import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart'
    as history;
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_message_row_reveal.dart';

void main() {
  test('history list compiles with row reveal transaction integration', () {
    expect(history.TIMUIKitHistoryMessageList, isNotNull);
  });

  testWidgets('shared progress expands complete rows by their real heights',
      (tester) async {
    final controller = AnimationController(
      vsync: tester,
      duration: const Duration(milliseconds: 400),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ChatMessageRowReveal(
                  progress: controller,
                  child: const SizedBox(height: 40, width: 100),
                ),
                ChatMessageRowReveal(
                  progress: controller,
                  child: const SizedBox(height: 100, width: 100),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.getSize(find.byType(Column)).height, 0);

    controller.value = 0.5;
    await tester.pump();
    expect(tester.getSize(find.byType(Column)).height, closeTo(70, 0.1));

    controller.value = 1;
    await tester.pump();
    expect(tester.getSize(find.byType(Column)).height, closeTo(140, 0.1));

    await tester.pumpWidget(const SizedBox.shrink());
    controller.dispose();
  });

  testWidgets(
      'row reveal changes real sliver extent without viewport transform',
      (tester) async {
    final animation = AnimationController(vsync: tester);
    final scrollController = ScrollController();

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: 60,
              child: CustomScrollView(
                controller: scrollController,
                reverse: true,
                slivers: [
                  SliverList(
                    delegate: SliverChildListDelegate([
                      ChatMessageRowReveal(
                        progress: animation,
                        child: const SizedBox(height: 40),
                      ),
                      ChatMessageRowReveal(
                        progress: animation,
                        child: const SizedBox(height: 100),
                      ),
                    ]),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    expect(scrollController.position.maxScrollExtent, 0);

    animation.value = 1;
    await tester.pump();
    expect(scrollController.position.maxScrollExtent, closeTo(80, 0.1));

    await tester.pumpWidget(const SizedBox.shrink());
    animation.dispose();
    scrollController.dispose();
  });
}
