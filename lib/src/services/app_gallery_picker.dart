import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/editable_asset_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart';

class AppGalleryMedia {
  const AppGalleryMedia({
    required this.asset,
    required this.file,
  });

  final AssetEntity asset;
  final File file;

  bool get isVideo => asset.type == AssetType.video;
}

/// 应用内相册统一入口：保留微信选择器交互、最近资源排序和空列表恢复。
class AppGalleryPicker {
  AppGalleryPicker._();

  static Future<List<AppGalleryMedia>> pick(
    BuildContext context, {
    required int maxAssets,
    RequestType requestType = RequestType.image,
    Color? themeColor,
  }) async {
    final assets = await EditableAssetPicker.pickAssets(
      context,
      pickerConfig: AssetPickerConfig(
        maxAssets: maxAssets,
        requestType: requestType,
        themeColor: themeColor ?? Theme.of(context).colorScheme.primary,
      ),
    );
    if (assets == null || assets.isEmpty) {
      return const <AppGalleryMedia>[];
    }

    final result = <AppGalleryMedia>[];
    for (final asset in assets) {
      final file = await EditableAssetPicker.resolveFile(asset);
      if (file != null && file.existsSync()) {
        result.add(AppGalleryMedia(asset: asset, file: file));
      }
    }
    return result;
  }

  static Future<File?> pickSingleImage(
    BuildContext context, {
    Color? themeColor,
  }) async {
    final result = await pick(
      context,
      maxAssets: 1,
      requestType: RequestType.image,
      themeColor: themeColor,
    );
    return result.isEmpty ? null : result.first.file;
  }
}
