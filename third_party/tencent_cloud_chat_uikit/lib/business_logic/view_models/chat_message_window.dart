import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/chat_message_window_policy.dart';

/// [ChatMessageWindow.trimToWindow] 的结果。只描述内存裁剪，不涉及存储删除。
class ChatMessageWindowTrimResult {
  const ChatMessageWindowTrimResult({
    required this.list,
    required this.didTrim,
    required this.removedNewerCount,
    required this.removedOlderCount,
    required this.trimmedAwayLatest,
    required this.trimmedAwayOldestInMemory,
  });

  final List<V2TimMessage> list;
  final bool didTrim;
  final int removedNewerCount;
  final int removedOlderCount;

  /// 裁掉了裁剪前内存中的最新端（newest-first 头）。
  final bool trimmedAwayLatest;

  /// 裁掉了裁剪前内存中的最旧端（newest-first 尾）。
  final bool trimmedAwayOldestInMemory;

  static ChatMessageWindowTrimResult unchanged(List<V2TimMessage> list) {
    return ChatMessageWindowTrimResult(
      list: list,
      didTrim: false,
      removedNewerCount: 0,
      removedOlderCount: 0,
      trimmedAwayLatest: false,
      trimmedAwayOldestInMemory: false,
    );
  }
}

/// 内存 Message Window：newest-first 列表上的双向滑动窗口纯函数。
class ChatMessageWindow {
  ChatMessageWindow._();

  /// [list] 必须已是 newest-first。
  ///
  /// [preferLatest]：贴底/非活跃等 → 只保留最新 [targetSize] 条。
  /// 否则按锚点（msgID/seq）向两侧保留，合成约 [targetSize] 的窗口。
  static ChatMessageWindowTrimResult trimToWindow({
    required List<V2TimMessage> list,
    bool preferLatest = false,
    String? anchorMsgID,
    String? anchorSeq,
    int? anchorIndexHint,
    int softMax = ChatMessageWindowPolicy.softMax,
    int targetSize = ChatMessageWindowPolicy.targetSize,
    int keepNewerSide = ChatMessageWindowPolicy.keepNewerSide,
    int keepOlderSide = ChatMessageWindowPolicy.keepOlderSide,
  }) {
    if (!ChatMessageWindowPolicy.enabled) {
      return ChatMessageWindowTrimResult.unchanged(list);
    }
    if (list.length <= softMax) {
      return ChatMessageWindowTrimResult.unchanged(list);
    }
    if (targetSize < 1) {
      return ChatMessageWindowTrimResult.unchanged(list);
    }
    final cappedTarget =
        targetSize > list.length ? list.length : targetSize;

    if (preferLatest) {
      return _trimKeepNewest(
        list,
        keepCount: cappedTarget,
      );
    }

    final anchorIndex = _resolveAnchorIndex(
      list,
      anchorMsgID: anchorMsgID,
      anchorSeq: anchorSeq,
      anchorIndexHint: anchorIndexHint,
    );
    return _trimAroundAnchor(
      list,
      anchorIndex: anchorIndex,
      targetSize: cappedTarget,
      keepNewerSide: keepNewerSide,
      keepOlderSide: keepOlderSide,
    );
  }

  static ChatMessageWindowTrimResult _trimKeepNewest(
    List<V2TimMessage> list, {
    required int keepCount,
  }) {
    if (list.length <= keepCount) {
      return ChatMessageWindowTrimResult.unchanged(list);
    }
    final removedOlder = list.length - keepCount;
    return ChatMessageWindowTrimResult(
      list: List<V2TimMessage>.of(list.sublist(0, keepCount)),
      didTrim: true,
      removedNewerCount: 0,
      removedOlderCount: removedOlder,
      trimmedAwayLatest: false,
      trimmedAwayOldestInMemory: true,
    );
  }

  static ChatMessageWindowTrimResult _trimAroundAnchor(
    List<V2TimMessage> list, {
    required int anchorIndex,
    required int targetSize,
    required int keepNewerSide,
    required int keepOlderSide,
  }) {
    final len = list.length;
    final safeAnchor = anchorIndex.clamp(0, len - 1);

    var start = safeAnchor - keepNewerSide;
    if (start < 0) {
      start = 0;
    }
    var end = safeAnchor + keepOlderSide + 1;
    if (end > len) {
      end = len;
    }

    // 向两侧补齐到接近 targetSize。
    var need = targetSize - (end - start);
    if (need > 0) {
      final growStart = start < need ? start : need;
      start -= growStart;
      need -= growStart;
      final roomEnd = len - end;
      final growEnd = roomEnd < need ? roomEnd : need;
      end += growEnd;
      need -= growEnd;
      if (need > 0 && start > 0) {
        final extra = start < need ? start : need;
        start -= extra;
      }
      if (need > 0 && end < len) {
        final room = len - end;
        final extra = room < need ? room : need;
        end += extra;
      }
    }

    // 仍超过 target：夹紧，尽量让锚点落在窗口内。
    if (end - start > targetSize) {
      start = safeAnchor - (targetSize ~/ 2);
      if (start < 0) {
        start = 0;
      }
      end = start + targetSize;
      if (end > len) {
        end = len;
        start = end - targetSize;
        if (start < 0) {
          start = 0;
        }
      }
    }

    if (start <= 0 && end >= len) {
      return ChatMessageWindowTrimResult.unchanged(list);
    }
    if (end - start >= len) {
      return ChatMessageWindowTrimResult.unchanged(list);
    }

    final trimmed = List<V2TimMessage>.of(list.sublist(start, end));
    return ChatMessageWindowTrimResult(
      list: trimmed,
      didTrim: true,
      removedNewerCount: start,
      removedOlderCount: len - end,
      trimmedAwayLatest: start > 0,
      trimmedAwayOldestInMemory: end < len,
    );
  }

  static int _resolveAnchorIndex(
    List<V2TimMessage> list, {
    String? anchorMsgID,
    String? anchorSeq,
    int? anchorIndexHint,
  }) {
    if (anchorIndexHint != null &&
        anchorIndexHint >= 0 &&
        anchorIndexHint < list.length) {
      return anchorIndexHint;
    }
    final msgID = anchorMsgID?.trim();
    if (msgID != null && msgID.isNotEmpty) {
      for (var i = 0; i < list.length; i++) {
        final id = list[i].msgID?.trim();
        if (id != null && id == msgID) {
          return i;
        }
      }
      for (var i = 0; i < list.length; i++) {
        final id = list[i].id?.trim();
        if (id != null && id == msgID) {
          return i;
        }
      }
    }
    final seq = anchorSeq?.trim();
    if (seq != null && seq.isNotEmpty) {
      for (var i = 0; i < list.length; i++) {
        final s = list[i].seq?.trim();
        if (s != null && s == seq) {
          return i;
        }
      }
    }
    // 无锚：取中部，避免误砍用户正在看的旧端或新端。
    return list.length ~/ 2;
  }
}
