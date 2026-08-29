import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_message_preview_image_resolver.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/media_preview_header_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_media_preview_item.dart';

class ChatMediaPreviewBuildResult {
  const ChatMediaPreviewBuildResult({
    required this.items,
    required this.initialIndex,
    required this.currentItem,
    required this.sortedMessages,
  });

  final List<ChatMediaPreviewItem> items;
  final int initialIndex;
  final ChatMediaPreviewItem? currentItem;
  final List<V2TimMessage> sortedMessages;

  bool get hasImage =>
      items.any((item) => item.type == ChatMediaPreviewType.image);

  bool get hasVideo =>
      items.any((item) => item.type == ChatMediaPreviewType.video);

  /// 会话里图+视频都有时走混滑画廊。
  bool get isMixed => hasImage && hasVideo;
}

/// 聊天全屏预览默认同时收集图片与视频，便于图文混滑。
const Set<ChatMediaPreviewType> kChatMediaPreviewAllTypes = {
  ChatMediaPreviewType.image,
  ChatMediaPreviewType.video,
};

/// 点图片气泡时只收图片，避免图集数量与列表里的图片条数对不上。
const Set<ChatMediaPreviewType> kChatMediaPreviewImageTypes = {
  ChatMediaPreviewType.image,
};

typedef ChatMediaHeroTagBuilder = Object Function(V2TimMessage message);

bool isChatMediaPreviewable(
  V2TimMessage message,
  Set<ChatMediaPreviewType> types,
) {
  return _isPreviewable(message, types);
}

ChatMediaPreviewBuildResult buildChatMediaPreviewItems({
  required List<V2TimMessage> originList,
  required V2TimMessage tappedMessage,
  required Set<ChatMediaPreviewType> types,
  required ChatMediaHeroTagBuilder heroTagBuilder,
  Future<void> Function(V2TimMessage message)? onDownload,
  Future<void> Function(V2TimMessage message, BuildContext previewContext)?
      onEdit,
  Future<void> Function(V2TimMessage message, BuildContext previewContext)?
      onSend,
  Future<void> Function(V2TimMessage message)? onForward,
  Future<void> Function(V2TimMessage message)? onDelete,
}) {
  final sortedMessages = collectChatMediaMessages(
    originList: originList,
    tappedMessage: tappedMessage,
    isPreviewable: (message) => _isPreviewable(message, types),
  );
  final canonical = resolveCanonicalChatMediaMessage(tappedMessage, originList);
  final items = <ChatMediaPreviewItem>[];

  for (final message in sortedMessages) {
    final type = _typeForMessage(message);
    if (type == null || !types.contains(type)) {
      continue;
    }
    final item = _itemForMessage(
      message: message,
      type: type,
      heroTagBuilder: heroTagBuilder,
      onDownload: onDownload,
      onEdit: onEdit,
      onSend: onSend,
      onForward: onForward,
      onDelete: onDelete,
    );
    if (item != null) {
      items.add(item);
    }
  }

  final initialIndex = _findInitialIndex(items, canonical);
  return ChatMediaPreviewBuildResult(
    items: items,
    initialIndex: initialIndex,
    currentItem: items.isEmpty ? null : items[initialIndex],
    sortedMessages: sortedMessages,
  );
}

bool _isPreviewable(
  V2TimMessage message,
  Set<ChatMediaPreviewType> types,
) {
  if (isChatMediaMessageRevoked(message)) {
    return false;
  }
  final type = _typeForMessage(message);
  return type != null && types.contains(type);
}

ChatMediaPreviewType? _typeForMessage(V2TimMessage message) {
  if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_IMAGE &&
      message.imageElem != null) {
    return ChatMediaPreviewType.image;
  }
  if (message.elemType == MessageElemType.V2TIM_ELEM_TYPE_VIDEO &&
      message.videoElem != null) {
    return ChatMediaPreviewType.video;
  }
  return null;
}

ChatMediaPreviewItem? _itemForMessage({
  required V2TimMessage message,
  required ChatMediaPreviewType type,
  required ChatMediaHeroTagBuilder heroTagBuilder,
  Future<void> Function(V2TimMessage message)? onDownload,
  Future<void> Function(V2TimMessage message, BuildContext previewContext)?
      onEdit,
  Future<void> Function(V2TimMessage message, BuildContext previewContext)?
      onSend,
  Future<void> Function(V2TimMessage message)? onForward,
  Future<void> Function(V2TimMessage message)? onDelete,
}) {
  switch (type) {
    case ChatMediaPreviewType.image:
      final placeholder =
          ChatMessagePreviewImageResolver.resolvePlaceholder(message);
      final provider =
          ChatMessagePreviewImageResolver.resolve(message) ?? placeholder;
      if (provider == null) {
        return null;
      }
      return ChatMediaPreviewItem(
        message: message,
        type: type,
        heroTag: heroTagBuilder(message),
        messageID: chatMediaPreviewMessageID(message),
        imageProvider: provider,
        placeholderImageProvider: placeholder == provider ? null : placeholder,
        headerTitle: MediaPreviewHeaderUtils.titleForMessage(message),
        headerSubtitle:
            MediaPreviewHeaderUtils.subtitleForMessage(message.timestamp),
        downloadFn: onDownload == null ? null : () => onDownload(message),
        editFn: onEdit == null
            ? null
            : (previewContext) => onEdit(message, previewContext),
        sendFn: onSend == null
            ? null
            : (previewContext) => onSend(message, previewContext),
        forwardFn: onForward == null ? null : () => onForward(message),
        deleteFn: onDelete == null ? null : () => onDelete(message),
      );
    case ChatMediaPreviewType.video:
      final videoElem = message.videoElem;
      if (videoElem == null) {
        return null;
      }
      return ChatMediaPreviewItem(
        message: message,
        type: type,
        heroTag: heroTagBuilder(message),
        messageID: chatMediaPreviewMessageID(message),
        videoElement: videoElem,
        headerTitle: MediaPreviewHeaderUtils.titleForMessage(message),
        headerSubtitle:
            MediaPreviewHeaderUtils.subtitleForMessage(message.timestamp),
        downloadFn: onDownload == null ? null : () => onDownload(message),
        forwardFn: onForward == null ? null : () => onForward(message),
        deleteFn: onDelete == null ? null : () => onDelete(message),
      );
  }
}

int _findInitialIndex(
  List<ChatMediaPreviewItem> items,
  V2TimMessage target,
) {
  for (var i = 0; i < items.length; i++) {
    if (isSameChatMediaMessage(items[i].message, target)) {
      return i;
    }
  }
  return 0;
}
