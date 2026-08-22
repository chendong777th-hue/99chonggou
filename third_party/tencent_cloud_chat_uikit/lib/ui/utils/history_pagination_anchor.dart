import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_uikit/ui/constants/history_message_constant.dart';

/// Helpers for choosing SDK-compatible history pagination anchors.
class HistoryPaginationAnchor {
  HistoryPaginationAnchor._();

  static final RegExp _sdkMsgIdPattern = RegExp(r'^\d+-\d+-');

  static bool isLocalInjectedMessage(V2TimMessage message) {
    final raw = message.localCustomData?.trim() ?? '';
    if (raw.isEmpty) {
      return _isSyntheticMsgId(message.msgID?.trim() ?? '');
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map && decoded['localGroupTips'] == true) {
        return true;
      }
    } catch (_) {}
    return _isSyntheticMsgId(message.msgID?.trim() ?? '');
  }

  static bool _isSyntheticMsgId(String msgID) {
    if (msgID.isEmpty) {
      return false;
    }
    return msgID.startsWith('ce_') ||
        msgID.startsWith('local_gt_') ||
        msgID.startsWith('local_');
  }

  static bool isArchiveHistoryMessage(V2TimMessage message) {
    final raw = message.localCustomData?.trim() ?? '';
    if (raw.contains('archiveHistory')) {
      return true;
    }
    final msgID = message.msgID?.trim() ?? '';
    // 归档合成 ID：`@TGS#xxx:seq` / `@TGS#_@TGS#xxx:seq`
    if (msgID.contains(':') && msgID.toUpperCase().contains('TGS#')) {
      return !_sdkMsgIdPattern.hasMatch(msgID);
    }
    return false;
  }

  static int messageSeq(V2TimMessage message) {
    return int.tryParse(message.seq?.toString() ?? '') ?? -1;
  }

  /// 首屏暖窗若几乎全是归档，且比参考时间（会话 lastMessage / 本地 tip）旧一大截，
  /// 说明 SDK 未拉到时被旧归档顶替——不能再 keep warm。
  static bool isStaleArchiveDominatedWindow(
    Iterable<V2TimMessage>? messages, {
    int? referenceTimestampSec,
    int staleGapSec = 120,
  }) {
    if (messages == null) {
      return false;
    }
    final list = messages.toList(growable: false);
    if (list.isEmpty) {
      return false;
    }
    var archiveCount = 0;
    var newestArchiveTs = 0;
    var newestNonLocalTs = 0;
    var newestAnyTs = 0;
    for (final message in list) {
      final ts = message.timestamp ?? 0;
      if (ts > newestAnyTs) {
        newestAnyTs = ts;
      }
      if (isLocalInjectedMessage(message)) {
        continue;
      }
      if (ts > newestNonLocalTs) {
        newestNonLocalTs = ts;
      }
      if (isArchiveHistoryMessage(message)) {
        archiveCount++;
        if (ts > newestArchiveTs) {
          newestArchiveTs = ts;
        }
      }
    }
    if (archiveCount == 0) {
      return false;
    }
    // 非本地消息里归档占多数才判定。
    final nonLocal = list.where((m) => !isLocalInjectedMessage(m)).length;
    if (nonLocal > 0 && archiveCount * 2 < nonLocal) {
      return false;
    }
    final ref = referenceTimestampSec ?? newestAnyTs;
    if (ref <= 0 || newestArchiveTs <= 0) {
      return false;
    }
    // 过期与否看「窗口里最新的真实消息」（非本地注入），不能拿最新归档比：
    // 正常分页出的窗口就是「顶部新 SDK 消息 + 下面更早归档」，归档必然比
    // 参考时间旧。只有连窗口顶部都比参考时间旧一大截，才是「旧归档顶替了
    // 新窗口」的过期窗（如 SDK 空拉时被旧归档整窗灌入），需要剥离。
    // 否则合法的归档上拉历史会被 hydrate 误剥（62→3 的进页闪变）。
    final windowFreshTs =
        newestNonLocalTs > newestArchiveTs ? newestNonLocalTs : newestArchiveTs;
    return ref > windowFreshTs + staleGapSec;
  }

  /// 剥掉归档消息，仅保留本地 tip / 实时消息（SDK 空时避免误展旧归档）。
  static List<V2TimMessage> withoutArchiveHistory(
    Iterable<V2TimMessage>? messages,
  ) {
    if (messages == null) {
      return const <V2TimMessage>[];
    }
    return messages
        .where((m) => !isArchiveHistoryMessage(m))
        .toList(growable: false);
  }

  /// 已补过旧历史的内存窗，不能再被首屏 peek（通常 20 条）整表冲掉。
  ///
  /// 迟到的 hydrate / roaming reconcile / bootstrap 会再拉最新一页并
  /// `mergePeekWindowWithLiveMemory`，把 120 条已填窗口盖成 20。
  static bool shouldPreserveFilledHistoryOverPeek({
    required int existingCount,
    required int fetchedCount,
    int firstScreenCount = HistoryMessageDartConstant.initialOpenFetchCount,
  }) {
    if (existingCount <= 0 || fetchedCount <= 0) {
      return false;
    }
    if (existingCount <= firstScreenCount * 2) {
      return false;
    }
    return existingCount > fetchedCount;
  }

  /// C2C 全程 SDK：内存已长过首屏后，任何 ≤ 首屏的 peek 都不得整表回刷。
  ///
  /// 群聊仍用 [shouldPreserveFilledHistoryOverPeek]（允许用干净 20 条
  /// 替换被本地/归档污染的 24/36 首屏）。C2C 首屏本身就是云端 20 条，
  /// `<= firstScreen * 2` 例外会把 38 条已填窗盖回 20。
  static bool shouldRejectC2cPeekRestamp({
    required int existingCount,
    required int incomingCount,
    int firstScreenCount = HistoryMessageDartConstant.initialOpenFetchCount,
  }) {
    if (existingCount <= firstScreenCount || incomingCount <= 0) {
      return false;
    }
    return incomingCount <= firstScreenCount && existingCount > incomingCount;
  }

  /// Only real IM messages can anchor SDK getHistoryMessageList pagination.
  static bool canUseForSdkPagination(V2TimMessage message) {
    if (isLocalInjectedMessage(message)) {
      return false;
    }
    final msgID = message.msgID?.trim() ?? '';
    // 自建归档合成 ID（如 `@TGS#:31`）不能拿去问 SDK。
    if (msgID.contains(':') && !_sdkMsgIdPattern.hasMatch(msgID)) {
      return false;
    }
    final seq = messageSeq(message);
    if (seq > 0) {
      return true;
    }
    if (msgID.isEmpty) {
      return false;
    }
    return _sdkMsgIdPattern.hasMatch(msgID);
  }

  /// messageListMap 最新在前：找时间最老且可用于 SDK 翻页的一条。
  static V2TimMessage? oldestSdkPaginationAnchor(
    Iterable<V2TimMessage>? messages,
  ) {
    if (messages == null) {
      return null;
    }
    V2TimMessage? picked;
    var pickedTs = 1 << 62;
    for (final message in messages) {
      if (!canUseForSdkPagination(message)) {
        continue;
      }
      final ts = message.timestamp ?? 0;
      final seq = messageSeq(message);
      final pickedSeq = picked == null ? -1 : messageSeq(picked);
      final older = picked == null ||
          ts < pickedTs ||
          (ts == pickedTs && seq > 0 && (pickedSeq < 0 || seq < pickedSeq));
      if (older) {
        picked = message;
        pickedTs = ts;
      }
    }
    return picked;
  }

  /// SDK `OLDER` 页官方顺序：越新越靠前，最后一条是下一页 `lastMsg`。
  /// 不要按时间戳重排后再取，否则和官方游标不一致。
  static V2TimMessage? tailOfCloudOlderPage(List<V2TimMessage>? page) {
    if (page == null || page.isEmpty) {
      return null;
    }
    for (var i = page.length - 1; i >= 0; i--) {
      final message = page[i];
      if (canUseForSdkPagination(message) &&
          !isArchiveHistoryMessage(message)) {
        return message;
      }
    }
    return null;
  }

  /// 官方续拉游标：优先上一页 SDK 尾巴；否则用最新一屏的最后一条。
  ///
  /// 禁止在整窗里重算「时间最老一条」——中间一旦有洞，游标会跳到洞后，
  /// 再拉只会更早，中间永远补不上。C2C / 群聊同一套。
  static V2TimMessage? officialOlderCursor({
    required List<V2TimMessage> newestFirstWindow,
    V2TimMessage? lastSdkPageTail,
    int firstScreenCount = HistoryMessageDartConstant.initialOpenFetchCount,
  }) {
    return c2cOfficialOlderCursor(
      newestFirstWindow: newestFirstWindow,
      lastSdkPageTail: lastSdkPageTail,
      firstScreenCount: firstScreenCount,
    );
  }

  /// 兼容旧名，等同 [officialOlderCursor]。
  static V2TimMessage? c2cOfficialOlderCursor({
    required List<V2TimMessage> newestFirstWindow,
    V2TimMessage? lastSdkPageTail,
    int firstScreenCount = HistoryMessageDartConstant.initialOpenFetchCount,
  }) {
    if (lastSdkPageTail != null &&
        canUseForSdkPagination(lastSdkPageTail) &&
        !isArchiveHistoryMessage(lastSdkPageTail)) {
      return lastSdkPageTail;
    }
    if (newestFirstWindow.isEmpty || firstScreenCount <= 0) {
      return null;
    }
    final end = newestFirstWindow.length < firstScreenCount
        ? newestFirstWindow.length
        : firstScreenCount;
    for (var i = end - 1; i >= 0; i--) {
      final message = newestFirstWindow[i];
      if (canUseForSdkPagination(message) &&
          !isArchiveHistoryMessage(message)) {
        return message;
      }
    }
    return null;
  }

  /// C2C 补旧锚点：只要 IM SDK 消息，不要归档合成行。
  /// 用归档当 lastMsg 会把下一页问到自建后端时间线，和 IM 对不上。
  static V2TimMessage? oldestImSdkPaginationAnchor(
    Iterable<V2TimMessage>? messages,
  ) {
    if (messages == null) {
      return null;
    }
    V2TimMessage? picked;
    var pickedTs = 1 << 62;
    for (final message in messages) {
      if (!canUseForSdkPagination(message) || isArchiveHistoryMessage(message)) {
        continue;
      }
      final ts = message.timestamp ?? 0;
      final seq = messageSeq(message);
      final pickedSeq = picked == null ? -1 : messageSeq(picked);
      final older = picked == null ||
          ts < pickedTs ||
          (ts == pickedTs && seq > 0 && (pickedSeq < 0 || seq < pickedSeq));
      if (older) {
        picked = message;
        pickedTs = ts;
      }
    }
    return picked;
  }

  /// 归档游标：跳过本地注入（ce_ / local_gt_），取真正最老一条。
  static V2TimMessage? oldestArchiveCursorAnchor(
    Iterable<V2TimMessage>? messages,
  ) {
    if (messages == null) {
      return null;
    }
    V2TimMessage? picked;
    var pickedTs = 1 << 62;
    for (final message in messages) {
      if (isLocalInjectedMessage(message)) {
        continue;
      }
      final ts = message.timestamp ?? 0;
      if (ts <= 0) {
        continue;
      }
      if (picked == null || ts < pickedTs) {
        picked = message;
        pickedTs = ts;
      }
    }
    return picked ?? oldestSdkPaginationAnchor(messages);
  }
}
