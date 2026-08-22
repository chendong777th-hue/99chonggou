import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_network_image.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/sticker/sticker_panel_theme.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_constants.dart';
import 'package:tim_ui_kit_sticker_plugin/utils/tim_ui_kit_sticker_data.dart';

/// 微信风格底部栏：「收藏+我的上传」合并 Tab 为粉红爱心。
class WeChatStickerBottomBar extends StatelessWidget {
  const WeChatStickerBottomBar({
    super.key,
    required this.packages,
    required this.selectedIndex,
    required this.onSelected,
    required this.panelTheme,
    this.onPackPreview,
    this.height = 40,
  });

  final List<CustomStickerPackage> packages;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final ValueChanged<int>? onPackPreview;
  final StickerPanelTheme panelTheme;
  final double height;

  static const double _iconBox = 40;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      color: panelTheme.bottomBarBackground,
      child: Row(
        children: [
          Expanded(
            child: packages.isEmpty
                ? const SizedBox.shrink()
                : ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    itemCount: packages.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 2),
                    itemBuilder: (context, index) {
                      final pack = packages[index];
                      final selected = index == selectedIndex;
                      return InkWell(
                        onTap: () => onSelected(index),
                        onLongPress: onPackPreview == null
                            ? null
                            : () => onPackPreview!(index),
                        borderRadius: BorderRadius.circular(4),
                        child: Container(
                          width: _iconBox,
                          height: _iconBox,
                          decoration: BoxDecoration(
                            color: selected
                                ? panelTheme.selectedTabColor
                                : panelTheme.bottomBarBackground,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          alignment: Alignment.center,
                          child: _PackMenuIcon(
                            package: pack,
                            selected: selected,
                            panelTheme: panelTheme,
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PackMenuIcon extends StatelessWidget {
  const _PackMenuIcon({
    required this.package,
    required this.selected,
    required this.panelTheme,
  });

  final CustomStickerPackage package;
  final bool selected;
  final StickerPanelTheme panelTheme;

  static const String _pluginAssetPackage = 'tim_ui_kit_sticker_plugin';

  @override
  Widget build(BuildContext context) {
    if (_usePinkHeartTab(package)) {
      return Icon(
        Icons.favorite,
        size: 22,
        color: selected
            ? panelTheme.onSelectedTabIconColor
            : StickerPanelTheme.heartPink,
      );
    }

    final menu = package.menuItem;
    final previewUrl = _firstStickerPreviewUrl(package);

    if (menu.url != null && menu.url!.startsWith('http')) {
      return _networkThumb(menu.url!, selected, previewUrl);
    }

    final path = _assetPath(package, menu);
    if (path != null) {
      return Image.asset(
        path,
        package: _assetPackageForPath(path),
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        errorBuilder: (_, __, ___) => _fallbackIcon(selected, previewUrl),
      );
    }

    if (menu.unicode != null) {
      return Text(
        _emojiFromCode(menu.unicode!),
        style: TextStyle(
          fontSize: 20,
          color: selected
              ? panelTheme.onSelectedTabIconColor
              : panelTheme.unselectedTabForeground,
        ),
      );
    }

    if (previewUrl != null && previewUrl.startsWith('http')) {
      return _networkThumb(previewUrl, selected, previewUrl);
    }

    return _fallbackIcon(selected, previewUrl);
  }

  Widget _networkThumb(String url, bool selected, String? altUrl) {
    return _ossNetworkImage(
      url: url,
      errorBuilder: (_, __, ___) {
        if (altUrl != null && altUrl != url && altUrl.startsWith('http')) {
          return _ossNetworkImage(
            url: altUrl,
            errorBuilder: (_, __, ___) => _fallbackIcon(selected, null),
          );
        }
        return _fallbackIcon(selected, null);
      },
    );
  }

  Widget _ossNetworkImage({
    required String url,
    required ImageErrorWidgetBuilder errorBuilder,
  }) {
    if (kIsWeb) {
      return AppNetworkImage(
        url: url,
        width: 22,
        height: 22,
        fit: BoxFit.contain,
        errorWidget: (context, _, error) =>
            errorBuilder(context, error, StackTrace.empty),
      );
    }
    return Image.network(
      url,
      width: 22,
      height: 22,
      fit: BoxFit.contain,
      errorBuilder: errorBuilder,
    );
  }

  Widget _fallbackIcon(bool selected, String? previewUrl) {
    if (previewUrl != null && previewUrl.startsWith('http')) {
      return _ossNetworkImage(
        url: previewUrl,
        errorBuilder: (_, __, ___) => Icon(
          Icons.emoji_emotions_outlined,
          size: 22,
          color: selected
              ? panelTheme.onSelectedTabIconColor
              : panelTheme.mutedIconColor,
        ),
      );
    }
    return Icon(
      Icons.emoji_emotions_outlined,
      size: 22,
      color: selected
          ? panelTheme.onSelectedTabIconColor
          : panelTheme.mutedIconColor,
    );
  }

  String? _firstStickerPreviewUrl(CustomStickerPackage package) {
    if (package.stickerList.isEmpty) {
      return null;
    }
    final first = package.stickerList.first;
    if (first.url != null && first.url!.isNotEmpty) {
      return first.url;
    }
    return null;
  }

  String _emojiFromCode(int code) {
    if (code <= 0x10FFFF) {
      return String.fromCharCode(code);
    }
    return '😀';
  }

  String? _assetPath(CustomStickerPackage package, CustomSticker menu) {
    if (menu.url != null && menu.url!.startsWith('assets/')) {
      return menu.url;
    }
    final base = package.baseUrl;
    if (base != null && base.isNotEmpty) {
      return '$base/${menu.name}';
    }
    return null;
  }

  String? _assetPackageForPath(String path) {
    if (path.contains('assets/custom_face_resource/4349') ||
        path.contains('assets/custom_face_resource/tcc1')) {
      return _pluginAssetPackage;
    }
    return null;
  }

  /// 收藏 + 我的上传（合并 Tab）。
  static bool _usePinkHeartTab(CustomStickerPackage package) {
    return package.name == StickerConstants.virtualPackFavorites;
  }
}
