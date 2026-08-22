import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';

/// 自建后端「更早冷历史」拉取请求。
///
/// 游标：`beforeTimeMs` → API `cursor`（更早于该时刻）。
/// 区间：群 `fromSeq`+`toSeq`；单聊 `fromTimeMs`+`toTimeMs`（洞补优先）。
class ArchiveHistoryRequest {
  /// 是否群会话。
  final bool isGroup;

  /// 群会话为 groupID（如 `@TGS#xxx`），单聊为对端 userID。
  final String conversationID;

  /// 当前登录用户 ID，用于判定消息是否本人发送（气泡左右）。
  final String? loginUserID;

  /// 当前列表中最老一条消息的时间戳（毫秒）。为空表示列表为空，取最新一页。
  final int? beforeTimeMs;

  /// 当前列表中最老一条消息的序号（群消息有效）。
  final int? beforeSeq;

  /// 当前列表中最老一条消息的 msgID。
  final String? beforeMsgID;

  /// 区间：单聊起始时间（毫秒，含）。
  final int? fromTimeMs;

  /// 区间：单聊结束时间（毫秒，含）。
  final int? toTimeMs;

  /// 区间：群起始 seq（含）。
  final int? fromSeq;

  /// 区间：群结束 seq（含）。
  final int? toSeq;

  /// 期望拉取条数。
  final int count;

  const ArchiveHistoryRequest({
    required this.isGroup,
    required this.conversationID,
    required this.count,
    this.loginUserID,
    this.beforeTimeMs,
    this.beforeSeq,
    this.beforeMsgID,
    this.fromTimeMs,
    this.toTimeMs,
    this.fromSeq,
    this.toSeq,
  });

  bool get hasTimeRange =>
      fromTimeMs != null && toTimeMs != null && toTimeMs! >= fromTimeMs!;

  bool get hasSeqRange =>
      fromSeq != null && toSeq != null && toSeq! >= fromSeq!;
}

/// 归档兜底返回结果。
class ArchiveHistoryResult {
  /// 拉取到的更早消息（顺序不限，UIKit 会统一去重排序）。
  final List<V2TimMessage> messages;

  /// 后端是否还有更早的消息，可继续上翻。
  final bool hasMore;

  const ArchiveHistoryResult({
    required this.messages,
    required this.hasMore,
  });

  static const ArchiveHistoryResult empty =
      ArchiveHistoryResult(messages: <V2TimMessage>[], hasMore: false);
}

typedef ArchiveOlderHistoryFetcher = Future<ArchiveHistoryResult> Function(
  ArchiveHistoryRequest request,
);

typedef ArchiveHistoryClearSync = Future<void> Function({
  required bool isGroup,
  required String conversationID,
});

typedef ConversationHistoryClearCoordinator = Future<void> Function({
  required bool isGroup,
  required String conversationID,
});

typedef HistoryClearedAtResolver = Future<int> Function(String conversationID);

/// 自建后端历史消息兜底源。
///
/// App 侧在启动时通过 [register] 注入实现（HTTP 拉取 + 转换为 [V2TimMessage]）。
/// 未注入时，UIKit 行为与之前完全一致，不受影响。
class ArchiveHistoryProvider {
  ArchiveHistoryProvider._();

  /// 历史分页统一以腾讯 SDK 本地/云端结果为准；后端归档不再参与消息查询。
  /// 保留 provider 类型和清空标记，避免影响清空会话、宽限期过滤与账号状态。
  static const bool enableOlderArchiveFetch = false;

  static ArchiveOlderHistoryFetcher? _fetcher;
  static ArchiveHistoryClearSync? _clearSync;
  static ConversationHistoryClearCoordinator? _clearCoordinator;
  static HistoryClearedAtResolver? _historyClearedAtResolver;

  static const Duration _archiveSkipGrace = Duration(seconds: 45);

  static final Map<String, int> _archiveSkipUntilMs = <String, int>{};
  static final Set<String> _pendingHistoryClearKeys = <String>{};

  static void register(ArchiveOlderHistoryFetcher? fetcher) {
    _fetcher = fetcher;
  }

  static void registerClearSync(ArchiveHistoryClearSync? clearSync) {
    _clearSync = clearSync;
  }

  static void registerClearCoordinator(
    ConversationHistoryClearCoordinator? coordinator,
  ) {
    _clearCoordinator = coordinator;
  }

  static void registerHistoryClearedAtResolver(
    HistoryClearedAtResolver? resolver,
  ) {
    _historyClearedAtResolver = resolver;
  }

  /// 丢掉清空水位及之前的消息，避免清空后 SDK/归档残留被灌回聊天页。
  static Future<List<V2TimMessage>> filterMessagesAfterHistoryClear({
    required String conversationID,
    required List<V2TimMessage> messages,
  }) async {
    if (messages.isEmpty) {
      return messages;
    }
    final pending = isHistoryClearPending(conversationID);
    final resolver = _historyClearedAtResolver;
    var clearedAt = 0;
    if (resolver != null) {
      clearedAt = await resolver(conversationID);
    }
    if (clearedAt <= 0 && pending) {
      // 清空进行中且水位尚未落库：按「此刻」过滤，避免旧消息回灌。
      clearedAt = DateTime.now().toUtc().millisecondsSinceEpoch;
    }
    if (clearedAt <= 0) {
      return messages;
    }
    return messages.where((message) {
      final ts = message.timestamp ?? 0;
      if (ts <= 0) {
        return false;
      }
      final ms = ts < 1000000000000 ? ts * 1000 : ts;
      return ms > clearedAt;
    }).toList(growable: false);
  }

  /// 会话是否处于清空宽限期（进行中或刚清空不久）。
  static bool isInHistoryClearGrace(String conversationID) {
    return isHistoryClearPending(conversationID) ||
        shouldSkipArchiveFallback(conversationID);
  }

  /// 会话清空水位（毫秒）。未注册或无水位时返回 0。
  static Future<int> historyClearedAtMs(String conversationID) async {
    final resolver = _historyClearedAtResolver;
    if (resolver == null) {
      return 0;
    }
    return resolver(conversationID);
  }

  /// 历史查询已下线。保留 getter 让 UIKit 的旧分支自然短路，避免改动
  /// SDK 分页状态机；清空水位同步仍通过本 Provider 独立工作。
  static bool get isAvailable => false;

  static bool get isClearSyncAvailable => _clearSync != null;

  static String normalizeConversationKey(String conversationID) {
    final id = conversationID.trim();
    if (id.startsWith('c2c_')) {
      return id.substring(4);
    }
    if (id.startsWith('group_')) {
      return id.substring(6);
    }
    return id;
  }

  static void markArchiveFallbackSkipped(String conversationID) {
    final key = normalizeConversationKey(conversationID);
    if (key.isEmpty) {
      return;
    }
    _archiveSkipUntilMs[key] = DateTime.now().toUtc().millisecondsSinceEpoch +
        _archiveSkipGrace.inMilliseconds;
  }

  /// 清除「跳过归档」标记（Web 进页重拉冷历史时用；清空会话后勿调用）。
  static void clearArchiveFallbackSkipped(String conversationID) {
    final key = normalizeConversationKey(conversationID);
    if (key.isEmpty) {
      return;
    }
    _archiveSkipUntilMs.remove(key);
  }

  static bool shouldSkipArchiveFallback(String conversationID) {
    final key = normalizeConversationKey(conversationID);
    if (key.isEmpty) {
      return false;
    }
    final until = _archiveSkipUntilMs[key];
    if (until == null) {
      return false;
    }
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (now >= until) {
      _archiveSkipUntilMs.remove(key);
      return false;
    }
    return true;
  }

  /// IM 清空 API 调用前标记，防止 SDK 同步触发的 onConversationDeleted 误删本地会话。
  static void markHistoryClearPending(String conversationID) {
    final key = normalizeConversationKey(conversationID);
    if (key.isEmpty) {
      return;
    }
    _pendingHistoryClearKeys.add(key);
  }

  static void clearHistoryClearPending(String conversationID) {
    _pendingHistoryClearKeys.remove(normalizeConversationKey(conversationID));
  }

  static bool isHistoryClearPending(String conversationID) {
    final key = normalizeConversationKey(conversationID);
    return key.isNotEmpty && _pendingHistoryClearKeys.contains(key);
  }

  static Future<ArchiveHistoryResult> fetchOlder(
    ArchiveHistoryRequest request,
  ) async {
    // 最终安全边界：即使调用方漏掉 isAvailable 判断，也不得访问后端。
    if (!enableOlderArchiveFetch) {
      return ArchiveHistoryResult.empty;
    }
    final fetcher = _fetcher;
    if (fetcher == null) {
      return ArchiveHistoryResult.empty;
    }
    return fetcher(request);
  }

  /// IM 本地/云端清空成功后，同步后端归档水位（`DELETE /me/messages/*`）。
  static Future<void> syncClearHistory({
    required bool isGroup,
    required String conversationID,
  }) async {
    final sync = _clearSync;
    if (sync == null) {
      return;
    }
    await sync(isGroup: isGroup, conversationID: conversationID);
  }

  /// IM 清空成功后：跳过后端归档兜底 → DELETE 归档 → App 侧清预览/刷新。
  static Future<void> completeHistoryClear({
    required bool isGroup,
    required String conversationID,
  }) async {
    markArchiveFallbackSkipped(conversationID);
    final coordinator = _clearCoordinator;
    if (coordinator != null) {
      await coordinator(isGroup: isGroup, conversationID: conversationID);
    }
    try {
      await syncClearHistory(
        isGroup: isGroup,
        conversationID: conversationID,
      );
    } finally {
      clearHistoryClearPending(conversationID);
    }
  }
}
