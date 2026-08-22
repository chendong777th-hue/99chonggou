import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/pages/sticker/sticker_upload_page.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/dice/dice_static_thumb.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_panel_theme.dart';
import 'package:tencent_cloud_chat_demo/src/provider/user_sticker_provider.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_image.dart';
import 'package:tencent_cloud_chat_demo/utils/dice_asset_warmup.dart';
import 'package:tencent_cloud_chat_demo/utils/dice_constants.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_send_helper.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_panel_long_press_preview.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_media.dart';
import 'package:tim_ui_kit_sticker_plugin/utils/tim_ui_kit_sticker_data.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';

/// 「收藏 + 我的上传」网格：每行 4 格；顺序为添加 → 骰子 → 用户表情。
class StickerMyCollectionGrid extends StatelessWidget {
  const StickerMyCollectionGrid({
    super.key,
    required this.pack,
    required this.sendFaceMsg,
    required this.panelTheme,
    this.deleteText,
    this.height,
    this.width,
    this.crossAxisCount = 4,
    this.showDeleteButton = false,
    this.bottomPadding = 0,
  });

  final CustomStickerPackage pack;
  final void Function(int index, String data) sendFaceMsg;
  final StickerPanelTheme panelTheme;
  final VoidCallback? deleteText;
  final double? height;
  final double? width;
  final int crossAxisCount;
  final bool showDeleteButton;
  final double bottomPadding;

  Future<void> _openUpload(BuildContext context) async {
    await Navigator.of(context).push(
      AppMaterialPageRoute(builder: (_) => const StickerUploadPage()),
    );
  }

  void _onDiceTap() {
    final value = math.Random().nextInt(6) + 1;
    final data = DiceConstants.dataForValue(value);
    if (data == null) {
      return;
    }
    sendFaceMsg(DiceConstants.diceFaceGroupIndex, data);
  }

  void _onStickerTap(CustomSticker sticker) {
    final stickerId = sticker.name.trim();
    if (stickerId.isEmpty) {
      return;
    }
    final item = UserStickerProvider.shared.findStickerById(stickerId);
    if (item != null) {
      StickerSendHelper.sendViaPanelCallback(
        sendFaceMsg,
        stickerId: stickerId,
        thumbUrl: item.thumbUrl,
        originUrl: item.originUrl,
      );
      return;
    }
    final url = sticker.url?.trim() ?? '';
    if (url.startsWith('http')) {
      sendFaceMsg(99, url);
    }
  }

  @override
  Widget build(BuildContext context) {
    final stickers = pack.stickerList;
    final showDice = DiceConstants.showInStickerPanel;
    // + 添加、（可选）置顶骰子、用户表情。
    final itemCount = stickers.length + (showDice ? 2 : 1);

    return ColoredBox(
      color: panelTheme.panelBackground,
      child: Stack(
        children: [
          GridView.builder(
            physics: const ClampingScrollPhysics(),
            padding: EdgeInsets.fromLTRB(8, 8, 8, bottomPadding),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: crossAxisCount,
              childAspectRatio: 1,
            ),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              if (index == 0) {
                return _AddStickerCell(
                  onTap: () => _openUpload(context),
                  panelTheme: panelTheme,
                );
              }
              if (showDice && index == 1) {
                return _DiceStickerCell(onTap: _onDiceTap);
              }
              final sticker = stickers[index - (showDice ? 2 : 1)];
              final layerLink = LayerLink();
              return GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => _onStickerTap(sticker),
                onLongPressStart: (_) {
                  StickerPanelLongPressPreview.show(
                    context: context,
                    layerLink: layerLink,
                    sticker: sticker,
                  );
                },
                onLongPressEnd: (_) => StickerPanelLongPressPreview.hide(),
                onLongPressCancel: StickerPanelLongPressPreview.hide,
                child: CompositedTransformTarget(
                  link: layerLink,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _StickerThumb(sticker: sticker),
                  ),
                ),
              );
            },
          ),
          if (showDeleteButton && deleteText != null)
            Align(
              alignment: Alignment.bottomRight,
              child: GestureDetector(
                onTap: deleteText!,
                child: Container(
                  decoration: BoxDecoration(
                    color: panelTheme.deleteButtonBackground,
                    boxShadow: [
                      BoxShadow(
                        color: panelTheme.deleteButtonShadow,
                        offset: Offset.zero,
                        blurRadius: 10,
                        spreadRadius: 2,
                      ),
                    ],
                    borderRadius: const BorderRadius.all(Radius.circular(4)),
                  ),
                  margin: const EdgeInsets.only(right: 10, bottom: 8),
                  width: 44,
                  height: 35,
                  child: Center(
                    child: Image.asset(
                      'images/delete_emoji.png',
                      package: 'tim_ui_kit_sticker_plugin',
                      width: 28,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DiceStickerCell extends StatelessWidget {
  const _DiceStickerCell({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    unawaited(DiceAssetWarmup.warm(context));
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.all(8),
        child: DiceStaticThumb(value: 6),
      ),
    );
  }
}

class _StickerThumb extends StatelessWidget {
  const _StickerThumb({required this.sticker});

  final CustomSticker sticker;

  @override
  Widget build(BuildContext context) {
    final stickerId = sticker.name.trim();
    final cached = stickerId.isNotEmpty
        ? UserStickerProvider.shared.findStickerById(stickerId)
        : null;
    if (cached != null) {
      return StickerImage(
        item: cached,
        preferAnimated: false,
        pauseWhenOffscreen: true,
        fit: BoxFit.contain,
      );
    }
    final url = sticker.url?.trim() ?? '';
    if (url.isNotEmpty) {
      return StickerImage.url(
        url: url,
        fallbackUrl: sticker.thumbUrl?.trim() ?? '',
        mediaType: sticker.mediaType ?? StickerMediaType.image,
        preferAnimated: false,
        pauseWhenOffscreen: true,
        fit: BoxFit.contain,
      );
    }
    return const Icon(Icons.emoji_emotions_outlined, size: 32);
  }
}

class _AddStickerCell extends StatelessWidget {
  const _AddStickerCell({
    required this.onTap,
    required this.panelTheme,
  });

  final VoidCallback onTap;
  final StickerPanelTheme panelTheme;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.all(4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: panelTheme.addCellBackground,
            border: Border.all(color: panelTheme.addCellBorder),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Center(
            child: Icon(
              Icons.add,
              size: 28,
              color: panelTheme.mutedIconColor,
            ),
          ),
        ),
      ),
    );
  }
}
