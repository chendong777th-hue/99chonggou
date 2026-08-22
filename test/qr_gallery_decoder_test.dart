import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:tencent_cloud_chat_demo/src/utils/qr_gallery_decoder.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const savedCard =
      'test/fixtures/qr_gallery/IMAGE_2026-06-20_21_22_37-56b1a881-05d3-45e7-b6b2-8ee6d77e0cf7.png';
  const screenshot =
      'test/fixtures/qr_gallery/IMAGE_2026-06-20_21_22_39-e3caf051-8631-41c6-bc49-fb42868d0d79.png';

  Future<void> expectDecoded(String path, Pattern idFragment) async {
    final sw = Stopwatch()..start();
    final value = await QrGalleryDecoder.decodeFromPath(path);
    sw.stop();
    expect(value, isNotNull, reason: 'failed to decode $path');
    expect(value!, contains(idFragment));
    expect(
      sw.elapsedMilliseconds,
      lessThan(10000),
      reason: 'decode took ${sw.elapsedMilliseconds}ms',
    );
  }

  test('decodes saved QR card image quickly', () async {
    await expectDecoded(savedCard, 'acnj6oxey9');
  });

  test('decodes full-page QR screenshot', () async {
    await expectDecoded(screenshot, 'jc1kbqdxvf');
  });

  test('pickPreferred favors app business payload', () {
    final preferred = QrGalleryDecoder.pickPreferred([
      'https://example.com',
      '{"type":"user","id":"u_abc","name":"n"}',
    ]);
    expect(preferred, contains('u_abc'));
  });

  test('returns null quickly for image without QR code', () async {
    final plain = img.Image(width: 640, height: 960);
    img.fill(plain, color: img.ColorRgb8(120, 180, 220));
    final tempDir = await Directory.systemTemp.createTemp('qr_gallery_test_');
    final path = '${tempDir.path}/plain.png';
    await File(path).writeAsBytes(img.encodePng(plain));

    final sw = Stopwatch()..start();
    final value = await QrGalleryDecoder.decodeFromPath(path);
    sw.stop();

    expect(value, isNull);
    expect(
      sw.elapsedMilliseconds,
      lessThan(10000),
      reason: 'no-QR decode took ${sw.elapsedMilliseconds}ms',
    );
    await tempDir.delete(recursive: true);
  });

  test('sync zxing2 helper decodes fixture', () {
    final value = QrGalleryDecoder.decodeZxingFromPathForTest(savedCard);
    expect(value, contains('acnj6oxey9'));
  });
}
