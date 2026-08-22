import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:extended_image/extended_image.dart';
import 'package:flutter/material.dart' hide Path;
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_gallery_asset_picker_provider.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/gallery_send_perf_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/asset_picker_edit_store.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/asset_picker_edit_viewer_delegate.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

/// 相册选择器：预览页支持图片编辑，网格缩略图同步显示编辑结果。
class AppAssetPickerEditBuilderDelegate
    extends DefaultAssetPickerBuilderDelegate {
  AppAssetPickerEditBuilderDelegate({
    required super.provider,
    required super.initialPermission,
    super.gridCount,
    super.pickerTheme,
    super.gridThumbnailSize,
    super.previewThumbnailSize,
    super.specialPickerType,
    super.specialItemPosition,
    super.specialItemBuilder,
    super.loadingIndicatorBuilder,
    super.selectPredicate,
    super.shouldRevertGrid,
    super.limitedPermissionOverlayPredicate,
    super.pathNameBuilder,
    super.assetsChangeCallback,
    super.assetsChangeRefreshPredicate,
    super.viewerUseRootNavigator,
    super.viewerPageRouteSettings,
    super.viewerPageRouteBuilder,
    super.themeColor,
    super.textDelegate,
    super.locale,
    super.keepScrollOffset,
    super.shouldAutoplayPreview,
    super.dragToSelect,
  });

  @override
  Widget imageAndVideoItemBuilder(
    BuildContext context,
    int index,
    AssetEntity asset,
  ) {
    final galleryProvider = provider is ChatGalleryAssetPickerProvider
        ? provider as ChatGalleryAssetPickerProvider
        : null;
    final trace = galleryProvider?.trace;

    Widget originalItem() {
      final isGif = asset.title?.toLowerCase().endsWith('.gif') ?? false;
      return Stack(
        fit: StackFit.expand,
        children: <Widget>[
          RepaintBoundary(
            child: _RecoveringGalleryThumbnail(
              asset: asset,
              thumbnailSize: gridThumbnailSize,
              index: index,
              trace: trace,
              onFirstThumbnailDisplayed: index == 0
                  ? galleryProvider?.markFirstThumbnailDisplayed
                  : null,
            ),
          ),
          if (isGif) gifIndicator(context, asset),
          if (asset.type == AssetType.video) videoIndicator(context, asset),
          if (asset.isLivePhoto) buildLivePhotoIndicator(context, asset),
        ],
      );
    }

    if (asset.type != AssetType.image) {
      return originalItem();
    }
    return ValueListenableBuilder<int>(
      valueListenable: AssetPickerEditStore.instance.revision,
      builder: (_, __, ___) {
        final edited = AssetPickerEditStore.instance.peek(asset.id);
        if (edited == null || !edited.existsSync()) {
          return originalItem();
        }
        return Stack(
          fit: StackFit.expand,
          children: <Widget>[
            RepaintBoundary(
              child: ExtendedImage(
                key: ValueKey<String>(
                  'edited_grid_${asset.id}_${edited.path}',
                ),
                image: FileImage(edited),
                fit: BoxFit.cover,
              ),
            ),
            if (asset.isLivePhoto) buildLivePhotoIndicator(context, asset),
          ],
        );
      },
    );
  }

  @override
  Future<void> viewAsset(
    BuildContext context,
    int? index,
    AssetEntity currentAsset,
  ) async {
    final p = context.read<DefaultAssetPickerProvider>();
    if ((!p.selectedAssets.contains(currentAsset) && p.selectedMaximumAssets) ||
        (isWeChatMoment &&
            currentAsset.type == AssetType.video &&
            p.selectedAssets.isNotEmpty)) {
      return;
    }
    final revert = effectiveShouldRevertGrid(context);
    final List<AssetEntity> current;
    final List<AssetEntity>? selected;
    final int effectiveIndex;
    if (isWeChatMoment) {
      if (currentAsset.type == AssetType.video) {
        current = <AssetEntity>[currentAsset];
        selected = null;
        effectiveIndex = 0;
      } else {
        final List<AssetEntity> list;
        if (index == null) {
          list = p.selectedAssets.reversed.toList(growable: false);
        } else {
          list = p.currentAssets;
        }
        current = list.where((e) => e.type == AssetType.image).toList();
        selected = p.selectedAssets;
        final i = current.indexOf(currentAsset);
        effectiveIndex = revert ? current.length - i - 1 : i;
      }
    } else {
      selected = p.selectedAssets;
      final List<AssetEntity> list;
      if (index == null) {
        if (revert) {
          list = p.selectedAssets.reversed.toList(growable: false);
        } else {
          list = p.selectedAssets;
        }
        effectiveIndex = selected.indexOf(currentAsset);
        current = list;
      } else {
        current = p.currentAssets;
        effectiveIndex = revert ? current.length - index - 1 : index;
      }
    }
    if (current.isEmpty) {
      throw StateError('Previewing empty assets is not allowed.');
    }
    final AssetPickerViewerProvider<AssetEntity>? viewerProvider =
        selected != null
            ? AssetPickerViewerProvider<AssetEntity>(
                selected,
                maxAssets: p.maxAssets,
              )
            : null;
    final List<AssetEntity>? result =
        await AssetPickerViewer.pushToViewerWithDelegate(
      context,
      delegate: AppAssetPickerEditViewerDelegate(
        currentIndex: effectiveIndex,
        previewAssets: current,
        themeData: theme,
        previewThumbnailSize: previewThumbnailSize,
        selectPredicate: selectPredicate,
        selectedAssets: selected,
        provider: viewerProvider,
        selectorProvider: p,
        specialPickerType: specialPickerType,
        maxAssets: p.maxAssets,
        shouldReversePreview: revert,
        shouldAutoplayPreview: shouldAutoplayPreview,
      ),
      useRootNavigator: viewerUseRootNavigator,
      pageRouteSettings: viewerPageRouteSettings,
      pageRouteBuilder: viewerPageRouteBuilder,
    );
    if (result != null) {
      Navigator.maybeOf(context)?.maybePop(result);
    }
  }
}

class _RecoveringGalleryThumbnail extends StatefulWidget {
  const _RecoveringGalleryThumbnail({
    required this.asset,
    required this.thumbnailSize,
    required this.index,
    required this.trace,
    required this.onFirstThumbnailDisplayed,
  });

  final AssetEntity asset;
  final ThumbnailSize thumbnailSize;
  final int index;
  final GallerySendPerfTrace? trace;
  final VoidCallback? onFirstThumbnailDisplayed;

  @override
  State<_RecoveringGalleryThumbnail> createState() =>
      _RecoveringGalleryThumbnailState();
}

class _RecoveringGalleryThumbnailState
    extends State<_RecoveringGalleryThumbnail> {
  static const _requestTimeout = Duration(seconds: 3);
  static const _upgradeTimeout = Duration(seconds: 2);
  static const _maxAutomaticRetries = 1;
  /// Grid still upgrades to HQ after first paint; anti-flash relies on stable
  /// Image key + gapless frameBuilder + precache before swap.
  static const bool _kEnableGridHqThumbnailUpgrade = true;

  Uint8List? _bytes;
  MemoryImage? _memoryImage;
  PMCancelToken? _cancelToken;
  int _attempt = 0;
  int _generation = 0;
  bool _loading = false;
  bool _decoded = false;
  bool _handlingDecodeFailure = false;
  bool _exhausted = false;
  bool _upgraded = false;

  @override
  void initState() {
    super.initState();
    _restart(notify: false);
  }

  @override
  void didUpdateWidget(covariant _RecoveringGalleryThumbnail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.asset.id != widget.asset.id ||
        oldWidget.thumbnailSize != widget.thumbnailSize) {
      _restart();
    }
  }

  ThumbnailSize get _pixelSize {
    final dpr = MediaQuery.maybeOf(context)?.devicePixelRatio ?? 2.0;
    final scale = dpr.clamp(2.0, 3.0);
    return ThumbnailSize(
      (widget.thumbnailSize.width * scale).round().clamp(200, 480),
      (widget.thumbnailSize.height * scale).round().clamp(200, 480),
    );
  }

  ThumbnailOption _thumbnailOption({
    required DeliveryMode deliveryMode,
    required ResizeMode resizeMode,
    required int quality,
  }) {
    if (Platform.isIOS || Platform.isMacOS) {
      return ThumbnailOption.ios(
        size: _pixelSize,
        format: ThumbnailFormat.jpeg,
        quality: quality,
        deliveryMode: deliveryMode,
        resizeMode: resizeMode,
      );
    }
    return ThumbnailOption(
      size: _pixelSize,
      format: ThumbnailFormat.jpeg,
      quality: quality,
    );
  }

  void _restart({bool notify = true}) {
    final previousToken = _cancelToken;
    _cancelToken = null;
    _generation++;
    _attempt = 0;
    _bytes = null;
    _memoryImage = null;
    _loading = false;
    _decoded = false;
    _handlingDecodeFailure = false;
    _exhausted = false;
    _upgraded = false;
    if (previousToken != null) {
      unawaited(PhotoManager.cancelRequest(previousToken).catchError((_) {}));
    }
    if (notify && mounted) {
      setState(() {});
    }
    unawaited(_load(_generation));
  }

  Future<void> _load(int generation) async {
    if (!mounted || generation != _generation || _loading) {
      return;
    }
    _loading = true;
    if (widget.index == 0) {
      widget.trace?.log(
        'picker_first_thumbnail_begin',
        index: widget.index,
        detail: 'attempt=$_attempt',
      );
    }

    await _GalleryThumbnailLoadGate.acquire();
    if (!mounted || generation != _generation) {
      _loading = false;
      _GalleryThumbnailLoadGate.release();
      return;
    }

    final token = PMCancelToken();
    _cancelToken = token;
    try {
      final bytes = await widget.asset
          .thumbnailDataWithOption(
            _thumbnailOption(
              deliveryMode: DeliveryMode.fastFormat,
              resizeMode: ResizeMode.fast,
              quality: Platform.isIOS || Platform.isMacOS ? 80 : 95,
            ),
            cancelToken: token,
          )
          .timeout(_requestTimeout);
      if (!mounted || generation != _generation) {
        return;
      }
      if (bytes == null || bytes.isEmpty) {
        throw StateError('PhotoKit returned empty thumbnail bytes');
      }
      _loading = false;
      _cancelToken = null;
      // Android / 鸿蒙没有 iOS 的 highQuality 升级路径。
      // 首帧必须在这里上屏，否则格子会一直灰、相册封面也被卡住。
      if (mounted && generation == _generation) {
        setState(() {
          _bytes = bytes;
          _memoryImage = MemoryImage(bytes);
        });
      }
      // Defer iOS HQ upgrade past first paint. Swap must stay gapless
      // (stable key + frameBuilder + precache) so thumbs do not flash.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || generation != _generation) {
          return;
        }
        unawaited(() async {
          await Future<void>.delayed(const Duration(milliseconds: 120));
          if (!mounted || generation != _generation) {
            return;
          }
          await _upgrade(generation);
        }());
      });
    } on TimeoutException catch (error) {
      await _cancelNativeRequest(token);
      await _retryOrExhaust(generation, 'timeout', error);
    } catch (error) {
      await _cancelNativeRequest(token);
      await _retryOrExhaust(generation, 'failed', error);
    } finally {
      if (identical(_cancelToken, token)) {
        _cancelToken = null;
      }
      _GalleryThumbnailLoadGate.release();
    }
  }

  Future<void> _upgrade(int generation) async {
    if (!_kEnableGridHqThumbnailUpgrade) {
      return;
    }
    if (!mounted ||
        generation != _generation ||
        _upgraded ||
        !(Platform.isIOS || Platform.isMacOS)) {
      return;
    }
    await _GalleryThumbnailLoadGate.acquireUpgrade();
    if (!mounted || generation != _generation || _upgraded) {
      _GalleryThumbnailLoadGate.releaseUpgrade();
      return;
    }
    final token = PMCancelToken();
    _cancelToken = token;
    try {
      final bytes = await widget.asset
          .thumbnailDataWithOption(
            _thumbnailOption(
              deliveryMode: DeliveryMode.highQualityFormat,
              resizeMode: ResizeMode.exact,
              quality: 95,
            ),
            cancelToken: token,
          )
          .timeout(_upgradeTimeout);
      if (!mounted ||
          generation != _generation ||
          bytes == null ||
          bytes.isEmpty) {
        return;
      }
      final previous = _bytes;
      // Same/smaller payload is not worth a visual swap.
      if (previous != null && bytes.length <= previous.length) {
        _upgraded = true;
        widget.trace?.log(
          'picker_thumbnail_upgrade_skipped',
          index: widget.index,
          detail: 'not_sharper from=${previous.length} to=${bytes.length}',
        );
        return;
      }
      // Decode into imageCache before setState so the first HQ frame is ready
      // and gaplessPlayback never falls back to the gray placeholder.
      final provider = MemoryImage(bytes);
      try {
        await precacheImage(provider, context);
      } catch (_) {
        // Still attempt the swap; frameBuilder keeps the fast frame if needed.
      }
      if (!mounted || generation != _generation) {
        return;
      }
      _upgraded = true;
      widget.trace?.log(
        'picker_thumbnail_upgraded',
        index: widget.index,
        detail: 'from=${previous?.length ?? 0} to=${bytes.length}',
      );
      setState(() {
        _bytes = bytes;
        _memoryImage = provider;
      });
    } catch (error) {
      await _cancelNativeRequest(token);
      widget.trace?.log(
        'picker_thumbnail_upgrade_skipped',
        index: widget.index,
        detail: 'error=$error',
      );
    } finally {
      if (identical(_cancelToken, token)) {
        _cancelToken = null;
      }
      _GalleryThumbnailLoadGate.releaseUpgrade();
    }
  }

  Future<void> _cancelNativeRequest(PMCancelToken token) async {
    try {
      await PhotoManager.cancelRequest(token);
      widget.trace?.log(
        'picker_thumbnail_native_cancelled',
        index: widget.index,
        detail: 'attempt=$_attempt',
      );
    } catch (error) {
      widget.trace?.log(
        'picker_thumbnail_cancel_failed',
        index: widget.index,
        detail: 'attempt=$_attempt error=$error',
      );
    }
  }

  Future<void> _retryOrExhaust(
    int generation,
    String reason,
    Object error,
  ) async {
    if (!mounted || generation != _generation) {
      return;
    }
    _loading = false;
    widget.trace?.log(
      'picker_thumbnail_$reason',
      index: widget.index,
      detail: 'attempt=$_attempt error=$error',
    );
    if (_attempt < _maxAutomaticRetries) {
      _attempt++;
      widget.trace?.log(
        'picker_thumbnail_retry',
        index: widget.index,
        detail: 'attempt=$_attempt reason=$reason',
      );
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (mounted && generation == _generation) {
        unawaited(_load(generation));
      }
      return;
    }
    if (widget.index == 0) {
      widget.trace?.markFirstThumbnailFailed(error);
    }
    if (mounted && generation == _generation) {
      setState(() => _exhausted = true);
    }
  }

  void _markDecoded() {
    if (_decoded) {
      return;
    }
    _decoded = true;
    if (widget.index == 0) {
      widget.trace?.markFirstThumbnailReady(width: 0, height: 0);
      widget.onFirstThumbnailDisplayed?.call();
    }
    if (_attempt > 0) {
      widget.trace?.log(
        'picker_thumbnail_recovered',
        index: widget.index,
        detail: 'attempt=$_attempt',
      );
    }
  }

  void _handleDecodeFailure(Object error) {
    if (_handlingDecodeFailure || _exhausted) {
      return;
    }
    _handlingDecodeFailure = true;
    scheduleMicrotask(() async {
      if (!mounted || _exhausted) {
        return;
      }
      setState(() {
        _bytes = null;
        _memoryImage = null;
      });
      await _retryOrExhaust(_generation, 'decode_failed', error);
      _handlingDecodeFailure = false;
    });
  }

  void _manualRetry() {
    _restart();
  }

  @override
  void dispose() {
    final token = _cancelToken;
    _cancelToken = null;
    _generation++;
    if (token != null) {
      unawaited(PhotoManager.cancelRequest(token).catchError((_) {}));
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_exhausted) {
      return Material(
        color: const Color(0x10000000),
        child: InkWell(
          onTap: _manualRetry,
          child: const Center(
            child: Icon(Icons.refresh_rounded, color: Color(0x66000000)),
          ),
        ),
      );
    }
    final bytes = _bytes;
    final memoryImage = _memoryImage;
    if (bytes == null || memoryImage == null) {
      return const ColoredBox(color: Color(0x10000000));
    }
    return Image(
      image: memoryImage,
      // Stable across byte swaps so gaplessPlayback can keep the prior frame.
      // Including bytes.length forced a remount on every HQ upgrade → flash.
      key: ValueKey<String>('gallery_${widget.asset.id}_$_generation'),
      fit: BoxFit.cover,
      gaplessPlayback: true,
      filterQuality: FilterQuality.medium,
      frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
        if (wasSynchronouslyLoaded || frame != null) {
          _markDecoded();
          return child;
        }
        // Already showed a frame (or upgrading bytes): never paint the gray
        // placeholder again — that was the visible "闪一下" on open.
        if (_decoded) {
          return child;
        }
        return const ColoredBox(color: Color(0x10000000));
      },
      errorBuilder: (_, error, __) {
        _handleDecodeFailure(error);
        return const ColoredBox(color: Color(0x10000000));
      },
    );
  }
}

class _GalleryThumbnailLoadGate {
  static const int _maxConcurrent = 4;
  static const int _maxUpgradeConcurrent = 2;
  static int _active = 0;
  static int _upgradeActive = 0;
  static final List<Completer<void>> _waiters = <Completer<void>>[];
  static final List<Completer<void>> _upgradeWaiters = <Completer<void>>[];

  static Future<void> acquire() {
    if (_active < _maxConcurrent) {
      _active++;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _waiters.add(waiter);
    return waiter.future;
  }

  static void release() {
    if (_waiters.isNotEmpty) {
      _waiters.removeAt(0).complete();
      return;
    }
    if (_active > 0) {
      _active--;
    }
  }

  static Future<void> acquireUpgrade() {
    if (_upgradeActive < _maxUpgradeConcurrent) {
      _upgradeActive++;
      return Future<void>.value();
    }
    final waiter = Completer<void>();
    _upgradeWaiters.add(waiter);
    return waiter.future;
  }

  static void releaseUpgrade() {
    if (_upgradeWaiters.isNotEmpty) {
      _upgradeWaiters.removeAt(0).complete();
      return;
    }
    if (_upgradeActive > 0) {
      _upgradeActive--;
    }
  }
}
