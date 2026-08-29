import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

const int _chatGalleryPageSize = 40;

/// 聊天发图：系统 Photo Picker 与自定义相册的路由与预热。
class ChatGalleryPickUtils {
  ChatGalleryPickUtils._();

  static PermissionRequestOption permissionRequestOption({
    RequestType requestType = RequestType.common,
  }) {
    return PermissionRequestOption(
      androidPermission: AndroidPermission(
        type: requestType,
        mediaLocation: false,
      ),
    );
  }

  /// 聊天移动端使用系统样式的可控相册。
  ///
  /// 原生 Photo Picker 不公开初始相册和资源排序配置，因此使用
  /// PhotoKit/MediaStore 数据实现同平台视觉，并保留最近活动排序能力。
  static Future<bool> shouldPreferCustomGalleryPicker({
    RequestType requestType = RequestType.common,
  }) async {
    if (kIsWeb) {
      return true;
    }
    // Mobile chat now uses the native image_picker route. Keep the custom
    // AssetEntity picker available only to legacy/non-native callers.
    if (Platform.isIOS || Platform.isAndroid) return false;
    return false;
  }

  /// 在需要预检权限的入口串行完成授权。
  ///
  /// 不要在打开选择器时清理缩略图缓存；清理与 Provider 首次查询并发会导致
  /// 已有照片短暂返回空缩略图，表现为偶发白屏。
  static Future<void> prepareCustomGalleryPicker({
    RequestType requestType = RequestType.common,
  }) async {
    try {
      await PhotoManager.requestPermissionExtend(
        requestOption: permissionRequestOption(requestType: requestType),
      );
    } catch (_) {}
  }

  /// [AssetPickerPageRoute] / 系统选图 pop 的 Future 常在退场动画开始前就完成。
  /// 在此之前做列表重建或相册文件导出，会与关闭动画抢主线程，造成顿挫。
  static Future<void> waitForPickerDismissSettle({
    Duration transitionDuration = const Duration(milliseconds: 250),
  }) async {
    if (kIsWeb) {
      return;
    }
    await SchedulerBinding.instance.endOfFrame;
    if (transitionDuration <= Duration.zero) {
      return;
    }
    await Future<void>.delayed(
      transitionDuration + const Duration(milliseconds: 16),
    );
  }

  static FilterOptionGroup telegramLikeFilterOptions() {
    return FilterOptionGroup(
      orders: [
        OrderOption(
          type: !kIsWeb && Platform.isIOS
              ? OrderOptionType.updateDate
              : OrderOptionType.createDate,
          asc: false,
        ),
      ],
    );
  }

  static String recentAlbumDisplayName(AssetPathEntity path) {
    if (path.isAll) {
      if (!kIsWeb && Platform.isIOS) {
        return '最近项目';
      }
      if (!kIsWeb && Platform.isAndroid) {
        return '最近';
      }
    }
    return path.name;
  }

  static AssetPickerConfig withPickerDefaults(AssetPickerConfig config) {
    final filterOptions =
        config.filterOptions ?? (!kIsWeb ? telegramLikeFilterOptions() : null);
    final sortPathsByModifiedDate = config.sortPathsByModifiedDate || !kIsWeb;

    if (config.limitedPermissionOverlayPredicate != null &&
        config.assetsChangeRefreshPredicate != null &&
        config.pathNameBuilder != null &&
        config.sortPathsByModifiedDate == sortPathsByModifiedDate &&
        config.pageSize <= _chatGalleryPageSize &&
        filterOptions == config.filterOptions) {
      return config;
    }
    return AssetPickerConfig(
      selectedAssets: config.selectedAssets,
      maxAssets: config.maxAssets,
      pageSize: config.pageSize > _chatGalleryPageSize
          ? _chatGalleryPageSize
          : config.pageSize,
      gridThumbnailSize: config.gridThumbnailSize,
      pathThumbnailSize: config.pathThumbnailSize,
      previewThumbnailSize: config.previewThumbnailSize,
      requestType: config.requestType,
      specialPickerType: config.specialPickerType,
      keepScrollOffset: config.keepScrollOffset,
      sortPathDelegate: config.sortPathDelegate ?? SortPathDelegate.common,
      sortPathsByModifiedDate: sortPathsByModifiedDate,
      filterOptions: filterOptions,
      gridCount: config.gridCount,
      themeColor: config.themeColor,
      pickerTheme: config.pickerTheme,
      textDelegate: config.textDelegate,
      specialItemPosition: config.specialItemPosition,
      specialItemBuilder: config.specialItemBuilder,
      loadingIndicatorBuilder: config.loadingIndicatorBuilder,
      selectPredicate: config.selectPredicate,
      // 系统照片流语义：最新资源位于首屏顶部，不采用 iOS 默认的倒序底部锚点。
      shouldRevertGrid: false,
      limitedPermissionOverlayPredicate:
          config.limitedPermissionOverlayPredicate ?? (_) => true,
      pathNameBuilder: config.pathNameBuilder ?? recentAlbumDisplayName,
      assetsChangeCallback: config.assetsChangeCallback,
      assetsChangeRefreshPredicate: config.assetsChangeRefreshPredicate ??
          (_, __, path) => path?.isAll ?? true,
      shouldAutoplayPreview: config.shouldAutoplayPreview,
      dragToSelect: config.dragToSelect,
    );
  }
}
