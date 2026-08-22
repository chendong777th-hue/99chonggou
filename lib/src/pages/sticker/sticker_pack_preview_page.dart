import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_my_collection_grid.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_panel_long_press_preview.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_panel_theme.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_constants.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';

/// 表情包全屏预览：展示整包表情，点击单项发送并关闭。
class StickerPackPreviewPage extends StatelessWidget {
  const StickerPackPreviewPage({
    super.key,
    required this.pack,
    required this.sendFaceMessage,
    this.deleteText,
    this.addText,
    this.addCustomEmojiText,
  });

  final CustomStickerPackage pack;
  final void Function(int index, String data) sendFaceMessage;
  final VoidCallback? deleteText;
  final void Function(int unicode)? addText;
  final void Function(String singleEmojiName)? addCustomEmojiText;

  static String titleForPack(CustomStickerPackage pack, AppI18n i18n) {
    if (pack.name == StickerConstants.virtualPackFavorites) {
      return i18n.t(
        zhHans: '我的收藏',
        zhHant: '我的收藏',
        en: 'My Favorites',
        ja: 'マイコレクション',
        ko: '내 즐겨찾기',
      );
    }
    if (pack.name == 'defaultEmoji') {
      return i18n.t(
        zhHans: '表情',
        zhHant: '表情',
        en: 'Emoji',
        ja: '絵文字',
        ko: '이모지',
      );
    }
    if (pack.name == '4349') {
      return i18n.t(
        zhHans: '经典表情',
        zhHant: '經典表情',
        en: 'Classic Emoji',
        ja: 'クラシック絵文字',
        ko: '클래식 이모지',
      );
    }
    if (pack.name == 'tcc1') {
      return i18n.t(
        zhHans: '云表情',
        zhHant: '雲表情',
        en: 'Cloud Emoji',
        ja: 'クラウド絵文字',
        ko: '클라우드 이모지',
      );
    }
    return pack.name.isNotEmpty
        ? pack.name
        : i18n.t(
            zhHans: '表情包',
            zhHant: '表情包',
            en: 'Sticker Pack',
            ja: 'スタンプパック',
            ko: '스티커 팩',
          );
  }

  static Future<void> open(
    BuildContext context, {
    required CustomStickerPackage pack,
    required void Function(int index, String data) sendFaceMessage,
    VoidCallback? deleteText,
    void Function(int unicode)? addText,
    void Function(String singleEmojiName)? addCustomEmojiText,
  }) {
    return Navigator.of(context).push(
      AppFullscreenDialogRoute(
        builder: (_) => StickerPackPreviewPage(
          pack: pack,
          sendFaceMessage: sendFaceMessage,
          deleteText: deleteText,
          addText: addText,
          addCustomEmojiText: addCustomEmojiText,
        ),
      ),
    );
  }

  void _sendAndClose(BuildContext context, int index, String data) {
    sendFaceMessage(index, data);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;
    final panelTheme = StickerPanelTheme.of(context);
    final isFavorites =
        pack.name == StickerConstants.virtualPackFavorites;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: AppColors.background(dark: dark),
        appBar: AppBar(
          elevation: 0,
          centerTitle: true,
          backgroundColor: AppColors.card(dark: dark),
          surfaceTintColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.close_rounded),
            color: AppColors.primaryBlue,
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(
            titleForPack(pack, i18n),
            style: TextStyle(
              color: AppColors.text(dark: dark),
              fontSize: 17,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        body: SafeArea(
          top: false,
          child: isFavorites
              ? StickerMyCollectionGrid(
                  pack: pack,
                  sendFaceMsg: (i, d) => _sendAndClose(context, i, d),
                  panelTheme: panelTheme,
                  deleteText: deleteText,
                  showDeleteButton: deleteText != null,
                  crossAxisCount: 4,
                )
              : LayoutBuilder(
                  builder: (context, constraints) {
                    return StickerPanel(
                      isWideScreen: false,
                      height: constraints.maxHeight,
                      width: constraints.maxWidth,
                      panelPadding: const EdgeInsets.fromLTRB(8, 12, 8, 12),
                      showBottomContainer: false,
                      sendTextMsg: null,
                      sendFaceMsg: (i, d) => _sendAndClose(context, i, d),
                      deleteText: deleteText ?? () {},
                      addText: addText ?? (_) {},
                      addCustomEmojiText: addCustomEmojiText ?? (_) {},
                      customStickerPackageList: [pack],
                      backgroundColor: panelTheme.panelBackground,
                      bottomColor: panelTheme.bottomBarBackground,
                      lightPrimaryColor: panelTheme.selectedTabColor,
                      showDeleteButton: false,
                      crossAxisCount: 4,
                      onLongTap: (context, layerLink, packIdx, sticker) {
                        StickerPanelLongPressPreview.show(
                          context: context,
                          layerLink: layerLink,
                          sticker: sticker,
                        );
                      },
                      onLongPressEnd: StickerPanelLongPressPreview.hide,
                    );
                  },
                ),
        ),
      ),
    );
  }
}
