import 'package:flutter/foundation.dart';
import 'package:tencent_cloud_chat_demo/src/services/android_performance_profile.dart';

/// 会话同步写库节奏开关（Phase 1：缓解 SDK 连续拉页写库卡顿/发烫）。
/// 热窗优先：首屏 `loadUiWindow` 为按 scope 限量快照（单聊/群聊各 LIMIT），非 owner 全表。
/// **禁止**挂机 idle 为「对齐腾讯全集」无限翻页；其余会话触底/增量再拉。
/// UI 列表：硬顶默认关；滑动窗默认开（内存裁切，触顶/触底再从库补页）。
/// 返回卡顿靠「禁止整窗 ByIds」+ 滚动中延后 UI 通知。
/// 数值只准改本文件。
class ConversationPerfFlags {
  ConversationPerfFlags._();

  /// `true`：`reset`/`force` 只重置游标，前台限页 + 后台 drain；`false`：恢复旧「reset 可一口气拉全量」。
  static bool pacedSdkPersist = true;

  /// 登录首屏后在 idle/background 按游标分批续翻，补齐大账号会话。
  /// 每轮仍只拉一页并让出主线程，避免阻塞首屏。
  // 后台分页会在 UI isolate 上持续执行 SDK 解码和 SQLite mirror 写入。
  // 高频交互期间默认关闭，触底/搜索仍按需分页；需要补齐时由业务显式开启。
  static const bool idleBackgroundDrainEnabled = false;

  /// 误开 [idleBackgroundDrainEnabled] 时的每会话启动页预算；用尽不再 resume。
  static const int idleDrainSessionPageBudget = 64;

  /// 回前台 coalesce 单帧最多 flush 条数，余量 post-frame 续刷。
  static const int resumeForegroundCoalesceBatchCap = 40;

  /// `true`：从聊天返回后的 soft reload 只 patch 刚离开会话，禁止整窗 `conversationsByIds`。
  static const bool postPopLightReloadEnabled = true;

  /// soft / merge-preserve 单次 `conversationsByIds` 条数帽。
  /// `<=0`：不按条数截断（生产路径应禁止整窗 ByIds，不依赖本帽）。
  static const int softReloadByIdsMax = 0;

  /// 前台最多连续拉/写页数（页大小见 sync 服务 `_defaultPageSize`）。
  static const int bootstrapForegroundPages = 2;

  /// 后台 drain 页与页之间让出主线程。
  static const Duration backgroundPageYield = Duration(milliseconds: 80);

  /// drain 默认不刷新 UI（0）；仅窗口 patch 路径单独处理。
  static const int backgroundUiRefreshEveryPages = 0;

  /// 前台限页结束后多久才允许开始 idle drain。
  static const Duration idleDrainStartDelay = Duration(seconds: 3);

  /// 空库 IM Snapshot 成功后，再推迟多久才开腾讯分页 idle drain（单次 Timer，不叠加 [idleDrainStartDelay]）。
  static const Duration snapshotDrainStartDelay = Duration(seconds: 8);

  /// 登录快照只负责优先补齐最近单聊；群列表和完整游标继续由 SDK 同步。
  static const int snapshotPriorityC2cLimit = 20;

  /// Snapshot 后端分路参数的契约下限；响应中的群和 preload 不提交到聊天窗。
  static const int snapshotRequestGroupFloor = 1;
  static const int snapshotRequestMessageFloor = 30;

  /// `false`：登录不走后端 IM Snapshot，首屏直接用本地会话库，再按需 SDK 分页同步。
  /// `true`：恢复「有库也 Snapshot 暖窗」方案 B。
  static const bool attemptImSnapshotOnLoginBootstrap = false;

  /// UI 列表总硬顶。`<=0` 表示无硬顶（不因长度拒收 append）。
  static const int uiWindowHardCap = 0;

  static bool get uiWindowHardCapEnabled => uiWindowHardCap > 0;

  /// 滑动窗口裁切。`false`：只追加不裁顶（无上限列表，用久了更卡）。
  /// 注意：即使为 `true`，[uiAppendOlderGrowsWindow] 开启时触底 append 仍只增不裁。
  static const bool uiSlidingWindowEnabled = true;

  static bool get uiSlidingWindowActive => uiSlidingWindowEnabled;

  /// 滑动窗 / patch 锚点裁切预算。触底翻页在 [uiAppendOlderGrowsWindow] 下不受此限。
  static const int uiSlidingWindowBudget = 120;

  /// `true`：下滑加载更旧会话时先抬高该类型显示数量（可超过 [uiSlidingWindowBudget]）。
  /// 超过 [uiAppendOlderMaxPerType] 后只裁**当前翻页类型**，对侧类型保留，
  /// 避免滑群把单聊 tab 挤空（单聊往往更旧、排在列表后段）。
  static const bool uiAppendOlderGrowsWindow = true;

  /// 触底扩窗：每个会话类型（单聊/群）各自的软上限。
  /// 总窗可达约 2×本值，但仍远小于无上限的数千条，避免主线程 hang。
  static const int uiAppendOlderMaxPerType = 240;

  /// 下滑续载的紧急上限（按类型）。
  /// 软顶内**不头裁**，让 ListView 可滚高度随条数增长（体感「继续往下加载」）；
  /// 仅超过本值才滑动裁切，避免一次滑进全库。`<=0` 时回退为立刻按软顶裁。
  static const int uiAppendOlderEmergencyMaxPerType =
      uiAppendOlderMaxPerType * 2;

  /// @Deprecated 兼容旧名；请用 [uiAppendOlderMaxPerType]。
  static const int uiAppendOlderMaxWindow = uiAppendOlderMaxPerType;

  /// 方案 C：回顶时从库序 offset=0 拉回的连续前缀长度（含置顶排序）。
  /// 也会作为「近顶」判断时的热头参考；软裁本身按视口连续切片，不再拆热头+旧尾。
  static const int uiAppendOlderHotHeadReserve = 40;

  /// 裁切时优先保留的置顶条数（仅 budget>0 且滑动开启时有意义）。
  /// 软裁路径会保留**全部**置顶；本值只约束 budget 锚点裁切。
  static const int uiSlidingWindowPinnedReserve = 16;

  /// 锚点裁切时「未读优先」条数上限。大账号群几乎全未读时若无上限，
  /// 会占满预算，触底 append 的更旧页进不了窗（noop），并挤掉已读单聊。
  /// `<=0`：关闭未读优先。
  static const int uiSlidingWindowUnreadReserve = 24;

  /// `true`：`upsertBatch` 入口短延迟合并 + 写串行，压碎片并发 txn。
  static const bool upsertWriteCoalesceEnabled = true;

  /// upsert 写合并窗口。
  static const Duration upsertWriteCoalesceDelay = Duration(milliseconds: 100);

  /// 列表滚动 / 进出聊天时拉长合并，错开手势帧。
  static const Duration upsertWriteCoalesceDelayBusy = Duration(
    milliseconds: 180,
  );

  /// 单个 SQLite 事务最多处理的会话数。只拆事务，不丢数据、不限制会话总数。
  static const int upsertTransactionChunkSize = 200;

  /// 连续流量下的最长等待，避免 quiet window 被不断重置而饥饿。
  static const Duration upsertWriteCoalesceMaxDelay = Duration(
    milliseconds: 250,
  );

  /// 忙碌态最长等待（滚动/聊天切换/post-pop）。
  static const Duration upsertWriteCoalesceMaxDelayBusy = Duration(
    milliseconds: 400,
  );

  /// ViewModel → 本地库 persist 去重窗口（闲时）。
  static const Duration persistDedupDelay = Duration(milliseconds: 60);

  /// 忙碌态 persist 去重窗口，减少「写库刚完又刷列表」。
  static const Duration persistDedupDelayBusy = Duration(milliseconds: 200);

  /// SDK `onConversationChanged` / `onNewConversation` 热路径 persist 去重（闲时）。
  static const Duration persistDedupDelayConversationListener =
      Duration(milliseconds: 32);

  /// SDK 会话监听热路径 busy 去重。
  static const Duration persistDedupDelayConversationListenerBusy =
      Duration(milliseconds: 64);

  /// 分页同步中预览 patch 最长排队；超时强制落地（仍不改 unread）。
  static const Duration pendingPreviewPatchMaxWait = Duration(
    milliseconds: 1200,
  );

  /// `true`：打 msg→callback→persist→ui 三段耗时探针（`[ConvPerfGate] realtime_latency`）。
  static const bool conversationRealtimeLatencyLogEnabled = false;

  /// `true`：无 `[` 的预览走纯 Text（滚动性能）；含内置表情 token 时仍走 ExtendedText。
  static const bool conversationListPlainPreviewText = true;

  /// 滚动中写库完成后：合并排队，停滑后再刷新列表 UI。
  /// 会话列表手感优先于毫秒级实时重排，避免高速滑动时被消息回调打断。
  static const bool deferUiNotifyWhileFeedScrolling = true;

  /// Chat 页打开时：推迟会话列表 Feed 的 `notifyListeners`（角标仍走 UnreadAggregate）。
  /// `false`：聊中也刷离屏 Feed（列表实时性优先）。
  static const bool deferUiNotifyWhileActiveChat = true;

  /// Chat 页内列表 UI notify 最长推迟；到期仍 flush 一次，防永不回列表饿死。
  static const Duration activeChatUiNotifyMaxDefer = Duration(
    milliseconds: 1200,
  );

  /// `true`：聊中 maxDefer 到期仍整表 `notifyListeners`（旧行为）。
  /// `false`：只保持 pending + 攒脏 ID，禁止聊中整表 flush。
  static const bool activeChatMaxDeferFullFlushEnabled = false;

  /// `true`：离开聊天不整表 reload，只 patch 刚离开会话；挂起的 Feed notify 仍会 flush。
  static const bool chatLeavePatchLeftOnlyEnabled = true;

  /// `true`：deactivate/dispose 对同一 leave 只交还一次。
  static const bool chatLeaveFlushDedupeEnabled = true;

  /// `true`：进聊期间脏会话 ID 延后分批补齐（非整表 notify）。
  static const bool activeChatDirtyCatchUpEnabled = true;

  /// 离开聊天后脏补齐延迟（未在滑时）。
  static const Duration postChatLeaveCatchUpDelay = Duration(
    milliseconds: 1200,
  );

  /// 脏补齐每批会话数。
  static const int activeChatDirtyCatchUpBatchSize = 20;

  /// `true`：两边 Conversation 的 folder_unread 单飞。
  /// 实现须用「单 bit pending + 结束后 microtask 补一次」，
  /// 禁止 per-join `whenComplete→schedule`（会同步风暴冻 UI）。
  static const bool folderUnreadSingleFlightEnabled = true;

  /// `true`：每个 in-flight 世代最多打 1 条 `folder_unread_single_flight_join`。
  static const bool folderUnreadSingleFlightJoinLogOncePerFlight = true;

  /// `true`：离开聊天不立刻跑 folder_unread，跟 catch-up/停滑。
  static const bool folderUnreadDeferOnChatLeave = true;

  /// `true`：离开聊天不立刻续 incomplete HistoryWarm。
  static const bool historyWarmDeferResumeAfterChatLeave = true;

  /// 离开聊天后 HistoryWarm 抑制时长。
  static const Duration postChatLeaveWarmSuppress = Duration(seconds: 8);

  /// `true`：会话行 `onTapDown` 即 press 暖历史（易与滑动冲突）。
  /// `false`：不在 onTapDown 暖（进聊路径仍可暖）。
  static const bool pressWarmOnTapDownEnabled = false;

  /// `true`：群聊行允许按下目标会话时 LOCAL warm 这一条。
  /// 群聊不做批量 press，不走 CLOUD，只给用户明确按下/点击的目标让路。
  static const bool groupPressWarmOnTapDownEnabled = true;

  /// `true`：`conversationsByIds` 日志带 caller。
  static const bool conversationsByIdsCallerLogEnabled = false;

  /// `true`：Chat 打开时仍 apply 内存窗（角标 delta）；仅 defer Feed notify。
  /// `false`：Chat 打开时连 persist UI apply 一并挂起（更省，角标靠 scheduleRefresh）。
  static const bool persistUiApplyWhileActiveChat = true;

  /// `false`：滚动中写库后不 apply / 不排会触发 loadUiWindow 的 soft；停滑 flush。
  /// `true`：滑动中也立刻 apply（列表实时性优先，但会更容易打断滚动帧）。
  static const bool persistUiApplyWhileFeedScrolling = false;

  /// `false`：resume quiet 窗内写库后不立刻灌 UI（可 schedule 角标）。
  static const bool persistUiApplyInResumeQuiet = false;

  /// `true`：`loadUiWindow` 单飞，并发调用合并到同一 Future。
  static const bool loadUiWindowSingleFlight = true;

  /// `true`：`loadUiWindow` 进行中若再有请求，结束后再跑一轮脏读，
  /// 所有等待方拿到最终结果（压冷启连环 begin）。
  static const bool loadUiWindowCoalesceWhileBusy = true;

  /// `true`：`ensurePinnedPresentInWindow` 仅 missing 时 ByIds，
  /// 且等待 upsert 写队列空闲后再读，避免与写库互顶。
  static const bool ensurePinnedWaitsUpsertIdle = true;

  /// ensurePinned 等待 upsert 空闲的上限；超时仍读，防饿死。
  static const Duration ensurePinnedUpsertIdleMaxWait = Duration(
    milliseconds: 800,
  );

  /// `true`：回顶热前缀两阶段（先 [uiAppendOlderHotHeadReserve]，再补满
  /// [uiAppendOlderMaxPerType]），减轻一次拉 240 的顿挫。
  static const bool restoreHotHeadTwoPhaseEnabled = true;

  /// `true`：触底/近顶翻页的 UI notify 走短窗合并，压 structure 风暴。
  static const bool appendUiNotifyCoalesceEnabled = true;

  /// append/prepend notify 合并窗口（与既有 48ms coalesce 对齐）。
  static const Duration appendUiNotifyCoalesceDelay = Duration(
    milliseconds: 48,
  );

  /// `false`：置顶/取消置顶立刻重排并 `notify`（实时优先）。
  /// `true`：先静默改 pin，再等 [ConversationListNotifier.pinReorderDelay] 重排（防双闪旧行为）。
  static const bool pinDeferredReorderEnabled = false;

  /// `true`：置顶点击后先改本地 UI，再等腾讯 `pinConversation`；失败回滚。
  static const bool pinOptimisticUiEnabled = true;

  /// `true`：免打扰点击后先改本地 UI，再等 SDK；失败回滚。
  static const bool recvOptOptimisticUiEnabled = true;

  /// 本地刚改免打扰后，阻止 SDK/落库旧 `recvOpt` 盖回的保护窗。
  static const Duration recvOptLocalGrace = Duration(seconds: 2);

  /// 停滑后再跑 folder_unread 的 settle；`<=0`：停滑立刻跑。
  static const Duration folderUnreadSettleAfterScroll = Duration(
    milliseconds: 400,
  );

  /// `true`：PostHome / 群 syncFull 避开 resume quiet 窗，错开首屏读窗。
  static const bool postHomeWaitResumeQuiet = true;

  /// `true`：UIKit `onViewModelPageLoaded` 写库后走 paced/defer，不每页重灌。
  static const bool viewModelPageUiApplyDeferred = true;

  /// `true`：resume quiet 内禁止 forceFull reload / folder unread 扫库 / history warm。
  static const bool resumeQuietBlocksHeavyUiReload = true;

  /// 覆盖 [ResumeForegroundPolicy.conversationHoldDuration]；`<=0` 用政策默认。
  static const Duration resumeQuietDuration = Duration(seconds: 3);

  /// `true`：滚动中暂停 SDK 续翻页（每页拉取前检查；maxWait 后强制继续防饿死）。
  /// 触底 `sync_next_page` / `resume_after_scroll` 不受此开关阻塞（见 sync 服务）。
  static const bool sdkPageFetchPauseWhileScrolling = true;

  /// SDK 翻页避让滚动上限。
  static const Duration sdkPageScrollPauseMaxWait =
      Duration(milliseconds: 1500);

  /// `true`：列表滚动中暂缓 ViewModel 分页写库，停滑再落盘（减主线程 SQLite 争用）。
  static const bool deferViewModelPersistWhileFeedScrolling = true;

  /// 停滑后落地 pending UI apply 的 settle 窗口，压掉 scroll_end 抖动连 flush。
  /// `<=0`：立即 flush。
  static const Duration uiApplyFlushSettleDelay = Duration(milliseconds: 400);

  /// 滑动中 UI `notifyListeners` 最长推迟；到期即使仍在滑也强制 flush。
  static const Duration feedScrollUiNotifyMaxDefer =
      Duration(milliseconds: 1200);

  /// PostHome 下一 stage 开始前若列表在滚则等待。
  static const bool postHomePauseWhileFeedScrolling = true;

  /// PostHome 避让滚动的上限，超时后继续 stage（防队列饿死）。
  static const Duration postHomeScrollPauseMaxWait =
      Duration(milliseconds: 800);

  /// 进聊天页时暂停好友/群/贴纸等重 stage，避免与首屏历史抢 IO。
  static const bool postHomePauseWhileChatOpen = true;

  /// 聊天页避让上限；超时后继续补全，防队列饿死。
  static const Duration postHomeChatPauseMaxWait = Duration(seconds: 6);

  /// 群 membership revision 合并窗口。
  static const Duration joinedGroupsRevisionCoalesce =
      Duration(milliseconds: 200);

  /// 会话列表视口锚点上报节流（翻页探测不走此节流）。
  static const Duration feedViewportAnchorThrottle =
      Duration(milliseconds: 120);

  /// 置顶行底色动画时长（原 180ms）。
  static const Duration conversationRowPinAnimDuration =
      Duration(milliseconds: 80);

  /// `true`：会话行侧滑 ActionPane 懒构建。
  static const bool lazyConversationSlidableActions = true;

  /// `true`：用轻量字段指纹替代 `sha256(utf8.encode(整包 raw_json))`，
  /// 并允许在 unchanged 快路径上跳过 `jsonEncode`。
  /// `false`：恢复旧「先整包 encode 再比指纹」。
  static const bool useLightweightFingerprint = true;

  /// 首屏快照：最新单聊条数（`conv_type=1`）。与 [uiSnapshotGroupLimit] 均 `>0` 时启用限量装载。
  static const int uiSnapshotC2cLimit = 40;

  /// 首屏快照：最新群聊条数（`conv_type=2`）。
  static const int uiSnapshotGroupLimit = 40;

  static bool get uiSnapshotEnabled =>
      uiSnapshotC2cLimit > 0 && uiSnapshotGroupLimit > 0;

  /// 下滑从库追加。
  static const int uiScrollPageSize = 40;

  /// 短列表自动填视口最多页数（仅 conversation 侧有界调用；禁止 itemBuilder 触发）。
  /// 与 SDK sync 解耦：本地 append 不受 isSyncing 挡住；填不满屏时连补直到可滚或无增长。
  static const int uiViewportFillMaxPages = 3;

  /// `false`：paced sync/drain 不得无限扩「冷」会话进 UI 窗（置顶/未读仍热准入；
  /// 未达 [uiSnapshotC2cLimit]/[uiSnapshotGroupLimit] 类型地板时仍可冷准入）。
  /// `true`：无硬顶时恢复旧「一律准入」（应急回滚）。与 [uiWindowHardCap] 解耦。
  static const bool sdkSyncAdmitColdConversations = false;

  /// show_name / id 关键字查询（单页）。
  static const int uiSearchLimit = 50;

  /// 全局搜索本地会话分页：每页条数 / 总上限 / 最多页数（防死循环）。
  static const int uiSearchPageSize = 50;
  static const int uiSearchMaxResults = 500;
  static const int uiSearchMaxPages = 30;

  /// 冷启动后延迟 history warm。
  static const Duration historyWarmAfterHomeDelay = Duration(seconds: 5);

  /// syncTop 后台预热只取轻量窗口；聊天页首开仍用完整 40 条历史窗口。
  static const int historyWarmSyncTopFetchCount = 24;

  /// `false`：syncTop 后台预热只读本地历史，避免空闲时批量打 CLOUD 抢滚动帧。
  /// 按下预热 / 聊天页打开仍可走 LOCAL→CLOUD。
  static const bool historyWarmSyncTopCloudEnabled = false;

  /// `true`：原生端批量读库行解码可走 `compute` Isolate（Web 忽略）。
  static const bool isolateRowDecodeEnabled = true;

  /// 单次 rows 达到该条数才走 Isolate；更小批量同步解码以免启动开销。
  static const int isolateRowDecodeMinRows = 24;

  /// `true`：会话置顶以腾讯 IM `pinConversation` / SDK `isPinned` 为真相；
  /// `false`：回退「只信自建后端、不调 pinConversation」。
  static const bool conversationPinTencentPrimary = true;

  /// 腾讯置顶成功后是否跟写自建 `/me/pinned-conversations`。
  /// 仅在 [conversationPinTencentPrimary] 为 `true` 时生效。
  static const bool conversationPinFollowWriteBackend = true;

  /// 登录时：自建有、腾讯无的置顶，分批补 `pinConversation(true)`。
  /// 仅在 [conversationPinTencentPrimary] 为 `true` 时生效。
  static const bool conversationPinMigrateBackendToTencentOnLogin = true;

  /// 会话列表灌库 **只允许** `getConversationListByFilter` 两路游标
  ///（单聊/群聊分开；首屏各拉 [uiSnapshotC2cLimit]/[uiSnapshotGroupLimit]）。
  /// 禁止改回 `false`：混流 `getConversationList` 业务路径已退役。
  static const bool conversationTypedByFilterSyncEnabled = true;

  /// Phase0–4：列表 UI 以 SDK `getConversationListByFilter` + [ConversationTabStore]
  /// 为权威源（腾讯方案 / 方案 A）；自建 SQLite 仅 mirror / 业务扩展。
  /// `false`：回退 legacy 读库 + hydrate 虚拟列表。
  /// 非 const：单测可临时打开；生产默认保持 `false` 直至验收翻开。
  ///
  /// Phase2（本开关为 true 时额外生效）：
  /// - paced / view_model 灌库不再驱动列表 UI；
  /// - resume quiet 不再 defer 列表 apply；
  /// - Listener 热路径先用 SDK 对象 patch TabStore，写库仅 mirror。
  ///
  /// Phase3：TabStore 排除归档；SQLite 列表字段 mirror-only。
  /// Phase4：停 hydrate 双写 / pendingUiApply 主列表路径；见 docs。
  static bool conversationListSdkPrimary = false;

  /// `true`：热启发现 `c2cHaveMore=false` 且本地单聊行数低于 [uiSnapshotC2cLimit]
  /// 时重开 C2C 游标并至少拉一页（修复混流/脏 meta 导致单聊永久不灌）。
  static const bool c2cCursorHealEnabled = true;

  /// `true`：真虚拟列表——ListView.itemCount≈库内该类型总数，视口附近水合；
  /// 软顶只限制水合缓存，**禁止**触底头裁换窗（避免整批替换）。
  /// `false`：回退方案 C 滑动软顶窗。
  static const bool conversationVirtualListEnabled = true;

  /// 虚拟列表：每个类型最多常驻水合条数（含置顶）。
  static int get virtualHydrateMaxPerType =>
      AndroidPerformanceProfile.instance.virtualHydrateMaxPerType;

  /// 虚拟列表：视口锚点上下各预取的条数。
  static int get virtualHydrateRadius =>
      AndroidPerformanceProfile.instance.virtualHydrateRadius;

  /// 虚拟列表：中心落在水合窗内且距窗缘 ≥ 本值时跳过跟滚水合。
  /// 须小于 [virtualHydrateRadius]，保证甩近边缘前仍会扩窗。
  static int get virtualHydrateSkipMargin =>
      AndroidPerformanceProfile.instance.virtualHydrateSkipMargin;

  /// 会话列表 ListView 前后缓存区；独立于聊天消息，避免滚动时过量预构建/头像解码。
  static double get conversationFeedCacheExtent =>
      AndroidPerformanceProfile.instance.conversationFeedCacheExtent;

  /// 虚拟列表：滚动监听两次水合请求的最小中心步进（条）。
  /// 停滑时仍会强制按最终中心补一次。
  static int get virtualHydrateCenterStep {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 14;
    }
    return 8;
  }

  /// 大账号（群数 ≥ [GroupLocalPerfFlags.largeAccountGroupThreshold]）中心步进。
  static int get virtualHydrateCenterStepLargeAccount {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 28;
    }
    return 24;
  }

  /// Android 全档：滚动中不发起虚拟水合，仅 scroll_end / force 补一次。
  /// 边滑边水合会在主线程叠 SQLite/SDK 解码，是普遍卡顿的主要来源之一。
  /// iOS 仍允许边滑边补，减少骨架闪现。
  static bool get virtualHydrateOnlyOnScrollSettle =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// 启动后禁止 viewport history warm 的时长（press 仍可）。
  static Duration get historyWarmSuppressAfterLaunch {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return const Duration(seconds: 35);
    }
    return const Duration(seconds: 20);
  }

  /// `true`：大账号关闭 viewport warm，仅 press 预热。
  static const bool historyWarmLargeAccountPressOnly = true;

  /// `true`：`conversationsByIds` / ensurePinned 打印 wait/query/total 分阶段日志。
  static const bool conversationsByIdsPhaseLogEnabled = false;

  /// `true`：归档列表走 prepare + JOIN/LIMIT 真分页；`false` 回退旧 `loadOlderAmongIds`。
  static const bool archiveTruePageEnabled = true;

  /// `true`：归档首屏不做全量 `conversationsByIds` missing probe。
  static const bool archiveDeferFullMissingProbe = true;

  /// 归档冷缺壳：单次 SDK `getConversation` 补齐上限。
  static const int archiveColdHydrateBatchSize = 8;

  /// `prepareArchiveIdSet` 写入 JOIN 候选的分块大小。
  static const int archivePrepareChunkSize = 400;

  /// `true`：prepare 分块之间 `await Future<void>.delayed(Duration.zero)` 让帧。
  static const bool archivePrepareYield = true;

  /// 单次打开归档页 `_archiveItems` 硬顶；达到后停载（退出重进可重置）。
  static const int archiveListEmergencyCap = 480;

  /// `true`：持久 `archive_id_index`（首版关，用会话表内 JOIN 候选表）。
  static const bool archiveIdIndexPersistent = false;

  /// `true`：归档 prepare / 取页打 `[ConvPerfGate] archive_page_*`。
  static const bool archivePagePhaseLogEnabled = false;

  /// `true`：主列表虚拟 count/page/hydrate 排除已归档（修主列表与归档双显）。
  static const bool virtualListExcludeArchivedEnabled = true;

  /// `true`：归档集变更时从 UI 水合窗 purge 已归档并刷新 totals。
  static const bool purgeUiOnArchiveChangeEnabled = true;

  /// `true`：folder_unread 单飞在开跑前同步占坑，禁止双 Tab 同时 run。
  static const bool folderUnreadAtomicClaimEnabled = true;

  /// `true`：归档页分页/已有列表时，归档 ID 变更不立刻整表 reload first。
  static const bool archivePageForbidReloadFirstWhilePaging = true;

  /// `true`：排除归档的 COUNT/PAGE 串行化，禁止 TEMP 表并发互踩打回全量总数。
  static const bool archiveExcludeQuerySerialized = true;

  /// `true`：归档/取消归档后同步主列表（purge + 恢复回灌 + totals）。
  static const bool archiveChangeMainListSyncEnabled = true;

  /// `true`：主列表归档同步单飞，合并连打。
  static const bool archiveChangeSyncSingleFlight = true;

  /// Phase3：自建 Conversation 表中 unread / lastMessage / orderKey / isPinned
  /// **对主列表 UI 仅为 mirror**（sdkPrimary 时 UI 读 TabStore/SDK）。
  /// 仍写入 SQLite，供角标聚合 / 离线兜底 / 分组 unread map；停写留给 Phase4
  ///（角标改挂 Store 之后）。
  static const bool conversationSqliteListFieldsMirrorOnly = true;

  /// `true`：ByFilter 单聊空时，从好友/置顶等候选按历史补建 C2C 会话壳。
  static const bool c2cHistoryBackfillEnabled = true;

  /// 单次最多探测的 C2C peer 数（防好友上千打爆）。
  static const int c2cHistoryBackfillMaxPeers = 30;

  /// 本地单聊行数 **低于** 本值时，即使已有壳也仍扫好友/置顶补壳。
  /// `<=0`：禁用「有壳仍扫好友」（回到旧行为：仅 localC2c==0 才扫）。
  /// 默认对齐 [uiSnapshotC2cLimit]，覆盖「SDK 只回几条、实际还有十几个有历史单聊」。
  static const int c2cHistoryBackfillFriendScanBelow = uiSnapshotC2cLimit;

  /// `true`：SDK 无会话壳时必须 history≥1 才补壳（好友≠有过会话）。
  static const bool c2cHistoryBackfillRequireHistory = true;

  /// `true`：好友列表纳入补壳候选。
  static const bool c2cHistoryBackfillIncludeFriends = true;

  /// `true`：置顶 C2C 纳入补壳候选。
  static const bool c2cHistoryBackfillIncludePinned = true;

  /// `true`：把 Snapshot 优先 C2C ID 并入候选（默认关）。
  static const bool c2cHistoryBackfillUseSnapshotIds = false;

  /// @Deprecated 假 spacer 页数；真虚拟列表用 itemCount=total，此值忽略。
  /// `<=0`：不插假高度。
  static const int virtualSpacerMaxPages = 0;

  /// `true`：本地类型耗尽且 haveMore 时触底必拉 SDK 一页（打 feed_bottom_sdk_page）。
  static const bool feedBottomSdkPageEnabled = true;

  /// 触底 SDK 拉页后仍无本地增量时的短压制，避免空转刷屏。
  static const Duration feedBottomSdkEmptySuppress = Duration(
    milliseconds: 800,
  );
}

/// SDK 会话分页写库模式。
enum ConversationSdkDrainMode {
  /// 最多 [ConversationPerfFlags.bootstrapForegroundPages] 页，有剩余则调度后台 drain。
  foregroundLimited,

  /// 在有 haveMore 时继续拉写，页间 yield；可被前台请求插队。
  backgroundContinue,

  /// 只拉写一页。
  singlePage,
}
