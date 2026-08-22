import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/dice/dice_static_thumb.dart';
import 'package:tencent_cloud_chat_demo/utils/dice_asset_warmup.dart';
import 'package:tencent_cloud_chat_demo/utils/dice_constants.dart';
import 'package:tencent_cloud_chat_demo/utils/dice_play_policy.dart';
import 'package:tencent_cloud_chat_demo/utils/dice_play_store.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_chat_bubble_size.dart';

/// 骰子主气泡：本机首次展示播动画，之后永久静帧。
class DiceFaceBubble extends StatefulWidget {
  const DiceFaceBubble({
    super.key,
    required this.value,
    this.playKey,
    this.maxWidthFactor = 0.26,
  });

  final int value;

  /// 稳定消息键；为空则永不播动画（预览场景可省略）。
  final String? playKey;

  final double maxWidthFactor;

  @override
  State<DiceFaceBubble> createState() => _DiceFaceBubbleState();
}

enum _DiceShowMode { still, animating }

class _DiceFaceBubbleState extends State<DiceFaceBubble> {
  /// 先静帧，避免 prefs 异步期间空白。
  _DiceShowMode _mode = _DiceShowMode.still;
  Key _animImageKey = UniqueKey();
  int _resolveToken = 0;
  bool _startingAnimation = false;

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
    // 气泡出现即催末帧缓存（无 context 的静帧路径）。
    unawaited(DiceAssetWarmup.ensureStillFrames());
    _resolveMode();
  }

  @override
  void didUpdateWidget(covariant DiceFaceBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value) {
      _resolveToken++;
      _startingAnimation = false;
      setState(() => _mode = _DiceShowMode.still);
      _resolveMode();
      return;
    }
    if (oldWidget.playKey != widget.playKey) {
      unawaited(_migrateOrResolvePlayKey(oldWidget.playKey));
    }
  }

  Future<void> _migrateOrResolvePlayKey(String? oldPlayKey) async {
    final oldKey = oldPlayKey?.trim() ?? '';
    final newKey = widget.playKey?.trim() ?? '';
    await DicePlayStore.instance.ensureLoaded();
    if (!mounted) {
      return;
    }
    final decision = decideDicePlayKeyUpdate(
      oldKey: oldKey,
      newKey: newKey,
      oldKeyPlayed: DicePlayStore.instance.hasPlayed(oldKey),
      newKeyPlayed: DicePlayStore.instance.hasPlayed(newKey),
      isAnimatingOrStarting:
          _startingAnimation || _mode == _DiceShowMode.animating,
    );
    switch (decision.action) {
      case DicePlayKeyAction.keepStill:
        return;
      case DicePlayKeyAction.keepAnimatingAndMigrate:
        final markKey = decision.markKey;
        if (markKey != null && markKey.isNotEmpty) {
          await DicePlayStore.instance.markPlayed(markKey);
        }
        return;
      case DicePlayKeyAction.keepStillAndMigrate:
        final markKey = decision.markKey;
        if (markKey != null && markKey.isNotEmpty) {
          await DicePlayStore.instance.markPlayed(markKey);
        }
        if (!mounted) {
          return;
        }
        if (_mode != _DiceShowMode.still) {
          setState(() => _mode = _DiceShowMode.still);
        }
        return;
      case DicePlayKeyAction.resolveMode:
        await _resolveMode();
        return;
    }
  }

  Future<void> _resolveMode() async {
    final token = ++_resolveToken;
    var key = widget.playKey?.trim() ?? '';
    if (key.isEmpty) {
      if (!mounted || token != _resolveToken) {
        return;
      }
      if (_mode != _DiceShowMode.still) {
        setState(() => _mode = _DiceShowMode.still);
      }
      return;
    }

    await DicePlayStore.instance.ensureLoaded();
    if (!mounted || token != _resolveToken) {
      return;
    }
    // await 后 playKey 可能已从本地 id 换成 msgID。
    key = widget.playKey?.trim() ?? '';
    if (key.isEmpty) {
      return;
    }
    if (DicePlayStore.instance.hasPlayed(key)) {
      // 开播后会立刻落盘；id→msgID 迁标记时不能把进行中的 webp 切成静帧。
      if (_mode == _DiceShowMode.animating || _startingAnimation) {
        return;
      }
      if (_mode != _DiceShowMode.still) {
        setState(() => _mode = _DiceShowMode.still);
      }
      return;
    }

    await _beginAnimating();
    if (!mounted || token != _resolveToken) {
      return;
    }
    await DicePlayStore.instance.markPlayed(key);
    final latest = widget.playKey?.trim() ?? '';
    if (latest.isNotEmpty && latest != key) {
      await DicePlayStore.instance.markPlayed(latest);
    }
  }

  Future<void> _beginAnimating() async {
    _startingAnimation = true;
    final path = DiceConstants.assetPathForValue(_value);
    await AssetImage(path).evict();
    if (!mounted) {
      _startingAnimation = false;
      return;
    }
    setState(() {
      _animImageKey = UniqueKey();
      _mode = _DiceShowMode.animating;
      _startingAnimation = false;
    });
  }

  Size _bubbleSize(BuildContext context) {
    return resolveStickerChatBubbleSize(
      screenWidth: MediaQuery.sizeOf(context).width,
      maxWidthFactor: widget.maxWidthFactor,
      intrinsicWidth: 512,
      intrinsicHeight: 512,
    );
  }

  @override
  Widget build(BuildContext context) {
    final size = _bubbleSize(context);
    final v = _value;
    final Widget child;
    switch (_mode) {
      case _DiceShowMode.still:
        child = DiceStaticThumb(value: v, cacheSize: 256);
      case _DiceShowMode.animating:
        child = TickerMode(
          enabled: true,
          child: Image.asset(
            DiceConstants.assetPathForValue(v),
            key: _animImageKey,
            fit: BoxFit.contain,
            filterQuality: FilterQuality.medium,
            errorBuilder: (context, error, stackTrace) {
              return DiceStaticThumb(value: v, cacheSize: 256);
            },
          ),
        );
    }
    return SizedBox(
      width: size.width,
      height: size.height,
      child: child,
    );
  }
}
