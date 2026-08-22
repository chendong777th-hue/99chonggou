import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_send_utils.dart';

void main() {
  test('ultra-tall poster keeps readable width instead of ~200px crush', () {
    // Old 1600-long-edge logic would yield ~232×1024 for similar aspect ratios.
    final target = resolveChatImageSendTargetSize(
      sourceWidth: 1080,
      sourceHeight: 5120,
    );
    expect(target.width, 1080);
    expect(target.height, 5120);
  });

  test('ultra-tall poster caps height at ultra-tall long edge', () {
    final target = resolveChatImageSendTargetSize(
      sourceWidth: 1080,
      sourceHeight: 12000,
    );
    expect(target.width, greaterThan(700));
    expect(target.height, kChatImageUltraTallMaxLongEdge);
  });

  test('normal photo still limits longest edge', () {
    final target = resolveChatImageSendTargetSize(
      sourceWidth: 4032,
      sourceHeight: 3024,
    );
    expect(target.width, 3072);
    expect(target.height, 2304);
  });

  test('narrow source is not upscaled', () {
    final target = resolveChatImageSendTargetSize(
      sourceWidth: 580,
      sourceHeight: 5120,
    );
    expect(target.width, 580);
    expect(target.height, 5120);
  });
}
