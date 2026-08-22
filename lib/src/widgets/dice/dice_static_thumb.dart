import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/utils/dice_asset_warmup.dart';
import 'package:tencent_cloud_chat_demo/utils/dice_constants.dart';

/// 骰子 webp 末帧静态图（入口 / 已看过气泡 / 预览）。
class DiceStaticThumb extends StatefulWidget {
  const DiceStaticThumb({
    super.key,
    this.value = 6,
    this.cacheSize = 128,
  });

  final int value;

  /// 解码目标边长（逻辑像素近似），减轻面板内存。
  final int cacheSize;

  @override
  State<DiceStaticThumb> createState() => _DiceStaticThumbState();
}

class _DiceStaticThumbState extends State<DiceStaticThumb> {
  ui.Image? _frame;
  bool _ownsFrame = false;
  bool _failed = false;

  int get _value {
    final v = widget.value;
    if (v < 1 || v > 6) {
      return 1;
    }
    return v;
  }

  @override
  void initState() {
    super.initState();
    if (!_tryApplyCachedFrame()) {
      _loadLastFrame();
    }
  }

  @override
  void didUpdateWidget(covariant DiceStaticThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.cacheSize != widget.cacheSize) {
      _disposeOwnedFrame();
      _frame = null;
      _failed = false;
      if (!_tryApplyCachedFrame()) {
        _loadLastFrame();
      }
    }
  }

  @override
  void dispose() {
    _disposeOwnedFrame();
    super.dispose();
  }

  void _disposeOwnedFrame() {
    if (_ownsFrame) {
      _frame?.dispose();
    }
    _frame = null;
    _ownsFrame = false;
  }

  bool _tryApplyCachedFrame() {
    final cached = DiceAssetWarmup.stillFrame(_value, widget.cacheSize);
    if (cached == null) {
      return false;
    }
    _frame = cached;
    _ownsFrame = false;
    _failed = false;
    return true;
  }

  Future<void> _loadLastFrame() async {
    try {
      final data =
          await rootBundle.load(DiceConstants.assetPathForValue(_value));
      final bytes = data.buffer.asUint8List();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: widget.cacheSize,
        targetHeight: widget.cacheSize,
      );
      ui.FrameInfo? last;
      for (var i = 0; i < codec.frameCount; i++) {
        final info = await codec.getNextFrame();
        last?.image.dispose();
        last = info;
      }
      if (!mounted) {
        last?.image.dispose();
        return;
      }
      final image = last?.image;
      if (image == null) {
        setState(() {
          _failed = true;
          _frame = null;
          _ownsFrame = false;
        });
        return;
      }
      // 优先并入全局缓存；失败则自持有。
      final cached = DiceAssetWarmup.stillFrame(_value, widget.cacheSize);
      if (cached != null) {
        image.dispose();
        setState(() {
          _frame = cached;
          _ownsFrame = false;
          _failed = false;
        });
        return;
      }
      final stored =
          DiceAssetWarmup.storeStillIfAbsent(_value, widget.cacheSize, image);
      setState(() {
        _frame = image;
        _ownsFrame = !stored;
        _failed = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() => _failed = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final frame = _frame;
    if (_failed) {
      return ColoredBox(
        color: const Color(0xFFF2F2F7),
        child: Center(
          child: Text(
            '$_value',
            style: const TextStyle(
              fontSize: 16,
              color: Color(0xFF8E8E93),
            ),
          ),
        ),
      );
    }
    if (frame == null) {
      // 非空占位，避免首帧全白；预热命中后通常不会走到这里。
      return const ColoredBox(color: Color(0xFFF2F2F7));
    }
    return RawImage(
      image: frame,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
    );
  }
}
