import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_sdk_app_id_resolver.dart';

void main() {
  test('prefers backend UserSig sdkAppId over cache and fallback', () {
    expect(
      resolveImSdkAppId(
        preferred: 1600000001,
        cached: 20042133,
        fallback: IMDemoConfig.sdkAppID,
      ),
      1600000001,
    );
  });

  test('uses cached sdkAppId when preferred missing', () {
    expect(
      resolveImSdkAppId(
        preferred: null,
        cached: 1600000002,
        fallback: IMDemoConfig.sdkAppID,
      ),
      1600000002,
    );
  });

  test('falls back to config when nothing else available', () {
    expect(
      resolveImSdkAppId(preferred: 0, cached: null),
      IMDemoConfig.sdkAppID,
    );
  });
}
