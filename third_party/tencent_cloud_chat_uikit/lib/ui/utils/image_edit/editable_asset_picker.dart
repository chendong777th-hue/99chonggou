import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart' hide Path;
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_gallery_asset_picker_provider.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_gallery_pick_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/gallery_send_perf_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/asset_picker_edit_builder_delegate.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/asset_picker_edit_store.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

enum GalleryResolveOutcome { success, permissionLimited, cloudTimeout, missingResource, unsupportedOrCorrupt, oversize, transientPlatformFailure }
class GalleryResolveResult {
  const GalleryResolveResult({required this.outcome, this.file, this.source});
  final GalleryResolveOutcome outcome;
  final File? file;
  final String? source;
  bool get isSuccess => outcome == GalleryResolveOutcome.success && file != null;
}

/// 支持预览编辑的相册选择器。
class EditableAssetPicker {
  EditableAssetPicker._();

  static const Duration _providerInitializeDelay = Duration.zero;

  static AssetPickerPageRoute<List<AssetEntity>> _defaultPickerRoute(
    Widget picker, {
    RouteSettings? settings,
  }) {
    return AssetPickerPageRoute<List<AssetEntity>>(
      builder: (_) => picker,
      settings: settings,
    );
  }

  /// 打开相册选择器（预览页可编辑图片）。
  static Future<List<AssetEntity>?> pickAssets(
    BuildContext context, {
    Key? key,
    PermissionRequestOption? permissionRequestOption,
    AssetPickerConfig pickerConfig = const AssetPickerConfig(),
    bool useRootNavigator = true,
    RouteSettings? pageRouteSettings,
    AssetPickerPageRouteBuilder<List<AssetEntity>>? pageRouteBuilder,
    GallerySendPerfTrace? perf,
  }) async {
    final ownsTrace = perf == null;
    final trace = perf ?? GallerySendPerfTrace(mode: 'editable_asset_picker');
    trace.log('picker_prepare_begin');
    AssetPickerEditStore.instance.beginSession();
    final effectivePickerConfig =
        ChatGalleryPickUtils.withPickerDefaults(pickerConfig);
    final resolvedPermission = permissionRequestOption ??
        ChatGalleryPickUtils.permissionRequestOption(
          requestType: effectivePickerConfig.requestType,
        );
    trace.log(
      'picker_permission_begin',
      detail: 'requestType=${effectivePickerConfig.requestType}',
    );
    try {
      final ps = await AssetPicker.permissionCheck(
        requestOption: resolvedPermission,
      );
      trace.log('picker_permission_ok', detail: ps.toString());
      final provider = ChatGalleryAssetPickerProvider(
        maxAssets: effectivePickerConfig.maxAssets,
        pageSize: effectivePickerConfig.pageSize,
        pathThumbnailSize: effectivePickerConfig.pathThumbnailSize,
        selectedAssets: effectivePickerConfig.selectedAssets,
        requestType: effectivePickerConfig.requestType,
        sortPathDelegate: effectivePickerConfig.sortPathDelegate,
        sortPathsByModifiedDate: effectivePickerConfig.sortPathsByModifiedDate,
        filterOptions: effectivePickerConfig.filterOptions,
        // Prefer zero delay so open does not flash an empty shell. Empty-path
        // cold starts are recovered by ChatGalleryAssetPickerProvider retries.
        initializeDelayDuration: _providerInitializeDelay,
        trace: trace,
      );
      final builderDelegate = AppAssetPickerEditBuilderDelegate(
        provider: provider,
        initialPermission: ps,
        gridCount: effectivePickerConfig.gridCount,
        pickerTheme: effectivePickerConfig.pickerTheme,
        gridThumbnailSize: effectivePickerConfig.gridThumbnailSize,
        previewThumbnailSize: effectivePickerConfig.previewThumbnailSize,
        specialPickerType: effectivePickerConfig.specialPickerType,
        specialItemPosition: effectivePickerConfig.specialItemPosition,
        specialItemBuilder: effectivePickerConfig.specialItemBuilder,
        loadingIndicatorBuilder: effectivePickerConfig.loadingIndicatorBuilder,
        selectPredicate: effectivePickerConfig.selectPredicate,
        shouldRevertGrid: effectivePickerConfig.shouldRevertGrid,
        limitedPermissionOverlayPredicate:
            effectivePickerConfig.limitedPermissionOverlayPredicate,
        pathNameBuilder: effectivePickerConfig.pathNameBuilder,
        assetsChangeCallback: effectivePickerConfig.assetsChangeCallback,
        assetsChangeRefreshPredicate:
            effectivePickerConfig.assetsChangeRefreshPredicate,
        textDelegate: effectivePickerConfig.textDelegate,
        themeColor: effectivePickerConfig.themeColor,
        locale: Localizations.maybeLocaleOf(context),
        shouldAutoplayPreview: effectivePickerConfig.shouldAutoplayPreview,
        dragToSelect: effectivePickerConfig.dragToSelect,
      );
      final picker = AssetPicker<AssetEntity, AssetPathEntity>(
        key: key,
        permissionRequestOption: resolvedPermission,
        builder: builderDelegate,
      );
      trace.log('picker_push_begin');
      final result = await Navigator.maybeOf(
        context,
        rootNavigator: useRootNavigator,
      )?.push<List<AssetEntity>>(
        pageRouteBuilder?.call(picker) ??
            _defaultPickerRoute(
              picker,
              settings: pageRouteSettings,
            ),
      );
      trace.log(
        'picker_push_returned',
        count: result?.length ?? 0,
        detail: result == null ? 'cancelled' : 'selected',
      );
      return result;
    } catch (error) {
      trace.log('picker_failed', detail: error.toString());
      rethrow;
    } finally {
      if (ownsTrace) {
        trace.markTaskReturned();
      }
    }
  }

  /// 获取资源原始文件（优先已编辑版本）。
  static Future<File?> resolveFile(AssetEntity asset) async {
    final edited = AssetPickerEditStore.instance.peek(asset.id);
    if (edited != null && edited.existsSync()) {
      return edited;
    }
    return asset.originFile;
  }

  /// 聊天发送用：优先已编辑文件；图片优先 [AssetEntity.file]（比 originFile 导出快）。
  static Future<File?> resolveFileForChatSend(
    AssetEntity asset, {
    GallerySendPerfTrace? perf,
    int? index,
  }) async {
    return (await resolveFileForChatSendResult(asset, perf: perf, index: index)).file;
  }

  static Future<GalleryResolveResult> resolveFileForChatSendResult(
    AssetEntity asset, {
    GallerySendPerfTrace? perf,
    int? index,
    Duration timeout = const Duration(seconds: 20),
    int retries = 2,
  }) async {
    final watch = Stopwatch()..start();
    perf?.log('resolve_file_begin', index: index);
    final edited = AssetPickerEditStore.instance.peek(asset.id);
    if (edited != null && edited.existsSync()) {
      perf?.log(
        'resolve_file_end',
        index: index,
        detail: 'source=edited itemMs=${watch.elapsedMilliseconds}',
      );
      return GalleryResolveResult(outcome: GalleryResolveOutcome.success, file: edited, source: 'edited');
    }
    Object? lastError;
    for (var attempt = 0; attempt <= retries; attempt++) {
      try {
        final file = await (asset.type == AssetType.image ? asset.file : asset.originFile)
            .timeout(timeout);
        if (file != null && file.existsSync()) {
          final source = asset.type == AssetType.image ? 'file' : 'origin';
          perf?.log('resolve_file_end', index: index,
              detail: 'source=$source attempt=${attempt + 1} itemMs=${watch.elapsedMilliseconds}');
          return GalleryResolveResult(outcome: GalleryResolveOutcome.success, file: file, source: source);
        }
        lastError = StateError('missing resource');
      } on TimeoutException catch (error) {
        lastError = error;
      } catch (error) {
        lastError = error;
      }
      if (attempt < retries) {
        perf?.log('resolve_file_retry', index: index, detail: 'attempt=${attempt + 1}');
        await Future<void>.delayed(const Duration(milliseconds: 120));
      }
    }
    final errorName = lastError?.runtimeType.toString().toLowerCase() ?? '';
    final outcome = lastError is TimeoutException
        ? GalleryResolveOutcome.cloudTimeout
        : (lastError is StateError
            ? GalleryResolveOutcome.missingResource
            : (errorName.contains('permission') || errorName.contains('access')
                ? GalleryResolveOutcome.permissionLimited
                : (errorName.contains('format') || errorName.contains('decode')
                    ? GalleryResolveOutcome.unsupportedOrCorrupt
                    : GalleryResolveOutcome.transientPlatformFailure)));
    perf?.log('resolve_file_terminal', index: index, detail: 'outcome=${outcome.name} attempts=${retries + 1}');
    return GalleryResolveResult(outcome: outcome);
  }

  /// 获取用于编辑的源文件（优先已编辑版本）。
  static Future<File?> resolveSourceFile(AssetEntity asset) {
    return resolveFile(asset);
  }
}
