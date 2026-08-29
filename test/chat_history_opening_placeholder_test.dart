import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_main_thread_perf.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart'
    show TIMUIKitHistoryMessageListController;
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_message_list_skeleton.dart';

void main() {
  group('ChatHistoryOpeningPlaceholderController', () {
    test('cold open shows once and cannot reactivate after removal', () {
      final controller = ChatHistoryOpeningPlaceholderController();
      final generation = controller.begin(
        initialMessageCount: 0,
        initialHistoryLoaded: false,
        isSearchJump: false,
        hasLockedEntryUnread: false,
      );

      expect(
        controller.phase,
        ChatHistoryOpeningPlaceholderPhase.waiting,
      );
      expect(
        controller.showAfterDelay(
          generation: generation,
          messageCount: 0,
          initialHistoryLoaded: false,
          revealPainted: false,
          isSearchJump: false,
          hasLockedEntryUnread: false,
        ),
        isTrue,
      );
      expect(controller.shouldPaint, isTrue);
      expect(controller.beginDismiss(generation), isTrue);
      expect(controller.finishDismiss(generation), isTrue);
      expect(
        controller.phase,
        ChatHistoryOpeningPlaceholderPhase.removed,
      );
      expect(
        controller.showAfterDelay(
          generation: generation,
          messageCount: 0,
          initialHistoryLoaded: false,
          revealPainted: false,
          isSearchJump: false,
          hasLockedEntryUnread: false,
        ),
        isFalse,
      );
    });

    test('warm, confirmed-empty, search and locked-unread opens stay inactive',
        () {
      final controller = ChatHistoryOpeningPlaceholderController();

      void expectInactive({
        int initialMessageCount = 0,
        bool initialHistoryLoaded = false,
        bool isSearchJump = false,
        bool hasLockedEntryUnread = false,
      }) {
        controller.begin(
          initialMessageCount: initialMessageCount,
          initialHistoryLoaded: initialHistoryLoaded,
          isSearchJump: isSearchJump,
          hasLockedEntryUnread: hasLockedEntryUnread,
        );
        expect(
          controller.phase,
          ChatHistoryOpeningPlaceholderPhase.inactive,
        );
      }

      expectInactive(initialMessageCount: 20);
      expectInactive(initialHistoryLoaded: true);
      expectInactive(isSearchJump: true);
      expectInactive(hasLockedEntryUnread: true);
    });

    test('fast local result suppresses the delayed placeholder', () {
      final controller = ChatHistoryOpeningPlaceholderController();
      final generation = controller.begin(
        initialMessageCount: 0,
        initialHistoryLoaded: false,
        isSearchJump: false,
        hasLockedEntryUnread: false,
      );

      expect(
        controller.showAfterDelay(
          generation: generation,
          messageCount: 3,
          initialHistoryLoaded: true,
          revealPainted: false,
          isSearchJump: false,
          hasLockedEntryUnread: false,
        ),
        isFalse,
      );
      expect(
        controller.phase,
        ChatHistoryOpeningPlaceholderPhase.removed,
      );
    });

    test('stale delayed and animation callbacks cannot affect a new open', () {
      final controller = ChatHistoryOpeningPlaceholderController();
      final staleGeneration = controller.begin(
        initialMessageCount: 0,
        initialHistoryLoaded: false,
        isSearchJump: false,
        hasLockedEntryUnread: false,
      );
      final currentGeneration = controller.begin(
        initialMessageCount: 0,
        initialHistoryLoaded: false,
        isSearchJump: false,
        hasLockedEntryUnread: false,
      );

      expect(
        controller.showAfterDelay(
          generation: staleGeneration,
          messageCount: 0,
          initialHistoryLoaded: false,
          revealPainted: false,
          isSearchJump: false,
          hasLockedEntryUnread: false,
        ),
        isFalse,
      );
      expect(controller.beginDismiss(staleGeneration), isFalse);
      expect(controller.finishDismiss(staleGeneration), isFalse);
      expect(controller.generation, currentGeneration);
      expect(
        controller.phase,
        ChatHistoryOpeningPlaceholderPhase.waiting,
      );
    });
  });

  testWidgets('skeleton trims rows to a short viewport without overflow',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 320,
            height: 180,
            child: ChatMessageListSkeleton(
              padding: EdgeInsets.zero,
              showAvatars: true,
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('chat_opening_placeholder_row_0')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey<String>('chat_opening_placeholder_row_3')),
      findsNothing,
    );
    expect(
      find.byKey(const ValueKey<String>('chat_opening_placeholder_avatar_0')),
      findsOneWidget,
    );
  });

  testWidgets('C2C skeleton does not paint avatar circles', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SizedBox(
          width: 320,
          height: 480,
          child: ChatMessageListSkeleton(showAvatars: false),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(
      find.byKey(const ValueKey<String>('chat_opening_placeholder_avatar_0')),
      findsNothing,
    );
  });

  test('history list keeps one real scroll tree under the fading overlay', () {
    final listController = TIMUIKitHistoryMessageListController();
    addTearDown(listController.dispose);
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart',
    ).readAsStringSync();

    expect('CustomScrollView('.allMatches(source).length, 1);
    expect(source.contains('ChatMessageListSkeleton('), isTrue);
    expect(source.contains("'chat_opening_placeholder'"), isTrue);
    expect(source.contains('FadeTransition('), isTrue);
    expect(source.contains('placeholderStillOpaque'), isTrue);
    expect(source.contains('MediaQuery.maybeOf(context)?.disableAnimations'),
        isTrue);
    expect(
      source.contains('ChatMainThreadPerf.openingPlaceholderFirstPaintMs'),
      isTrue,
    );
    expect(
      source.contains('ChatMainThreadPerf.openingPlaceholderVisibleMs'),
      isTrue,
    );
    expect(
      source.contains('ChatMainThreadPerf.messagesFirstVisibleMs'),
      isTrue,
    );
  });
}
