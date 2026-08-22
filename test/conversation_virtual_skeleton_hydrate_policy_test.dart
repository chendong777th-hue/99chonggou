import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_virtual_hydrate_policy.dart';

void main() {
  test('skeleton hydration waits until fling settles', () {
    expect(
      conversationVirtualSkeletonMayRequestHydrate(
        onlyOnScrollSettle: true,
        isScrolling: true,
      ),
      isFalse,
    );
    expect(
      conversationVirtualSkeletonMayRequestHydrate(
        onlyOnScrollSettle: true,
        isScrolling: false,
      ),
      isTrue,
    );
  });

  test('continuous hydration mode may request while scrolling', () {
    expect(
      conversationVirtualSkeletonMayRequestHydrate(
        onlyOnScrollSettle: false,
        isScrolling: true,
      ),
      isTrue,
    );
  });
}
