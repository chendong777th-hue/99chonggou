import 'dart:collection';

import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/link_preview_entry.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/link_preview/models/link_preview_content.dart';
import 'package:tim_ui_kit_sticker_plugin/utils/tim_custom_face_data.dart';

/// Caches expensive markdown / hyperlink text builders per message.
class MessageHyperlinkTextCache {
  MessageHyperlinkTextCache._();

  static final MessageHyperlinkTextCache instance =
      MessageHyperlinkTextCache._();

  final LinkedHashMap<String, _MessageHyperlinkTextCacheEntry> _cache =
      LinkedHashMap();
  static const int _maxEntries = 256;

  String _buildKey({
    required String messageKey,
    required String messageText,
    required bool isMarkdown,
    required bool isUseQQPackage,
    required bool isUseTencentCloudChatPackage,
    required bool isUseTencentCloudChatPackageOldKeys,
    required int customEmojiCount,
    required bool isEnableTextSelection,
  }) {
    return [
      messageKey,
      messageText.hashCode,
      isMarkdown,
      isUseQQPackage,
      isUseTencentCloudChatPackage,
      isUseTencentCloudChatPackageOldKeys,
      customEmojiCount,
      isEnableTextSelection,
    ].join('|');
  }

  LinkPreviewText getOrCreate({
    required String messageKey,
    required String messageText,
    required bool isMarkdown,
    Function(String)? onLinkTap,
    void Function(String id)? onTapChatIdMention,
    bool isEnableTextSelection = false,
    bool isUseQQPackage = false,
    bool isUseTencentCloudChatPackage = false,
    bool isUseTencentCloudChatPackageOldKeys = false,
    List<CustomEmojiFaceData> customEmojiStickerList = const [],
  }) {
    final key = _buildKey(
      messageKey: messageKey,
      messageText: messageText,
      isMarkdown: isMarkdown,
      isUseQQPackage: isUseQQPackage,
      isUseTencentCloudChatPackage: isUseTencentCloudChatPackage,
      isUseTencentCloudChatPackageOldKeys: isUseTencentCloudChatPackageOldKeys,
      customEmojiCount: customEmojiStickerList.length,
      isEnableTextSelection: isEnableTextSelection,
    );
    final cached = _cache.remove(key);
    if (cached != null) {
      if (identical(cached.onLinkTap, onLinkTap) &&
          identical(cached.onTapChatIdMention, onTapChatIdMention)) {
        _cache[key] = cached;
        return cached.text;
      }
    }
    final created = LinkPreviewEntry.getHyperlinksText(
      messageText,
      isMarkdown,
      onLinkTap: onLinkTap,
      onTapChatIdMention: onTapChatIdMention,
      isEnableTextSelection: isEnableTextSelection,
      isUseQQPackage: isUseQQPackage,
      isUseTencentCloudChatPackage: isUseTencentCloudChatPackage,
      isUseTencentCloudChatPackageOldKeys: isUseTencentCloudChatPackageOldKeys,
      customEmojiStickerList: customEmojiStickerList,
    )!;
    _cache[key] = _MessageHyperlinkTextCacheEntry(
      text: created,
      onLinkTap: onLinkTap,
      onTapChatIdMention: onTapChatIdMention,
    );
    while (_cache.length > _maxEntries) {
      _cache.remove(_cache.keys.first);
    }
    return created;
  }

  void clear() => _cache.clear();
}

class _MessageHyperlinkTextCacheEntry {
  const _MessageHyperlinkTextCacheEntry({
    required this.text,
    required this.onLinkTap,
    required this.onTapChatIdMention,
  });

  final LinkPreviewText text;
  final Function(String)? onLinkTap;
  final void Function(String id)? onTapChatIdMention;
}
