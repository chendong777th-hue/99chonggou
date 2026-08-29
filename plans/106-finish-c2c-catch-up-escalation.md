# Plan 106: 为 C2C 云端追赶耗尽建立可续跑的不完整状态

> **Executor instructions**: 严格按步骤执行，先写“多于三页”的失败测试，再扩展
> reconciliation 状态。禁止用 C2C per-sender Seq、时间空白 marker、无界请求或无条件
> replace 最新窗伪造 Telegram `difference` 语义。命中 STOP 条件时停止并报告。
> 完成后更新 `plans/README.md`。
>
> **Drift check（首先执行）**：
> `git diff --stat 9f7c46e..HEAD -- third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_cloud_catch_up.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_coordinator.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_writer.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart lib/src/chat.dart lib/src/services/chat_history_recovery_coordinator.dart lib/src/services/im_recovery_service.dart test/message_cloud_catch_up_test.dart test/message_reconciliation_coordinator_test.dart test/message_reconciliation_writer_test.dart test/message_reconciliation_production_wiring_test.dart`
> 当前基于 dirty worktree；逐段核对下面的现场代码，禁止 reset、checkout 或覆盖他人修改。

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: 092 Steps 1-4；104 的 group-only gap 收敛；发布前完成 092 Step 5
- **Category**: correctness / resilience / integration tests
- **Planned at**: commit `9f7c46e`, 2026-08-25（dirty worktree）

## Execution (2026-08-25)

- 代码已完成：`continuation` disposition、`cloudContinuationPending` phase、
  `cloudHasMoreNewer` 状态、有界当前轮重试和 active-bottom continuation 已接线；C2C
  不使用 per-sender Seq 作为群连续性证明。
- writer 的群 Seq 跟踪改为显式 `trackSeqGaps`，裸群存储 key 不再误走 C2C 分支。
- 定向 `git diff --check` 通过；Flutter/Dart focused tests、analyze 和 format 受
  `/Users/qiu/flutter/bin/cache/engine.stamp` 权限阻塞，待操作员批准沙箱外重试。
- 092 Step 5、长断线双账号矩阵、搜索/离底/optimistic/deferred 联合验收仍未执行，
  因此当前不宣称完全完成。

## Why this matters

C2C 没有可在本项目中当作全局单调游标的协议 Seq。当前生产 catch-up 用最新真实
`lastMsg` 做 `CLOUD_NEWER`，每次成功结果经 writer 提交，这是正确基础；但 controller
最多运行三次或十秒。当每页仍返回 `isFinished == false` 时，attempt 返回 `retry`，最终
`MessageCloudCatchUpResult.completed == false`，而调用方用 `unawaited` 丢弃结果。

更关键的是，`completeHistoryReconciliation` 会因为 C2C 没有 `missingSeqRanges` 把
coordinator phase 标成 `complete`，即使 SDK 明确说还有下一页。因此长断线缺失超过有界
页数后，系统既没有可查询的 incomplete 状态，也不保证后续续跑；消息可能要等另一次
重连、前台或重新进页才出现。

该计划不承诺 Telegram `pts/difference` 等级的协议证明。目标是如实表达“已提交当前页，
但云端仍有 newer 页”，在不破坏用户阅读位置和 optimistic 行的前提下安排有界续跑。

## Current state

`_runCloudCatchUpAttempt` 当前：

```dart
final commit = completeHistoryReconciliation(...);
...
final needsAnotherPage = missingSeqs.isEmpty && !response.isFinished;
if (state.missingSeqRanges.isNotEmpty || needsAnotherPage) {
  return MessageCloudCatchUpDisposition.retry;
}
return MessageCloudCatchUpDisposition.complete;
```

`MessageReconciliationCoordinator.completeRequest` 当前只看 offline 和 group missing ranges：

```dart
final phase = isOfflineCloudFallback
    ? MessageReconciliationPhase.offlineLocalOnly
    : normalizedRanges.isNotEmpty
        ? MessageReconciliationPhase.gapDetected
        : MessageReconciliationPhase.complete;
```

`Chat._scheduleReconnectHistoryRecovery` 当前：

```dart
unawaited(globalModel.reconcileConversationCloud(
  conversationId,
  reason: 'im_reconnected',
));
```

结果的 `completed/attempts/timedOut` 没有进入 recovery state 或后续调度。

## Baseline evidence

现有 `test/message_cloud_catch_up_test.dart` 证明三次 retry 后 controller 返回
`completed == false`，但没有测试 production caller 如何处理它，也没有四页以上 C2C
history 的集成测试。计划生成时 Flutter 测试因 SDK cache 权限被阻塞，沙箱外自动审核
服务返回 503；执行者必须在可用工具链中重新建立基线。

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Inventory | `git status --short` | 记录已有修改，不覆盖无关文件 |
| Trace callers | `rg -n "reconcileConversationCloud|MessageCloudCatchUpResult|isFinished|needsCloudRetry" lib third_party/tencent_cloud_chat_uikit/lib test` | 每个 incomplete 结果有 owner |
| State tests | `flutter test test/message_cloud_catch_up_test.dart test/message_reconciliation_coordinator_test.dart test/message_reconciliation_writer_test.dart` | 全部通过 |
| Integration | `flutter test test/c2c_cloud_catch_up_continuation_test.dart test/message_reconciliation_production_wiring_test.dart` | 全部通过 |
| Recovery regression | `flutter test test/chat_history_recovery_coordinator_test.dart test/chat_history_recovery_satisfaction_test.dart` | 全部通过 |
| Analyze | `flutter analyze third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_cloud_catch_up.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_coordinator.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_writer.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart lib/src/chat.dart lib/src/services/chat_history_recovery_coordinator.dart lib/src/services/im_recovery_service.dart` | 相关文件无新增 error |
| Format | `dart format --output=none --set-exit-if-changed <changed Dart files>` | exit 0 |
| Hygiene | `git diff --check` | exit 0 |

## Scope

**In scope**：

- C2C CLOUD_NEWER response 的 `isFinished`/continuation state
- bounded catch-up result 的 exhausted/timedOut/offline/complete 表达
- active conversation 的有界续跑触发与 viewport guard
- writer/coordinator 状态、脱敏诊断和对应单元/集成测试
- 与 092 Step 5 deferred/hidden projection 的发布前联合门禁

**Out of scope**：新增服务端同步游标、C2C Seq 连续性、时间间隔 gap marker、群 Seq 补洞、
SDK 升级、全量本地数据库替换、无界后台轮询、搜索/around-window 重写。

## Git workflow

- Branch: `codex/106-finish-c2c-catch-up-escalation`
- 提交顺序：多页红测 -> typed incomplete -> result owner -> bounded continuation -> viewport fallback。
- 不 push、不合并，除非操作员明确要求。

## Steps

### Step 1: 用四页以上 C2C 场景锁定假 complete

新增 `test/c2c_cloud_catch_up_continuation_test.dart`，fake SDK 按 `lastMsg` 返回至少五页，
前四页 `isFinished:false`，最后一页 true。断言：

1. 每页 response rows 经同一 writer 提交，各 msgID 一次。
2. 第三次 attempt 后 controller result 为 exhausted/incomplete，而 coordinator 不能是 complete。
3. 后续 continuation 从最后已提交真实消息锚点继续，不重头拉第一页。
4. continuation 最终遇到 `isFinished:true` 后才转 complete。
5. history 期间实时、optimistic、deferred/hidden rows 不丢失、不提前揭示。

**Verify**：修复前稳定复现“result 未完成但 coordinator complete/调用方丢弃”的矛盾。

### Step 2: 把分页未完成纳入 reconciliation 契约

- `completeHistory/completeRequest` 接收明确的 `cloudHasMoreNewer` 或等价 typed 字段；禁止
  从 resultCount、时间差或 C2C Seq 猜测。
- `MessageReconciliationState` 记录 continuation pending、最后 cloud anchor、generation、
  last disposition；`needsCloudRetry` 包含该状态。
- 一页提交成功与整个 catch-up complete 分开：当前页可以形成 writer revision，同时
  coordinator 保持 incomplete。
- group missing range 仍由 104 的 Seq 状态负责；不要把两个概念塞进同一个 bool 后丢失原因。

**Verify**：online + `isFinished:false` 保持 incomplete；online + true 完成；offline/local
fallback、timeout、stale completion 各自保持现有非完成语义。

### Step 3: 给 bounded result 明确终止原因

当前 `retry` 同时表示“还有下一页”和“请求失败”。扩展 result/disposition，使调用方至少
能区分：

- `complete`
- `offline`
- `exhaustedWithContinuation`
- `timedOut/transientFailure`
- invalidated/stale 只作为内部诊断，不覆盖新 generation

attempt 数必须是实际启动次数；若总时限在下一次启动前耗尽，不能报告虚假的 maxAttempts。
controller 仍保持 per-conversation single-flight 和硬时限。

**Verify**：3 次成功但 `isFinished:false` 与 3 次 exception 返回不同 disposition；timeout
后的 late completion 不能把状态改成 complete。

### Step 4: 让 production caller 成为结果 owner

- 不再在 `Chat`/恢复路径中完全丢弃 `MessageCloudCatchUpResult`。通过 GlobalModel typed
  state 或 recovery coordinator 消费结果，不在 widget 中复制同步状态。
- open、preview-ahead、foreground、IM reconnect 和用户回到 newest edge 统一调用同一
  result-aware 入口；现有 `ChatHistoryRefreshBus` 分页可以并行承担 UI load，但不能被
  当作 catch-up 完成证明。
- 同一 conversation continuation single-flight；切会话/dispose 后旧 completion 只记录
  stale，不调度新会话。
- 重启后无需持久化消息正文或第二套数据库；重新打开会话本身是合法新 generation，
  从 SDK/权威窗最新锚点重新证明。

**Verify**：每种恢复 reason 都有确定 owner；同一次亮屏的合并策略仍成立；
`im_reconnected` 不被错误 coalesce 掉。

### Step 5: 定义有界续跑预算和冷却

成功分页和网络失败使用不同预算：

- 单轮仍受 10 秒/页数硬上限约束，避免前台长时间占用。
- `exhaustedWithContinuation` 在 active、online 且没有 history request 时安排一次冷却后的
  continuation；每个 route generation 有总页数/时长预算，达到后停止自动续跑并保持
  typed incomplete。
- 新的 foreground/reconnect/preview-ahead/newest-edge/open 事件可启动新预算。
- offline 只等待网络恢复；transient error 使用有限退避；不创建常驻周期 Timer。
- 诊断记录 reason、attempt/page、resultCount、isFinished、anchor hash 和 final disposition，
  不记录正文、完整 ID、UserSig。

具体页数上限由 fake/真机延迟和 Tencent 限频数据决定，必须是命名常量并有测试，禁止
散落 magic number。

**Verify**：五页能通过续跑完成；永久 `isFinished:false` 在预算后停止；重新前台可续跑；
离开 route 后不再自动请求。

### Step 6: 只在安全 viewport 使用 newest-window 兜底

若 C2C 长时间 incomplete 且产品要求优先保证“最新消息可见”，可在以下全部条件满足时
执行一次 newest-window cloud reconciliation：active conversation、用户位于底部、非搜索/
around-window、没有历史请求、没有发送接管事务。该兜底仍通过 writer merge，不能
`replace:true` 丢弃旧窗。

用户正在看历史、菜单打开、后台、搜索定位或 deferred projection 未收敛时，只保留
incomplete 状态和轻量诊断，不跳滚动、不清列表、不揭示隐藏消息。若无法无损 merge，
不要实施 newest-window fallback，依赖下一恢复 trigger。

**Verify**：底部场景拿到最新行；离底/搜索/发送中场景不 reset 窗口，optimistic row、
anchor、scroll offset 和 hidden/deferred 集合保持。

### Step 7: 联合 092 Step 5 和真机验收

106 正式发布前完成 092 Step 5，保证 raw/buffered/hidden/visible 在 completed generation
收敛。用两个账号验证短断线、超过三页长断线、前后台、重连、preview 领先、离底阅读、
搜索定位、发送中恢复、永久分页未结束/限频。比较 msgID 集合和顺序，不只看截图。

**Verify**：可返回的多页消息最终无需离开重进即可出现；预算耗尽时状态仍明确 incomplete，
下一合法 trigger 能续跑；没有无界网络、重复行、滚动跳变或发送状态回退。

## Done criteria

- [ ] C2C `isFinished:false` 不再被 coordinator 标为 complete。
- [ ] 当前页提交成功与整个 catch-up 完成是两个独立状态。
- [ ] bounded result 区分 continuation、offline、timeout/transient 和 complete。
- [ ] production caller 消费 incomplete 结果并安排有界后续动作。
- [ ] continuation 从最后已提交真实锚点继续，所有 msgID 各一次。
- [ ] 永久未完成响应会在 route/session 预算后停止，不形成常驻轮询。
- [ ] 离底、搜索、optimistic、deferred/hidden 和滚动位置不被兜底破坏。
- [ ] 092 Step 5、自动测试、定向 analyze、format、diff check 全通过。
- [ ] 双账号长断线矩阵通过并留存脱敏日志。
- [ ] Scope 外无修改（计划索引除外）。

## STOP conditions

- 实现准备把 C2C per-sender Seq 当作全局连续游标。
- 只能靠时间空白、消息数量或 preview timestamp 宣称“全部同步完成”。
- 需要无界 Timer/请求、无条件 replace 窗口或删除本地真实消息。
- SDK 不返回可靠 `isFinished`，且无其他服务端 continuation 契约；保留 incomplete 并升级
  协议决策，禁止伪 complete。
- newest-window 兜底会破坏搜索锚点、离底阅读、optimistic row 或发送状态。
- 092 Step 5 未完成且 hidden/deferred 行仍可能永久不收敛。
- 自动或真机测试出现重复、顺序、未读、滚动或媒体状态回归。

## Maintenance notes

C2C 的 `complete` 只能表示 SDK 明确返回 `isFinished:true`，且对应 generation 的 writer
commit 已成功；它不等于 Telegram 的协议级 difference proof。未来更换 SDK 或增加服务端
游标时，应替换 continuation 证据来源，不要同时保留时间启发式和新协议两套“完整性”真源。
