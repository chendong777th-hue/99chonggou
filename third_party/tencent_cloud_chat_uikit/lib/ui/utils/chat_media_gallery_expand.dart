import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/chat_media_gallery_utils.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/chat_media_preview_item.dart';

/// 图集本地分页扩窗。只扩当前会话、当前预览，不写进聊天内存窗，不打云端。
/// 顺序旧→新：第 1 张最早，最后一张最新；右滑历史，左滑最新。
abstract final class ChatMediaGalleryExpandPolicy {
  /// 单侧最多翻本地页数，只防死循环；正常以 isFinished 或 [maxItems] 结束。
  static const int maxPagesPerSide = 20;

  /// 每页条数，与聊天历史分页对齐。
  static const int pageSize = 40;

  /// 图集总媒体上限，以点击消息为中心截窗。
  static const int maxItems = 500;

  /// 会话级扩窗结果缓存时长。
  static const Duration cacheTtl = Duration(seconds: 45);

  /// 同时缓存的会话×类型上限，超出按最近最少使用淘汰。
  static const int maxCacheEntries = 8;
}

class ChatMediaGalleryExpandPage {
  const ChatMediaGalleryExpandPage({
    required this.messages,
    required this.isFinished,
  });

  final List<V2TimMessage> messages;
  final bool isFinished;
}

typedef ChatMediaGalleryHistoryLoader = Future<ChatMediaGalleryExpandPage>
    Function({
  required HistoryMsgGetTypeEnum getType,
  required int count,
  String? lastMsgID,
  V2TimMessage? lastMsg,
  required List<int> messageTypeList,
});

List<int> chatMediaGalleryMessageTypeList(Set<ChatMediaPreviewType> types) {
  final list = <int>[];
  if (types.contains(ChatMediaPreviewType.image)) {
    list.add(MessageElemType.V2TIM_ELEM_TYPE_IMAGE);
  }
  if (types.contains(ChatMediaPreviewType.video)) {
    list.add(MessageElemType.V2TIM_ELEM_TYPE_VIDEO);
  }
  return list;
}

bool chatMediaGalleryShouldExpand({
  required int currentCount,
  required bool hasMoreOlder,
  required bool hasMoreNewer,
  int maxItems = ChatMediaGalleryExpandPolicy.maxItems,
}) {
  if (currentCount >= maxItems) {
    return false;
  }
  return hasMoreOlder || hasMoreNewer;
}

/// 合并内存窗媒体与本地扩窗结果，按旧→新去重后截到 [maxItems]。
List<V2TimMessage> mergeChatMediaGalleryMessages({
  required List<V2TimMessage> seedNewestFirst,
  required List<V2TimMessage> expanded,
  required V2TimMessage tappedMessage,
  required bool Function(V2TimMessage) isPreviewable,
  int maxItems = ChatMediaGalleryExpandPolicy.maxItems,
}) {
  final combined = <V2TimMessage>[
    ...seedNewestFirst,
    ...expanded,
  ];
  final collected = collectChatMediaMessages(
    originList: combined,
    tappedMessage: tappedMessage,
    isPreviewable: isPreviewable,
  );
  if (maxItems <= 0 || collected.length <= maxItems) {
    return collected;
  }
  var tappedIndex = 0;
  for (var i = 0; i < collected.length; i++) {
    if (isSameChatMediaMessage(collected[i], tappedMessage)) {
      tappedIndex = i;
      break;
    }
  }
  final half = maxItems ~/ 2;
  var start = tappedIndex - half;
  if (start < 0) {
    start = 0;
  }
  var end = start + maxItems;
  if (end > collected.length) {
    end = collected.length;
    start = end - maxItems;
    if (start < 0) {
      start = 0;
    }
  }
  return collected.sublist(start, end);
}

/// 缓存命中且包含当前点击消息时，与最新内存窗合并；否则返回 null 走 SDK。
List<V2TimMessage>? resolveCachedChatMediaGallery({
  required List<V2TimMessage>? cachedOldestFirst,
  required List<V2TimMessage> seedNewestFirst,
  required V2TimMessage tappedMessage,
  required bool Function(V2TimMessage) isPreviewable,
  int maxItems = ChatMediaGalleryExpandPolicy.maxItems,
}) {
  final cached = cachedOldestFirst;
  if (cached == null || cached.isEmpty) {
    return null;
  }
  final hasTapped =
      cached.any((message) => isSameChatMediaMessage(message, tappedMessage));
  if (!hasTapped) {
    return null;
  }
  return mergeChatMediaGalleryMessages(
    seedNewestFirst: seedNewestFirst,
    expanded: cached,
    tappedMessage: tappedMessage,
    isPreviewable: isPreviewable,
    maxItems: maxItems,
  );
}

/// 把新到的媒体插到图集最新侧；已在列表里则不替换，避免下载进度把图集整页刷掉。
List<V2TimMessage> appendIncomingChatMediaGalleryMessage({
  required List<V2TimMessage> currentOldestFirst,
  required V2TimMessage incoming,
  required bool Function(V2TimMessage) isPreviewable,
  int maxItems = ChatMediaGalleryExpandPolicy.maxItems,
}) {
  if (!isPreviewable(incoming)) {
    return currentOldestFirst;
  }
  for (var i = 0; i < currentOldestFirst.length; i++) {
    if (isSameChatMediaMessage(currentOldestFirst[i], incoming)) {
      return currentOldestFirst;
    }
  }
  final next = List<V2TimMessage>.of(currentOldestFirst)..add(incoming);
  if (maxItems <= 0 || next.length <= maxItems) {
    return next;
  }
  return next.sublist(next.length - maxItems);
}

class ChatMediaGalleryExpandCursor {
  const ChatMediaGalleryExpandCursor({
    this.lastMsgID,
    this.lastMsg,
  });

  final String? lastMsgID;
  final V2TimMessage? lastMsg;
}

ChatMediaGalleryExpandCursor? chatMediaGalleryOldestCursor(
  List<V2TimMessage> newestFirst,
) {
  for (var i = newestFirst.length - 1; i >= 0; i--) {
    final message = newestFirst[i];
    if (isChatListNonMessageRow(message)) {
      continue;
    }
    final msgID = message.msgID?.trim();
    if (msgID != null && msgID.isNotEmpty) {
      return ChatMediaGalleryExpandCursor(
        lastMsgID: msgID,
        lastMsg: message,
      );
    }
  }
  return null;
}

ChatMediaGalleryExpandCursor? chatMediaGalleryNewestCursor(
  List<V2TimMessage> newestFirst,
) {
  for (final message in newestFirst) {
    if (isChatListNonMessageRow(message)) {
      continue;
    }
    final msgID = message.msgID?.trim();
    if (msgID != null && msgID.isNotEmpty) {
      return ChatMediaGalleryExpandCursor(
        lastMsgID: msgID,
        lastMsg: message,
      );
    }
  }
  return null;
}

class ChatMediaGalleryExpandResult {
  const ChatMediaGalleryExpandResult({
    required this.messagesOldestFirst,
    required this.didExpand,
    required this.olderFinished,
    required this.newerFinished,
    required this.pageCount,
  });

  final List<V2TimMessage> messagesOldestFirst;
  final bool didExpand;
  final bool olderFinished;
  final bool newerFinished;
  final int pageCount;
}

Future<ChatMediaGalleryExpandResult> expandChatMediaGalleryMessages({
  required List<V2TimMessage> seedNewestFirst,
  required V2TimMessage tappedMessage,
  required Set<ChatMediaPreviewType> types,
  required ChatMediaGalleryHistoryLoader loader,
  required bool Function(V2TimMessage) isPreviewable,
  int maxPagesPerSide = ChatMediaGalleryExpandPolicy.maxPagesPerSide,
  int pageSize = ChatMediaGalleryExpandPolicy.pageSize,
  int maxItems = ChatMediaGalleryExpandPolicy.maxItems,
  void Function(List<V2TimMessage> oldestFirst)? onProgress,
}) async {
  final typeList = chatMediaGalleryMessageTypeList(types);
  final expanded = <V2TimMessage>[];
  var olderFinished = false;
  var newerFinished = false;
  var pageCount = 0;

  List<V2TimMessage> snapshot() {
    return mergeChatMediaGalleryMessages(
      seedNewestFirst: seedNewestFirst,
      expanded: expanded,
      tappedMessage: tappedMessage,
      isPreviewable: isPreviewable,
      maxItems: maxItems,
    );
  }

  Future<void> pullSide({
    required HistoryMsgGetTypeEnum getType,
    required ChatMediaGalleryExpandCursor? start,
    required void Function(bool finished) markFinished,
  }) async {
    var cursor = start;
    if (cursor == null) {
      markFinished(true);
      return;
    }
    for (var i = 0; i < maxPagesPerSide; i++) {
      final currentCursor = cursor;
      if (currentCursor == null) {
        markFinished(true);
        return;
      }
      if (snapshot().length >= maxItems) {
        return;
      }
      final page = await loader(
        getType: getType,
        count: pageSize,
        lastMsgID: currentCursor.lastMsgID,
        lastMsg: currentCursor.lastMsg,
        messageTypeList: typeList,
      );
      pageCount++;
      if (page.messages.isEmpty) {
        markFinished(true);
        return;
      }
      expanded.addAll(page.messages);
      onProgress?.call(snapshot());
      if (page.isFinished || page.messages.length < pageSize) {
        markFinished(true);
        return;
      }
      final nextId = page.messages.last.msgID?.trim();
      if (nextId == null ||
          nextId.isEmpty ||
          nextId == currentCursor.lastMsgID) {
        markFinished(true);
        return;
      }
      cursor = ChatMediaGalleryExpandCursor(
        lastMsgID: nextId,
        lastMsg: page.messages.last,
      );
    }
  }

  await pullSide(
    getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
    start: chatMediaGalleryOldestCursor(seedNewestFirst),
    markFinished: (finished) => olderFinished = finished,
  );
  await pullSide(
    getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_NEWER_MSG,
    start: chatMediaGalleryNewestCursor(seedNewestFirst),
    markFinished: (finished) => newerFinished = finished,
  );

  final merged = mergeChatMediaGalleryMessages(
    seedNewestFirst: seedNewestFirst,
    expanded: expanded,
    tappedMessage: tappedMessage,
    isPreviewable: isPreviewable,
    maxItems: maxItems,
  );
  return ChatMediaGalleryExpandResult(
    messagesOldestFirst: merged,
    didExpand: expanded.isNotEmpty,
    olderFinished: olderFinished,
    newerFinished: newerFinished,
    pageCount: pageCount,
  );
}

class ChatMediaGalleryExpandCacheEntry {
  ChatMediaGalleryExpandCacheEntry({
    required this.messagesOldestFirst,
    required this.expiresAt,
  });

  final List<V2TimMessage> messagesOldestFirst;
  final DateTime expiresAt;

  bool get isExpired => DateTime.now().isAfter(expiresAt);
}

/// 会话级短缓存：同一会话短时间内反复点图不重复打 SDK。
class ChatMediaGalleryExpandCache {
  ChatMediaGalleryExpandCache._();

  static final Map<String, ChatMediaGalleryExpandCacheEntry> _entries = {};

  static String keyFor({
    required String conversationID,
    required Set<ChatMediaPreviewType> types,
  }) {
    final typeKey = types.map((e) => e.name).toList()..sort();
    return '$conversationID|${typeKey.join(',')}';
  }

  static List<V2TimMessage>? get(String key) {
    _pruneExpired();
    final entry = _entries.remove(key);
    if (entry == null) {
      return null;
    }
    if (entry.isExpired) {
      return null;
    }
    _entries[key] = entry;
    return entry.messagesOldestFirst;
  }

  static void put(String key, List<V2TimMessage> messages) {
    _pruneExpired();
    _entries.remove(key);
    while (_entries.length >= ChatMediaGalleryExpandPolicy.maxCacheEntries) {
      _entries.remove(_entries.keys.first);
    }
    _entries[key] = ChatMediaGalleryExpandCacheEntry(
      messagesOldestFirst: List<V2TimMessage>.unmodifiable(messages),
      expiresAt: DateTime.now().add(ChatMediaGalleryExpandPolicy.cacheTtl),
    );
  }

  static void _pruneExpired() {
    _entries.removeWhere((_, entry) => entry.isExpired);
  }

  static void clear() {
    _entries.clear();
  }
}
