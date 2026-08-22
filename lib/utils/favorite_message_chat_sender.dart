import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tencent_cloud_chat_demo/src/models/favorite_message_models.dart';
import 'package:tencent_cloud_chat_demo/utils/media_url_resolver.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/ui/controller/tim_uikit_chat_controller.dart';

/// 将收藏项发送到当前聊天会话。
class FavoriteMessageChatSender {
  FavoriteMessageChatSender._();

  static Future<bool> send({
    required FavoriteMessageItem item,
    required TIMUIKitChatController chatController,
    required String convId,
    required ConvType convType,
  }) async {
    if (kIsWeb) {
      return false;
    }
    final model = chatController.model;
    if (model == null || convId.isEmpty) {
      return false;
    }

    try {
      switch (item.type) {
        case FavoriteMessageType.text:
          return _sendText(model, item, convId, convType);
        case FavoriteMessageType.image:
          return _sendImage(model, item, convId, convType);
        case FavoriteMessageType.video:
          return _sendVideo(model, item, convId, convType);
      }
    } catch (e, st) {
      if (kDebugMode) {
        debugPrint('[Favorite] send to chat failed: $e\n$st');
      }
      return false;
    }
  }

  static Future<bool> _sendText(
    TUIChatSeparateViewModel model,
    FavoriteMessageItem item,
    String convId,
    ConvType convType,
  ) async {
    final text = item.text?.trim() ?? '';
    if (text.isEmpty) {
      return false;
    }
    final res = await model.sendTextMessage(
      text: text,
      convID: convId,
      convType: convType,
    );
    return res != null && res.code == 0;
  }

  static Future<bool> _sendImage(
    TUIChatSeparateViewModel model,
    FavoriteMessageItem item,
    String convId,
    ConvType convType,
  ) async {
    final file = await _resolveLocalImageFile(item);
    if (file == null) {
      return false;
    }
    final res = await model.sendImageMessage(
      imagePath: file.path,
      convID: convId,
      convType: convType,
    );
    return res != null && res.code == 0;
  }

  static Future<bool> _sendVideo(
    TUIChatSeparateViewModel model,
    FavoriteMessageItem item,
    String convId,
    ConvType convType,
  ) async {
    final videoFile = await _resolveLocalVideoFile(item);
    if (videoFile == null) {
      return false;
    }
    String? snapshotPath;
    final thumb = item.localThumbPath?.trim() ?? '';
    if (thumb.isNotEmpty && File(thumb).existsSync()) {
      snapshotPath = thumb;
    } else {
      final thumbUrl = item.thumbUrl?.trim() ?? '';
      if (thumbUrl.startsWith('http')) {
        final snap = await _downloadHttpToTempFile(
          MediaUrlResolver.resolve(thumbUrl) ?? thumbUrl,
          defaultExt: 'jpg',
        );
        snapshotPath = snap?.path;
      }
    }

    final res = await model.sendVideoMessage(
      videoPath: videoFile.path,
      snapshotPath: snapshotPath,
      duration: item.durationSec,
      convID: convId,
      convType: convType,
    );
    return res != null && res.code == 0;
  }

  static Future<File?> _resolveLocalImageFile(FavoriteMessageItem item) async {
    for (final raw in [item.localMediaPath, item.localThumbPath]) {
      final p = raw?.trim() ?? '';
      if (p.isNotEmpty && !p.startsWith('http') && File(p).existsSync()) {
        return File(p);
      }
    }
    final url = item.mediaUrl ?? item.thumbUrl;
    if (url != null && url.trim().startsWith('http')) {
      return _downloadHttpToTempFile(
        MediaUrlResolver.resolve(url) ?? url,
        defaultExt: 'jpg',
      );
    }
    return null;
  }

  static Future<File?> _resolveLocalVideoFile(FavoriteMessageItem item) async {
    final local = item.localMediaPath?.trim() ?? '';
    if (local.isNotEmpty && !local.startsWith('http') && File(local).existsSync()) {
      return File(local);
    }
    final url = item.mediaUrl?.trim() ?? '';
    if (url.startsWith('http')) {
      return _downloadHttpToTempFile(
        MediaUrlResolver.resolve(url) ?? url,
        defaultExt: 'mp4',
      );
    }
    return null;
  }

  static Future<File?> _downloadHttpToTempFile(
    String url, {
    required String defaultExt,
  }) async {
    final trimmed = url.trim();
    if (!trimmed.startsWith('http')) {
      return null;
    }
    final dir = await getTemporaryDirectory();
    final file = File(
      '${dir.path}/fav_send_${DateTime.now().millisecondsSinceEpoch}.$defaultExt',
    );
    await Dio().download(trimmed, file.path);
    if (!file.existsSync() || await file.length() == 0) {
      return null;
    }
    return file;
  }
}
