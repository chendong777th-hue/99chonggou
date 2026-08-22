import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/qr_web_login_payload.dart';

void main() {
  test('QrWebLoginPayload tryParse accepts v1 json', () {
    final payload = QrWebLoginPayload.tryParse(
      '{"type":"web_login","sessionId":"sess_abc","v":1}',
    );
    expect(payload, isNotNull);
    expect(payload!.sessionId, 'sess_abc');
    expect(payload.version, 1);
  });

  test('QrWebLoginPayload tryParse rejects user qr', () {
    expect(
      QrWebLoginPayload.tryParse('{"type":"user","id":"u1"}'),
      isNull,
    );
  });

  test('QrWebLoginPayload encode roundtrip', () {
    const original = QrWebLoginPayload(sessionId: 's1', version: 1);
    final parsed = QrWebLoginPayload.tryParse(original.encode());
    expect(parsed?.sessionId, 's1');
    expect(parsed?.version, 1);
  });
}
