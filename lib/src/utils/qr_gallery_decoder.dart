import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_zxing/flutter_zxing.dart';
import 'package:image/image.dart' as img;
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tencent_cloud_chat_demo/src/utils/qr_image_normalizer.dart';
import 'package:tencent_cloud_chat_demo/src/utils/qr_web_login_payload.dart';
import 'package:tencent_cloud_chat_demo/src/utils/qr_zxing2_decode.dart';

/// 相册二维码识别：规范化 → flutter_zxing 多 pass → zxing2 兜底。
///
/// 不假设码在画面中心。相册路径默认不调用 ML Kit analyzeImage。
class QrGalleryDecoder {
  QrGalleryDecoder._();

  static const Duration _totalTimeout = Duration(seconds: 8);
  static const Duration _normalizeBudget = Duration(milliseconds: 800);
  static const Duration _flutterZxingPassBudget = Duration(milliseconds: 550);
  static const Duration _zxing2Reserve = Duration(milliseconds: 1500);

  static bool? _flutterZxingReady;

  /// 对外入口：返回一条优先业务码的 raw；失败为 null。
  static Future<String?> decodeFromPath(
    String path, {
    @Deprecated('Gallery path no longer uses ML Kit analyzeImage')
    MobileScannerController? mlKitScanner,
  }) async {
    final results = await scanAll(path);
    return pickPreferred(results);
  }

  /// 返回去重后的全部文本。
  static Future<List<String>> scanAll(String path) async {
    if (path.trim().isEmpty || kIsWeb) {
      return const <String>[];
    }

    final deadline = DateTime.now().add(_totalTimeout);
    NormalizedQrImage? normalized;
    try {
      normalized = await QrImageNormalizer.normalize(path).timeout(
        _normalizeBudget,
        onTimeout: () => NormalizedQrImage(
          path: path,
          width: 0,
          height: 0,
          isTemporary: false,
        ),
      );
      final scanPath =
          (normalized.path.isNotEmpty) ? normalized.path : path;
      return await _scanPasses(scanPath, deadline: deadline);
    } catch (_) {
      return const <String>[];
    } finally {
      await normalized?.disposeTemporary();
    }
  }

  @visibleForTesting
  static String? pickPreferred(List<String> values) {
    if (values.isEmpty) {
      return null;
    }
    for (final value in values) {
      if (_looksLikeAppBusinessQr(value)) {
        return value;
      }
    }
    return values.first;
  }

  /// 单测同步入口（纯 Dart zxing2，不依赖 FFI）。
  @visibleForTesting
  static String? decodeZxingFromPathForTest(String path) {
    return pickPreferred(decodeQrWithZxing2FromPath(path));
  }

  static Future<List<String>> _scanPasses(
    String path, {
    required DateTime deadline,
  }) async {
    final collected = <String>{};

    void absorb(Iterable<String> batch) {
      for (final item in batch) {
        final text = item.trim();
        if (text.isNotEmpty) {
          collected.add(text);
        }
      }
    }

    Duration remaining() {
      final left = deadline.difference(DateTime.now());
      return left.isNegative ? Duration.zero : left;
    }

    if (_isFlutterZxingUsable()) {
      final passes = <DecodeParams>[
        DecodeParams(
          format: Format.qrCode,
          tryRotate: true,
          tryHarder: false,
          tryInverted: false,
          maxSize: 2048,
        ),
        DecodeParams(
          format: Format.qrCode,
          tryRotate: true,
          tryHarder: true,
          tryInverted: true,
          maxSize: 2048,
        ),
        DecodeParams(
          format: Format.qrCode,
          tryRotate: true,
          tryHarder: true,
          tryInverted: true,
          maxSize: 3072,
        ),
      ];
      for (final params in passes) {
        if (remaining() <= _zxing2Reserve) {
          break;
        }
        final budget = _minDuration(
          _flutterZxingPassBudget,
          remaining() - _zxing2Reserve,
        );
        if (budget <= Duration.zero) {
          break;
        }
        absorb(await _decodeFlutterZxing(path, params).timeout(
          budget,
          onTimeout: () => const <String>[],
        ));
        if (collected.isNotEmpty) {
          return collected.toList(growable: false);
        }
      }
    }

    // 灰度增强主要为原生 flutter_zxing 服务；VM 单测跳过以免主 isolate 同步 decode 拖死超时。
    if (_isFlutterZxingUsable() && remaining() > _zxing2Reserve) {
      final enhanced = await _writeEnhancedGrayJpeg(path)
          .timeout(remaining() - _zxing2Reserve, onTimeout: () => null);
      if (enhanced != null) {
        try {
          if (remaining() > _zxing2Reserve) {
            absorb(await _decodeFlutterZxing(
              enhanced,
              DecodeParams(
                format: Format.qrCode,
                tryRotate: true,
                tryHarder: true,
                tryInverted: true,
                maxSize: 2048,
              ),
            ).timeout(
              _minDuration(
                _flutterZxingPassBudget,
                remaining() - _zxing2Reserve,
              ),
              onTimeout: () => const <String>[],
            ));
          }
          if (collected.isEmpty &&
              remaining() > const Duration(milliseconds: 200)) {
            absorb(await compute(decodeQrWithZxing2FromPath, enhanced).timeout(
              remaining(),
              onTimeout: () => const <String>[],
            ));
          }
        } finally {
          try {
            final file = File(enhanced);
            if (await file.exists()) {
              await file.delete();
            }
          } catch (_) {}
        }
        if (collected.isNotEmpty) {
          return collected.toList(growable: false);
        }
      }
    }

    // FFI 不可用（单测 VM）或原生仍失败时，纯 Dart 全图多尺度兜底。
    if (remaining() > const Duration(milliseconds: 150)) {
      final budget = remaining();
      // 桌面/单测直接同步调用，避免 compute 拉起 isolate 的额外开销与加载问题。
      if (!(Platform.isIOS || Platform.isAndroid) ||
          Platform.environment.containsKey('FLUTTER_TEST')) {
        absorb(decodeQrWithZxing2FromPath(path));
      } else {
        absorb(await compute(decodeQrWithZxing2FromPath, path).timeout(
          budget,
          onTimeout: () => const <String>[],
        ));
      }
    }
    return collected.toList(growable: false);
  }

  static bool _isFlutterZxingUsable() {
    if (kIsWeb) {
      return false;
    }
    // 仅真机 iOS/Android 走原生引擎；桌面 VM 单测无 dylib。
    if (!(Platform.isIOS || Platform.isAndroid)) {
      return false;
    }
    if (Platform.environment.containsKey('FLUTTER_TEST')) {
      return false;
    }
    final cached = _flutterZxingReady;
    if (cached != null) {
      return cached;
    }
    try {
      final _ = zx.version();
      _flutterZxingReady = true;
    } catch (_) {
      _flutterZxingReady = false;
    }
    return _flutterZxingReady!;
  }

  static Duration _minDuration(Duration a, Duration b) {
    return a <= b ? a : b;
  }

  static Future<List<String>> _decodeFlutterZxing(
    String path,
    DecodeParams params,
  ) async {
    try {
      final codes = await zx.readBarcodesImagePathString(path, params: params);
      return codes.codes
          .where((c) => c.isValid && (c.text?.trim().isNotEmpty ?? false))
          .map((c) => c.text!.trim())
          .toList(growable: false);
    } catch (_) {
      try {
        final code = await zx.readBarcodeImagePathString(path, params: params);
        final text = code.text?.trim() ?? '';
        if (code.isValid && text.isNotEmpty) {
          return <String>[text];
        }
      } catch (_) {}
      return const <String>[];
    }
  }

  static Future<String?> _writeEnhancedGrayJpeg(String path) async {
    try {
      final bytes = await File(path).readAsBytes();
      var image = img.decodeImage(bytes);
      if (image == null) {
        return null;
      }
      image = img.grayscale(image);
      image = img.adjustColor(image, contrast: 1.25);
      final encoded = img.encodeJpg(image, quality: 92);
      final dir = await getTemporaryDirectory();
      final outDir = Directory('${dir.path}/qr_norm');
      if (!await outDir.exists()) {
        await outDir.create(recursive: true);
      }
      final out = File(
        '${outDir.path}/qr_enh_${DateTime.now().millisecondsSinceEpoch}.jpg',
      );
      await out.writeAsBytes(encoded, flush: true);
      return out.path;
    } catch (_) {
      return null;
    }
  }

  static bool _looksLikeAppBusinessQr(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) {
      return false;
    }
    if (QrWebLoginPayload.tryParse(trimmed) != null) {
      return true;
    }
    try {
      final decoded = jsonDecode(trimmed);
      if (decoded is Map) {
        final type = decoded['type']?.toString();
        final id = decoded['id']?.toString() ?? '';
        if (id.isNotEmpty && (type == 'user' || type == 'group')) {
          return true;
        }
      }
    } catch (_) {}
    return false;
  }
}
