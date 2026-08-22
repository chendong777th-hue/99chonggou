import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/models/sticker_models.dart';
import 'package:tencent_cloud_chat_demo/src/provider/user_sticker_provider.dart';
import 'package:tencent_cloud_chat_demo/src/repository/sticker_repository.dart';
import 'package:tencent_cloud_chat_demo/src/pages/sticker/sticker_single_preview_page.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_image.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_chat_bubble_size.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_constants.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_image_size_probe.dart';

class StickerFaceBubble extends StatefulWidget {
  const StickerFaceBubble({
    super.key,
    required this.data,
    /// 超出此屏宽比例才等比缩小；主气泡默认约 0.4。
    this.maxWidthFactor = 0.4,
    this.enableFullScreenPreview = true,
  });

  final String data;
  final double maxWidthFactor;
  final bool enableFullScreenPreview;

  @override
  State<StickerFaceBubble> createState() => _StickerFaceBubbleState();
}

class _StickerFaceBubbleState extends State<StickerFaceBubble> {
  StickerItem? _item;
  bool _loading = false;
  int _probeToken = 0;

  Size _displaySizeOf(BuildContext context) {
    return resolveStickerChatBubbleSize(
      screenWidth: MediaQuery.sizeOf(context).width,
      maxWidthFactor: widget.maxWidthFactor,
      intrinsicWidth: _item?.width,
      intrinsicHeight: _item?.height,
    );
  }

  @override
  void initState() {
    super.initState();
    UserStickerProvider.shared.addListener(_onStickerProviderChanged);
    StickerRepository.instance.revision.addListener(_onStickerCacheChanged);
    _resolve(initial: true);
  }

  @override
  void dispose() {
    UserStickerProvider.shared.removeListener(_onStickerProviderChanged);
    StickerRepository.instance.revision.removeListener(_onStickerCacheChanged);
    super.dispose();
  }

  void _applyItem(StickerItem? item, {required bool loading}) {
    setState(() {
      _item = item;
      _loading = loading;
    });
    if (item != null && _hasDisplayableItem(item) && !item.hasIntrinsicSize) {
      unawaited(_probeMissingSize(item));
    }
  }

  Future<void> _probeMissingSize(StickerItem item) async {
    if (item.hasIntrinsicSize) {
      return;
    }
    final token = ++_probeToken;
    // 优先静态缩略图：更快且宽高比通常与原图一致。
    final probeUrl = item.displayUrl(preferAnimated: false);
    final fallbackUrl = item.originUrl.trim().isNotEmpty &&
            item.originUrl.trim() != probeUrl
        ? item.originUrl.trim()
        : '';
    Size? size = await StickerImageSizeProbe.instance.probe(
      probeUrl,
      stickerId: item.stickerId,
    );
    if (size == null && fallbackUrl.isNotEmpty) {
      size = await StickerImageSizeProbe.instance.probe(
        fallbackUrl,
        stickerId: item.stickerId,
      );
    }
    if (!mounted || token != _probeToken || size == null) {
      return;
    }
    final width = size.width.round();
    final height = size.height.round();
    if (width <= 0 || height <= 0) {
      return;
    }
    final enriched = item.copyWithSize(width: width, height: height);
    setState(() => _item = enriched);
    if (enriched.stickerId.isNotEmpty) {
      StickerRepository.instance.putCache(enriched);
    }
  }

  void _onStickerCacheChanged() {
    if (!mounted) {
      return;
    }
    final stickerId =
        StickerRepository.instance.parseStickerId(widget.data)?.trim() ?? '';
    if (stickerId.isEmpty) {
      return;
    }
    final cached = StickerRepository.instance.getCached(stickerId);
    if (cached == null || !_hasDisplayableItem(cached)) {
      return;
    }
    final current = _item;
    if (current != null &&
        _hasDisplayableItem(current) &&
        current.hasIntrinsicSize) {
      return;
    }
    if (current != null &&
        current.hasIntrinsicSize == cached.hasIntrinsicSize &&
        current.thumbUrl == cached.thumbUrl &&
        current.originUrl == cached.originUrl) {
      return;
    }
    _applyItem(cached, loading: false);
  }

  void _onStickerProviderChanged() {
    if (!mounted) {
      return;
    }
    final stickerId =
        StickerRepository.instance.parseStickerId(widget.data)?.trim() ?? '';
    if (stickerId.isEmpty) {
      return;
    }
    final current = _item;
    if (current != null &&
        _hasDisplayableItem(current) &&
        current.hasIntrinsicSize) {
      return;
    }
    final fromProvider = UserStickerProvider.shared.findStickerById(stickerId);
    if (fromProvider != null && _hasDisplayableItem(fromProvider)) {
      StickerRepository.instance.putCache(fromProvider);
      _applyItem(fromProvider, loading: false);
      return;
    }
    final sync =
        StickerRepository.instance.resolveStickerItemSync(widget.data);
    if (sync != null && _hasDisplayableItem(sync)) {
      _applyItem(sync, loading: false);
    }
  }

  bool _hasDisplayableItem(StickerItem? item) {
    return item != null && item.displayUrl(preferAnimated: false).isNotEmpty;
  }

  @override
  void didUpdateWidget(StickerFaceBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) {
      _probeToken++;
      _resolve();
    }
  }

  Future<void> _resolve({bool initial = false}) async {
    if (!StickerRepository.instance.isDynamicFaceData(widget.data)) {
      if (initial) {
        _item = null;
        _loading = false;
      } else if (mounted) {
        setState(() {
          _item = null;
          _loading = false;
        });
      }
      return;
    }

    final sync =
        StickerRepository.instance.resolveStickerItemSync(widget.data);
    if (sync != null && _hasDisplayableItem(sync)) {
      if (mounted) {
        _applyItem(sync, loading: false);
      }
      return;
    }

    if (initial) {
      _loading = true;
    } else if (mounted) {
      setState(() {
        _loading = true;
      });
    }

    final item =
        await StickerRepository.instance.resolveStickerItem(widget.data);
    if (!mounted) {
      return;
    }
    _applyItem(_hasDisplayableItem(item) ? item : null, loading: false);
  }

  @override
  Widget build(BuildContext context) {
    final displaySize = _displaySizeOf(context);
    Widget child;
    if (_loading) {
      child = SizedBox(
        width: displaySize.width,
        height: displaySize.height,
        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
      );
    } else if (_hasDisplayableItem(_item)) {
      child = StickerImage(
        item: _item!,
        preferAnimated: true,
        pauseWhenOffscreen: true,
        fit: BoxFit.contain,
        width: displaySize.width,
        height: displaySize.height,
      );
    } else {
      final assetPath = resolveBuiltinFaceAssetPath(widget.data);
      if (assetPath != null) {
        child = Image.asset(
          assetPath,
          fit: BoxFit.contain,
          width: displaySize.width,
          height: displaySize.height,
          gaplessPlayback: true,
          errorBuilder: (_, __, ___) => _placeholder(displaySize),
        );
      } else {
        child = _placeholder(displaySize);
      }
    }
    final bubble = SizedBox(
      width: displaySize.width,
      height: displaySize.height,
      child: child,
    );
    if (!widget.enableFullScreenPreview) {
      return bubble;
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => StickerSinglePreviewPage.open(
        context,
        data: widget.data,
        assetPath:
            _item == null ? resolveBuiltinFaceAssetPath(widget.data) : null,
        preloadedItem: _item,
      ),
      child: bubble,
    );
  }

  Widget _placeholder(Size displaySize) {
    final iconSize = math.min(displaySize.width, displaySize.height) * 0.3;
    return Container(
      width: displaySize.width,
      height: displaySize.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Colors.black12,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(Icons.emoji_emotions_outlined, size: iconSize),
    );
  }
}

bool stickerFaceShouldUseCustomBubble(String data) {
  final t = data.trim();
  return t.isNotEmpty;
}

String? resolveBuiltinFaceAssetPath(String data) {
  var path = data.trim();
  if (path.isEmpty ||
      path.startsWith('http') ||
      path.startsWith(StickerConstants.stickerDataScheme)) {
    return null;
  }
  if (path.contains('assets/custom_face_resource/')) {
    if (!path.contains('@2x.png') && !path.endsWith('.png')) {
      path = '$path@2x.png';
    }
    return path;
  }

  var emojiName = path;
  if (emojiName.startsWith('[') && emojiName.endsWith(']')) {
    emojiName = emojiName.substring(1, emojiName.length - 1);
  }
  if (emojiName.startsWith('TUIEmoji_')) {
    return 'assets/custom_face_resource/tcc1/$emojiName.png';
  }

  int? dirNumber;
  if (path.contains('yz')) {
    dirNumber = 4350;
  } else if (path.contains('ys')) {
    dirNumber = 4351;
  } else if (path.contains('gcs')) {
    dirNumber = 4352;
  }
  if (dirNumber == null) {
    return null;
  }

  final name = path.contains('/') ? path.split('/').last : path;
  final baseName = name.split('@').first.split('.').first;
  return 'assets/custom_face_resource/$dirNumber/$baseName@2x.png';
}
