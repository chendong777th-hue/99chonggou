import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/api/platform_api.dart';

void main() {
  test('PlatformSplashConfig parses disabled payload', () {
    final config = PlatformSplashConfig.fromJson(const {
      'enabled': false,
      'version': 'default',
      'imageUrl': null,
    });
    expect(config.enabled, isFalse);
    expect(config.version, 'default');
    expect(config.imageUrl, isNull);
    expect(config.hasDownloadableImage, isFalse);
  });

  test('PlatformSplashConfig parses enabled payload', () {
    final config = PlatformSplashConfig.fromJson(const {
      'enabled': true,
      'version': '20260718-01',
      'imageUrl': 'https://cdn.example.com/splash/20260718-01/splash.webp',
      'imageMd5': 'd41d8cd98f00b204e9800998ecf8427e',
      'contentType': 'image/webp',
      'width': 1080,
      'height': 1920,
      'bytes': 286720,
      'fit': 'cover',
    });
    expect(config.enabled, isTrue);
    expect(config.version, '20260718-01');
    expect(config.hasDownloadableImage, isTrue);
    expect(config.width, 1080);
    expect(config.height, 1920);
    expect(config.contentType, 'image/webp');
  });

  test('PlatformSplashConfig treats blank imageUrl as disabled download', () {
    final config = PlatformSplashConfig.fromJson(const {
      'enabled': true,
      'version': '20260718-01',
      'imageUrl': '   ',
    });
    expect(config.hasDownloadableImage, isFalse);
  });
}
