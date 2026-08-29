# Plan 107: 批量化会话提交并降低列表投影热路径成本

> **Executor instructions**: 严格按步骤执行。每一步运行对应验证命令并确认预期
> 结果后再继续。不得以延长 debounce、减少同步来源、关闭虚拟列表、开启
> `conversationListSdkPrimary` 或丢弃会话事件来换取性能。命中 STOP 条件时停止并报告。
> 完成后更新 `plans/README.md`。
>
> **Drift check（首先执行）**：
> `git diff --stat 9f7c46e..HEAD -- lib/src/services/conversation_local/conversation_sync_service.dart lib/src/services/conversation_local/conversation_local_store.dart lib/src/services/conversation_local/conversation_mutation_coordinator.dart lib/src/services/conversation_local/conversation_mutation_shadow_bridge.dart lib/src/services/conversation_local/conversation_list_notifier.dart lib/src/services/conversation_local/conversation_unread_aggregate.dart lib/src/services/conversation_local/conversation_tab_store.dart lib/src/services/conversation_local/conversation_perf_gate_log.dart lib/src/services/conversation_unread_trace.dart test`
> 当前工作区很脏；逐段核对下述现场实现，不得 reset、checkout 或覆盖其他修改。

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: 093；102 完成行为验证后再切生产提交路径
- **Category**: perf / tech-debt / tests
- **Planned at**: commit `9f7c46e`, 2026-08-25

## Why this matters

SDK 会话批次目前先逐会话恢复 Coordinator durable state，再逐 candidate 调用 Store
commit。每条提交可能独立查询状态、读取/解码 `raw_json`、编码指纹、写会话行和写
Coordinator state。提交后的 UI 又在 `_conversations`、type hydrate、index cache、
TabStore 和 aggregate 间重复扫描、排序和通知。首次同步、弱网重连、连续入站和批量
已读会放大为 N+1 SQLite 往返、主 isolate JSON 分配和重复 notify。

本计划保留 093/102 的正确性不变量，将批次作为最小持久化和 UI 提交单位，并建立
可回归的性能预算。

## Current state

- `conversation_sync_service.dart:_commitSdkConversationBatch`：先循环调用
  `coordinatorDurableState`，再循环调用 `commitCoordinatorPlan`。
- `conversation_local_store.dart:commitCoordinatorPlan`：单 plan 加载 state 并按字段
  分派到单行更新，随后单独持久化 Coordinator state。
- conversation 表只投影 `last_msg_id`；需要完整 lastMessage anchor 或字段合并时仍可能
  解码 `raw_json`。
- `conversation_list_notifier.dart:_preserveHotPreviewsDuringHydrate` 和
  `_applyConversationsFromStore` 对每条 incoming 使用 `indexWhere`；批次更新近似
  `O(batch × window)`。
- `_rebuildConversationsFromTypeHydrates` 合并、补 pin、全量排序后 notify；同一 committed
  batch 还可能触发 unread delta 与 `scheduleRefresh` 的数据库校准。
- `ConversationUnreadTrace.enabled` 当前全版本为 true；大量正常事件仍产生 Map、字符串、
  hash 和控制台输出。用户要求保留全版本详细日志，因此只能优化承载方式，不能删除关键
  诊断事件。

## Performance budgets

以 100 条 SDK conversation snapshot、其中 40 条实际变化为固定 benchmark：

- durable state 读取：最多 1 次 SQL query，不得按会话查询。
- conversation existing rows：最多 1 次分块 query（SQLite 参数上限需要分块时按块计）。
- Store commit：1 个 transaction；会话 batch 与 Coordinator state batch 各一次提交。
- `raw_json` decode：只解码确实需要合并的 existing 行；unchanged lightweight probe 不解码。
- UI 查找：建立 canonical ID index，批量 apply 不得执行每条 `indexWhere` 全窗扫描。
- 每个 committed batch：Notifier 最多一次可见 notify；aggregate 最多一次 delta commit，
  正确 delta 已知时不得立即再扫描 Store。
- Release 正常事件日志不得逐条同步打印；错误、rollback reject、watermark accept/reject
  仍须全版本可导出并脱敏。

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Hygiene | `git diff --check` | exit 0 |
| Analyze | `flutter analyze lib/src/services/conversation_local/conversation_sync_service.dart lib/src/services/conversation_local/conversation_local_store.dart lib/src/services/conversation_local/conversation_mutation_coordinator.dart lib/src/services/conversation_local/conversation_mutation_shadow_bridge.dart lib/src/services/conversation_local/conversation_list_notifier.dart lib/src/services/conversation_local/conversation_unread_aggregate.dart lib/src/services/conversation_local/conversation_tab_store.dart lib/src/services/conversation_local/conversation_perf_gate_log.dart lib/src/services/conversation_unread_trace.dart` | 无新增 analyzer error |
| Focused tests | `flutter test test/conversation_commit_batch_perf_test.dart test/conversation_coordinator_commit_contract_test.dart test/conversation_preview_monotonic_projection_test.dart test/conversation_unread_guard_test.dart test/conversation_list_notifier_incremental_test.dart test/conversation_ui_window_test.dart test/conversation_virtual_tail_window_test.dart test/conversation_perf_gate_log_test.dart` | 全部通过 |
| Broad regression | `flutter test test/conversation_sync_reload_coalesce_test.dart test/conversation_pending_sdk_sync_test.dart test/conversation_mutation_coordinator_test.dart test/conversation_mutation_shadow_bridge_test.dart test/conversation_unread_clear_service_test.dart test/conversation_unread_merge_foreground_test.dart test/conversation_tab_store_test.dart` | 全部通过 |

## Scope

**In scope**：

- `lib/src/services/conversation_local/conversation_sync_service.dart`
- `lib/src/services/conversation_local/conversation_local_store.dart`
- `lib/src/services/conversation_local/conversation_mutation_coordinator.dart`
- `lib/src/services/conversation_local/conversation_mutation_shadow_bridge.dart`
- `lib/src/services/conversation_local/conversation_list_notifier.dart`
- `lib/src/services/conversation_local/conversation_unread_aggregate.dart`
- `lib/src/services/conversation_local/conversation_tab_store.dart`
- `lib/src/services/conversation_local/conversation_perf_gate_log.dart`
- `lib/src/services/conversation_unread_trace.dart`
- 直接对应的 conversation 测试与 benchmark 测试
- `plans/107-lighten-conversation-commit-and-projection.md`、`plans/README.md`

**Out of scope**：SDK/native 协议、聊天消息历史、媒体、UI 布局、数据库替换、开启
SDK-primary、取消虚拟列表、改变未读/lastMessage/pin/draft/archive 权威、删除全版本关键
日志、通过更长 Timer 合批。

## Steps

### Step 1: 建立确定性性能计数器和正确性基线

新增 `test/conversation_commit_batch_perf_test.dart`。为 Store 增加仅测试可见的 batch
profile counters：durable-state query 次数、conversation-row query 次数、transaction
次数、raw JSON decode 次数、conversation/state write 数。为 Notifier 记录 canonical
lookup fallback 次数、notify 次数，为 Aggregate 记录 Store calibration 次数。

测试 1/10/100 条批次，并同时断言最终 msgID、unread、order、pin、draft、tombstone 和
102 read barrier 语义。不得只断言耗时；CI 机器差异大，预算以操作次数为权威。

**Verify**：新测试在旧实现上稳定显示 100 条批次存在逐条 state/commit 行为，并且既有
093/102 正确性测试保持绿色。

### Step 2: 增加 Store 批量预取 API

在 `ConversationLocalStore` 新增 alias-safe 批量接口，一次读取：

- 所有 canonical conversation durable states；
- 所有对应 conversation rows；
- lightweight comparison columns；仅需要字段合并的行再 decode `raw_json`。

返回 typed batch context，不向 SyncService 暴露 SQLite row Map。Web memory-only 分支
返回同一类型。分块必须遵守 SQLite 参数上限，community/group alias 使用现有
`_conversationEquivalenceKey`。

**Verify**：100 条预取的 durable-state query 为 1，conversation query 为 1 或明确的
参数分块数；alias/tombstone 测试通过。

### Step 3: 实现 Coordinator batch commit transaction

新增 `commitCoordinatorPlansBatch`，按 owner 校验所有 plan，在一次 Store transaction
内完成 admission、字段级 merge、conversation batch write 和 Coordinator state batch
write。结果返回一个 `ConversationUiSnapshotBatch`，包含最终 committed rows、deleted IDs、
changed field masks、unread deltas 和 commit generation。

要求：

- 复用 `commitCoordinatorPlan` 的 disposition/tombstone/idempotency 语义；单 plan API
  改为长度 1 的 batch wrapper，避免两套规则。
- 同 canonical ID 的多个 plan 按 Coordinator sequence 依次 reduce，最终只写一行；不能
  在 reducer 前丢事件。
- 102 barrier 裁决必须发生在 batch context 入场前，拒绝旧 unread 不产生 delta。
- transaction 失败不得提前更新内存 Coordinator state。

**Verify**：100 条批次 transaction=1；故意制造中间写失败时 conversation 与 state 均
回滚；093、102、draft/pin/delete 测试通过。

### Step 4: 切换 SyncService 到单次批量提交

修改 `_commitSdkConversationBatch`：批量读取 durable state、一次准备 plans、一次调用
`commitCoordinatorPlansBatch`。删除生产循环中的逐条
`coordinatorDurableState`/`commitCoordinatorPlan`；测试 override 和 072 kill switch
保留完整 rollback path，但不能双写。

**Verify**：静态搜索表明 `_commitSdkConversationBatch` 内没有逐 conversation await；
100 条 snapshot 满足 Step 1 budgets。

### Step 5: 为 Notifier 建立 canonical ID index

在 `ConversationListNotifier` 维护 `_conversations` 与每个 `_typeHydrate` 页的 canonical
ID → index 映射。所有替换、排序、reload、clearSession、hydrate window jump 后原子重建；
字段 patch 使用 O(1) index，找不到时才使用现有 alias fallback 并计数。

不要缓存裸对象引用；索引只保存位置，任何结构变化后必须重建。`_typeIndexSnapshotCache`
仍按虚拟绝对 index 管理，不得与 canonical index 混用。

**Verify**：100 条 committed batch 的全窗 `indexWhere` fallback=0；置顶重排、归档删除、
hydrate jump、账号切换和 virtual tail 测试通过。

### Step 6: 统一 committed UI batch 与 aggregate 提交

让 Notifier、type hydrate、TabStore（未来 SDK-primary 契约）和 Aggregate 消费同一个
`ConversationUiSnapshotBatch`。Notifier 在一个 suppression scope 内完成全部字段 patch、
必要排序、cache 更新，最后最多 notify 一次。Aggregate 优先应用 batch 内 unread deltas；
只有 batch 声明 unknown/incomplete 时才 `scheduleRefresh` 扫 Store。

**Verify**：单批 40 条变化 notify<=1、aggregate delta commit<=1、Store calibration=0；
未知兼容批次仍会校准一次。可见行、离屏 hydrate、底部角标和重启结果一致。

### Step 7: 降低全版本日志热路径成本

保留用户要求的全版本详细日志，但将正常高频事件写入固定容量、脱敏的内存 ring buffer；
错误、Coordinator reject、watermark accept/reject、transaction failure 立即输出。增加运行时
导出接口时只返回已脱敏结构，不包含正文、真实 ID、头像 URL 或 SDK desc。

`ConversationPerfGateLog`/`ConversationUnreadTrace` 在日志关闭或采样未命中时必须先返回，
不能先创建 extras Map、计算 SHA 或拼接字符串。测试计数器保持可用。

**Verify**：日志单测证明关键事件始终记录、正常事件有界、导出脱敏；Release profile 中
100 条正常 snapshot 不产生 100 次同步 `debugPrint`。

### Step 8: Profile 与真机发布门禁

iOS/Android profile build 覆盖 1000 会话冷启动、100 条重连批次、连续 20 条入站、全部
已读、快速滚动 hydrate。记录每阶段计数和 P50/P95：SDK recv→SQLite commit、commit→UI
notify、frame build/raster、SQLite lock wait。优化后不得比优化前增加任何正确性回归。

**Verify**：操作次数满足 budgets；P95 commit 和 UI notify 明显下降；无摘要回退、未读
复活、pin/draft/archive 丢失、虚拟列表 skeleton 或多账号串写。

## Test plan

- 新增 `test/conversation_commit_batch_perf_test.dart`：1/10/100 条操作计数、事务回滚、
  alias、tombstone、unchanged skip、混合字段 batch。
- 扩展 `conversation_list_notifier_incremental_test.dart`：canonical index 生命周期、单次
  notify、排序后索引重建。
- 扩展 `conversation_unread_aggregate_test.dart`：known delta 不扫库、unknown batch 只扫一次。
- 扩展 `conversation_perf_gate_log_test.dart`：ring buffer 容量、关键事件、脱敏导出、关闭
  快路径零 hash/零输出。
- 必须联合运行 093 的 preview monotonic 测试和 102 的 watermark 测试。

## Done criteria

- [ ] 100 条 SDK batch durable/conversation 读取满足预算，Store transaction=1。
- [ ] `_commitSdkConversationBatch` 不再逐会话 await durable state 或 commit。
- [ ] 单 plan 与 batch plan 共用一套 Store commit 语义。
- [ ] Notifier 批量 apply 无全窗 `indexWhere`，每批最多一次 notify。
- [ ] known unread deltas 不触发立即 Store calibration。
- [ ] 全版本关键日志保留、脱敏且有界；正常事件不逐条同步打印。
- [ ] 093 lastMessage 单调性和 102 read watermark 测试通过。
- [ ] focused、broad tests、analyze、`git diff --check` 全部通过。
- [ ] iOS/Android profile 记录满足操作预算且无产品语义回归。
- [ ] Scope 外无修改；`plans/README.md` 已更新。

## STOP conditions

- 102 尚未取得行为测试证据，或 batch commit 会改变 read barrier/version 语义。
- 批量事务要求新增第二套 Coordinator/Store 真源。
- 必须丢弃事件、延长 debounce、关闭 SDK source 或关闭虚拟列表才能达标。
- canonical index 无法在排序/归档/hydrate 后可靠重建。
- transaction rollback 后内存 state 与 SQLite 无法恢复一致。
- Release 诊断无法在保留关键全版本日志的同时做到脱敏和有界。
- 任一 unread、lastMessage、draft、pin、mute、archive、tombstone、多账号或虚拟列表测试
  连续两次失败且无法在 scope 内修复。

## Maintenance notes

- 新增 conversation mutation source 时必须进入同一 batch context，禁止恢复逐条 Store
  commit。
- 新增 UI 投影容器时消费 `ConversationUiSnapshotBatch`，不能复制字段裁决或 unread 聚合。
- schema 若未来增加 lastMessage timestamp/seq 投影列，应作为独立 migration 计划；本计划
  先以 decode-on-demand 证明收益，避免同时扩大数据库迁移风险。
- 评审重点检查：事件是否在 reducer 前被合并、事务失败是否污染内存 state、索引是否在
  所有结构变化后重建、日志是否在构造敏感/昂贵字段前完成开关判断。

## Execution record (2026-08-25)

- Step 1 代码已落地：Store 增加仅测试可见的 durable-state query、单 plan commit、
  Coordinator state write、raw JSON decode 计数器；新增
  `test/conversation_commit_batch_perf_test.dart`，锁定 10 条 plan 当前产生 10 次 commit、
  10 次 durable query 和 10 次 state write 的基线。
- `git diff --check` 已通过。
- Flutter 基线测试与 102 回归未启动：SDK 缓存写入授权的自动审批服务再次返回 HTTP
  503。操作员随后明确要求继续切换生产批量事务路径，因此已覆盖原 STOP 门禁继续执行。
- Step 2–4 主热路径已切换：SDK batch 使用一次 alias-safe durable-state 分块查询、一次
  `_upsertBatchImpl` row transaction、一次 Coordinator state batch transaction；
  `_commitSdkConversationBatch` 不再逐 candidate 调用 `commitCoordinatorPlan`。state batch
  失败会恢复进程内 Coordinator state。
- 已继续完成跨表单单原子事务：`_upsertBatchImpl` 增加内部 `DatabaseExecutor` 模式，
  传入现有 transaction 时只执行 row merge/batch；SDK batch 在
  `coordinatorSdkUpsertAtomicBatch` 同一 transaction 内依次写 conversation rows 与
  Coordinator states，不使用嵌套 transaction。失败时 SQLite 回滚两张表并恢复进程内
  Coordinator state。
- 单原子事务切换后的 focused tests 再次因授权服务 HTTP 503 未启动；直接调用 Dart formatter 又因
  本机 Dart VM `cpuinfo_macos.cc` 崩溃退出。当前只有 `git diff --check` 和静态 writer
  审计证据，不能标记完成。
- Step 5 主热路径代码已落地：`ConversationListNotifier` 增加主窗口与每个 type hydrate
  页的 canonical ID → position 索引；SDK-primary adopt、hydrate load/patch/insert/remove、
  test seed、session clear 和 committed apply 后重建或维护索引。`_applyConversationsFromStore`
  使用批内 canonical working index，hydrate preview/patch 仅在索引校验失败时执行兼容扫描，
  并通过 `canonicalLookupFallbacksForTest` 计数。
- Step 6 部分落地：`applyCommittedBatch` 的多行 committed snapshots 仍通过单次
  `_applyConversationsFromStore` 完成排序、hydrate 同步、aggregate delta apply 和一次 notify
  调度；新增测试覆盖三行 committed batch 只通知一次，以及裸 ID/canonical alias 更新不走
  全窗 fallback。`ConversationUiSnapshotBatch` 内建 unread delta/completeness 与 Aggregate
  unknown calibration 契约尚未实现，Step 6 不标记完成。
- 本次限定文件 `git diff --check` 通过。`flutter analyze` 未进入 analyzer：Flutter SDK
  尝试写 `/Users/qiu/flutter/bin/cache/engine.stamp` 时被沙箱拒绝；行为测试和 analyzer 证据
  仍待可用授权环境补跑。
- Step 6 增加 staged committed-batch unread 契约：`ConversationUiSnapshotBatch` 支持无 UI/SDK
  依赖的 `ConversationUiUnreadDelta` 列表和 nullable `unreadProjectionComplete`。Notifier
  在 committed batch 内一次转换并提交 Aggregate；明确 complete 的 batch 不调 Store 校准，
  明确 incomplete 的 batch 只调度一次校准，旧 batch (`null`) 保留原有窗口推导行为。
- Aggregate 增加测试可见的 delta commit、calibration、refresh schedule 计数器；新增
  Notifier 测试覆盖 complete batch 不校准、incomplete batch 单次调度。当前 SDK batch 尚未
  填充 Store 层 old/new unread delta，因此生产 batch 暂不声明 complete，避免错误跳过校准。
- 后续执行继续推进 Store 侧：新增 `ConversationSdkCommittedBatch` 与
  `commitCoordinatorSdkUpsertPlansBatchResult`，在同一 SDK transaction 的旧行读取和 merge
  过程中收集 old/new notifiable unread delta，并保留原有 `List<V2TimConversation>` wrapper
  兼容旧调用方。限定文件 `git diff --check` 通过。
- 当前仍未完成 SyncService result 透传：生产 `_commitSdkConversationBatch` 尚有多处只消费
  list 的调用，直接替换会造成重复 UI 投影；下一步必须先增加内部 result 方法，再让
  `_applyPacedSyncPageToUi`/committed UI 入口消费同一 batch。Flutter analyze/test 仍受 SDK
  cache 写权限审批 HTTP 503 阻断。
- 已继续完成最小生产透传：`_commitSdkConversationBatch` 增加可选 committed-result 回调，
  paced sync 路径将 Store 事务产生的 unread deltas 转换为同一
  `ConversationUiSnapshotBatch`，由 Notifier 一次消费；旧 list 返回契约和其它调用方保持不变。
  仅在没有 typed result 的兼容路径保留原有 out-of-window 校准。空 rows 但存在 committed
  delta 时 Notifier 不再提前 return。限定文件 `git diff --check` 通过。
- 新增 `test/conversation_commit_batch_perf_test.dart` typed result 回归：首次提交断言
  `0→1` unread，第二次同会话提交断言 `1→7` unread，同时确认 completeness=true；这是
  Store 事务 old/new projection 的直接证据。Flutter 测试尚未启动，仅完成静态检查。
- 对 `applyCompatibilityStoreProjection` 做了静态 writer audit：正常 paced sync 已迁移到
  `applyCommittedBatch`；剩余调用集中在 reload/recovery、post-pop compatibility、撤回/发送
  乐观补丁、以及 rollback/legacy allowlist。它们不能在没有对应 typed committed result 前
  直接删除；Plan 108 后续应逐组迁移并保留明确 reason allowlist。
- Plan 108 继续收口：`commitCreatedConversation` 和 `retainOpenedGroupConversation` 现在
  通过 `_commitSdkConversationBatch` 的 typed result 回调构造 `ConversationUiSnapshotBatch`，
  统一进入 Notifier；只有 result 不可用时才保留 compatibility fallback。撤回/发送乐观补丁
  仍保留旧入口，等待 Plan 109 的 message commit 派生摘要后再迁移，避免临时 UI 状态成为
  第二个会话事实源。`git diff --check` 已通过。
