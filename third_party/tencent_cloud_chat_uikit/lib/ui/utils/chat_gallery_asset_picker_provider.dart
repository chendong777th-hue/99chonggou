import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:tencent_cloud_chat_uikit/ui/utils/chat_gallery_asset_sort.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/gallery_send_perf_trace.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

const List<Duration> _galleryPathRetryDelays = [
  Duration(milliseconds: 150),
  Duration(milliseconds: 400),
  Duration(milliseconds: 900),
];

const List<Duration> _galleryAssetRetryDelays = [
  Duration(milliseconds: 180),
  Duration(milliseconds: 450),
  Duration(milliseconds: 1000),
];

const Duration _galleryQueryTimeout = Duration(seconds: 5);
const Duration _galleryFullPathsFallbackDelay = Duration(milliseconds: 1500);
const Duration _galleryPathThumbnailTimeout = Duration(seconds: 2);

/// 自定义相册 Provider：默认落在「最近/全部」目录，并按最近活动排序资源。
class ChatGalleryAssetPickerProvider extends DefaultAssetPickerProvider {
  ChatGalleryAssetPickerProvider({
    super.selectedAssets,
    super.maxAssets,
    super.pageSize,
    super.pathThumbnailSize,
    super.requestType,
    super.sortPathDelegate,
    super.sortPathsByModifiedDate,
    super.filterOptions,
    super.initializeDelayDuration,
    this.trace,
  });

  final GallerySendPerfTrace? trace;
  Future<void> _pathsLoadTail = Future<void>.value();
  Future<void> _assetsLoadTail = Future<void>.value();
  final Completer<void> _firstThumbnailDisplayed = Completer<void>();

  void markFirstThumbnailDisplayed() {
    if (_firstThumbnailDisplayed.isCompleted) {
      return;
    }
    _firstThumbnailDisplayed.complete();
    trace?.log('picker_first_thumbnail_displayed');
  }

  PathWrapper<AssetPathEntity> _recentAlbumWrapper() {
    return paths.firstWhere(
      (wrapper) => wrapper.path.isAll,
      orElse: () => paths.first,
    );
  }

  @override
  Future<void> getPaths({
    bool onlyAll = false,
    bool keepPreviousCount = false,
  }) {
    trace?.log(
      'picker_paths_enqueued',
      detail:
          'onlyAll=$onlyAll keepPreviousCount=$keepPreviousCount mounted=$mounted',
    );
    final load = _pathsLoadTail.then(
      (_) => _getPathsWithRecovery(
        onlyAll: onlyAll,
        keepPreviousCount: keepPreviousCount,
      ),
    );
    _pathsLoadTail = load.then<void>(
      (_) {},
      onError: (_, __) {},
    );
    return load;
  }

  Future<void> _getPathsWithRecovery({
    required bool onlyAll,
    required bool keepPreviousCount,
  }) async {
    if (!onlyAll &&
        !keepPreviousCount &&
        currentAssets.isNotEmpty &&
        !_firstThumbnailDisplayed.isCompleted) {
      trace?.log(
        'picker_full_paths_deferred',
        count: currentAssets.length,
      );
      await Future.any<void>([
        _firstThumbnailDisplayed.future,
        Future<void>.delayed(_galleryFullPathsFallbackDelay),
      ]);
      trace?.log(
        'picker_full_paths_resumed',
        detail: _firstThumbnailDisplayed.isCompleted
            ? 'first_thumbnail_displayed'
            : 'fallback_timeout',
      );
    }
    final previousPaths = List<PathWrapper<AssetPathEntity>>.from(paths);
    final previousCurrentPath = currentPath;
    Object? lastError;

    for (var attempt = 0;
        attempt <= _galleryPathRetryDelays.length;
        attempt++) {
      if (!mounted) {
        trace?.log(
          'picker_paths_aborted_unmounted',
          detail: 'onlyAll=$onlyAll attempt=$attempt',
        );
        return;
      }
      try {
        trace?.log(
          'picker_paths_query_begin',
          detail: 'onlyAll=$onlyAll attempt=$attempt',
        );
        await super
            .getPaths(
              onlyAll: onlyAll,
              keepPreviousCount: keepPreviousCount,
            )
            .timeout(_galleryQueryTimeout);
        trace?.log(
          'picker_paths_result',
          count: paths.length,
          detail: 'onlyAll=$onlyAll attempt=$attempt',
        );
        if (paths.isNotEmpty) {
          break;
        }
        final permission = await PhotoManager.getPermissionState(
          requestOption: PermissionRequestOption(
            androidPermission: AndroidPermission(
              type: requestType,
              mediaLocation: false,
            ),
          ),
        ).timeout(_galleryQueryTimeout);
        if (!permission.hasAccess) {
          trace?.log(
            'picker_paths_permission_unavailable',
            detail: permission.toString(),
          );
          _settleAsEmpty();
          return;
        }
      } catch (error) {
        lastError = error;
        trace?.log(
          'picker_paths_error',
          detail: 'onlyAll=$onlyAll attempt=$attempt error=$error',
        );
      }
      if (attempt < _galleryPathRetryDelays.length) {
        await Future<void>.delayed(_galleryPathRetryDelays[attempt]);
      }
    }

    if (paths.isEmpty) {
      // onlyAll 首轮成功、随后全目录刷新短暂失败时，保留已经可用的首屏，
      // 避免一次瞬时空结果把用户正在看的相册清成永久 loading。
      if (previousPaths.isNotEmpty && currentAssets.isNotEmpty) {
        paths = previousPaths;
        currentPath = previousCurrentPath ?? _recentAlbumWrapper();
        hasAssetsToDisplay = true;
        isAssetsEmpty = false;
        trace?.log(
          'picker_paths_preserved_previous',
          count: previousPaths.length,
          detail: 'onlyAll=$onlyAll error=${lastError ?? 'empty'}',
        );
        return;
      }
      trace?.log(
        'picker_paths_exhausted',
        detail: 'onlyAll=$onlyAll error=${lastError ?? 'empty'}',
      );
      _settleAsEmpty();
      return;
    }

    // wechat_assets_picker 会先 onlyAll:true 再 onlyAll:false。
    // 第二次刷新 paths 后不会重绑 currentPath（??= 已占用），
    // 顶部目录名与网格内容容易仍停留在其它实体相册。
    final recent = _recentAlbumWrapper();
    currentPath = recent;
    trace?.log(
      'picker_paths_applied',
      count: paths.length,
      detail:
          'onlyAll=$onlyAll currentIsAll=${recent.path.isAll} currentAssets=${currentAssets.length}',
    );
    final pathChanged = previousCurrentPath?.path.id != recent.path.id;
    final shouldReloadAssets =
        !onlyAll && (currentAssets.isEmpty || pathChanged || keepPreviousCount);
    if (shouldReloadAssets) {
      await getAssetsFromCurrentPath();
    } else {
      trace?.log(
        'picker_assets_reload_skipped',
        count: currentAssets.length,
        detail:
            'onlyAll=$onlyAll pathChanged=$pathChanged keepPreviousCount=$keepPreviousCount',
      );
    }
  }

  void _settleAsEmpty() {
    if (!mounted) {
      return;
    }
    currentPath = null;
    currentAssets = const <AssetEntity>[];
    totalAssetsCount = 0;
    hasAssetsToDisplay = false;
    isAssetsEmpty = true;
  }

  ThumbnailOption get _pathThumbnailOption {
    if (Platform.isIOS || Platform.isMacOS) {
      // 上游默认 iOS 缩略图是 opportunistic，会和网格抢 PhotoKit，
      // 并把 iCloud 降质图吞掉。封面同样只取本地最快图。
      return ThumbnailOption.ios(
        size: pathThumbnailSize,
        format: ThumbnailFormat.jpeg,
        quality: 80,
        deliveryMode: DeliveryMode.fastFormat,
        resizeMode: ResizeMode.fast,
      );
    }
    return ThumbnailOption(
      size: pathThumbnailSize,
      format: ThumbnailFormat.jpeg,
      quality: 80,
    );
  }

  @override
  Future<Uint8List?> getThumbnailFromPath(
    PathWrapper<AssetPathEntity> path,
  ) async {
    if (!_firstThumbnailDisplayed.isCompleted) {
      trace?.log(
        'picker_path_thumb_skipped_until_grid',
        detail: 'pathHash=${path.path.id.hashCode}',
      );
      return null;
    }
    try {
      if (requestType == RequestType.audio) {
        return null;
      }
      final assetCount = path.assetCount ?? await path.path.assetCountAsync;
      if (assetCount == 0) {
        return null;
      }
      final assets = await path.path.getAssetListRange(
        start: 0,
        end: 1,
      );
      if (assets.isEmpty) {
        return null;
      }
      final asset = assets.single;
      if (asset.type != AssetType.image && asset.type != AssetType.video) {
        return null;
      }
      final data = await asset
          .thumbnailDataWithOption(_pathThumbnailOption)
          .timeout(_galleryPathThumbnailTimeout);
      final index = paths.indexWhere((item) => item.path.id == path.path.id);
      if (index != -1) {
        paths[index] = paths[index].copyWith(
          assetCount: assetCount,
          thumbnailData: data,
        );
        notifyListeners();
      }
      return data;
    } catch (error) {
      trace?.log(
        'picker_path_thumb_error',
        detail: 'pathHash=${path.path.id.hashCode} error=$error',
      );
      return null;
    }
  }

  @override
  Future<void> getAssetsFromPath([int? page, AssetPathEntity? path]) async {
    final requestedPath = path ?? currentPath?.path;
    if (requestedPath == null) {
      trace?.log('picker_assets_no_current_path');
      isAssetsEmpty = true;
      hasAssetsToDisplay = false;
      return;
    }
    trace?.log(
      'picker_assets_enqueued',
      detail:
          'page=${page ?? currentAssetsListPage} pathHash=${requestedPath.id.hashCode}',
    );
    final load = _assetsLoadTail.then((_) async {
      // 相册切换后，排队中的旧目录请求不再覆盖新目录数据。
      if (currentPath?.path.id != requestedPath.id) {
        trace?.log(
          'picker_assets_discarded_before_query',
          detail: 'pathHash=${requestedPath.id.hashCode}',
        );
        return;
      }
      final requestedPage = page ?? currentAssetsListPage;
      var assets = <AssetEntity>[];
      int? assetCount;
      Object? lastError;

      for (var attempt = 0;
          attempt <= _galleryAssetRetryDelays.length;
          attempt++) {
        if (!mounted || currentPath?.path.id != requestedPath.id) {
          trace?.log(
            'picker_assets_aborted_stale',
            detail:
                'page=$requestedPage attempt=$attempt mounted=$mounted pathHash=${requestedPath.id.hashCode}',
          );
          return;
        }
        try {
          trace?.log(
            'picker_assets_query_begin',
            detail:
                'page=$requestedPage attempt=$attempt pathHash=${requestedPath.id.hashCode}',
          );
          assets = await requestedPath
              .getAssetListPaged(
                page: requestedPage,
                size: pageSize,
              )
              .timeout(_galleryQueryTimeout);
          final wrapper = currentPath;
          assetCount = wrapper?.assetCount ??
              await requestedPath.assetCountAsync.timeout(_galleryQueryTimeout);
          trace?.log(
            'picker_assets_result',
            count: assets.length,
            detail: 'page=$requestedPage total=$assetCount attempt=$attempt',
          );
          if (requestedPage > 0 || assets.isNotEmpty || assetCount == 0) {
            break;
          }
        } catch (error) {
          lastError = error;
          trace?.log(
            'picker_assets_error',
            detail: 'page=$requestedPage attempt=$attempt error=$error',
          );
        }
        if (attempt < _galleryAssetRetryDelays.length) {
          await Future<void>.delayed(_galleryAssetRetryDelays[attempt]);
        }
      }

      if (currentPath?.path.id != requestedPath.id) {
        trace?.log(
          'picker_assets_discarded_after_query',
          detail: 'page=$requestedPage pathHash=${requestedPath.id.hashCode}',
        );
        return;
      }

      final updated = requestedPage == 0
          ? <AssetEntity>[]
          : List<AssetEntity>.from(currentAssets);
      final existingIds = updated.map((asset) => asset.id).toSet();
      updated.addAll(assets.where((asset) => existingIds.add(asset.id)));
      updated.sort(ChatGalleryAssetSort.compareByRecentActivityDesc);
      currentAssets = updated;

      totalAssetsCount = assetCount ?? updated.length;
      hasAssetsToDisplay = updated.isNotEmpty;
      // 查询重试耗尽后必须结束 loading。即使原生 count 暂时大于零，
      // 也先展示可恢复的空态，不能永久保持 false/false 转圈组合。
      isAssetsEmpty = updated.isEmpty;
      trace?.log(
        'picker_assets_state_applied',
        count: updated.length,
        detail:
            'page=$requestedPage total=$totalAssetsCount display=$hasAssetsToDisplay empty=$isAssetsEmpty',
      );
      if (updated.isEmpty && (assetCount ?? 0) > 0) {
        trace?.log(
          'picker_assets_exhausted',
          detail:
              'page=$requestedPage total=$assetCount error=${lastError ?? 'empty'}',
        );
      }
    });
    _assetsLoadTail = load.then<void>(
      (_) {},
      onError: (_, __) {},
    );
    return load;
  }

  @override
  Future<void> loadMoreAssets() => getAssetsFromPath();
}
