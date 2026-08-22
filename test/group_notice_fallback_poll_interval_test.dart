import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_bootstrap.dart';

void main() {
  test('group notice REST fallback polls every three seconds', () {
    expect(
      GroupNoticeBootstrap.fallbackPollInterval,
      const Duration(seconds: 3),
    );
  });
}
