import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tencent_cloud_chat_demo/src/api/favorite_message_api.dart';
import 'package:tencent_cloud_chat_demo/src/models/favorite_message_models.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';

enum FavoriteFromMessageOutcome {
  added,
  alreadyExists,
  unsupported,
  failed,
}

/// 聊天收藏操作结果（含失败时的服务端提示）。
class FavoriteAddResult {
  const FavoriteAddResult(this.outcome, [this.errorMessage]);

  final FavoriteFromMessageOutcome outcome;
  final String? errorMessage;
}

const _maxFavoriteVideoSec = 60;

/// 是否可在长按菜单中「收藏」。
bool canFavoriteMessage(V2TimMessage message) {
  if (kIsWeb) {
    return false;
  }
  switch (message.elemType) {
    case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
      return (message.textElem?.text?.trim() ?? '').isNotEmpty;
    case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
      return message.imageElem != null;
    case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
      final duration = message.videoElem?.duration ?? 0;
      return message.videoElem != null && duration <= _maxFavoriteVideoSec;
    default:
      return false;
  }
}

/// 将聊天消息收藏到服务端 `POST /me/favorites` 或 `/me/favorites/upload`。
Future<FavoriteAddResult> addMessageToFavorites(
  V2TimMessage message, {
  String? sourceSenderName,
  String? sourceConvLabel,
  String? sourceConvId,
}) async {
  if (kIsWeb || !canFavoriteMessage(message)) {
    return const FavoriteAddResult(FavoriteFromMessageOutcome.unsupported);
  }

  final api = FavoriteMessageApi.instance;
  final msgId = message.msgID?.trim() ?? '';
  final convId = sourceConvId?.trim();
  final sender = sourceSenderName?.trim();
  final convLabel = sourceConvLabel?.trim();

  try {
    switch (message.elemType) {
      case MessageElemType.V2TIM_ELEM_TYPE_TEXT:
        await api.create(
          CreateFavoriteRequest(
            type: FavoriteMessageType.text,
            text: message.textElem?.text,
            sourceMsgId: msgId.isEmpty ? null : msgId,
            sourceConvId: convId,
            sourceSenderName: sender,
            sourceConvLabel: convLabel,
          ),
        );
        return const FavoriteAddResult(FavoriteFromMessageOutcome.added);

      case MessageElemType.V2TIM_ELEM_TYPE_IMAGE:
        final file = await _resolveImageFile(message);
        if (file != null) {
          await api.upload(
            file: file,
            type: FavoriteMessageType.image,
            sourceMsgId: msgId.isEmpty ? null : msgId,
            sourceConvId: convId,
            sourceSenderName: sender,
            sourceConvLabel: convLabel,
          );
          return const FavoriteAddResult(FavoriteFromMessageOutcome.added);
        }
        final urls = _imageRemoteUrls(message);
        if (urls.mediaUrl == null) {
          return const FavoriteAddResult(
            FavoriteFromMessageOutcome.failed,
            '图片未下载完成，请稍后再试',
          );
        }
        await api.create(
          CreateFavoriteRequest(
            type: FavoriteMessageType.image,
            remoteMediaUrl: urls.mediaUrl,
            remoteThumbUrl: urls.thumbUrl ?? urls.mediaUrl,
            sourceMsgId: msgId.isEmpty ? null : msgId,
            sourceConvId: convId,
            sourceSenderName: sender,
            sourceConvLabel: convLabel,
          ),
        );
        return const FavoriteAddResult(FavoriteFromMessageOutcome.added);

      case MessageElemType.V2TIM_ELEM_TYPE_VIDEO:
        return _favoriteVideoMessage(
          message,
          api: api,
          sourceMsgId: msgId.isEmpty ? null : msgId,
          sourceConvId: convId,
          sourceSenderName: sender,
          sourceConvLabel: convLabel,
        );

      default:
        return const FavoriteAddResult(FavoriteFromMessageOutcome.unsupported);
    }
  } on DioError catch (e) {
    final errText = FavoriteMessageApi.errorMessage(e);
    if (kDebugMode) {
      debugPrint('[Favorite] addMessageToFavorites: $errText');
    }
    if (_errorCode(e) == 'FAVORITE_ALREADY_EXISTS') {
      return const FavoriteAddResult(FavoriteFromMessageOutcome.alreadyExists);
    }
    return FavoriteAddResult(FavoriteFromMessageOutcome.failed, errText);
  } catch (e, st) {
    if (kDebugMode) {
      debugPrint('[Favorite] addMessageToFavorites failed: $e\n$st');
    }
    return FavoriteAddResult(FavoriteFromMessageOutcome.failed, '$e');
  }
}

Future<FavoriteAddResult> _favoriteVideoMessage(
  V2TimMessage message, {
  required FavoriteMessageApi api,
  String? sourceMsgId,
  String? sourceConvId,
  String? sourceSenderName,
  String? sourceConvLabel,
}) async {
  final elem = message.videoElem;
  if (elem == null) {
    return const FavoriteAddResult(
      FavoriteFromMessageOutcome.failed,
      '视频消息无效',
    );
  }
  final duration = elem.duration ?? 0;

  final resolved = await _resolveVideoFiles(message);
  if (resolved.video != null) {
    await api.upload(
      file: resolved.video!,
      type: FavoriteMessageType.video,
      snapshot: resolved.snapshot,
      durationSec: duration > 0 ? duration : null,
      sourceMsgId: sourceMsgId,
      sourceConvId: sourceConvId,
      sourceSenderName: sourceSenderName,
      sourceConvLabel: sourceConvLabel,
    );
    return const FavoriteAddResult(FavoriteFromMessageOutcome.added);
  }

  final videoUrl = elem.videoUrl?.trim() ?? '';
  if (!videoUrl.startsWith('http')) {
    return const FavoriteAddResult(
      FavoriteFromMessageOutcome.failed,
      '视频未下载完成，请稍后再试',
    );
  }
  final snapshotUrl = elem.snapshotUrl?.trim() ?? '';
  await api.create(
    CreateFavoriteRequest(
      type: FavoriteMessageType.video,
      remoteMediaUrl: videoUrl,
      remoteThumbUrl:
          snapshotUrl.isNotEmpty ? snapshotUrl : null,
      durationSec: duration > 0 ? duration : null,
      sourceMsgId: sourceMsgId,
      sourceConvId: sourceConvId,
      sourceSenderName: sourceSenderName,
      sourceConvLabel: sourceConvLabel,
    ),
  );
  return const FavoriteAddResult(FavoriteFromMessageOutcome.added);
}

String? _errorCode(DioError e) {
  final data = e.response?.data;
  if (data is Map) {
    return data['code']?.toString();
  }
  return null;
}

File? _existingFile(String? path) {
  final p = path?.trim() ?? '';
  if (p.isEmpty || !File(p).existsSync()) {
    return null;
  }
  return File(p);
}

Future<void> _refreshImageElemOnline(V2TimMessage message) async {
  final msgId = message.msgID?.trim() ?? '';
  if (msgId.isEmpty) {
    return;
  }
  final list = message.imageElem?.imageList;
  if (list != null && list.isNotEmpty) {
    return;
  }
  final sdk = TIMUIKitCore.getSDKInstance();
  final res = await sdk.getMessageManager().getMessageOnlineUrl(msgID: msgId);
  if (res.code == 0 && res.data?.imageElem != null) {
    message.imageElem = res.data!.imageElem;
  }
}

Future<void> _refreshVideoElemOnline(V2TimMessage message) async {
  final msgId = message.msgID?.trim() ?? '';
  if (msgId.isEmpty) {
    return;
  }
  final elem = message.videoElem;
  if (elem != null &&
      (elem.videoUrl?.trim().isNotEmpty == true ||
          elem.localVideoUrl?.trim().isNotEmpty == true)) {
    return;
  }
  final sdk = TIMUIKitCore.getSDKInstance();
  final res = await sdk.getMessageManager().getMessageOnlineUrl(msgID: msgId);
  if (res.code == 0 && res.data?.videoElem != null) {
    message.videoElem = res.data!.videoElem;
  }
}

Future<File?> _resolveImageFile(V2TimMessage message) async {
  final imageElem = message.imageElem;
  if (imageElem == null) {
    return null;
  }

  final path = imageElem.path?.trim() ?? '';
  final fromPath = _existingFile(path);
  if (fromPath != null) {
    return fromPath;
  }

  final imageList = imageElem.imageList;
  if (imageList != null) {
    for (final img in imageList) {
      final local = _existingFile(img?.localUrl);
      if (local != null) {
        return local;
      }
    }
  }

  final msgId = message.msgID?.trim() ?? '';
  if (msgId.isNotEmpty) {
    await _refreshImageElemOnline(message);
    final sdk = TIMUIKitCore.getSDKInstance();
    final res = await sdk.getMessageManager().downloadMessage(
          msgID: msgId,
          messageType: 3,
          imageType: 0,
          isSnapshot: false,
        );
    if (res.code == 0) {
      final afterPath = _existingFile(message.imageElem?.path);
      if (afterPath != null) {
        return afterPath;
      }
      final listAfter = message.imageElem?.imageList;
      if (listAfter != null) {
        for (final img in listAfter) {
          final local = _existingFile(img?.localUrl);
          if (local != null) {
            return local;
          }
        }
      }
    }
  }

  final originUrl = _originImageUrl(message);
  if (originUrl != null) {
    return _downloadHttpToTempFile(originUrl, defaultExt: 'jpg');
  }

  return null;
}

({String? mediaUrl, String? thumbUrl}) _imageRemoteUrls(V2TimMessage message) {
  final media = _originImageUrl(message);
  if (media == null) {
    return (mediaUrl: null, thumbUrl: null);
  }
  final list = message.imageElem?.imageList;
  String? thumb;
  if (list != null) {
    final small = MessageUtils.getImageFromImgList(
      list,
      HistoryMessageDartConstant.smallImgPrior,
    );
    final t = small?.url?.trim() ?? '';
    if (t.startsWith('http')) {
      thumb = t;
    }
  }
  return (mediaUrl: media, thumbUrl: thumb ?? media);
}

Future<({File? video, File? snapshot})> _resolveVideoFiles(
  V2TimMessage message,
) async {
  var elem = message.videoElem;
  if (elem == null) {
    return (video: null, snapshot: null);
  }

  File? pickVideo() {
    for (final candidate in [elem!.videoPath, elem.localVideoUrl]) {
      final f = _existingFile(candidate);
      if (f != null) {
        return f;
      }
    }
    return null;
  }

  File? pickSnapshot() {
    for (final candidate in [elem!.snapshotPath, elem.localSnapshotUrl]) {
      final f = _existingFile(candidate);
      if (f != null) {
        return f;
      }
    }
    return null;
  }

  var video = pickVideo();
  var snapshot = pickSnapshot();
  if (video != null) {
    return (video: video, snapshot: snapshot);
  }

  final msgId = message.msgID?.trim() ?? '';
  if (msgId.isEmpty) {
    return (video: null, snapshot: snapshot);
  }

  final sdk = TIMUIKitCore.getSDKInstance();
  await _refreshVideoElemOnline(message);
  elem = message.videoElem;
  video = pickVideo();
  snapshot = pickSnapshot();
  if (video != null) {
    return (video: video, snapshot: snapshot);
  }

  final dlVideo = await sdk.getMessageManager().downloadMessage(
        msgID: msgId,
        messageType: 5,
        imageType: 0,
        isSnapshot: false,
      );
  if (dlVideo.code == 0) {
    elem = message.videoElem;
    video = pickVideo();
  }

  final dlSnap = await sdk.getMessageManager().downloadMessage(
        msgID: msgId,
        messageType: 5,
        imageType: 0,
        isSnapshot: true,
      );
  if (dlSnap.code == 0) {
    snapshot = pickSnapshot();
  }

  video ??= pickVideo();
  if (video != null) {
    return (video: video, snapshot: snapshot);
  }

  final videoUrl = elem?.videoUrl?.trim() ?? '';
  if (videoUrl.startsWith('http')) {
    final downloaded = await _downloadHttpToTempFile(videoUrl, defaultExt: 'mp4');
    if (downloaded != null) {
      if (snapshot == null) {
        final snapUrl = elem?.snapshotUrl?.trim() ?? '';
        if (snapUrl.startsWith('http')) {
          snapshot = await _downloadHttpToTempFile(snapUrl, defaultExt: 'jpg');
        }
      }
      return (video: downloaded, snapshot: snapshot);
    }
  }

  return (video: null, snapshot: snapshot);
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

Future<File?> _downloadHttpToTempFile(
  String url, {
  String defaultExt = 'jpg',
}) async {
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
          : (lower.contains('.png')
              ? 'png'
              : (lower.contains('.mp4')
                  ? 'mp4'
                  : (lower.contains('.mov') ? 'mov' : defaultExt))));
  final file = File(
    '${dir.path}/fav_import_${DateTime.now().millisecondsSinceEpoch}.$ext',
  );
  await Dio().download(trimmed, file.path);
  if (!file.existsSync() || await file.length() == 0) {
    return null;
  }
  return file;
}
