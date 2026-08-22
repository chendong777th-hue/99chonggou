import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_chat_notification_registry.dart';

void main() {
  tearDown(() {
    ImChatNotificationRegistry.instance.clearAll();
  });

  test('remove cleans empty threads without mutating map during iteration', () {
    final registry = ImChatNotificationRegistry.instance;
    registry.register(
      threadId: 'c2c_alice',
      notificationId: 1,
      msgKey: 'msg-1',
    );
    registry.register(
      threadId: 'c2c_bob',
      notificationId: 2,
      msgKey: 'msg-2',
    );

    expect(() => registry.remove(1), returnsNormally);
    expect(registry.idsForThread('c2c_alice'), isEmpty);
    expect(registry.idsForThread('c2c_bob'), contains(2));
  });
}
