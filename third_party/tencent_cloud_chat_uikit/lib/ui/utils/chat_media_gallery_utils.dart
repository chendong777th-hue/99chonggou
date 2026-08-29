import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_status.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/image_gallery_item.dart';

class ChatBubbleImageWarmDecodeHint {
  const ChatBubbleImageWarmDecodeHint({
    required this.decodeByWidth,
    required this.targetPx,
  });

  final bool decodeByWidth;
  final int targetPx;
}

class _ChatBubbleImageWarmDecodeEntry {
  const _ChatBubbleImageWarmDecodeEntry({
    required this.hint,
    required this.expiresAtMs,
  });

  final ChatBubbleImageWarmDecodeHint hint;
  final int expiresAtMs;
}

const int _maxChatBubbleImageWarmDecodeHints = 48;
const Duration _chatBubbleImageWarmDecodeHintTtl = Duration(seconds: 12);
final Map<String, _ChatBubbleImageWarmDecodeEntry>
    _chatBubbleImageWarmDecodeHints =
    <String, _ChatBubbleImageWarmDecodeEntry>{};

/// Registers the exact ResizeImage key used by route-entry media prefetch.
///
/// The short-lived hint lets the mounted bubble join the same in-flight image
/// decode instead of creating a second provider at a different cache size.
void registerChatBubbleImageWarmDecodeHint(
  String cacheKey, {
  required bool decodeByWidth,
  required int targetPx,
}) {
  final key = cacheKey.trim();
  if (key.isEmpty || targetPx <= 0) {
    return;
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  _chatBubbleImageWarmDecodeHints.removeWhere(
    (_, entry) => entry.expiresAtMs <= now,
  );
  _chatBubbleImageWarmDecodeHints.remove(key);
  _chatBubbleImageWarmDecodeHints[key] = _ChatBubbleImageWarmDecodeEntry(
    hint: ChatBubbleImageWarmDecodeHint(
      decodeByWidth: decodeByWidth,
      targetPx: targetPx,
    ),
    expiresAtMs: now + _chatBubbleImageWarmDecodeHintTtl.inMilliseconds,
  );
  while (_chatBubbleImageWarmDecodeHints.length >
      _maxChatBubbleImageWarmDecodeHints) {
    _chatBubbleImageWarmDecodeHints.remove(
      _chatBubbleImageWarmDecodeHints.keys.first,
    );
  }
}

ChatBubbleImageWarmDecodeHint? chatBubbleImageWarmDecodeHint(
  String cacheKey,
) {
  final key = cacheKey.trim();
  if (key.isEmpty) {
    return null;
  }
  final entry = _chatBubbleImageWarmDecodeHints[key];
  if (entry == null) {
    return null;
  }
  if (entry.expiresAtMs <= DateTime.now().millisecondsSinceEpoch) {
    _chatBubbleImageWarmDecodeHints.remove(key);
    return null;
  }
  return entry.hint;
}

void forgetChatBubbleImageWarmDecodeHint(String cacheKey) {
  _chatBubbleImageWarmDecodeHints.remove(cacheKey.trim());
}

/// 退出大图/图集时驱逐预览位图；勿传入气泡 thumb provider。
void evictChatPreviewImageProviders(Iterable<ImageProvider?> providers) {
  if (kIsWeb) {
    return;
  }
  final cache = PaintingBinding.instance.imageCache;
  final seen = <int>{};
  for (final provider in providers) {
    if (provider == null) {
      continue;
    }
    final id = identityHashCode(provider);
    if (!seen.add(id)) {
      continue;
    }
    try {
      cache.evict(provider);
    } catch (_) {}
  }
}

class _IndexedChatMediaMessage {
  const _IndexedChatMediaMessage({
    required this.message,
    required this.listIndex,
  });

  final V2TimMessage message;
  final int listIndex;
}

/// 分别匹配 [msgID] 与 [id]，避免 `msgID ?? id` 单字符串误判。
bool isSameChatMediaMessage(V2TimMessage a, V2TimMessage b) {
  if (identical(a, b)) {
    return true;
  }
  final aMsgID = a.msgID?.trim();
  final bMsgID = b.msgID?.trim();
  if (aMsgID != null &&
      aMsgID.isNotEmpty &&
      bMsgID != null &&
      bMsgID.isNotEmpty &&
      aMsgID == bMsgID) {
    return true;
  }
  final aId = a.id;
  final bId = b.id;
  if (aId != null && bId != null && aId == bId) {
    return true;
  }
  return false;
}

/// 将点击时的消息对象归一化为 [originList] 中的列表项（优先使用含 msgID 的版本）。
V2TimMessage resolveCanonicalChatMediaMessage(
  V2TimMessage target,
  List<V2TimMessage> originList,
) {
  for (final message in originList) {
    if (isSameChatMediaMessage(message, target)) {
      return message;
    }
  }
  return target;
}

String? chatMediaPreviewMessageID(V2TimMessage message) {
  return message.msgID ?? message.id?.toString();
}

/// 聊天气泡图片 cacheKey。同一消息可能先拿到缩略图、随后补齐大图 URL，
/// 因此必须把实际 URL 纳入 key；否则大图 provider 会继续命中旧缩略图。
String chatMediaBubbleImageCacheKey(String? msgID, {String? urlFallback}) {
  final id = msgID?.trim() ?? '';
  final trimmed = urlFallback?.trim() ?? '';
  if (id.isNotEmpty && trimmed.isNotEmpty) {
    return '$id:bubble:$trimmed';
  }
  if (id.isNotEmpty) {
    return '$id:bubble';
  }
  if (trimmed.isNotEmpty) {
    return 'bubble:$trimmed';
  }
  return 'bubble:unknown';
}

/// 气泡 [Image] 的稳定 Widget key（按消息，不按 URL/路径/展示源）。
///
/// [kind] 仅作兼容保留，有 msgID 时不再写入 key。否则网图出帧后切本地
/// thumb 会从 `chat_img_net_*` 变成 `chat_img_local_*`，拆掉 Element，
/// [Image.gaplessPlayback] 失效，框内同图再闪一下。
String chatBubbleImageWidgetKey({
  required String kind,
  String? msgID,
  String? idFallback,
  String? urlOrPathFallback,
}) {
  final id = msgID?.trim() ?? '';
  if (id.isNotEmpty) {
    return 'chat_img_bubble_$id';
  }
  final client = idFallback?.trim() ?? '';
  if (client.isNotEmpty) {
    return 'chat_img_bubble_id_$client';
  }
  final fallback = urlOrPathFallback?.trim() ?? '';
  if (fallback.isNotEmpty) {
    return 'chat_img_bubble_$fallback';
  }
  final safeKind = kind.trim().isEmpty ? 'bubble' : kind.trim();
  return 'chat_img_${safeKind}_unknown';
}

/// 气泡是否已成功解出过一帧（跨 URL/路径切换复用，避免 frameBuilder 再闪灰）。
String chatBubbleImageReadyToken({String? msgID, String? idFallback}) {
  final id = msgID?.trim() ?? '';
  if (id.isNotEmpty) {
    return 'bubble_ready:$id';
  }
  final client = idFallback?.trim() ?? '';
  if (client.isNotEmpty) {
    return 'bubble_ready:id:$client';
  }
  return 'bubble_ready:anon';
}

/// 预览原图/大图/缩略图使用不同 cacheKey，避免缩略图 URL 写入后长期命中小图。
String chatMediaPreviewImageCacheKey(String? msgID, {required int imageType}) {
  final id = msgID?.trim() ?? '';
  if (id.isEmpty) {
    return 'preview:$imageType';
  }
  return '$id:preview:$imageType';
}

/// 聊天列表里的时间分割线等「非消息行」，图集收集需排除。
bool isChatListNonMessageRow(V2TimMessage message) {
  return message.elemType == 11 || message.elemType == 101;
}

/// Revoked media keeps its original image/video element in the SDK message so
/// the chat row can render a revoke tip. It must not remain previewable merely
/// because that payload is still attached.
bool isChatMediaMessageRevoked(V2TimMessage message) {
  if (message.status == MessageStatus.V2TIM_MSG_STATUS_LOCAL_REVOKED) {
    return true;
  }
  final raw = message.cloudCustomData?.trim() ?? '';
  if (raw.isEmpty) {
    return false;
  }
  try {
    final decoded = jsonDecode(raw);
    return decoded is Map && decoded['isRevoke'] == true;
  } catch (_) {
    return false;
  }
}

/// 去掉时间分割线，保留与 [TIMUIKitHistoryMessageList] 一致的消息行。
List<V2TimMessage> filterChatGalleryOriginRows(List<V2TimMessage> messages) {
  if (messages.isEmpty) {
    return const <V2TimMessage>[];
  }
  return messages
      .where(
        (message) =>
            !isChatListNonMessageRow(message) &&
            !isChatMediaMessageRevoked(message),
      )
      .toList(growable: false);
}

/// 统计当前聊天列表里可预览的媒体条数（与图集收集口径对齐）。
int countChatListPreviewableMedia({
  required List<V2TimMessage> displayListNewestFirst,
  required bool Function(V2TimMessage) isPreviewable,
}) {
  var count = 0;
  for (final message in filterChatGalleryOriginRows(displayListNewestFirst)) {
    if (isPreviewable(message)) {
      count++;
    }
  }
  return count;
}

/// 图集页码：最早一张为 1，最新一张为 [count]。顺序旧→新，右滑更早、左滑更新。
String chatMediaGalleryPageLabel({
  required int indexOldestFirst,
  required int count,
}) {
  if (count <= 0) {
    return '';
  }
  final page = indexOldestFirst.clamp(0, count - 1) + 1;
  return '$page / $count';
}

/// 图集左侧插入更早媒体后，用旧列表里的当前张去新列表定位，避免下标错位。
int retainChatMediaGalleryIndex({
  required int currentIndex,
  required List<V2TimMessage> oldOldestFirst,
  required List<V2TimMessage> newOldestFirst,
}) {
  if (newOldestFirst.isEmpty) {
    return 0;
  }
  if (oldOldestFirst.isEmpty ||
      currentIndex < 0 ||
      currentIndex >= oldOldestFirst.length) {
    return currentIndex.clamp(0, newOldestFirst.length - 1);
  }
  final current = oldOldestFirst[currentIndex];
  for (var i = 0; i < newOldestFirst.length; i++) {
    if (isSameChatMediaMessage(newOldestFirst[i], current)) {
      return i;
    }
  }
  return currentIndex.clamp(0, newOldestFirst.length - 1);
}

/// 在旧→新图集列表里查找目标消息下标；找不到返回 -1。
int findChatMediaGalleryMessageIndex({
  required List<V2TimMessage> messagesOldestFirst,
  required V2TimMessage target,
}) {
  for (var i = 0; i < messagesOldestFirst.length; i++) {
    if (isSameChatMediaMessage(messagesOldestFirst[i], target)) {
      return i;
    }
  }
  return -1;
}

/// 图集扩窗后定位当前页：优先锚定用户点开的那条消息，再保留旧页映射。
int resolveChatMediaGalleryIndexAfterExpand({
  required int currentIndex,
  required List<V2TimMessage> oldOldestFirst,
  required List<V2TimMessage> newOldestFirst,
  V2TimMessage? tappedMessage,
  int? preferredIndex,
}) {
  if (newOldestFirst.isEmpty) {
    return 0;
  }
  if (tappedMessage != null) {
    for (var i = 0; i < newOldestFirst.length; i++) {
      if (isSameChatMediaMessage(newOldestFirst[i], tappedMessage)) {
        return i;
      }
    }
  }
  if (preferredIndex != null &&
      preferredIndex >= 0 &&
      preferredIndex < newOldestFirst.length) {
    return preferredIndex;
  }
  return retainChatMediaGalleryIndex(
    currentIndex: currentIndex,
    oldOldestFirst: oldOldestFirst,
    newOldestFirst: newOldestFirst,
  );
}

List<V2TimMessage> chatMediaGalleryMessagesFromImageItems(
  List<ImageGalleryItem> items,
) {
  return [
    for (final item in items)
      if (item.sourceMessage != null) item.sourceMessage!,
  ];
}

/// 扩窗后目标页超出当前已挂载的 PageView 条数时，立刻 jumpToPage 会被
/// maxScrollExtent 夹回旧页。典型：内存窗 8 张停在第 8 张，扩到 497 张后
/// 逻辑页是 496，但滚动位置仍停在 7，左右一滑就露出第 8 张。
bool chatMediaGalleryMustDeferPageJump({
  required int targetIndex,
  required int attachedChildCount,
}) {
  if (attachedChildCount <= 0) {
    return true;
  }
  return targetIndex >= attachedChildCount;
}

/// 条数变了就必须重建 PageController：initialPage 只在创建时生效，
/// 扩窗后仍可能把滚动弹回打开瞬间的旧页。
bool chatMediaGalleryShouldReplacePageController({
  required int oldItemCount,
  required int newItemCount,
}) {
  return oldItemCount != newItemCount && newItemCount > 0;
}

/// 图集顺序：旧 → 新；与 reverse 聊天列表「上旧下新」一致。
int compareChatMediaMessagesForGallery(
  V2TimMessage a,
  int aListIndex,
  V2TimMessage b,
  int bListIndex,
) {
  final timestampCompare = (a.timestamp ?? 0).compareTo(b.timestamp ?? 0);
  if (timestampCompare != 0) {
    return timestampCompare;
  }
  final aSeq = a.seq is int ? a.seq as int : 0;
  final bSeq = b.seq is int ? b.seq as int : 0;
  final seqCompare = aSeq.compareTo(bSeq);
  if (seqCompare != 0) {
    return seqCompare;
  }
  // originList 为 newest→oldest：index 越大越旧，图集越靠前。
  return bListIndex.compareTo(aListIndex);
}

List<_IndexedChatMediaMessage> _dedupeIndexedEntries(
  List<_IndexedChatMediaMessage> entries,
) {
  final deduped = <_IndexedChatMediaMessage>[];
  for (final entry in entries) {
    final existingIndex = deduped.indexWhere(
      (item) => isSameChatMediaMessage(item.message, entry.message),
    );
    if (existingIndex < 0) {
      deduped.add(entry);
      continue;
    }
    if (entry.listIndex > deduped[existingIndex].listIndex) {
      deduped[existingIndex] = entry;
    }
  }
  return deduped;
}

List<V2TimMessage> collectChatMediaMessages({
  required List<V2TimMessage> originList,
  required V2TimMessage tappedMessage,
  required bool Function(V2TimMessage) isPreviewable,
}) {
  final entries = <_IndexedChatMediaMessage>[];
  for (var i = 0; i < originList.length; i++) {
    final message = originList[i];
    if (!isPreviewable(message)) {
      continue;
    }
    entries.add(_IndexedChatMediaMessage(message: message, listIndex: i));
  }

  final canonical = resolveCanonicalChatMediaMessage(tappedMessage, originList);
  if (isPreviewable(canonical) &&
      !entries
          .any((entry) => isSameChatMediaMessage(entry.message, canonical))) {
    entries.add(
      _IndexedChatMediaMessage(
        message: canonical,
        listIndex: originList.length,
      ),
    );
  }

  final deduped = _dedupeIndexedEntries(entries);
  deduped.sort(
    (a, b) => compareChatMediaMessagesForGallery(
      a.message,
      a.listIndex,
      b.message,
      b.listIndex,
    ),
  );
  return deduped.map((entry) => entry.message).toList(growable: false);
}

int findChatMediaGalleryIndex({
  required List<V2TimMessage> sortedMessages,
  required V2TimMessage target,
  required bool Function(V2TimMessage) canIncludeInGallery,
}) {
  var galleryIndex = 0;
  for (final message in sortedMessages) {
    if (!canIncludeInGallery(message)) {
      continue;
    }
    if (isSameChatMediaMessage(target, message)) {
      return galleryIndex;
    }
    galleryIndex++;
  }
  return 0;
}
