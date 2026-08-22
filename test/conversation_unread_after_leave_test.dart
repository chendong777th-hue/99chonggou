import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/active_chat_registry.dart';
import 'package:tencent_cloud_chat_demo/src/services/foreground_chat_guard.dart';

void main() {
  tearDown(() {
    ForegroundChatGuard.debugOverride = null;
    ActiveChatRegistry.instance.reset();
  });

  test('ForegroundChatGuard still active after route is covered', () {
    ActiveChatRegistry.instance.enter('c2c_alice');
    expect(ForegroundChatGuard.isActiveConversation('c2c_alice'), isTrue);

    ActiveChatRegistry.instance.updateRouteVisible(false);
    expect(ForegroundChatGuard.isActiveConversation('c2c_alice'), isTrue);
    expect(ActiveChatRegistry.instance.hasOpenChat, isTrue);
  });

  test('ForegroundChatGuard inactive after registry leave', () {
    ActiveChatRegistry.instance.enter('c2c_alice');
    ActiveChatRegistry.instance.leave('c2c_alice');
    expect(ForegroundChatGuard.isActiveConversation('c2c_alice'), isFalse);
  });
}
