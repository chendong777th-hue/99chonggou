import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/utils/qr_app_payload.dart';

void main() {
  group('QrAppPayload.encode', () {
    test('builds website url with type/id/name for external scanners', () {
      final encoded = QrAppPayload.encode(
        baseUrl: 'https://99chat.app',
        type: QrAppPayloadType.user,
        id: 'u123',
        name: '小明',
      );
      final uri = Uri.parse(encoded);
      expect(uri.scheme, 'https');
      expect(uri.host, '99chat.app');
      expect(uri.queryParameters['type'], 'user');
      expect(uri.queryParameters['id'], 'u123');
      expect(uri.queryParameters['name'], '小明');
      expect(uri.queryParameters['from'], 'qr');
    });

    test('merges into existing query parameters', () {
      final encoded = QrAppPayload.encode(
        baseUrl: 'https://99chat.app/download?channel=official',
        type: QrAppPayloadType.group,
        id: '@TGS#abc',
      );
      final uri = Uri.parse(encoded);
      expect(uri.path, '/download');
      expect(uri.queryParameters['channel'], 'official');
      expect(uri.queryParameters['type'], 'group');
      expect(uri.queryParameters['id'], '@TGS#abc');
    });

    test('falls back to json when base url missing', () {
      final encoded = QrAppPayload.encode(
        baseUrl: '',
        type: QrAppPayloadType.user,
        id: 'u1',
        name: 'n',
      );
      expect(encoded, '{"type":"user","id":"u1","name":"n"}');
    });
  });

  group('QrAppPayload.tryParse', () {
    test('parses legacy json', () {
      final payload = QrAppPayload.tryParse(
        '{"type":"group","id":"g1","name":"群"}',
      );
      expect(payload?.type, QrAppPayloadType.group);
      expect(payload?.id, 'g1');
      expect(payload?.name, '群');
    });

    test('parses website url', () {
      final payload = QrAppPayload.tryParse(
        'https://99chat.app/?type=user&id=u9&name=%E5%B0%8F%E6%98%8E&from=qr',
      );
      expect(payload?.type, QrAppPayloadType.user);
      expect(payload?.id, 'u9');
      expect(payload?.name, '小明');
    });

    test('ignores plain website without type/id', () {
      expect(
        QrAppPayload.tryParse('https://99chat.app/'),
        isNull,
      );
    });

    test('ignores web_login json', () {
      expect(
        QrAppPayload.tryParse(
          '{"type":"web_login","sessionId":"s1","v":1}',
        ),
        isNull,
      );
    });
  });
}
