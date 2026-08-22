import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_history_warm_scheduler.dart';

void main() {
  tearDown(ActiveChatRegistry.instance.reset);

  group('ActiveChatRegistry', () {
    test('enter marks conversation active when route visible', () {
      ActiveChatRegistry.instance.enter('c2c_alice');
      ActiveChatRegistry.instance.updateRouteVisible(true);

      expect(ActiveChatRegistry.instance.isActiveChat('c2c_alice'), isTrue);
      expect(
        ActiveChatRegistry.instance.isActiveChatInForeground('c2c_alice'),
        isTrue,
      );
    });

    test('route invisible conversation is not active', () {
      ActiveChatRegistry.instance.enter('c2c_alice');
      ActiveChatRegistry.instance.updateRouteVisible(false);

      expect(ActiveChatRegistry.instance.isActiveChat('c2c_alice'), isFalse);
      expect(ActiveChatRegistry.instance.hasOpenChat, isTrue);
      expect(
        ActiveChatRegistry.instance.matchesOpenConversation('c2c_alice'),
        isTrue,
      );
    });

    test('background lifecycle suppresses foreground active chat', () {
      ActiveChatRegistry.instance.enter('c2c_alice');
      ActiveChatRegistry.instance.setLifecycleForeground(false);

      expect(ActiveChatRegistry.instance.isActiveChat('c2c_alice'), isTrue);
      expect(
        ActiveChatRegistry.instance.isActiveChatInForeground('c2c_alice'),
        isFalse,
      );
    });

    test('leave clears only matching conversation', () {
      ActiveChatRegistry.instance.enter('c2c_alice');
      ActiveChatRegistry.instance.leave('c2c_bob');
      expect(ActiveChatRegistry.instance.isActiveChat('c2c_alice'), isTrue);

      ActiveChatRegistry.instance.leave('c2c_alice');
      expect(ActiveChatRegistry.instance.isActiveChat('c2c_alice'), isFalse);
    });
  });

  group('warm scheduler skips memory fill for open chat', () {
    test('route invisible still skips fill for the open conversation', () {
      ActiveChatRegistry.instance.enter('c2c_alice');
      ActiveChatRegistry.instance.updateRouteVisible(false);

      expect(
        ConversationHistoryWarmScheduler.shouldSkipMemoryFillForOpenChat(
          cacheKey: 'alice',
          conversationID: 'c2c_alice',
        ),
        isTrue,
      );
      expect(
        ConversationHistoryWarmScheduler.shouldSkipMemoryFillForOpenChat(
          cacheKey: 'c2c_alice',
        ),
        isTrue,
      );
      expect(ActiveChatRegistry.instance.isActiveChat('c2c_alice'), isFalse);
    });

    test('no open chat does not skip fill', () {
      expect(
        ConversationHistoryWarmScheduler.shouldSkipMemoryFillForOpenChat(
          cacheKey: 'c2c_alice',
          conversationID: 'c2c_alice',
        ),
        isFalse,
      );
    });

    test('open bob does not skip fill for alice', () {
      ActiveChatRegistry.instance.enter('c2c_bob');
      expect(
        ConversationHistoryWarmScheduler.shouldSkipMemoryFillForOpenChat(
          cacheKey: 'c2c_alice',
          conversationID: 'c2c_alice',
        ),
        isFalse,
      );
    });

    test('fill-memory skip uses matchesOpenConversation not isActiveChat', () {
      final source = File(
        'lib/src/services/conversation_history_warm_scheduler.dart',
      ).readAsStringSync();
      expect(source.contains('shouldSkipMemoryFillForOpenChat'), isTrue);
      expect(
        source.contains('isActiveChat(cacheKey)'),
        isFalse,
      );
    });
  });
}
