import 'dart:ui';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tim_ui_kit_sticker_plugin/utils/tim_ui_kit_sticker_data.dart';

class StickerPanel extends StatefulWidget {
  final void Function()? sendTextMsg;
  final void Function(int index, String data) sendFaceMsg;
  final void Function(int unicode) addText;
  final void Function(String emojiName)? addCustomEmojiText;
  final void Function() deleteText;
  final List<CustomStickerPackage> customStickerPackageList;
  final Widget? emptyPlaceHolder;
  final void Function(BuildContext context, LayerLink layerLink,
      int selectedPackageIdx, CustomSticker selectedSticker)? onLongTap;
  final VoidCallback? onLongPressEnd;
  final bool showBottomContainer;
  final int crossAxisCount;
  final bool showDeleteButton;
  final Color? backgroundColor;
  final Color? bottomColor;
  final Color? lightPrimaryColor;
  final EdgeInsetsGeometry? panelPadding;
  final double? height;
  final double? width;
  final bool isWideScreen;

  const StickerPanel({Key? key,
    this.sendTextMsg,
    required this.sendFaceMsg,
    required this.deleteText,
    required this.addText,
    this.addCustomEmojiText,
    this.bottomColor,
    required this.customStickerPackageList,
    this.emptyPlaceHolder,
    this.onLongTap,
    this.onLongPressEnd,
    this.backgroundColor = const Color(0xFFEDEDED),
    this.lightPrimaryColor = const Color(0xFF3371CD),
    this.showBottomContainer = true,
    this.showDeleteButton = true,
    this.crossAxisCount = 8,
    this.height,
    this.width,
    this.isWideScreen = false,
    this.panelPadding})
      : super(key: key);

  @override
  State<StatefulWidget> createState() => _EmojiPanelState();
}

class _EmojiPanelState extends State<StickerPanel> {
  int selectedIdx = 0;
  late List<int> textEmojiIndexList;
  late List<int> customEmojiStickerIndexList;

  @override
  void initState() {
    super.initState();
    textEmojiIndexList = _computeTextEmojiIndexList();
    customEmojiStickerIndexList = _computeCustomEmojiStickerIndexList();
  }

  @override
  void didUpdateWidget(StickerPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.customStickerPackageList != widget.customStickerPackageList) {
      textEmojiIndexList = _computeTextEmojiIndexList();
      customEmojiStickerIndexList = _computeCustomEmojiStickerIndexList();
    }
  }

  List<int> _computeTextEmojiIndexList() {
    final textEmojiList = <int>[];
    for (var i = 0; i < widget.customStickerPackageList.length; i++) {
      if (!widget.customStickerPackageList[i].isCustomSticker) {
        textEmojiList.add(i);
      }
    }
    return textEmojiList;
  }

  List<int> _computeCustomEmojiStickerIndexList() {
    final customEmojiList = <int>[];
    for (var i = 0; i < widget.customStickerPackageList.length; i++) {
      if (widget.customStickerPackageList[i].isCustomEmojiSticker) {
        customEmojiList.add(i);
      }
    }
    return customEmojiList;
  }

  List<Widget> _buildEmojiListWidget(
      List<CustomStickerPackage> customStickerList) {
    List<Widget> list = [];
    for (var index = 0; index < (customStickerList.length); index++) {
      final customEmojiFace = customStickerList[index];

      list.add(InkWell(
        onTap: () {
          setState(() {
            selectedIdx = index;
          });
        },
        child: Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
                color: selectedIdx == index
                    ? widget.lightPrimaryColor
                    : widget.backgroundColor,
                borderRadius: widget.isWideScreen
                    ? null
                    : const BorderRadius.all(Radius.circular(4))),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Expanded(
                    child: Center(
                      child: Material(
                        color: Colors.transparent,
                        child: customEmojiFace.isCustomSticker
                            ? (customEmojiFace.isCustomEmojiSticker
                            ? (customEmojiFace.isDefaultEmojiSticker
                            ? CustomEmojiItem(
                            size: 22,
                            sticker: customEmojiFace.menuItem,
                            isCustomEmoji: true,
                            isDeafultEmoji: true,
                            baseUrl: customEmojiFace.baseUrl)
                            : CustomEmojiItem(
                            size: 22,
                            sticker: customEmojiFace.menuItem,
                            isCustomEmoji: true,
                            baseUrl: customEmojiFace.baseUrl))
                            : CustomEmojiItem(
                            size: 22,
                            sticker: customEmojiFace.menuItem,
                            baseUrl: customEmojiFace.baseUrl))
                            : Container(
                          padding: const EdgeInsets.only(bottom: 2),
                          child: EmojiItem(
                            size: 19,
                            name: customEmojiFace.menuItem.name,
                            unicode: customEmojiFace.menuItem.unicode!,
                          ),
                        ),
                      ),
                    ))
              ],
            )),
      ));
    }
    return list;
  }

  Widget _buildStickerGrid({
    required int crossAxisCount,
    required int itemCount,
    required Widget Function(BuildContext context, int index) itemBuilder,
  }) {
    return GridView.builder(
      physics: const ClampingScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 1,
      ),
      itemCount: itemCount,
      itemBuilder: itemBuilder,
    );
  }

  Widget _buildDeleteButton() {
    return Align(
      alignment: Alignment.bottomRight,
      child: SingleChildScrollView(
        child: GestureDetector(
          onTap: widget.deleteText,
          child: Container(
              decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                        color: const Color(0x66bebebe),
                        offset: Offset(0.0, 0.0),
                        blurRadius: 10,
                        spreadRadius: 2),
                  ],
                  borderRadius: const BorderRadius.all(Radius.circular(4))),
              margin: const EdgeInsets.only(right: 10),
              width: 44,
              height: 35,
              child: Center(
                child: Image.asset(
                  'images/delete_emoji.png',
                  package: 'tim_ui_kit_sticker_plugin',
                  width: 28,
                ),
              )),
        ),
      ),
    );
  }

  Widget _wrapLongPress({
    required CustomSticker item,
    required Widget child,
    required VoidCallback onTap,
  }) {
    final layerLink = LayerLink();
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: onTap,
      onLongPressStart: (LongPressStartDetails details) {
        widget.onLongTap?.call(context, layerLink, selectedIdx, item);
      },
      onLongPressEnd: (LongPressEndDetails details) {
        widget.onLongPressEnd?.call();
      },
      onLongPressCancel: () {
        widget.onLongPressEnd?.call();
      },
      child: CompositedTransformTarget(
        link: layerLink,
        child: child,
      ),
    );
  }

  Widget _buildEmojiPanel(List<int> textEmojiIndexList,
      List<int> customEmojiStickerIndexList,
      List<CustomStickerPackage> customStickerList) {
    if (customStickerList.isEmpty) return Container();
    if (customStickerList[selectedIdx].stickerList.isEmpty) {
      return widget.emptyPlaceHolder ??
          Center(
            child: Text(TIM_t("暂无表情"),
                style: const TextStyle(color: Colors.black12, fontSize: 24)),
          );
    }
    if (textEmojiIndexList.contains(selectedIdx)) {
      final stickers = customStickerList[selectedIdx].stickerList;
      return Stack(
        children: [
          _buildStickerGrid(
            crossAxisCount: widget.crossAxisCount,
            itemCount: stickers.length,
            itemBuilder: (context, index) {
              final item = stickers[index];
              return _wrapLongPress(
                item: item,
                onTap: () => widget.addText(item.unicode!),
                child: EmojiItem(
                  name: item.name,
                  unicode: item.unicode!,
                ),
              );
            },
          ),
          if (widget.showDeleteButton && !widget.isWideScreen)
            _buildDeleteButton(),
        ],
      );
    }
    if (customEmojiStickerIndexList.contains(selectedIdx)) {
      final pack = customStickerList[selectedIdx];
      final stickers = pack.stickerList;
      return Stack(
        children: [
          _buildStickerGrid(
            crossAxisCount: widget.isWideScreen ? 7 : 8,
            itemCount: stickers.length,
            itemBuilder: (context, index) {
              final item = stickers[index];
              return _wrapLongPress(
                item: item,
                onTap: () {
                  widget.addCustomEmojiText?.call(item.name);
                },
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: CustomEmojiItem(
                    isBigImage: false,
                    isCustomEmoji: true,
                    isDeafultEmoji: pack.isDefaultEmoji,
                    baseUrl: pack.baseUrl,
                    sticker: item,
                  ),
                ),
              );
            },
          ),
          if (widget.showDeleteButton && !widget.isWideScreen)
            _buildDeleteButton(),
        ],
      );
    }
    final pack = customStickerList[selectedIdx];
    final stickers = pack.stickerList;
    return _buildStickerGrid(
      crossAxisCount: widget.crossAxisCount,
      itemCount: stickers.length,
      itemBuilder: (context, index) {
        final item = stickers[index];
        return _wrapLongPress(
          item: item,
          onTap: () {
            if (pack.baseUrl == null) {
              widget.sendFaceMsg(item.index, item.name);
            } else {
              final path = '${pack.baseUrl}/${item.name}';
              widget.sendFaceMsg(item.index, path);
            }
          },
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: CustomEmojiItem(
              isBigImage: true,
              baseUrl: pack.baseUrl,
              sticker: item,
            ),
          ),
        );
      },
    );
  }

  Widget _buildBottomPanel(List<int> textEmojiIndexList,
      List<int> customEmojiStickerIndexList,
      List<CustomStickerPackage> customStickerList) {
    return SizedBox(
        height: 40,
        child: Row(children: [
          Expanded(
              child: Container(
                  margin: const EdgeInsets.only(right: 25),
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child:
                    Row(children: _buildEmojiListWidget(customStickerList)),
                  ))),
          if ((textEmojiIndexList.contains(selectedIdx) ||
              customEmojiStickerIndexList.contains(selectedIdx)) &&
              widget.sendTextMsg != null)
            ElevatedButton(
                child: Text(TIM_t("发送")),
                style: ElevatedButton.styleFrom(),
                onPressed: () {
                  widget.sendTextMsg!();
                })
        ]));
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.width ?? 350,
      child: Column(
        children: [
          Container(
            height:
            (widget.height ?? 248) - (widget.showBottomContainer ? 48 : 0),
            color: widget.backgroundColor,
            padding: widget.panelPadding ??
                (widget.isWideScreen
                    ? const EdgeInsets.all(16)
                    : const EdgeInsets.fromLTRB(24, 16, 24, 16)),
            child: Scrollbar(
              child: _buildEmojiPanel(textEmojiIndexList,
                  customEmojiStickerIndexList, widget.customStickerPackageList),
            ),
          ),
          widget.showBottomContainer
              ? Container(
              padding: EdgeInsets.fromLTRB(
                  widget.isWideScreen ? 0 : 16, 0, 16, 0),
              color: widget.bottomColor,
              child: _buildBottomPanel(
                  textEmojiIndexList,
                  customEmojiStickerIndexList,
                  widget.customStickerPackageList))
              : Container(),
        ],
      ),
    );
  }
}

class EmojiItem extends StatelessWidget {
  const EmojiItem(
      {Key? key, required this.name, required this.unicode, this.size})
      : super(key: key);
  final String name;
  final int unicode;
  final double? size;

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: TextStyle(
        fontSize: size ?? 26,
      ),
      child: Text(
        String.fromCharCode(unicode),
        style: const TextStyle(fontFamily: 'MaterialIcons'),
      ),
    );
  }
}

class CustomEmojiItem extends StatefulWidget {
  const CustomEmojiItem({Key? key,
    required this.sticker,
    this.baseUrl,
    this.size,
    this.isBigImage = false,
    this.isCustomEmoji = false,
    this.isDeafultEmoji = false})
      : super(key: key);

  final CustomSticker sticker;
  final String? baseUrl;
  final bool? isBigImage;
  final double? size;
  final bool isDeafultEmoji;
  final bool isCustomEmoji;

  @override
  State<StatefulWidget> createState() => _CustomEmojiItemState();
}

class _CustomEmojiItemState extends State<CustomEmojiItem> {
  ImageInfo? _imageInfo;

  bool isFromNetwork() {
    final panelUrl = _panelDisplayUrl();
    return panelUrl.startsWith('http');
  }

  String getUrl() {
    return widget.baseUrl == null
        ? widget.sticker.url ?? ''
        : '${widget.baseUrl}/${widget.sticker.name}';
  }

  String _panelDisplayUrl() {
    final thumb = widget.sticker.thumbUrl?.trim() ?? '';
    if (thumb.isNotEmpty) {
      return thumb;
    }
    final legacy = getUrl();
    if (_isAnimatedUrl(legacy) &&
        (widget.sticker.originUrl?.trim().isNotEmpty ?? false)) {
      return legacy;
    }
    return legacy;
  }

  bool _isAnimatedUrl(String url) {
    if (url.isEmpty) {
      return false;
    }
    final path = Uri.tryParse(url)?.path.toLowerCase() ?? url.toLowerCase();
    return path.endsWith('.gif') ||
        path.endsWith('.webp') ||
        path.endsWith('.apng');
  }

  bool isAnimatedLocalAsset() {
    if (isFromNetwork()) {
      return false;
    }
    return _isAnimatedUrl(getUrl());
  }

  double get size => widget.isBigImage! ? 60 : 30;

  void _buildFristFrameFromLocalImg(ImageProvider image) async {
    dynamic data;
    if (image is AssetImage) {
      AssetBundleImageKey key =
      await image.obtainKey(const ImageConfiguration());
      data = await key.bundle.load(key.name);
    } else if (image is FileImage) {
      data = await image.file.readAsBytes();
    } else if (image is MemoryImage) {
      data = image.bytes;
    }
    _getFirstFrame(data);
  }

  void _getFirstFrame(dynamic data) async {
    var codec = await PaintingBinding.instance
        .instantiateImageCodecWithSize(data.buffer.asUint8List());
    FrameInfo? frameInfo = await codec.getNextFrame();
    if (frameInfo != null && mounted) {
      setState(() {
        _imageInfo = ImageInfo(image: frameInfo.image);
      });
    }
  }

  Widget _buildNetworkImage(String url) {
    final cacheKey = stickerPanelImageCacheKey(widget.sticker.name, url);
    if (kIsWeb) {
      return Image.network(
        url,
        height: size,
        width: size,
        fit: BoxFit.contain,
        gaplessPlayback: true,
        webHtmlElementStrategy: WebHtmlElementStrategy.prefer,
        errorBuilder: (_, __, ___) => SizedBox(
          width: size,
          height: size,
          child: const Icon(Icons.emoji_emotions_outlined, size: 20),
        ),
      );
    }
    return Image(
      image: CachedNetworkImageProvider(url, cacheKey: cacheKey),
      height: size,
      width: size,
      fit: BoxFit.contain,
      gaplessPlayback: true,
      errorBuilder: (_, __, ___) => SizedBox(
        width: size,
        height: size,
        child: const Icon(Icons.emoji_emotions_outlined, size: 20),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final panelUrl = _panelDisplayUrl();
    final isImgFromNetwork = panelUrl.startsWith('http');
    final isLocalAnimated = isAnimatedLocalAsset();
    Widget? img;

    if (isImgFromNetwork) {
      img = _buildNetworkImage(panelUrl);
    } else if (isLocalAnimated) {
      _buildFristFrameFromLocalImg(Image.asset(
        getUrl(),
        height: size,
        width: size,
      ).image);
    } else if (widget.isCustomEmoji) {
      if (widget.isDeafultEmoji) {
        img = Image.asset(
          getUrl(),
          height: size,
          width: size,
          package: 'tim_ui_kit_sticker_plugin',
        );
      } else {
        img = Image.asset(
          getUrl(),
          height: size,
          width: size,
        );
      }
    } else {
      img = Image.asset(
        getUrl(),
        height: size,
        width: size,
      );
    }

    return SizedBox(
        width: widget.size ?? size,
        height: widget.size ?? size,
        child: isLocalAnimated
            ? RawImage(
                image: _imageInfo?.image,
                width: size,
                height: size,
              )
            : img);
  }
}
