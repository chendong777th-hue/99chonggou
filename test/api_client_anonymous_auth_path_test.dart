import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';

void main() {
  group('ApiClient.isAnonymousAuthPath', () {
    test('qr scan/confirm require auth', () {
      expect(ApiClient.isAnonymousAuthPath('/auth/login/qr/scan'), isFalse);
      expect(ApiClient.isAnonymousAuthPath('/auth/login/qr/confirm'), isFalse);
      expect(ApiClient.isAnonymousAuthPath('auth/login/qr/scan'), isFalse);
    });

    test('qr session create/poll stay anonymous', () {
      expect(ApiClient.isAnonymousAuthPath('/auth/login/qr/session'), isTrue);
      expect(
        ApiClient.isAnonymousAuthPath(
          '/auth/login/qr/session/a1b2c3d4-e5f6',
        ),
        isTrue,
      );
    });

    test('password login stays anonymous', () {
      expect(ApiClient.isAnonymousAuthPath('/auth/login/password'), isTrue);
    });
  });

  group('ApiClient.resolveClientPlatformHeader', () {
    test('contact uses iOS release channel on Android', () {
      expect(
        ApiClient.resolveClientPlatformHeader(
          path: '/api/v1/platform/contact',
          clientPlatform: 'Android',
        ),
        'iOS',
      );
      expect(
        ApiClient.resolveClientPlatformHeader(
          path: 'api/v1/platform/contact',
          clientPlatform: 'Android',
        ),
        'iOS',
      );
    });

    test('other paths keep the real client platform', () {
      expect(
        ApiClient.resolveClientPlatformHeader(
          path: '/api/v1/platform/splash',
          clientPlatform: 'Android',
        ),
        'Android',
      );
      expect(
        ApiClient.resolveClientPlatformHeader(
          path: '/sms/send',
          clientPlatform: 'iOS',
        ),
        'iOS',
      );
    });
  });
}
