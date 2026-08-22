import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/models/sticker_models.dart';
import 'package:tencent_cloud_chat_demo/src/provider/user_sticker_provider.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_image.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_media.dart';
import 'package:tim_ui_kit_sticker_plugin/utils/tim_ui_kit_sticker_data.dart';

/// 表情面板长按放大预览：播放 GIF 动画，松手关闭。
class StickerPanelLongPressPreview {
  StickerPanelLongPressPreview._();

  static OverlayEntry? _entry;

  static void show({
    required BuildContext context,
    required LayerLink layerLink,
    required CustomSticker sticker,
  }) {
    hide();
    final item = _resolveStickerItem(sticker);
    if (item == null) {
      return;
    }
    _entry = OverlayEntry(
      builder: (ctx) => Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: ColoredBox(color: Colors.black.withValues(alpha: 0.05)),
            ),
          ),
          CompositedTransformFollower(
            link: layerLink,
            showWhenUnlinked: false,
            offset: const Offset(-30, -130),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(8),
              clipBehavior: Clip.antiAlias,
              color: Colors.white,
              child: Padding(
                padding: const EdgeInsets.all(8),
                child: StickerImage(
                  item: item,
                  preferAnimated: true,
                  width: 120,
                  height: 120,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          ),
        ],
      ),
    );
    Overlay.of(context).insert(_entry!);
  }

  static void hide() {
    _entry?.remove();
    _entry = null;
  }

  static StickerItem? _resolveStickerItem(CustomSticker sticker) {
    final stickerId = sticker.name.trim();
    if (stickerId.isNotEmpty) {
      final fromProvider = UserStickerProvider.shared.findStickerById(stickerId);
      if (fromProvider != null) {
        return fromProvider;
      }
    }
    final thumb = sticker.thumbUrl?.trim() ?? '';
    final origin = sticker.originUrl?.trim() ?? '';
    final url = sticker.url?.trim() ?? '';
    final resolvedThumb = thumb.isNotEmpty ? thumb : url;
    final resolvedOrigin = origin.isNotEmpty ? origin : url;
    if (resolvedThumb.isEmpty && resolvedOrigin.isEmpty) {
      return null;
    }
    final mediaType = sticker.mediaType?.trim() ?? '';
    return StickerItem(
      stickerId: stickerId,
      thumbUrl: resolvedThumb,
      originUrl: resolvedOrigin,
      mediaType: mediaType.isNotEmpty
          ? mediaType
          : (StickerMediaType.isGifUrl(resolvedOrigin)
              ? StickerMediaType.gif
              : StickerMediaType.image),
    );
  }
}
