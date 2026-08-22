import 'dart:math' as math;

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart' hide Path;
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/app_image_editor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/asset_picker_edit_store.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/editable_asset_picker.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/edited_image_gallery_save.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';
import 'package:wechat_picker_library/wechat_picker_library.dart';

/// 相册预览页：顶栏「编辑」→ 保存相册 + 刷新预览/底部缩略图。
class AppAssetPickerEditViewerDelegate
    extends DefaultAssetPickerViewerBuilderDelegate {
  AppAssetPickerEditViewerDelegate({
    required super.currentIndex,
    required super.previewAssets,
    required super.themeData,
    super.selectorProvider,
    super.provider,
    super.selectedAssets,
    super.previewThumbnailSize,
    super.specialPickerType,
    super.maxAssets,
    super.shouldReversePreview,
    super.selectPredicate,
    super.shouldAutoplayPreview,
  });

  AssetEntity get _currentAsset {
    final index = shouldReversePreview
        ? previewAssets.length - currentIndex - 1
        : currentIndex;
    return previewAssets.elementAt(index);
  }

  bool get _canEditCurrent =>
      AppImageEditor.isSupported && _currentAsset.type == AssetType.image;

  Future<void> _openEditor(BuildContext context) async {
    if (!_canEditCurrent) {
      return;
    }
    final source = await EditableAssetPicker.resolveSourceFile(_currentAsset);
    if (source == null || !context.mounted) {
      return;
    }
    final edited = await AppImageEditor.open(context, source);
    if (edited == null || !context.mounted) {
      return;
    }

    final saved = await EditedImageGallerySave.save(context, edited);
    if (!context.mounted) {
      return;
    }
    if (!saved) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('保存到相册失败，请检查相册权限')),
      );
    }

    AssetPickerEditStore.instance.put(_currentAsset.id, edited);
  }

  @override
  Widget assetPageBuilder(BuildContext context, int index) {
    final asset = previewAssets.elementAt(
      shouldReversePreview ? previewAssets.length - index - 1 : index,
    );
    if (asset.type != AssetType.image) {
      return super.assetPageBuilder(context, index);
    }
    return ValueListenableBuilder<int>(
      valueListenable: AssetPickerEditStore.instance.revision,
      builder: (_, __, ___) {
        final edited = AssetPickerEditStore.instance.peek(asset.id);
        if (edited != null && edited.existsSync()) {
          return MergeSemantics(
            child: Consumer<AssetPickerViewerProvider<AssetEntity>?>(
              builder: (
                BuildContext c,
                AssetPickerViewerProvider<AssetEntity>? p,
                Widget? w,
              ) {
                final isSelected =
                    (p?.currentlySelectedAssets ?? selectedAssets)
                            ?.contains(asset) ??
                        false;
                return Semantics(
                  label:
                      '${semanticsTextDelegate.semanticTypeLabel(asset.type)}'
                      '${index + 1}',
                  selected: isSelected,
                  image: true,
                  child: w,
                );
              },
              child: ExtendedImage(
                key: ValueKey<String>(
                    'edited_preview_${asset.id}_${edited.path}'),
                image: FileImage(edited),
                fit: BoxFit.contain,
                mode: ExtendedImageMode.gesture,
                initGestureConfigHandler: (_) => GestureConfig(
                  minScale: 0.9,
                  maxScale: 3.0,
                  animationMaxScale: 3.5,
                  inPageView: true,
                ),
              ),
            ),
          );
        }
        return super.assetPageBuilder(context, index);
      },
    );
  }

  @override
  Widget bottomDetailItemBuilder(BuildContext context, int index) {
    const double padding = 8.0;

    void onTap(AssetEntity asset) {
      int page;
      if (previewAssets != selectedAssets) {
        page = previewAssets.indexOf(asset);
      } else {
        page = index;
      }
      if (shouldReversePreview) {
        page = previewAssets.length - page - 1;
      }
      if (pageController.page == page.toDouble()) {
        return;
      }
      pageController.jumpToPage(page);
      final double offset =
          (index - 0.5) * (bottomPreviewHeight - padding * 3) -
              MediaQuery.sizeOf(context).width / 4;
      previewingListController.animateTo(
        math.max(0, offset),
        curve: Curves.ease,
        duration: kThemeChangeDuration,
      );
    }

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: padding,
        vertical: padding * 2,
      ),
      child: AspectRatio(
        aspectRatio: 1.0,
        child: StreamBuilder<int>(
          initialData: currentIndex,
          stream: pageStreamController.stream,
          builder: (_, AsyncSnapshot<int> snapshot) {
            final AssetEntity asset = selectedAssets!.elementAt(index);
            final viewingIndex = shouldReversePreview
                ? previewAssets.length - snapshot.data! - 1
                : snapshot.data!;
            final bool isViewing = previewAssets[viewingIndex] == asset;
            return ValueListenableBuilder<int>(
              valueListenable: AssetPickerEditStore.instance.revision,
              builder: (_, __, ___) {
                final edited = asset.type == AssetType.image
                    ? AssetPickerEditStore.instance.peek(asset.id)
                    : null;
                final Widget item = switch (asset.type) {
                  AssetType.image when edited != null && edited.existsSync() =>
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: ExtendedImage(
                          key: ValueKey<String>(
                            'edited_thumb_${asset.id}_${edited.path}',
                          ),
                          image: FileImage(edited),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  AssetType.image => Positioned.fill(
                      child: RepaintBoundary(
                        child: ExtendedImage(
                          image: AssetEntityImageProvider(asset,
                              isOriginal: false),
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                  AssetType.video => Positioned.fill(
                      child: Stack(
                        children: <Widget>[
                          if (edited != null && edited.existsSync())
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: ExtendedImage(
                                  key: ValueKey<String>(
                                    'edited_thumb_${asset.id}_${edited.path}',
                                  ),
                                  image: FileImage(edited),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            )
                          else
                            Positioned.fill(
                              child: RepaintBoundary(
                                child: ExtendedImage(
                                  image: AssetEntityImageProvider(
                                    asset,
                                    isOriginal: false,
                                  ),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                          Center(
                            child: Icon(
                              Icons.video_library,
                              color: themeData.iconTheme.color
                                  ?.withValues(alpha: 0.54),
                            ),
                          ),
                        ],
                      ),
                    ),
                  AssetType.audio =>
                    const Center(child: Icon(Icons.audiotrack)),
                  AssetType.other => const SizedBox.shrink(),
                };
                return Semantics(
                  label:
                      '${semanticsTextDelegate.semanticTypeLabel(asset.type)}'
                      '${index + 1}',
                  selected: isViewing,
                  onTap: () {
                    onTap(asset);
                  },
                  onTapHint: semanticsTextDelegate.sActionPreviewHint,
                  excludeSemantics: true,
                  child: GestureDetector(
                    onTap: () {
                      onTap(asset);
                    },
                    child: Selector<AssetPickerViewerProvider<AssetEntity>?,
                        List<AssetEntity>?>(
                      selector:
                          (_, AssetPickerViewerProvider<AssetEntity>? p) =>
                              p?.currentlySelectedAssets,
                      child: item,
                      builder: (
                        _,
                        List<AssetEntity>? currentlySelectedAssets,
                        Widget? w,
                      ) {
                        final bool isSelected =
                            currentlySelectedAssets?.contains(asset) ?? false;
                        return Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            if (w != null) w,
                            if (isSelected)
                              const PositionedDirectional(
                                top: 4,
                                end: 4,
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.white,
                                  size: 20,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  @override
  Widget appBar(BuildContext context) {
    final bar = AssetPickerAppBar(
      leading: Semantics(
        sortKey: ordinalSortKey(0),
        child: IconButton(
          onPressed: () {
            Navigator.maybeOf(context)?.maybePop();
          },
          tooltip: MaterialLocalizations.of(context).backButtonTooltip,
          icon: const Icon(Icons.arrow_back_ios_new),
        ),
      ),
      centerTitle: true,
      title: specialPickerType == null
          ? Semantics(
              sortKey: ordinalSortKey(0.1),
              child: StreamBuilder<int>(
                initialData: currentIndex,
                stream: pageStreamController.stream,
                builder: (_, AsyncSnapshot<int> snapshot) => ScaleText(
                  '${snapshot.requireData + 1}/${previewAssets.length}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            )
          : null,
      actions: [
        if (_canEditCurrent)
          Semantics(
            sortKey: ordinalSortKey(0.15),
            child: TextButton(
              onPressed: () => _openEditor(context),
              child: ScaleText(
                textDelegate.edit,
                style: TextStyle(
                  color: themeData.colorScheme.secondary,
                  fontSize: 17,
                ),
              ),
            ),
          ),
        if (provider != null)
          Semantics(
            sortKey: ordinalSortKey(0.2),
            child: selectButton(context),
          ),
        const SizedBox(width: 14),
      ],
    );
    return ValueListenableBuilder(
      valueListenable: isDisplayingDetail,
      builder: (_, v, child) => AnimatedPositionedDirectional(
        duration: kThemeAnimationDuration,
        curve: Curves.easeInOut,
        top: v ? 0.0 : -(context.topPadding + bar.preferredSize.height),
        start: 0.0,
        end: 0.0,
        child: child!,
      ),
      child: bar,
    );
  }

  @override
  Widget bottomDetailBuilder(BuildContext context) {
    final barColor = themeData.bottomAppBarTheme.color;
    final backgroundColor = barColor?.withValues(
      alpha: barColor.a * (isAppleOS(context) ? .9 : 1),
    );
    return PositionedDirectional(
      start: 0.0,
      end: 0.0,
      bottom: 0.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.end,
        children: <Widget>[
          CNP<AssetPickerViewerProvider<AssetEntity>?>.value(
            value: provider,
            child: ValueListenableBuilder<bool>(
              valueListenable: isDisplayingDetail,
              builder: (_, bool visible, __) {
                return ValueListenableBuilder<int>(
                  valueListenable: selectedNotifier,
                  builder: (_, int count, ___) {
                    if (!visible || provider == null || count <= 0) {
                      return const SizedBox.shrink();
                    }
                    return Container(
                      width: double.maxFinite,
                      height: bottomPreviewHeight,
                      color: backgroundColor,
                      child: ListView.builder(
                        controller: previewingListController,
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 5.0),
                        physics: const ClampingScrollPhysics(),
                        itemCount: count,
                        itemBuilder: bottomDetailItemBuilder,
                      ),
                    );
                  },
                );
              },
            ),
          ),
          Container(
            height: bottomBarHeight + context.bottomPadding,
            padding: const EdgeInsets.symmetric(horizontal: 20.0)
                .copyWith(bottom: context.bottomPadding),
            decoration: BoxDecoration(
              border: Border(top: BorderSide(color: themeData.canvasColor)),
              color: backgroundColor,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: <Widget>[confirmButton(context)],
            ),
          ),
        ],
      ),
    );
  }

  /// 底部「发送」：未勾选时也可发送当前预览图（优先编辑版）。
  @override
  Widget confirmButton(BuildContext context) {
    return CNP<AssetPickerViewerProvider<AssetEntity>?>.value(
      value: provider,
      child: Consumer<AssetPickerViewerProvider<AssetEntity>?>(
        builder: (_, AssetPickerViewerProvider<AssetEntity>? provider, __) {
          Future<void> onPressed() async {
            if (isWeChatMoment && hasVideo) {
              if (await onChangingSelected(context, currentAsset, false)) {
                Navigator.maybeOf(context)?.pop(<AssetEntity>[currentAsset]);
              }
              return;
            }

            if (provider != null && provider.isSelectedNotEmpty) {
              Navigator.maybeOf(context)?.pop(provider.currentlySelectedAssets);
              return;
            }

            Navigator.maybeOf(context)?.pop(<AssetEntity>[_currentAsset]);
          }

          final selectedCount = provider?.currentlySelectedAssets.length ?? 0;
          final maxAssets = selectorProvider?.maxAssets;

          String buildText() {
            if (isWeChatMoment && hasVideo) {
              return textDelegate.confirm;
            }
            if (selectedCount > 0 && maxAssets != null) {
              return '${TIM_t('发送')} ($selectedCount/$maxAssets)';
            }
            return TIM_t('发送');
          }

          final isButtonEnabled = previewAssets.isNotEmpty;
          return MaterialButton(
            minWidth:
                selectedCount > 0 || (isWeChatMoment && hasVideo) ? 48 : 20,
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            color: themeData.colorScheme.secondary,
            disabledColor: themeData.splashColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(3),
            ),
            onPressed: isButtonEnabled ? onPressed : null,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            child: ScaleText(
              buildText(),
              style: TextStyle(
                color: themeData.textTheme.bodyLarge?.color,
                fontSize: 17,
                fontWeight: FontWeight.normal,
              ),
              overflow: TextOverflow.fade,
              softWrap: false,
              semanticsLabel: buildText(),
            ),
          );
        },
      ),
    );
  }
}
