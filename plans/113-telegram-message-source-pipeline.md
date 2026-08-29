# Plan 113: 收敛 Telegram 式聊天消息来源与单一提交管线

> **Executor instructions**: 这是消息正文来源和提交边界的架构迁移计划。先完整阅读本文件，
> 再执行 Drift check。每一步都必须运行对应验证命令并记录结果。不得 reset、checkout 或
> 覆盖工作区已有修改。命中 STOP 条件时停止并报告，不要自行扩大范围。

> **Drift check（首先执行）**：
> `git diff --stat 9f7c46e..HEAD -- lib/src/chat.dart lib/src/services/chat_history_peek_bootstrap.dart lib/src/services/conversation_history_warm_scheduler.dart lib/src/services/conversation_peek_service.dart lib/src/services/web_message_loader.dart lib/src/services/message_history_coverage_store.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models third_party/tencent_cloud_chat_uikit/lib/data_services/message test`
>
> 当前工作树是 dirty 的。若上述路径自 `9f7c46e` 之后有变更，必须先逐段核对 Current state；
> 不得因为差异存在就覆盖他人修改。

## Status

- **Priority**: P0
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: 092 Steps 1–4；103；104；106；102/107 的行为验证
- **Blocks**: 109 的“消息事实直接派生会话摘要”；111 的统一恢复状态机正式发布
- **Category**: architecture / correctness / migration
- **Planned at**: commit `9f7c46e`, 2026-08-25

## Why this matters

当前聊天页的第一帧读取 `TUIChatGlobalModel.messageListMap`，但消息正文可能由 SDK local DB、
腾讯云端历史、预热任务、实时回调、Web loader 或合成行旁路写入。这样“页面已经显示”容易被
误解成“云端历史已经完整”，云端响应也容易被误当成可以直接替换整窗的最终真相。

Telegram 式体验要求把三个概念分开：本地消息快照负责立即可见；云端批次负责验证和扩展
覆盖；UI 只消费单一提交器发布的 projection。当前代码已经有 local snapshot、latest window、
coverage ledger 和 reconciliation writer 的基础，但仍有直接 `setMessageList` 旁路，且批次
缺少统一的 cursor/provenance/tombstone 契约。本计划完成这层收敛，不复制 Telegram 的
`pts/qts/difference` 协议，也不创建第二套消息正文数据库。

## Target flow

```text
SDK local DB / cloud history / realtime callback / optimistic send
  ↓ typed MessageHistoryBatch or MessageDelta
MessageRepository + per-conversation generation
  ↓
MessageReconciliationWriter (唯一 authoritative commit)
  ↓ one revision + coverage update
TUIChatGlobalModel.messageListMap (UI projection/cache)
  ↓
Chat history list
```

明确语义：

- `localSnapshot`：可见但 provisional；SDK `isFinished` 不证明云端 older 已耗尽。
- `latestWindow`：云端最新窗口校对；只在有明确删除/撤回证明时删除已有行。
- `olderPage`：只扩展 older 边界；不能重置 newest 边界。
- `newerCatchUp`：只扩展 newer 边界；`isFinished:false` 保持 continuation pending。
- `gapFill`：只对群 Seq 缺口做 merge；永远不能 replace。
- `realtime` / `optimistic`：进入同一 writer；历史请求期间进入 pending buffer。

## Current state

### 页面和历史入口

- `lib/src/chat.dart:8472` 首次渲染直接读取 `TUIChatGlobalModel.messageListMap`。它不是
  `ConversationLocalStore` 的正文查询。
- `lib/src/services/chat_history_peek_bootstrap.dart:353-457` 已能先读本地并调用
  `markLocalInitialHistoryVisible`；`469-683` 后续使用云端最新窗口并区分
  `markCloudInitialHistoryVerified`。
- `lib/src/services/conversation_peek_service.dart:64-151` 将 `loadForChatEntry` 定义为
  `CLOUD_OLDER`，`loadLocalForChatEntry` 定义为 `LOCAL_OLDER`。
- `lib/src/services/conversation_history_warm_scheduler.dart:1070-1205` 仍可能直接把 warm
  结果写入 `setMessageList`；非 viewportLocal 分支还可能调用旧的 `markInitialHistoryLoaded`。
- `lib/src/services/web_message_loader.dart:49-65,99-120` 仍直接 fetch/`setMessageList`；
  Web 的 `LOCAL_*` 在 `third_party/tencent_cloud_chat_uikit/lib/data_services/message/message_web_history_loader_web.dart:45-53`
  会规范化为 `CLOUD_*`，所以 Web 没有真正的 native local DB 首显。

### Writer、identity 和 coverage

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_writer.dart:65-170`
  已实现 generation、pending realtime、历史完成合并和 stale completion 拒绝。
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_identity.dart:75-167`
  已规定 `msgID` 是精确云端身份，`localID` 不能云端去重，optimistic stable ID 只做发送关联，
  同 Seq/different msgID 必须保留。
- `lib/src/services/message_history_coverage_store.dart:128-163,211-258` 已持久化
  provisional/verified 状态、边界、群 Seq hole、C2C boundary hole、clear epoch 和账号隔离，
  但还没有完整的请求 cursor/page chain/proof 记录。

### 仍存在的写入旁路

静态搜索当前约有 44 处 `setMessageList` 调用。重点生产入口包括：

- `conversation_history_warm_scheduler.dart:1180`
- `web_message_loader.dart:59,115`
- `call_bubble_insert_service.dart:62`
- `group_local/group_local_tips_service.dart:1069,1091`
- `group_tips_operator_patch_service.dart:207,255`
- `tui_chat_separate_view_model.dart` 多处历史、归档和合成行路径
- `tui_chat_history_pagination_load.dart:1065` 归档兼容分支

这些调用不一定都应删除：合成 UI 行可以保留，但必须通过 typed projection mutation 或
明确的 compatibility allowlist 进入同一个提交边界，不能与 authoritative history 混用。

### 现有实现约束

- `ArchiveHistoryProvider.enableOlderArchiveFetch` 和 `isAvailable` 固定为 false；自建 archive
  不是普通 C2C/group 的现行正文来源，不得在本计划重新启用。
- C2C 不能使用 Group Seq 推断全局连续性；只能使用真实 `msgID` 边界、SDK cursor、
  `isFinished` 和 coverage 状态。
- 腾讯 SDK 的 `CLOUD_*` 可能在异常网络条件下退化为本地结果；“请求类型是 cloud”不等于
  “已经获得 cloud proof”。必须保留 `MessageReconciliationProvenance` 的实际来源判断。
- 不得通过无条件 `replace:true`、清空列表再拉取、无限 retry、复制消息正文到第二个 SQLite
  或关闭 deferred/hidden projection 来制造表面稳定。

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Inventory | `git status --short` | 记录已有修改；不覆盖无关文件 |
| Static writer audit | `rg -n "setMessageList\\(" lib/src third_party/tencent_cloud_chat_uikit/lib` | 每个生产调用都归入迁移表或 compatibility allowlist |
| Format | `dart format --output=none --set-exit-if-changed <changed Dart files>` | exit 0，无格式变更 |
| Focused tests | `flutter test test/chat_history_peek_policy_test.dart test/message_history_coverage_test.dart test/message_reconciliation_writer_test.dart test/message_reconciliation_production_wiring_test.dart test/message_cloud_catch_up_test.dart` | 全部通过 |
| Continuity tests | `flutter test test/message_ordering_test.dart test/group_gap_repair_integration_test.dart test/c2c_cloud_catch_up_continuation_test.dart` | 全部通过；若文件尚未存在，按 Step 6 创建 |
| Static analysis | `flutter analyze lib/src/services/chat_history_peek_bootstrap.dart lib/src/services/conversation_history_warm_scheduler.dart lib/src/services/conversation_peek_service.dart lib/src/services/web_message_loader.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_writer.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart` | 无新增 analyzer error |
| Hygiene | `git diff --check` | exit 0 |

当前环境曾出现 `/Users/qiu/flutter/bin/cache/engine.stamp` 权限阻塞和 Flutter 授权服务
503。若同一问题重现，记录为环境阻塞，不得把未运行测试标为通过；可继续运行纯 Dart/静态
检查，但必须在最终状态中保留阻塞说明。

## Scope

**In scope**

- `lib/src/services/chat_history_peek_bootstrap.dart`
- `lib/src/services/conversation_history_warm_scheduler.dart`
- `lib/src/services/conversation_peek_service.dart`
- `lib/src/services/web_message_loader.dart`
- `lib/src/services/message_history_coverage_store.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_writer.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_coordinator.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_history_coverage.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_history_pagination_load.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
- `third_party/tencent_cloud_chat_uikit/lib/data_services/message/message_history_peek_loader.dart`
- 新增一个与上述模块同层的 typed batch/provenance 契约文件（建议命名
  `message_history_batch.dart`，若已有等价类型则复用，不重复创建）
- 对应 `test/` 单元、契约和集成测试

**Out of scope**

- Tencent native SDK 二进制、服务端协议、SDK 升级或抓包验证
- 自建 archive 的重新启用或消息正文复制到 app-owned SQLite
- 发送协议、媒体缓存、消息 UI 样式、滚动布局和 Telegram forum/thread 功能
- 会话列表本地权威迁移（由 108/112 负责）
- 会话摘要派生（由 109 负责）
- 登录/前台/重连恢复触发器的全局重构（由 111 负责）
- 删除所有 `setMessageList` 字符串；合成 UI 行只能在明确 allowlist 下保留

## Git workflow

- 分支：`codex/113-telegram-message-source-pipeline`
- 建议提交顺序：批次契约与红测 → local-first 接线 → cloud merge/coverage → writer 旁路迁移
  → Web/分页/合成行适配 → 端到端回归。
- 不 push、不合并、不提交到用户分支，除非操作员明确要求。

## Steps

### Step 1: 建立消息来源静态账本和可观察基线

建立一份测试/诊断可读取的生产入口 allowlist，逐个记录每个 `setMessageList` 调用的：

```text
conversation key
source: local/cloud/realtime/optimistic/synthetic/compatibility
batch kind
replace vs merge
是否经过 generation
是否更新 coverage
```

先不改行为。为 `MessageReconciliationWriter` 和 `TUIChatGlobalModel` 增加测试可见的 commit
metadata，至少包含 source、batchKind、generation、revision、resultCount、cloudProof、
clearEpoch；不得包含正文、完整用户 ID、UserSig 或媒体 URL。

**Verify**：

- `rg -n "setMessageList\\(" ...` 的每一处生产调用都有表格/allowlist 条目；
- 新增契约测试能观察一次 local snapshot、一次 latest window、一次 realtime 和一次
  synthetic mutation 的 source/batchKind；
- `flutter test test/message_reconciliation_production_wiring_test.dart` 通过。

### Step 2: 固化 typed history batch/provenance 契约

新增或复用 `MessageHistoryBatch`，字段至少包括：

```text
conversationKey
requestedSource / actualSource
batchKind
requestGeneration
clearEpoch
requestedCursor (lastMsgID / lastMsgSeq / direction)
returnedOldest / returnedNewest
isFinished
hasMoreOlder / cloudHasMoreNewer
cloudResponseProven
messages
tombstones / explicitDeletes
```

`MessageHistoryPeekLoader` 的 local/cloud 返回值通过 adapter 转换成该 envelope；不要让调用方
从普通 `List<V2TimMessage>` 猜测来源或完整性。Web adapter 必须把 `LOCAL_* → CLOUD_*` 的
退化写入 `actualSource`，而不是假装存在本地库。

**Verify**：纯 Dart 测试覆盖 local-only、cloud-proven、cloud-request-but-local-fallback、
empty cloud response、`isFinished:false`、stale generation、clear epoch mismatch；所有
枚举字段都有显式断言。

### Step 3: 让 local snapshot 成为唯一首帧快路径

将 `chat_history_peek_bootstrap.dart`、warm scheduler 和 Web loader 的首屏入口统一为：

```text
read local snapshot if supported
→ writer commit(localSnapshot, provisional)
→ release first-frame gate
→ schedule one latestWindow cloud reconciliation
```

要求：

1. `local.isFinished` 只能影响本地读取状态，不能设置 `olderExhausted=true` 的云端证明。
2. 已有 provisional 窗口时，云端空结果或疑似本地退化结果不能清空窗口；继续按 coverage
   状态重试或标记 incomplete。
3. `markLocalInitialHistoryVisible` 不能触发第二个隐式 cloud pull；只有显式 cloud batch
   经过 writer 提交后才可标记 `markCloudInitialHistoryVerified`。
4. Web 没有 native local DB 时允许直接进入 cloud request，但 UI/coverage 必须显示
   `cloudPending`，不得伪造 `localSnapshot`。

**Verify**：

- 本地慢、云端更慢时，首帧先出现本地消息；
- 云端完成后保留本地实时/optimistic 行，重叠消息按 `msgID` 只出现一次；
- 本地只有一条且 `isFinished=true` 时仍保持可能有 older，不误报完整短会话；
- Web 的 local 请求在测试中显示 actualSource=cloud；
- `flutter test test/chat_history_peek_policy_test.dart test/message_history_coverage_test.dart` 通过。

### Step 4: 实现 range-aware latest window merge，禁止盲目 union/replace

扩展 writer/coordinator 的完成契约，使 `latestWindow` 明确表示“最新边界的云端校对”，而
不是普通 append。提交逻辑必须：

- 以 `msgID` 为精确云端身份，optimistic stable ID 只用于本地发送替换；
- 保留请求开始后到达的 realtime 和 sending rows；
- 保留已加载但不在本次 latest window 内的 older rows；
- 只有显式 tombstone、撤回/删除事件或 SDK 明确的清理水位才能移除已有消息；
- `isFinished:false` 写入 `newerContinuationPending`，不能把当前页完成当作整个同步完成；
- 云端响应 generation、clear epoch 不匹配时完全丢弃，不更新 list、coverage 或 diagnostics 的
  当前状态。

**Verify**：新增测试覆盖：

1. 本地 older 100–120 + 云端 latest 115–135，结果保留 100–135；
2. 云端窗口缺少本地 118，但没有 tombstone，118 保留；
3. 有 tombstone 的 118 才删除；
4. history 期间 realtime 136 到达，最终 136 保留且不重复；
5. stale cloud response 不能覆盖新 generation；
6. 同 Seq/different msgID 两条都保留。

### Step 5: 把 older/newer/gap/realtime 全部接入同一 writer

按以下顺序迁移生产入口：

1. `tui_chat_history_pagination_load.dart` 的 older/newer 继续使用
   `MessageHistoryBatchKind.olderPage/newerCatchUp`，禁止在 adapter 外自行 merge。
2. `tui_chat_separate_view_model.dart` 的 `_commitHistoricalMessages`、群 gap repair 和
   archive-disabled 分支统一调用 writer；不得忽略 SDK history 返回值。
3. `conversation_history_warm_scheduler.dart` 改为提交 `localSnapshot`/`latestWindow`，
   不再直接 replace `messageListMap`。
4. `web_message_loader.dart` 改为通过同一 batch adapter，保留 Web 的 cloud actualSource。
5. call bubble、group tips 等 synthetic rows 不伪装成历史消息；通过 typed synthetic
   mutation 进入 writer，或保留在 compatibility allowlist 并明确不更新 coverage。

每迁移一个入口，先保留旧实现 behind test-only rollback hook，再删除生产双写。调用方不得
自行决定 `replace`；由 batch kind 和 writer policy 决定。

**Verify**：

- 静态审计显示 authoritative history 路径没有直接 `setMessageList`；剩余调用全部是
  synthetic/compatibility allowlist；
- 生产 wiring 测试证明 local/cloud/older/newer/gap/realtime 各自只有一个 commit revision；
- 同一请求不会同时触发旧 merge 和新 writer merge；
- `flutter test test/message_reconciliation_production_wiring_test.dart test/group_gap_repair_integration_test.dart test/c2c_cloud_catch_up_continuation_test.dart` 通过。

### Step 6: 扩展持久 coverage 为可恢复 page/cursor ledger

在现有 `MessageHistoryCoverageStore` 上增加最小元数据，不复制正文：

```text
lastRequestGeneration
lastActualSource
lastBatchKind
requestedDirection
requestedAnchorMsgID / requestedAnchorSeq
returnedOldestMsgID / returnedNewestMsgID
olderCursor / newerCursor (opaque, nullable)
cloudHasMoreNewer
cloudVerifiedAt
coverageProofKind
```

Group 额外保存已验证 Seq ranges 和 unresolved ranges；C2C 保存 msgID 边界、cursor chain 和
boundary hole。只有 writer commit 成功且 generation/clearEpoch 仍有效时才持久化 coverage。
本地 snapshot 只能推进 local fields/status=provisional；云端实际证明且没有未解决 hole 才能
推进 verified。

迁移必须兼容现有 `message_history_coverage_v1.db`：旧行字段缺失时使用 unknown/null，
不能把默认 0 解释为已完成或云端证明。

**Verify**：

- 杀进程/重启后 coverage 能恢复并继续正确 cursor；
- 账号切换、clear epoch 和旧 generation 不会串写；
- C2C 不产生 Seq gap；Group 只对服务端 Seq 记录 gap；
- coverage 单测确认 stale revision/epoch 不可回写。

### Step 7: 建立 source-to-UI 端到端回归矩阵

新增或扩展以下测试，必须观察权威 commit/list，而不是只检查日志或源码字符串：

- cold open：local available/cloud slow；
- local empty/cloud available；
- offline cloud request 返回本地退化结果；
- latest window 与 local overlap；
- cloud empty while provisional；
- older page、newer continuation、group gap fill；
- realtime during every history generation；
- optimistic send adoption by server `msgID`；
- same Seq/different `msgID` conflict；
- clear history and stale response；
- Web local fallback semantics；
- account switch and app restart with persisted coverage；
- synthetic call/group rows do not change history coverage.

所有失败应提供脱敏 source、batchKind、generation、anchor hash 和 resultCount，禁止正文和
完整账号 ID。

**Verify**：运行 Commands 表中的 focused、continuity、analyze、format 和 hygiene 命令；
每个测试矩阵场景至少有一个可重复的自动化断言。真实双设备和 Web 浏览器矩阵仍需在发布
前执行，不能用静态测试替代。

## Test plan

- 新增 `test/message_history_batch_contract_test.dart`：envelope、provenance、cursor、
  tombstone、clear epoch 和 stale generation。
- 扩展 `test/chat_history_peek_policy_test.dart`：local-first、cloud empty、Web cloud
  fallback、provisional/verified 状态。
- 扩展 `test/message_reconciliation_writer_test.dart`：latestWindow range merge、pending
  realtime、optimistic adoption、same Seq conflict。
- 扩展 `test/message_reconciliation_production_wiring_test.dart`：所有 authoritative
  ingress 的单 revision 和 source/batch metadata。
- 使用 `test/group_gap_repair_integration_test.dart`、
  `test/c2c_cloud_catch_up_continuation_test.dart` 验证 104/106 的生产接线；如果计划执行时
  文件不存在，先按现有 `message_cloud_catch_up_test.dart` 和
  `message_reconciliation_writer_test.dart` 的 fake 风格创建，不能只做源码字符串测试。
- 账号隔离/coverage 使用 `test/message_history_coverage_test.dart` 作为结构样例。

## Done criteria

- [ ] 首屏在 Native 上优先从 SDK local snapshot 提交并释放 UI gate；云端校对在后台进行。
- [ ] Web 不伪造 local source；`LOCAL_*` 退化为 cloud 时 provenance 可观察。
- [ ] 所有 authoritative history/realtime/older/newer/gap 入口经过同一个 writer；剩余
      `setMessageList` 调用均有明确 synthetic/compatibility 说明。
- [ ] `latestWindow` 不盲目 replace；没有 tombstone 不删除窗口外本地消息。
- [ ] C2C 不使用 Group Seq 推断连续性；Group gap 有界且只由 writer 提交。
- [ ] coverage 能记录 source、cursor、bounds、continuation、hole、clear epoch，并在重启后恢复。
- [ ] stale generation/clear epoch/cloud fallback 不会覆盖当前 UI 或推进错误 coverage。
- [ ] focused tests、continuity tests、analyze、format、`git diff --check` 通过；环境阻塞已如实记录。
- [ ] 没有新增第二套消息正文 SQLite，也没有重新启用 archive fallback。
- [ ] `plans/README.md` 状态行已更新；Scope 外没有修改。

## STOP conditions

停止并报告，不要 improvisation：

- `MessageHistoryPeekLoader` 或腾讯 SDK 返回值无法区分 local/cloud，而产品又要求标记
  `cloudVerified`；此时只能保留 provisional/incomplete。
- 任何迁移步骤必须复制消息正文到第二个 app-owned 数据库才能完成。
- C2C 实现被迫使用跨发送者 Seq、时间间隔或列表位置证明全局连续性。
- 云端窗口没有明确 tombstone/删除证明，却要求删除窗口外本地消息。
- 发现某个 `setMessageList` 调用承担的是独立 UI synthetic projection，且没有可表达该语义的
  typed mutation；先扩大契约设计，不要强行归入历史 writer。
- 旧 generation 或 clear epoch 的响应仍能改变当前 list/coverage。
- focused 测试连续两次失败，或 Flutter 工具链仍被权限/服务阻塞；保留失败证据并停止。

## Maintenance notes

- 109 必须消费本计划输出的 committed message batch，而不是重新监听 SDK conversation
  callback 推导 lastMessage/unread；否则会重新形成双链路。
- 110/111 只能使用本计划持久化的 coverage/provenance/continuation 状态，不得再增加第三套
  unread 或 recovery 状态表。
- 后续 SDK 升级要重新确认 `CLOUD_*` 在异常网络下的 fallback 语义，以及 `isFinished`、
  `lastMsgID`、`lastMsgSeq` 的 cursor 契约；协议变化时先更新 batch adapter 和契约测试。
- 审查新消息入口时，必须回答四个问题：来源是什么、身份是什么、覆盖证明是什么、哪个
  writer revision 提交了它。只要有一个问题答不上来，就不能把入口当作 authoritative history。
