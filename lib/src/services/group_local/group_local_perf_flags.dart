/// 群本地库写库节奏（与会话 ConversationPerfFlags 隔离）。
/// 数值只准改本文件。
class GroupLocalPerfFlags {
  GroupLocalPerfFlags._();

  /// `replaceAll` 每块最多 upsert 条数（热同步）。
  static const int syncFullWriteChunkSize = 80;

  /// 块与块之间让出事件循环（热同步）。
  static const Duration syncFullWriteChunkYield = Duration(milliseconds: 40);

  /// 会话列表滚动时块间让出（让手势帧先跑）。
  static const Duration syncFullWriteChunkYieldWhileScrolling = Duration(
    milliseconds: 80,
  );

  /// 冷启动（本地无群或几乎全量 upsert）时每块条数。
  /// `<=0`：整批一次写完。
  static const int coldStartWriteChunkSize = 250;

  /// 冷启动块间让出；`Duration.zero` 表示不让出。
  static const Duration coldStartWriteChunkYield = Duration(milliseconds: 8);

  /// `existing.isEmpty` 或 upsert 占比 ≥ 此阈值时走冷启动节奏。
  static const double coldStartUpsertRatio = 0.85;

  /// `tcp_auth_ok` 后延迟再 syncFull，错开 Snapshot/会话落盘高峰。
  static const Duration tcpAuthSyncFullDelay = Duration(seconds: 2);

  /// `false`：恢复 tcp_auth 立即 syncFull。
  static const bool tcpAuthSyncFullDelayEnabled = true;

  /// 会话列表滚动中推迟非 refresh 的 syncFull 启动。
  static const bool deferSyncFullWhileFeedScrolling = true;

  /// 滚动结束后再开 syncFull 的尾延迟。
  static const Duration syncFullAfterScrollSettle = Duration(milliseconds: 350);

  /// `true`：resume quiet 内推迟非 refresh 的 syncFull（错开会话首屏读窗）。
  static const bool deferSyncFullWhileResumeQuiet = true;

  /// resume quiet 结束后再开 syncFull 的尾延迟。
  static const Duration syncFullAfterResumeQuietSettle = Duration(
    milliseconds: 200,
  );

  /// quiet 结束后，非 refresh 的 post_home / tcp_auth syncFull 再额外延后。
  /// 与 [syncFullAfterResumeQuietSettle] 取较大值。
  static const Duration postHomeSyncFullMinDelayAfterQuiet = Duration(
    seconds: 8,
  );

  /// `true`：本地已完整且 meta 未过期时，非 refresh 跳过全量 HTTP。
  static const bool skipNetworkSyncFullWhenLocalComplete = true;

  /// 低于此本地群数不跳过网络全量（防小库误判）。
  static const int localCompleteMinCount = 100;

  /// ≥ 此本地群数视为大账号（延后 / 预热降级 / 水合步进）。
  /// 须与 [ConversationPerfFlags] 侧大账号语义一致。
  static const int largeAccountGroupThreshold = 500;

  /// 持久化 `last_full_sync` 最大年龄；超时则不可 skip 网络。
  static const Duration fullSyncMaxAge = Duration(hours: 24);

  /// `true`：登录后空闲轻量对账（先比 total，不匹配再全量）。
  static const bool idleReconcileEnabled = true;

  /// 登录后首次空闲对账延迟。
  static const Duration idleReconcileDelay = Duration(seconds: 45);

  /// `true`：syncFull 进行中暂停 HistoryWarm 视口/非主动 press 通道。
  static const bool syncFullExclusiveWithHistoryWarm = true;

  /// `/me/groups` 分页之间让出；`Duration.zero` 不让出。
  static const Duration meGroupsPageYield = Duration(milliseconds: 24);

  /// 「我的群聊」：持久化 index_tag + 轻量骨架 + 缓存，保留 AZ。
  /// `false`：回退旧 TIMUIKitGroup + loadGroupListData 全量路径。
  static const bool myGroupListAzOptimizeEnabled = true;

  /// 同账号、store revision 未变时进页跳过重读骨架。
  static const bool myGroupListMemoryReuseEnabled = true;

  /// 缺 index_tag 行的分块 backfill 大小。
  static const int myGroupListBackfillChunkSize = 200;

  /// 已废弃：搜索不再截断。保留常量以免外部误引用时仍可读到历史含义。
  @Deprecated('Search no longer caps results; limit is unused.')
  static const int myGroupListSearchLimit = 200;
}
