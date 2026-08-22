import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/web_chat_open_policy.dart';

void main() {
  group('WebChatOpenPolicy', () {
    test('UIKit history path never owns initial archive deferral', () {
      expect(
        WebChatOpenPolicy.shouldDeferInitialArchive(
          isInitialWindow: true,
          sdkMessageCount: 5,
        ),
        isFalse,
      );
      expect(
        WebChatOpenPolicy.shouldDeferInitialArchive(
          isInitialWindow: true,
          sdkMessageCount: 0,
        ),
        isFalse,
      );
      expect(
        WebChatOpenPolicy.shouldDeferInitialArchive(
          isInitialWindow: false,
          sdkMessageCount: 5,
        ),
        isFalse,
      );
    });

    test('useCallOnlyOpenDedupe only for web chat_open slot', () {
      if (kIsWeb) {
        expect(
          WebChatOpenPolicy.useCallOnlyOpenDedupe(scheduleSlot: 'chat_open'),
          isTrue,
        );
      } else {
        expect(
          WebChatOpenPolicy.useCallOnlyOpenDedupe(scheduleSlot: 'chat_open'),
          isFalse,
        );
      }
      expect(
        WebChatOpenPolicy.useCallOnlyOpenDedupe(scheduleSlot: 'default'),
        isFalse,
      );
    });
  });
}
