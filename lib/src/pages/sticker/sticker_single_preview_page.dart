import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/models/sticker_models.dart';
import 'package:tencent_cloud_chat_demo/src/repository/sticker_repository.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_image.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_constants.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';

/// 单张表情全屏预览（聊天气泡点击）。
class StickerSinglePreviewPage extends StatefulWidget {
  const StickerSinglePreviewPage({
    super.key,
    required this.data,
    this.assetPath,
    this.preloadedItem,
  });

  final String data;
  final String? assetPath;
  final StickerItem? preloadedItem;

  static Future<void> open(
    BuildContext context, {
    required String data,
    String? assetPath,
    StickerItem? preloadedItem,
  }) {
    return Navigator.of(context).push(
      AppFullscreenDialogRoute(
        builder: (_) => StickerSinglePreviewPage(
          data: data,
          assetPath: assetPath,
          preloadedItem: preloadedItem,
        ),
      ),
    );
  }

  @override
  State<StickerSinglePreviewPage> createState() =>
      _StickerSinglePreviewPageState();
}

class _StickerSinglePreviewPageState extends State<StickerSinglePreviewPage> {
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    if (widget.preloadedItem != null ||
        (widget.assetPath != null && widget.assetPath!.isNotEmpty)) {
      if (mounted) {
        setState(() => _loading = false);
      }
      return;
    }
    if (widget.data.startsWith(StickerConstants.stickerDataScheme)) {
      await StickerRepository.instance.resolveStickerItem(widget.data);
    }
    if (mounted) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final maxSide = size.shortestSide * 0.72;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light,
      child: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        behavior: HitTestBehavior.opaque,
        child: Scaffold(
          backgroundColor: Colors.black.withValues(alpha: 0.92),
          body: SafeArea(
            child: Stack(
              children: [
                Center(
                  child: _loading
                      ? const CircularProgressIndicator(color: Colors.white70)
                      : _buildImage(maxSide),
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildImage(double maxSide) {
    final preloaded = widget.preloadedItem;
    if (preloaded != null) {
      return StickerImage(
        item: preloaded,
        width: maxSide,
        height: maxSide,
        preferAnimated: true,
        fit: BoxFit.contain,
      );
    }

    final asset = widget.assetPath;
    if (asset != null && asset.isNotEmpty) {
      if (asset.startsWith('http')) {
        return Image.network(
          asset,
          width: maxSide,
          height: maxSide,
          fit: BoxFit.contain,
        );
      }
      return Image.asset(
        asset,
        width: maxSide,
        height: maxSide,
        fit: BoxFit.contain,
        package: asset.contains('tim_ui_kit_sticker_plugin')
            ? 'tim_ui_kit_sticker_plugin'
            : null,
      );
    }

    if (widget.data.startsWith('http')) {
      return StickerImage.url(
        url: widget.data,
        width: maxSide,
        height: maxSide,
        preferAnimated: true,
        fit: BoxFit.contain,
      );
    }

    if (widget.data.startsWith(StickerConstants.stickerDataScheme)) {
      return FutureBuilder(
        future: StickerRepository.instance.resolveStickerItem(widget.data),
        builder: (context, snap) {
          final item = snap.data;
          if (item == null) {
            return Icon(
              Icons.emoji_emotions_outlined,
              size: maxSide * 0.4,
              color: Colors.white54,
            );
          }
          return StickerImage(
            item: item,
            width: maxSide,
            height: maxSide,
            preferAnimated: true,
            fit: BoxFit.contain,
          );
        },
      );
    }

    return Icon(
      Icons.emoji_emotions_outlined,
      size: maxSide * 0.4,
      color: Colors.white54,
    );
  }
}
