import 'dart:convert';
import 'dart:io';

import 'package:collection/collection.dart';
import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_value_callback.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_value_callback.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_callback.dart';
import 'package:tencent_cloud_chat_uikit/base_widgets/tim_ui_kit_class.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_separate_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_chat_global_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/message/message_services.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/separate_models/tui_chat_model_tools.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/app_image_editor.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/edited_image_gallery_save.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/image_preview_edit_store.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitSearch/conversation_asset_utils.dart';

/// 全屏图片预览：编辑后保存相册；预览页可点「发送」发出（优先编辑版）。
class ImagePreviewEditor {
  ImagePreviewEditor._();

  static bool get isSupported => AppImageEditor.isSupported;

  static Future<void> editMessageImageAndSave({
    required BuildContext previewContext,
    required V2TimMessage message,
  }) async {
    if (!isSupported) {
      return;
    }
    final source = await _resolveMessageSourceFile(message);
    if (source == null || !previewContext.mounted) {
      _toast(TIM_t('无法读取图片'));
      return;
    }

    final edited = await AppImageEditor.open(previewContext, source);
    if (edited == null || !previewContext.mounted) {
      return;
    }

    final saved = await EditedImageGallerySave.save(previewContext, edited);
    if (!previewContext.mounted) {
      return;
    }

    final messageId = _messageKey(message);
    if (messageId != null) {
      ImagePreviewEditStore.instance.put(messageId, edited);
    }

    if (!saved) {
      _toast(TIM_t('保存到相册失败'));
      return;
    }
    _toast(TIM_t('已保存到相册'));
  }

  static Future<void> sendMessageImage({
    required BuildContext previewContext,
    required V2TimMessage message,
    required String convID,
    required ConvType convType,
    TUIChatSeparateViewModel? chatModel,
  }) async {
    final messageId = _messageKey(message);
    File? imageFile;
    if (messageId != null) {
      imageFile = ImagePreviewEditStore.instance.peek(messageId);
    }
    imageFile ??= await _resolveMessageSourceFile(message);
    if (imageFile == null || !await imageFile.exists()) {
      _toast(TIM_t('无法读取图片'));
      return;
    }

    final trimmedConvID = convID.trim();
    if (trimmedConvID.isEmpty) {
      _toast(TIM_t('发送失败'));
      return;
    }

    final sendFuture = chatModel != null
        ? chatModel.sendImageMessage(
            imagePath: imageFile.path,
            convID: trimmedConvID,
            convType: convType,
          )
        : _sendImageWithoutChatModel(
            imagePath: imageFile.path,
            convID: trimmedConvID,
            convType: convType,
          );

    if (sendFuture == null) {
      _toast(TIM_t('发送失败'));
      return;
    }

    final result = previewContext.mounted
        ? await MessageUtils.handleMessageError(sendFuture, previewContext)
        : await sendFuture;

    if (!previewContext.mounted) {
      return;
    }

    if (result != null && result.code == 0) {
      _toast(TIM_t('已发送'));
      Navigator.of(previewContext).pop();
      return;
    }

    if (result == null) {
      _toast(TIM_t('发送失败'));
    }
  }

  static String? _messageKey(V2TimMessage message) {
    final msgId = message.msgID?.trim();
    if (msgId != null && msgId.isNotEmpty) {
      return msgId;
    }
    final id = message.id?.toString().trim();
    if (id != null && id.isNotEmpty) {
      return id;
    }
    return null;
  }

  static Future<V2TimValueCallback<V2TimMessage>?>? _sendImageWithoutChatModel({
    required String imagePath,
    required String convID,
    required ConvType convType,
  }) async {
    final messageService = serviceLocator<MessageService>();
    final tools = serviceLocator<TUIChatModelTools>();
    final globalModel = serviceLocator<TUIChatGlobalModel>();

    final imageMessageInfo = await messageService.createImageMessage(
      imagePath: imagePath,
    );
    final messageInfo = imageMessageInfo?.messageInfo;
    if (imageMessageInfo == null || messageInfo == null) {
      return null;
    }

    final messageInfoWithSender =
        tools.setUserInfoForMessage(messageInfo, imageMessageInfo.id);
    return globalModel.sendMessageFromController(
      messageInfo: messageInfoWithSender,
      convID: convID,
      convType: convType,
    );
  }

  static Future<File?> _resolveMessageSourceFile(V2TimMessage message) async {
    final model = serviceLocator<TUIChatGlobalModel>();
    final localPath = _resolveConversationImageLocalPath(message, model);
    if (localPath.isNotEmpty) {
      final file = File(localPath);
      if (await file.exists()) {
        return file;
      }
    }

    final imageElem = message.imageElem;
    if (imageElem == null) {
      return null;
    }
    final originalImg =
        conversationImageFromList(message, V2TimImageTypesEnum.original);
    final url = originalImg?.url ?? imageElem.path ?? '';
    if (url.startsWith('http://') || url.startsWith('https://')) {
      return _downloadToTemp(url);
    }
    if (url.isNotEmpty) {
      final file = File(url);
      if (await file.exists()) {
        return file;
      }
    }
    return null;
  }

  static String _resolveConversationImageLocalPath(
    V2TimMessage message,
    TUIChatGlobalModel model,
  ) {
    final path = message.imageElem?.path;
    if (path != null && path.isNotEmpty && File(path).existsSync()) {
      return path;
    }
    final localUrl = message.imageElem?.imageList?.firstOrNull?.localUrl;
    if (localUrl != null && localUrl.isNotEmpty && File(localUrl).existsSync()) {
      return localUrl;
    }
    final msgID = message.msgID;
    if (msgID != null && msgID.isNotEmpty) {
      final savedPath = model.getFileMessageLocation(msgID);
      if (savedPath.isNotEmpty && File(savedPath).existsSync()) {
        return savedPath;
      }
    }
    return '';
  }

  static Future<File?> _downloadToTemp(String url) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return null;
      }
      final bytes = response.bodyBytes;
      if (bytes.isEmpty) {
        return null;
      }
      final dir = await getTemporaryDirectory();
      final digest = md5.convert(utf8.encode(url)).toString();
      final file = File(
        '${dir.path}/preview_edit_$digest.jpg',
      );
      await file.writeAsBytes(bytes, flush: true);
      return file;
    } catch (_) {
      return null;
    }
  }

  static void _toast(String text) {
    TIMUIKitClass.onTIMCallback(
      TIMCallback(
        type: TIMCallbackType.INFO,
        infoRecommendText: text,
      ),
    );
  }
}
