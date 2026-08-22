import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_header_state_controller.dart';

void main() {
  test('setSnapshot notifies only when header snapshot changes', () {
    final controller = ChatHeaderStateController();
    var notifyCount = 0;
    controller.addListener(() => notifyCount++);

    controller.setSnapshot(
      conversationFaceUrl: ' https://example.com/a.png ',
      titleText: ' Alice ',
    );
    expect(notifyCount, 1);
    expect(controller.conversationFaceUrl, 'https://example.com/a.png');
    expect(controller.titleText, 'Alice');

    controller.setSnapshot(
      conversationFaceUrl: 'https://example.com/a.png',
      titleText: 'Alice',
    );
    expect(notifyCount, 1);

    controller.setSnapshot(
      conversationFaceUrl: 'https://example.com/b.png',
      titleText: 'Alice',
    );
    expect(notifyCount, 2);

    controller.setSnapshot(
      conversationFaceUrl: 'https://example.com/b.png',
      titleText: 'Alice (3)',
      notify: false,
    );
    expect(notifyCount, 2);
    expect(controller.titleText, 'Alice (3)');

    controller.dispose();
  });
}
