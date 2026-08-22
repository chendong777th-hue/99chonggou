import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;
import 'package:zxing2/qrcode.dart';

/// 纯 Dart zxing2 全图解码（无 flutter_zxing/FFI），可供 `compute` 使用。
///
/// 策略：中小图先原图；大图先短边再抬分辨率；小图才放大。不做中心假 crop。
List<String> decodeQrWithZxing2FromPath(String path) {
  try {
    final bytes = File(path).readAsBytesSync();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) {
      return const <String>[];
    }
    final found = <String>{};
    for (final variant in _iterFullImageVariants(decoded)) {
      final text = _decodeWithZxing2(variant);
      if (text != null && text.trim().isNotEmpty) {
        found.add(text.trim());
      }
    }
    return found.toList(growable: false);
  } catch (_) {
    return const <String>[];
  }
}

String? _decodeWithZxing2(img.Image image) {
  final pixels = image
      .convert(numChannels: 4)
      .getBytes(order: img.ChannelOrder.abgr)
      .buffer
      .asInt32List();
  final source = RGBLuminanceSource(image.width, image.height, pixels);
  final reader = QRCodeReader();
  for (final binarizer in <Binarizer>[
    GlobalHistogramBinarizer(source),
    HybridBinarizer(source),
  ]) {
    try {
      final result = reader.decode(BinaryBitmap(binarizer));
      if (result.text.isNotEmpty) {
        return result.text;
      }
    } catch (_) {}
  }
  return null;
}

img.Image _limitSide(img.Image image, int maxSide) {
  final longSide = math.max(image.width, image.height);
  if (longSide <= maxSide) {
    return image;
  }
  final scale = maxSide / longSide;
  return img.copyResize(
    image,
    width: (image.width * scale).round().clamp(1, maxSide),
    height: (image.height * scale).round().clamp(1, maxSide),
    interpolation: img.Interpolation.linear,
  );
}

Iterable<img.Image> _iterFullImageVariants(img.Image source) sync* {
  final seen = <String>{};
  img.Image? unique(img.Image image) {
    final key = '${image.width}x${image.height}';
    if (!seen.add(key)) {
      return null;
    }
    return image;
  }

  final longSide = math.max(source.width, source.height);

  if (longSide <= 1400) {
    final original = unique(source);
    if (original != null) {
      yield original;
    }
    // 略缩小：有时能压掉 UI 噪声
    if (longSide > 600) {
      final mid = unique(_limitSide(source, (longSide * 0.75).round()));
      if (mid != null) {
        yield mid;
      }
    }
  } else {
    for (final maxSide in <int>[720, 1080, 1600, 2048]) {
      final scaled = unique(_limitSide(source, maxSide));
      if (scaled != null) {
        yield scaled;
      }
      if (math.max(scaled?.width ?? 0, scaled?.height ?? 0) >= longSide) {
        break;
      }
    }
  }

  if (longSide <= 900) {
    final up2 = unique(img.copyResize(
      source,
      width: source.width * 2,
      height: source.height * 2,
      interpolation: img.Interpolation.cubic,
    ));
    if (up2 != null) {
      yield up2;
    }
  }
}
