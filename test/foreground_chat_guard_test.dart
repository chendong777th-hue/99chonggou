import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/foreground_chat_guard.dart';

void main() {
  tearDown(() {
    ForegroundChatGuard.debugOverride = null;
    ActiveChatRegistry.instance.reset();
  });

  group('ForegroundChatGuard', () {
    test('debugOverride takes precedence', () {
      ForegroundChatGuard.debugOverride = (_) => true;
      expect(ForegroundChatGuard.isActiveConversation(''), isTrue);
      expect(ForegroundChatGuard.isActiveConversation('c2c_alice'), isTrue);

      ForegroundChatGuard.debugOverride = (_) => false;
      expect(ForegroundChatGuard.isActiveConversation('c2c_alice'), isFalse);
    });

    test('matches active chat registry conversation id', () {
      ActiveChatRegistry.instance.enter('c2c_alice');
      expect(ForegroundChatGuard.isActiveConversation('c2c_alice'), isTrue);
      expect(ForegroundChatGuard.isActiveConversation('alice'), isTrue);
      expect(ForegroundChatGuard.isActiveConversation('c2c_bob'), isFalse);
    });

    test('still suppresses unread when chat is covered but not left', () {
      ActiveChatRegistry.instance.enter('c2c_alice', routeVisible: false);
      expect(ForegroundChatGuard.isActiveConversation('c2c_alice'), isTrue);
      expect(ActiveChatRegistry.instance.isActiveChat('c2c_alice'), isFalse);
      expect(ActiveChatRegistry.instance.hasOpenChat, isTrue);
      expect(
        ActiveChatRegistry.instance.matchesOpenConversation('c2c_alice'),
        isTrue,
      );
    });

    test('empty conversation id is inactive', () {
      expect(ForegroundChatGuard.isActiveConversation(null), isFalse);
      expect(ForegroundChatGuard.isActiveConversation(''), isFalse);
    });
  });
}
