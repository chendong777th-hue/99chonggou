import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_image_size_probe.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    StickerImageSizeProbe.instance.clear();
  });

  test('empty url returns null', () async {
    final size = await StickerImageSizeProbe.instance.probe('  ');
    expect(size, isNull);
  });

  test('probes MemoryImage pixel size and caches by url', () async {
    final bytes = await _encodePng(width: 120, height: 80);
    final provider = MemoryImage(bytes);

    final first = await StickerImageSizeProbe.instance.probe(
      'memory://sticker-a',
      provider: provider,
      timeout: const Duration(seconds: 5),
    );
    expect(first, isNotNull);
    expect(first!.width, 120);
    expect(first.height, 80);

    final cached = StickerImageSizeProbe.instance.cached('memory://sticker-a');
    expect(cached, same(first));

    final second = await StickerImageSizeProbe.instance.probe(
      'memory://sticker-a',
      provider: MemoryImage(Uint8List.fromList(bytes)),
    );
    expect(second, same(first));
  });
}

Future<Uint8List> _encodePng({required int width, required int height}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);
  canvas.drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF00AAFF),
  );
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  return byteData!.buffer.asUint8List();
}
