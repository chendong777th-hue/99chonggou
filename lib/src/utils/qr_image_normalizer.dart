import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NormalizedQrImage {
  const NormalizedQrImage({
    required this.path,
    required this.width,
    required this.height,
    required this.isTemporary,
  });

  final String path;
  final int width;
  final int height;
  final bool isTemporary;

  Future<void> disposeTemporary() async {
    if (!isTemporary) {
      return;
    }
    try {
      final file = File(path);
      if (await file.exists()) {
        await file.delete();
      }
    } catch (_) {}
  }
}

/// 平台侧把相册图转成正立 JPEG（处理 HEIC / Exif / 超大边），供 zxing 解码。
class QrImageNormalizer {
  QrImageNormalizer._();

  static const MethodChannel _channel = MethodChannel('qr_image_normalize');

  /// [maxSide]：规范化输出长边上限（默认 4096，保留小码细节供二次扫描）。
  static Future<NormalizedQrImage> normalize(
    String path, {
    int maxSide = 4096,
    int quality = 92,
  }) async {
    final source = path.trim();
    if (source.isEmpty) {
      return const NormalizedQrImage(
        path: '',
        width: 0,
        height: 0,
        isTemporary: false,
      );
    }
    if (kIsWeb) {
      return NormalizedQrImage(
        path: source,
        width: 0,
        height: 0,
        isTemporary: false,
      );
    }
    // 桌面单测无平台实现，直接回退原路径，避免 MethodChannel 空等。
    if (!(Platform.isIOS || Platform.isAndroid)) {
      return NormalizedQrImage(
        path: source,
        width: 0,
        height: 0,
        isTemporary: false,
      );
    }

    try {
      final raw = await _channel
          .invokeMethod<dynamic>('normalize', <String, dynamic>{
        'path': source,
        'maxSide': maxSide,
        'quality': quality.clamp(50, 100),
      }).timeout(const Duration(milliseconds: 800));
      if (raw is Map) {
        final outPath = (raw['path'] ?? '').toString().trim();
        if (outPath.isNotEmpty) {
          return NormalizedQrImage(
            path: outPath,
            width: _asInt(raw['width']),
            height: _asInt(raw['height']),
            isTemporary: raw['isTemporary'] == true,
          );
        }
      }
    } catch (_) {
      // 通道不可用、超时或解码失败时回退原路径（PNG/JPEG 夹具仍可走 Dart decode）。
    }

    return NormalizedQrImage(
      path: source,
      width: 0,
      height: 0,
      isTemporary: false,
    );
  }

  static int _asInt(Object? value) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.toInt();
    }
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }
}
