import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/painting.dart';
import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/common_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_img_trace.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_preview_resolution_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

class ChatMessagePreviewImageResolver {
  ChatMessagePreviewImageResolver._();

  static final MessageService _messageService = serviceLocator<MessageService>();

  static V2TimImage? _imageFromList(
    V2TimMessage message,
    V2TimImageTypesEnum imgType,
  ) {
    final imageList = message.imageElem?.imageList;
    if (imageList == null) {
      return null;
    }
    return MessageUtils.getImageFromImgList(
      imageList,
      HistoryMessageDartConstant.imgPriorMap[imgType] ??
          HistoryMessageDartConstant.oriImgPrior,
    );
  }

  static ImageProvider? _cachedNetworkPreviewProvider(
    String url,
    String? msgID,
    int imageType,
  ) {
    return CachedNetworkImageProvider(
      url,
      cacheKey: chatMediaPreviewImageCacheKey(msgID, imageType: imageType),
    );
  }

  static ImageProvider _cachedNetworkBubbleProvider(
    String url,
    String? msgID,
  ) {
    return CachedNetworkImageProvider(
      url,
      cacheKey: chatMediaBubbleImageCacheKey(msgID, urlFallback: url),
    );
  }

  static V2TimImage? _imageBySdkType(V2TimMessage message, int type) {
    final list = message.imageElem?.imageList;
    if (list == null) {
      return null;
    }
    for (final item in list) {
      if (item?.type == type) {
        return item;
      }
    }
    return null;
  }

  static List<(V2TimImage?, int)> _previewBigNetworkEntries(
    V2TimMessage message,
  ) {
    final originalType =
        HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['ORIGINAL']!;
    final bigType = HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['BIG']!;
    // 首屏优先 BIG（更易命中、少失效 URL）；ORIGIN 由 refreshOriginal 升级。
    // 若先挂过期 ORIGIN，加载失败叠媒体页灰底会整屏无图。
    return [
      (_imageBySdkType(message, bigType), bigType),
      (_imageBySdkType(message, originalType), originalType),
    ];
  }

  /// 真正的原图档（SDK type=0）。升级 / 下载门禁不得把 BIG/SMALL 算进来。
  static List<(V2TimImage?, int)> _previewOriginTypeNetworkEntries(
    V2TimMessage message,
  ) {
    final originalType =
        HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['ORIGINAL']!;
    return [
      (_imageBySdkType(message, originalType), originalType),
    ];
  }

  static ImageProvider? _localBigPreviewFile(V2TimMessage message) {
    try {
      final selfPath = message.imageElem?.path;
      if (message.isSelf == true &&
          selfPath != null &&
          selfPath.isNotEmpty &&
          File(selfPath).existsSync()) {
        return FileImage(File(selfPath));
      }
    } catch (_) {}

    final originalType =
        HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['ORIGINAL']!;
    final bigType = HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['BIG']!;
    for (final localUrl in [
      _imageBySdkType(message, originalType)?.localUrl,
      _imageBySdkType(message, bigType)?.localUrl,
    ]) {
      try {
        if (TencentUtils.checkString(localUrl) != null &&
            File(localUrl!).existsSync()) {
          return FileImage(File(localUrl));
        }
      } catch (_) {}
    }
    return null;
  }

  static ImageProvider? _localOriginalPreviewFile(V2TimMessage message) {
    try {
      final selfPath = message.imageElem?.path;
      if (message.isSelf == true &&
          selfPath != null &&
          selfPath.isNotEmpty &&
          File(selfPath).existsSync()) {
        return FileImage(File(selfPath));
      }
    } catch (_) {}

    // 只用 SDK ORIGIN 的 localUrl；勿用 oriImgPrior 回落到 BIG/SMALL。
    final originalType =
        HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['ORIGINAL']!;
    final originLocal = _imageBySdkType(message, originalType)?.localUrl;
    try {
      if (TencentUtils.checkString(originLocal) != null &&
          File(originLocal!).existsSync()) {
        return FileImage(File(originLocal));
      }
    } catch (_) {}
    return null;
  }

  static bool _providerIsOriginNetwork(
    ImageProvider? provider,
    String? msgID,
  ) {
    if (provider is! CachedNetworkImageProvider) {
      return false;
    }
    final originKey = chatMediaPreviewImageCacheKey(
      msgID,
      imageType: HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['ORIGINAL']!,
    );
    return provider.cacheKey == originKey;
  }

  static bool _providerIsOriginLocal(
    ImageProvider? provider,
    V2TimMessage message,
  ) {
    if (provider is! FileImage) {
      return false;
    }
    final path = provider.file.path;
    try {
      final selfPath = message.imageElem?.path;
      if (message.isSelf == true &&
          TencentUtils.checkString(selfPath) != null &&
          path == selfPath) {
        return true;
      }
      final originalType =
          HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['ORIGINAL']!;
      final originLocal = _imageBySdkType(message, originalType)?.localUrl;
      if (TencentUtils.checkString(originLocal) != null &&
          path == originLocal) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  /// 当前 provider 是否已是 ORIGIN 档（网络 cacheKey=0 或本地 ORIGIN/自发原路径）。
  static bool isOriginTierProvider(
    ImageProvider? provider,
    V2TimMessage message,
  ) {
    return _providerIsOriginNetwork(provider, message.msgID) ||
        _providerIsOriginLocal(provider, message);
  }

  static bool _isSameImageProvider(
    ImageProvider? a,
    ImageProvider? b,
  ) {
    if (a == null || b == null) {
      return false;
    }
    if (identical(a, b)) {
      return true;
    }
    if (a is FileImage && b is FileImage) {
      return a.file.path == b.file.path;
    }
    if (a is CachedNetworkImageProvider && b is CachedNetworkImageProvider) {
      return a.url == b.url && a.cacheKey == b.cacheKey;
    }
    if (a is NetworkImage && b is NetworkImage) {
      return a.url == b.url;
    }
    return false;
  }

  /// 预览占位：与聊天气泡缩略图策略对齐，复用 thumb cacheKey。
  ///
  /// 即使与大图 URL 相同也返回 bubble cacheKey 版本，便于全屏加载时立刻画出
  /// 气泡里已缓存的底图，避免黑屏只转圈。
  static ImageProvider? resolvePlaceholder(V2TimMessage message) {
    final originalImg = _imageFromList(message, V2TimImageTypesEnum.original);
    final bigImg = _imageFromList(message, V2TimImageTypesEnum.big);
    final smallImg = _imageFromList(message, V2TimImageTypesEnum.small);
    final primary = resolve(message);

    if (PlatformUtils().isWeb && message.imageElem?.path != null) {
      return null;
    }

    try {
      final selfPath = message.imageElem?.path;
      if (message.isSelf == true &&
          selfPath != null &&
          selfPath.isNotEmpty &&
          File(selfPath).existsSync()) {
        final provider = FileImage(File(selfPath));
        // 本地原图即主图时无需另铺底图。
        return _isSameImageProvider(provider, primary) ? null : provider;
      }
    } catch (_) {}

    try {
      final smallLocal = smallImg?.localUrl;
      if (TencentUtils.checkString(smallLocal) != null &&
          File(smallLocal!).existsSync()) {
        return FileImage(File(smallLocal));
      }
      final bigLocal = bigImg?.localUrl;
      if (TencentUtils.checkString(bigLocal) != null &&
          File(bigLocal!).existsSync()) {
        final provider = FileImage(File(bigLocal));
        return _isSameImageProvider(provider, primary) ? null : provider;
      }
      final originLocal = originalImg?.localUrl;
      if (TencentUtils.checkString(originLocal) != null &&
          File(originLocal!).existsSync()) {
        final provider = FileImage(File(originLocal));
        return _isSameImageProvider(provider, primary) ? null : provider;
      }
    } catch (_) {}

    // 网络：优先小图，其次大图/原图；一律走气泡 cacheKey，复用会话里已解码的图。
    for (final img in [
      smallImg,
      bigImg,
      originalImg,
      _imageBySdkType(message, 1),
      _imageBySdkType(message, 2),
    ]) {
      final url = TencentUtils.checkString(img?.url);
      if (url != null) {
        return _cachedNetworkBubbleProvider(url, message.msgID);
      }
    }

    return null;
  }

  /// 全屏预览首屏：优先原图（THUMB 只作占位，无原图时再降级大图）。
  static ImageProvider? resolve(V2TimMessage message) {
    if (PlatformUtils().isWeb && message.imageElem?.path != null) {
      return NetworkImage(message.imageElem!.path!);
    }

    final localPreview = _localBigPreviewFile(message);
    if (localPreview != null) {
      return localPreview;
    }

    for (final entry in _previewBigNetworkEntries(message)) {
      final url = TencentUtils.checkString(entry.$1?.url);
      if (url != null) {
        return _cachedNetworkPreviewProvider(url, message.msgID, entry.$2);
      }
    }

    return null;
  }

  /// 原图 provider（仅 SDK ORIGIN），用于扇形升级；不得回落 BIG/SMALL。
  static ImageProvider? resolveOriginal(V2TimMessage message) {
    if (PlatformUtils().isWeb && message.imageElem?.path != null) {
      return NetworkImage(message.imageElem!.path!);
    }

    final localOriginal = _localOriginalPreviewFile(message);
    if (localOriginal != null) {
      return localOriginal;
    }

    for (final entry in _previewOriginTypeNetworkEntries(message)) {
      final url = TencentUtils.checkString(entry.$1?.url);
      if (url != null) {
        return _cachedNetworkPreviewProvider(url, message.msgID, entry.$2);
      }
    }

    return null;
  }

  static bool shouldUpgradeToOriginal(
    V2TimMessage message,
    ImageProvider? currentProvider,
  ) {
    if (isOriginTierProvider(currentProvider, message)) {
      return false;
    }
    if (currentProvider == null) {
      return hasLocalOriginal(message) ||
          hasResolvableOriginalUrl(message) ||
          TencentUtils.checkString(message.msgID) != null;
    }
    if (hasLocalOriginal(message) || hasResolvableOriginalUrl(message)) {
      final original = resolveOriginal(message);
      if (original == null) {
        return true;
      }
      return !_isSameImageProvider(original, currentProvider);
    }
    // 仅有 BIG/SMALL 时仍可走 downloadMessage(ORIGINAL)。
    return TencentUtils.checkString(message.msgID) != null;
  }

  static bool hasLocalPreviewImage(V2TimMessage message) {
    return _localBigPreviewFile(message) != null ||
        _localOriginalPreviewFile(message) != null;
  }

  static bool hasLocalOriginal(V2TimMessage message) {
    if (PlatformUtils().isWeb) {
      return false;
    }
    try {
      final selfPath = message.imageElem?.path;
      if (message.isSelf == true &&
          selfPath != null &&
          selfPath.isNotEmpty &&
          File(selfPath).existsSync()) {
        return true;
      }
      final originalType =
          HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['ORIGINAL']!;
      final originLocal = _imageBySdkType(message, originalType)?.localUrl;
      if (TencentUtils.checkString(originLocal) != null &&
          File(originLocal!).existsSync()) {
        return true;
      }
    } catch (_) {}
    return false;
  }

  static bool hasResolvablePreviewUrl(V2TimMessage message) {
    for (final entry in _previewBigNetworkEntries(message)) {
      final url = TencentUtils.checkString(entry.$1?.url);
      if (url != null && url.startsWith('http')) {
        return true;
      }
    }
    return false;
  }

  /// 仅当 SDK ORIGIN(0) 带 http URL 时为 true；BIG/SMALL 不算。
  static bool hasResolvableOriginalUrl(V2TimMessage message) {
    for (final entry in _previewOriginTypeNetworkEntries(message)) {
      final url = TencentUtils.checkString(entry.$1?.url);
      if (url != null && url.startsWith('http')) {
        return true;
      }
    }
    return false;
  }

  static bool isSameImageProvider(ImageProvider? a, ImageProvider? b) =>
      _isSameImageProvider(a, b);

  /// 拉取原图 URL / 下载原图本地文件，供扇形升级动画使用。
  static Future<ImageProvider?> refreshOriginal(V2TimMessage message) async {
    final msgID = TencentUtils.checkString(message.msgID);
    if (msgID == null) {
      return resolveOriginal(message);
    }

    if (!hasLocalOriginal(message)) {
      if (hasResolvableOriginalUrl(message)) {
        ChatImgTrace.log(
          '[ChatImg] event=preview_refresh_skip_http msgId=$msgID',
        );
      } else {
        try {
          final response = await _messageService.getMessageOnlineUrl(
            msgID: msgID,
            reportError: false,
          );
          final imageElem = response.data?.imageElem;
          if (imageElem != null) {
            message.imageElem = imageElem;
          }
        } catch (_) {}

        if (hasResolvableOriginalUrl(message)) {
          ChatImgTrace.log(
            '[ChatImg] event=preview_refresh_skip_download msgId=$msgID '
            'reason=has_url_after_online',
          );
        } else {
          ChatImgTrace.log('[ChatImg] event=preview_refresh_download msgId=$msgID');
          try {
            await _messageService.downloadMessage(
              msgID: msgID,
              messageType: 3,
              imageType:
                  HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['ORIGINAL']!,
              isSnapshot: false,
              reportError: false,
            );
          } catch (e) {
            ChatImgTrace.log(
              '[ChatImg] event=preview_refresh_download_error msgId=$msgID err=$e',
            );
          }
        }
      }
    }

    final refreshed = resolveOriginal(message);
    if (refreshed != null) {
      PaintingBinding.instance.imageCache.evict(refreshed);
    }
    return refreshed;
  }

  /// 兼容旧调用。
  static Future<ImageProvider?> refresh(V2TimMessage message) =>
      refreshOriginal(message);

  /// 预览用解码包装：本地图保持原样，网络图按屏尺寸上限解码。
  static ImageProvider wrapPreviewDecode({
    required BuildContext context,
    required V2TimMessage? message,
    required ImageProvider provider,
    bool preferFullResolution = false,
  }) {
    if (provider is FileImage) {
      return provider;
    }
    final target = imagePreviewDecodeTargetForMessage(
      context,
      message: message,
      preferFullResolution: preferFullResolution,
    );
    return imagePreviewDecodedProvider(provider, target: target);
  }
}
