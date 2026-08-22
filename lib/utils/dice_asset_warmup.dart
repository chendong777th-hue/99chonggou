import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/utils/dice_constants.dart';

/// 骰子 webp 预热：末帧内存缓存 + 动画 Asset 预缓存（幂等）。
class DiceAssetWarmup {
  DiceAssetWarmup._();

  static const List<int> defaultStillSizes = <int>[128, 256];

  static final Map<String, ui.Image> _stillFrames = <String, ui.Image>{};
  static Future<void>? _stillWarmup;
  static Future<void>? _animatedWarmup;

  static String _stillKey(int value, int cacheSize) => '$value@$cacheSize';

  /// 同步取末帧；未预热则返回 null。
  static ui.Image? stillFrame(int value, int cacheSize) {
    final v = value < 1 || value > 6 ? 1 : value;
    return _stillFrames[_stillKey(v, cacheSize)];
  }

  /// 缓存未命中时由解码路径写入；已存在则忽略（调用方负责 dispose 多余图）。
  static bool storeStillIfAbsent(int value, int cacheSize, ui.Image image) {
    final v = value < 1 || value > 6 ? 1 : value;
    final key = _stillKey(v, cacheSize);
    if (_stillFrames.containsKey(key)) {
      return false;
    }
    _stillFrames[key] = image;
    return true;
  }

  /// 解码 1–6 末帧到内存；可重复调用，合并为单次进行中的 Future。
  static Future<void> ensureStillFrames({
    List<int> sizes = defaultStillSizes,
  }) {
    return _stillWarmup ??= _warmStillFrames(sizes);
  }

  static Future<void> _warmStillFrames(List<int> sizes) async {
    try {
      final uniqueSizes = sizes.toSet().where((s) => s > 0).toList();
      for (final cacheSize in uniqueSizes) {
        for (var value = 1; value <= 6; value++) {
          final key = _stillKey(value, cacheSize);
          if (_stillFrames.containsKey(key)) {
            continue;
          }
          try {
            final data =
                await rootBundle.load(DiceConstants.assetPathForValue(value));
            final bytes = data.buffer.asUint8List();
            final codec = await ui.instantiateImageCodec(
              bytes,
              targetWidth: cacheSize,
              targetHeight: cacheSize,
            );
            ui.FrameInfo? last;
            for (var i = 0; i < codec.frameCount; i++) {
              final info = await codec.getNextFrame();
              last?.image.dispose();
              last = info;
            }
            final image = last?.image;
            if (image == null) {
              continue;
            }
            if (!storeStillIfAbsent(value, cacheSize, image)) {
              image.dispose();
            }
          } catch (_) {
            // 单点失败不阻断其余点数。
          }
        }
      }
    } finally {
      // 允许失败后重试。
      if (_stillFrames.length < 6 * sizes.toSet().length) {
        _stillWarmup = null;
      }
    }
  }

  /// 预缓存动画 Asset（需 [BuildContext]）；与末帧预热一并触发。
  static Future<void> precacheAnimated(BuildContext context) {
    return _animatedWarmup ??= _precacheAnimated(context);
  }

  static Future<void> _precacheAnimated(BuildContext context) async {
    try {
      for (var value = 1; value <= 6; value++) {
        if (!context.mounted) {
          return;
        }
        try {
          await precacheImage(
            AssetImage(DiceConstants.assetPathForValue(value)),
            context,
          );
        } catch (_) {
          // 单点失败不阻断。
        }
      }
    } finally {
      // 若 context 中途失效，允许下次再试。
      if (!context.mounted) {
        _animatedWarmup = null;
      }
    }
  }

  /// 进聊天 / 表情面板：末帧必做；有 context 时再 precache 动画。
  static Future<void> warm(
    BuildContext? context, {
    List<int> stillSizes = defaultStillSizes,
  }) async {
    await ensureStillFrames(sizes: stillSizes);
    if (context == null || !context.mounted) {
      return;
    }
    await precacheAnimated(context);
  }
}
