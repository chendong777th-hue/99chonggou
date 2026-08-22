import 'dart:io';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_image.dart';

import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_preview_image_resolver.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/image_edit/image_preview_editor.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_gallery_item.dart';

enum ConversationAssetTab { media, file }

String conversationMediaHeroTag(V2TimMessage message) {
  return 'conv_media_${message.msgID ?? message.id ?? message.timestamp}';
}

V2TimImage? conversationImageFromList(
  V2TimMessage message,
  V2TimImageTypesEnum imgType,
) {
  final list = message.imageElem?.imageList;
  if (list == null) {
    return null;
  }
  return MessageUtils.getImageFromImgList(
    list,
    HistoryMessageDartConstant.imgPriorMap[imgType] ??
        HistoryMessageDartConstant.oriImgPrior,
  );
}

ImageProvider? resolveConversationImagePreviewProvider(V2TimMessage message) {
  return ChatMessagePreviewImageResolver.resolve(message);
}

List<ImageGalleryItem> buildConversationImageGalleryItems(
  List<V2TimMessage> imageMessages, {
  Future<void> Function(V2TimMessage message)? onDownload,
  Future<void> Function(V2TimMessage message, BuildContext previewContext)?
      onEdit,
  Future<void> Function(V2TimMessage message, BuildContext previewContext)?
      onSend,
}) {
  final items = <ImageGalleryItem>[];
  for (final message in imageMessages) {
    final provider = resolveConversationImagePreviewProvider(message);
    if (provider == null) {
      continue;
    }
    items.add(
      ImageGalleryItem(
        imageProvider: provider,
        placeholderImageProvider:
            ChatMessagePreviewImageResolver.resolvePlaceholder(message),
        heroTag: conversationMediaHeroTag(message),
        messageID: message.msgID,
        sourceMessage: message,
        downloadFn: onDownload == null ? null : () => onDownload(message),
        editFn: onEdit == null || !ImagePreviewEditor.isSupported
            ? null
            : (previewContext) => onEdit(message, previewContext),
        sendFn: onSend == null
            ? null
            : (previewContext) => onSend(message, previewContext),
      ),
    );
  }
  return items;
}

int findConversationImageGalleryIndex(
  List<V2TimMessage> imageMessages,
  V2TimMessage target,
) {
  var galleryIndex = 0;
  for (final message in imageMessages) {
    final provider = resolveConversationImagePreviewProvider(message);
    if (provider == null) {
      continue;
    }
    final isTarget = isSameChatMediaMessage(target, message);
    if (isTarget) {
      return galleryIndex;
    }
    galleryIndex++;
  }
  return 0;
}


bool isConversationMediaMessage(V2TimMessage message) {
  final type = message.elemType;
  return type == MessageElemType.V2TIM_ELEM_TYPE_IMAGE ||
      type == MessageElemType.V2TIM_ELEM_TYPE_VIDEO;
}

bool isConversationFileMessage(V2TimMessage message) {
  return message.elemType == MessageElemType.V2TIM_ELEM_TYPE_FILE;
}

String? resolveConversationImagePreviewUrl(V2TimMessage message) {
  final list = message.imageElem?.imageList;
  if (list == null || list.isEmpty) {
    return null;
  }
  final thumb = MessageUtils.getImageFromImgList(
    list,
    HistoryMessageDartConstant.smallImgPrior,
  );
  final url = thumb?.url?.trim() ?? '';
  if (url.startsWith('http')) {
    return url;
  }
  final local = thumb?.localUrl?.trim() ?? message.imageElem?.path?.trim() ?? '';
  if (local.isNotEmpty && !PlatformUtils().isWeb && File(local).existsSync()) {
    return local;
  }
  final original = MessageUtils.getImageFromImgList(
    list,
    HistoryMessageDartConstant.oriImgPrior,
  );
  final originUrl = original?.url?.trim() ?? '';
  return originUrl.startsWith('http') ? originUrl : null;
}

String? resolveConversationVideoSnapshotUrl(V2TimMessage message) {
  final snapshot = message.videoElem?.snapshotUrl?.trim() ?? '';
  if (snapshot.startsWith('http')) {
    return snapshot;
  }
  final local = message.videoElem?.snapshotPath?.trim() ?? '';
  if (local.isNotEmpty && !PlatformUtils().isWeb && File(local).existsSync()) {
    return local;
  }
  return null;
}

String? resolveConversationMediaPreviewUrl(V2TimMessage message) {
  if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE) {
    return resolveConversationImagePreviewUrl(message);
  }
  if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO) {
    return resolveConversationVideoSnapshotUrl(message);
  }
  return null;
}
