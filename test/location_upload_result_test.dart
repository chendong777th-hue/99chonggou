import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/location_api.dart';

void main() {
  test('LocationUploadResult parses accepted throttle window', () {
    final result = LocationUploadResult.fromJson(const {
      'accepted': true,
      'nextUploadAfterMs': 10800000,
    });
    expect(result.accepted, isTrue);
    expect(result.nextUploadAfterMs, 10800000);
  });

  test('LocationUploadResult uses default interval when missing', () {
    final result = LocationUploadResult.fromJson(const {
      'accepted': false,
    });
    expect(result.accepted, isFalse);
    expect(
      result.nextUploadAfterMs,
      LocationApi.defaultNextUploadAfterMs,
    );
  });
}
