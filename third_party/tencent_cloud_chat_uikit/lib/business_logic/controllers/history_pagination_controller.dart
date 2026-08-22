import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';

enum LoadDirection { previous, latest }

/// Per-conversation history pagination + archive fallback flags.
///
/// Owned by [TUIChatSeparateViewModel]. Load loops live in
/// `HistoryPaginationLoadRunner` (same library as the view model); the runner is
/// bound here so the public API is `controller.loadChatRecord(...)`.
class HistoryPaginationController {
  bool haveMoreData = false;
  bool haveMoreLatestData = false;
  bool previousPaginationInFlight = false;

  /// 自建后端归档「更早冷历史」是否已拉到底（避免拉空后反复请求同一段）。
  bool archiveOlderExhausted = false;

  /// 是否已进入归档兜底分页（此后列表最老一条来自归档，不能再作为 SDK 锚点）。
  bool archiveOlderActive = false;

  /// 首屏 SDK 为空且未接受归档为「当前尾巴」时：禁止上拉再用归档挖旧消息。
  bool suppressArchiveUntilSdkHistory = false;

  final Set<String> historyLoadingKeys = <String>{};

  bool get isLoadingChatHistory => historyLoadingKeys.isNotEmpty;

  void resetForConversationInit() {
    archiveOlderExhausted = false;
    archiveOlderActive = false;
    suppressArchiveUntilSdkHistory = false;
  }

  Future<bool> Function({
    HistoryMsgGetTypeEnum? getType,
    int lastMsgSeq,
    required int count,
    String? lastMsgID,
    LoadDirection direction,
    bool forceReloadNewest,
  })? _loadChatRecordBound;

  void bindLoadChatRecord(
    Future<bool> Function({
      HistoryMsgGetTypeEnum? getType,
      int lastMsgSeq,
      required int count,
      String? lastMsgID,
      LoadDirection direction,
      bool forceReloadNewest,
    }) runner,
  ) {
    _loadChatRecordBound = runner;
  }

  Future<bool> loadChatRecord({
    HistoryMsgGetTypeEnum? getType,
    int lastMsgSeq = -1,
    required int count,
    String? lastMsgID,
    LoadDirection direction = LoadDirection.previous,
    bool forceReloadNewest = false,
  }) {
    final bound = _loadChatRecordBound;
    if (bound == null) {
      throw StateError('HistoryPaginationController.loadChatRecord not bound');
    }
    return bound(
      getType: getType,
      lastMsgSeq: lastMsgSeq,
      count: count,
      lastMsgID: lastMsgID,
      direction: direction,
      forceReloadNewest: forceReloadNewest,
    );
  }
}
