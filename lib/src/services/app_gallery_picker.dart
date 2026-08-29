import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/services/system_media_picker.dart';
import 'package:wechat_assets_picker/wechat_assets_picker.dart'
    show RequestType;

class AppGalleryMedia {
  const AppGalleryMedia({
    required this.media,
  });

  final PickedMedia media;
  File get file => File(media.path);

  bool get isVideo => media.isVideo;
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
    final picked = requestType == RequestType.video
        ? await SystemMediaPicker.pickVideos(maxAssets: maxAssets)
        : await SystemMediaPicker.pickImages(maxAssets: maxAssets);
    return picked
        .map((media) => AppGalleryMedia(media: media))
        .toList(growable: false);
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
