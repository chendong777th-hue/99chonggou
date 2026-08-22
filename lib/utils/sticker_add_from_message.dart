import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tencent_cloud_chat_demo/src/api/sticker_api.dart';
import 'package:tencent_cloud_chat_demo/src/provider/user_sticker_provider.dart';
import 'package:tencent_cloud_chat_demo/src/repository/sticker_repository.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_compress_util.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_upload_media.dart';
import 'package:tencent_cloud_chat_demo/utils/sticker_media.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';

enum StickerAddFromMessageOutcome {
  added,
  alreadyExists,
  unsupported,
  failed,
}

/// 是否可在长按菜单中「添加到表情」。
bool canAddMessageToStickers(V2TimMessage message) {
  if (kIsWeb) {
    return false;
  }
  switch (message.elemType) {
    case MessageElemType.V2TIM_ELEM_TYPE_FACE:
      final data = message.faceElem?.data?.trim() ?? '';
      if (data.isEmpty) {
        return false;
      }
      return StickerRepository.instance.parseStickerId(data) != null ||
          data.startsWith('http');
    case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
      return message.imageElem != null;
    default:
      return false;
  }
}

/// 将消息中的表情/图片加入「我的表情」（收藏或上传自定义包）。
Future<StickerAddFromMessageOutcome> addMessageToStickers(
  V2TimMessage message,
) async {
  if (kIsWeb) {
    return StickerAddFromMessageOutcome.unsupported;
  }
  try {
    switch (message.elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_FACE:
        return _addFromFaceMessage(message);
      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        return _addFromImageMessage(message);
      default:
        return StickerAddFromMessageOutcome.unsupported;
    }
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[Sticker] addMessageToStickers failed: $e\n$st');
    }
    return StickerAddFromMessageOutcome.failed;
  }
}

Future<StickerAddFromMessageOutcome> _addFromFaceMessage(
  V2TimMessage message,
) async {
  final data = message.faceElem?.data?.trim() ?? '';
  if (data.isEmpty) {
    return StickerAddFromMessageOutcome.unsupported;
  }

  final stickerId = StickerRepository.instance.parseStickerId(data);
  if (stickerId != null) {
    final outcome = await UserStickerProvider.shared.favorite(stickerId);
    switch (outcome) {
      case StickerFavoriteOutcome.added:
        try {
          await StickerApi.instance.addToCustomPack(stickerId);
        } catch (_) {}
        return StickerAddFromMessageOutcome.added;
      case StickerFavoriteOutcome.alreadyExists:
        return StickerAddFromMessageOutcome.alreadyExists;
      case StickerFavoriteOutcome.invalidId:
        return StickerAddFromMessageOutcome.failed;
    }
  }

  if (!data.startsWith('http')) {
    return StickerAddFromMessageOutcome.unsupported;
  }

  final file = await _downloadHttpToTempFile(data);
  if (file == null) {
    return StickerAddFromMessageOutcome.failed;
  }
  return _uploadFileAsSticker(file);
}

Future<StickerAddFromMessageOutcome> _addFromImageMessage(
  V2TimMessage message,
) async {
  final file = await _resolveImageMessageFile(message);
  if (file == null) {
    return StickerAddFromMessageOutcome.failed;
  }
  return _uploadFileAsSticker(file);
}

Future<StickerAddFromMessageOutcome> _uploadFileAsSticker(File file) async {
  final path = file.path.toLowerCase();
  final isGif = path.endsWith('.gif') || StickerMediaType.isGifUrl(path);
  final prepared = await StickerCompressUtil.compressForUpload(
    file,
    isGif: isGif,
  );
  if (prepared == null) {
    return StickerAddFromMessageOutcome.failed;
  }
  final uploadFile = prepared.file;
  try {
    final maxBytes = isGif
        ? StickerUploadMediaType.gifMaxBytes
        : StickerUploadMediaType.staticMaxBytes;
    if (await uploadFile.length() > maxBytes) {
      return StickerAddFromMessageOutcome.failed;
    }
    final item =
        await StickerApi.instance.uploadSticker(uploadFile, isGif: prepared.isGif);
    await UserStickerProvider.shared.afterUpload(item);
    return StickerAddFromMessageOutcome.added;
  } finally {
    if (prepared.deleteAfterUpload) {
      try {
        if (await uploadFile.exists()) {
          await uploadFile.delete();
        }
      } catch (_) {}
    }
  }
}

Future<File?> _resolveImageMessageFile(V2TimMessage message) async {
  final imageElem = message.imageElem;
  if (imageElem == null) {
    return null;
  }

  final path = imageElem.path?.trim() ?? '';
  if (path.isNotEmpty && File(path).existsSync()) {
    return File(path);
  }

  final imageList = imageElem.imageList;
  if (imageList != null) {
    for (final img in imageList) {
      final local = img?.localUrl?.trim() ?? '';
      if (local.isNotEmpty && File(local).existsSync()) {
        return File(local);
      }
    }
  }

  final originUrl = _originImageUrl(message);
  if (originUrl != null) {
    final downloaded = await _downloadHttpToTempFile(originUrl);
    if (downloaded != null) {
      return downloaded;
    }
  }

  final msgId = message.msgID?.trim() ?? '';
  if (msgId.isEmpty) {
    return null;
  }

  final sdk = TIMUIKitCore.getSDKInstance();
  final res = await sdk.getMessageManager().downloadMessage(
        msgID: msgId,
        messageType: 3,
        imageType: 0,
        isSnapshot: false,
      );
  if (res.code != 0) {
    return null;
  }

  if (path.isNotEmpty && File(path).existsSync()) {
    return File(path);
  }
  if (imageList != null) {
    for (final img in imageList) {
      final local = img?.localUrl?.trim() ?? '';
      if (local.isNotEmpty && File(local).existsSync()) {
        return File(local);
      }
    }
  }
  return null;
}

String? _originImageUrl(V2TimMessage message) {
  final list = message.imageElem?.imageList;
  if (list == null || list.isEmpty) {
    return null;
  }
  final original = MessageUtils.getImageFromImgList(
    list,
    HistoryMessageDartConstant.oriImgPrior,
  );
  final url = original?.url?.trim() ?? '';
  if (url.startsWith('http')) {
    return url;
  }
  for (final img in list) {
    final u = img?.url?.trim() ?? '';
    if (u.startsWith('http')) {
      return u;
    }
  }
  return null;
}

Future<File?> _downloadHttpToTempFile(String url) async {
  final trimmed = url.trim();
  if (!trimmed.startsWith('http')) {
    return null;
  }
  final dir = await getTemporaryDirectory();
  final lower = trimmed.toLowerCase();
  final ext = lower.contains('.gif')
      ? 'gif'
      : (lower.contains('.webp')
          ? 'webp'
          : (lower.contains('.png') ? 'png' : 'jpg'));
  final file = File(
    '${dir.path}/sticker_import_${DateTime.now().millisecondsSinceEpoch}.$ext',
  );
  await Dio().download(trimmed, file.path);
  if (!file.existsSync() || await file.length() == 0) {
    return null;
  }
  return file;
}
