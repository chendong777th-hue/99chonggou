# Plan 104: 让群 Seq 补洞结果经唯一 Writer 进入消息列表

> **Executor instructions**: 严格按步骤执行，先写集成失败测试，再移除重复的
> `_fillGap` 旁路。禁止把 SDK 请求成功、marker 消失或日志出现当作消息已补齐。
> 命中 STOP 条件时停止并报告。完成后更新 `plans/README.md`。
>
> **Drift check（首先执行）**：
> `git diff --stat 9f7c46e..HEAD -- third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/gap_detector.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_coordinator.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_writer.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_cloud_catch_up.dart test/message_reconciliation_coordinator_test.dart test/message_reconciliation_writer_test.dart test/message_reconciliation_production_wiring_test.dart`
> 当前基于 dirty worktree；逐段核对下面的现场代码，禁止 reset、checkout 或覆盖他人修改。

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: 103；092 Steps 1-4 已完成的 reconciliation writer
- **Category**: bug / correctness / integration tests
- **Planned at**: commit `9f7c46e`, 2026-08-25（dirty worktree）

## Execution (2026-08-25)

- GlobalModel 的 Tencent 群 Seq gap 已统一走 bounded cloud reconciliation/writer，旧
  `_fillGap`/marker 旁路已移除；C2C 时间间隔不再由 `GapDetector` 证明为缺口。
- SeparateViewModel 仍保留面向 SelfHosted `ArchiveHistoryProvider` 的暖开
  `_fillGapsFromImCloud` 路径；它不属于本轮 Tencent reconciliation 入口，但会影响“所有
  群 Seq gap 唯一 Writer”的最终范围门禁，需在发布前单独审查，当前不将 104 标为全链路完成。
- 额外收敛 writer 的群判型：裸群/社群存储 key 由当前 `ConvType` 或消息 `groupID`
  显式证明，避免 `group_` 前缀猜测误把真实群当 C2C。
- 定向 `git diff --check` 通过；Flutter/Dart focused tests、analyze 和 format 受
  `/Users/qiu/flutter/bin/cache/engine.stamp` 权限阻塞，待操作员批准沙箱外重试。
- 双设备群聊矩阵与 092 Step 5 仍是发布门禁，当前不宣称完全完成。

## Why this matters

当前群消息补洞有两条生产路径：`reconcileConversationCloud` 会把 SDK 结果提交到
`completeHistoryReconciliation`，而 `_fillGap` 从上下边缘直接调用两次历史 API，
却丢弃两个返回值。后者随后用仍含 marker 的列表重新检测；`GapDetector` 会跳过
marker 相邻 pair，于是它可能认为 gap 已消失、删除 marker，即使任何缺失消息都没有
进入 `_messageListMap`。

这会制造“补洞成功”的假象。修复目标不是增加第三种拉取方式，而是让所有群 Seq gap
只走 092 已接线的云端对账和唯一 writer，并对云端确实找不到的 Seq 做有界、可观测的
终止裁决。

## Current state

已存在的正确提交路径：

```dart
final response = await _messageService.getHistoryMessageListWithComplete(...);
final commit = completeHistoryReconciliation(
  request: request,
  history: response.messageList,
  ...
);
```

`_fillGap` 当前旁路：

```dart
await _messageService.getHistoryMessageListWithComplete(...); // 返回值未使用
...
final stillHasGap = GapDetector.detectGaps(
  newestFirst: list,
  isGroup: isGroup,
  fullScan: true,
).any((g) => g.gapId == gap.gapId);
```

`GapDetector.detectGaps` 又有：

```dart
if (_isGapMarker(msgA) || _isGapMarker(msgB)) continue;
```

因此“marker 不再被 detector 报告”不等于“lowerSeq + 1 到 upperSeq - 1 已提交”。

另外两项现场事实：

- `setMessageList` 调 `detectGaps(fullScan: replace || previous.isEmpty)` 时没有传
  `seamIndex`，所以所谓局部扫描实际仍走全表。
- C2C 分支用时间间隔猜缺口，且 `_maxInternalGap` 包含候选间隔本身；时间空白既不是
  丢消息证明，该阈值实现也无法提供 Telegram `pts/difference` 式协议连续性。

## Baseline evidence

计划生成时尝试运行：

`flutter test test/message_cloud_catch_up_test.dart test/message_reconciliation_coordinator_test.dart test/message_reconciliation_writer_test.dart test/message_reconciliation_production_wiring_test.dart`

沙箱内被 Flutter 写 `/Users/qiu/flutter/bin/cache/engine.stamp` 的权限阻塞；沙箱外授权
自动审核服务返回 503，未获得新的通过证据。现有测试覆盖 controller 限次、writer
事务和静态生产接线，但没有证明 `_fillGap` 返回行会进入 `messageListMap`。

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Inventory | `git status --short` | 记录已有修改，不覆盖无关文件 |
| Search bypasses | `rg -n "_fillGap|GapFillCoordinator|getHistoryMessageListWithComplete|createGapMarker|detectGaps" third_party/tencent_cloud_chat_uikit/lib` | 每个 fetch/commit 责任明确 |
| Unit tests | `flutter test test/message_reconciliation_coordinator_test.dart test/message_reconciliation_writer_test.dart test/message_cloud_catch_up_test.dart` | 全部通过 |
| Production contract | `flutter test test/message_reconciliation_production_wiring_test.dart test/group_gap_repair_integration_test.dart` | 全部通过 |
| Analyze | `flutter analyze third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/gap_detector.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_coordinator.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_writer.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_cloud_catch_up.dart` | 相关文件无新增 error |
| Format | `dart format --output=none --set-exit-if-changed <changed Dart files>` | exit 0 |
| Hygiene | `git diff --check` | exit 0 |

## Scope

**In scope**：

- `tui_chat_global_model.dart` 的群 gap 发现、云端 catch-up 调用与 writer commit
- `gap_detector.dart` 的群 Seq 检测及遗留 marker/协调器清理
- `message_reconciliation_coordinator.dart`、`message_reconciliation_writer.dart`、
  `message_cloud_catch_up.dart` 中群缺口状态和有界终止所需的最小契约
- 对应 root `test/` 与 UIKit package tests

**Out of scope**：C2C 时间空白检测或完整性证明、可见 loading 分割线设计、SDK 升级、
消息发送、已读、历史清空协议、归档服务、Telegram 协议复制。C2C 续跑由 106 处理。

## Git workflow

- Branch: `codex/104-close-group-gap-repair-loop`
- 提交顺序：集成红测 -> 旁路删除 -> 单 writer 补洞 -> terminal/cooldown -> 性能契约。
- 不 push、不合并，除非操作员明确要求。

## Steps

### Step 1: 建立“SDK 行真正进入权威列表”的失败测试

新增 `test/group_gap_repair_integration_test.dart`，使用可控 fake history service 和真实
reconciliation writer/commit adapter，至少覆盖：

1. 当前列表有 Seq 100、103，SDK 对 `messageSeqList=[101,102]` 返回两行。
2. 完成后 `messageListMap` 或等价权威投影包含 100、101、102、103，各 msgID 一次。
3. history 请求期间实时到达 104，最终同一 writer revision 包含 101、102、104，旧 history
   completion 不覆盖实时行。
4. 重复 SDK 结果和重复 gap 触发不增加重复行或第二个并发 request。
5. stale/timeout completion 不提交。

测试必须观察实际 commit 输出或 production adapter，不能只断言源码包含方法名。

**Verify**：修复前测试稳定证明 `_fillGap` 请求结果未被提交，或证明当前生产入口无法
注入/观察；后者需要先提取最小可测 adapter，不得用纯字符串测试替代行为测试。

### Step 2: 删除直接 edge fetch 旁路

- `_fillGap` 不再自行 `findMessages` 后分别 CLOUD_OLDER/CLOUD_NEWER。
- 群 gap 统一调用 `reconcileConversationCloud(reason: 'seq_gap_<range>')`；由
  `_boundedMissingGroupSeqs` 生成 `messageSeqList`，由
  `completeHistoryReconciliation` 发布。
- 合并 reorder timeout、`setMessageList` 检测和已有 `_triggerGroupGapCatchUp` 的触发语义，
  最终只保留一个 per-conversation single-flight 入口。
- 删除无调用的 `GapFillCoordinator`；若仍需防重，使用 bounded catch-up 或 coordinator
  的 request generation，不保留第二套 in-flight map。

**Verify**：全仓不存在忽略 `getHistoryMessageListWithComplete` 返回值的 gap fetch；每个
生产补洞响应都能追到 `completeHistoryReconciliation`。

### Step 3: 只把群 Seq 当作 correctness gap

- `GapDetector` 的 correctness API 只对群消息比较有效 numeric Seq。
- C2C 时间间隔不再插入 gap marker，也不触发补洞；C2C 依赖 lastMsg/preview/cloud
  catch-up，并由 106 表达 incomplete 状态。
- local tip、time divider、optimistic row 和其他非服务端消息不能作为 Seq 相邻边界。
- history clear 边界若无法从 SDK 契约证明，不得跨边界虚构 missing Seq。

**Verify**：群 `100,103` 报 101-102；连续群 Seq 无 gap；C2C 相隔数天不被当作丢消息；
本地注入行不制造 gap。

### Step 4: 移除伪 marker，分离同步状态与消息数据

当前 `elemType: 11` marker 会被 `getMessageList` 的时间分割投影过滤，用户看不到注释
承诺的 loading；同时它会干扰 detector。执行以下收敛：

- 不再把 gap marker 写入 `messageListMap` 权威业务消息集合。
- gap 的 `loading/retry/unavailable` 状态保存在 reconciliation coordinator 诊断状态，
  不伪装成 `V2TimMessage`。
- 本计划不新增 UI。若产品要求可见补洞状态，另建 presentation 计划，消费 typed state。
- 删除 `createGapMarker/isGapMarker` 及相关过滤，前提是全仓无其他调用；否则先迁移调用。

**Verify**：补洞期间权威列表只包含 SDK/optimistic 合法消息；detector 不因 marker 跳过
真实相邻 pair；删除 marker 不改变时间分割线。

### Step 5: 为“云端找不到缺失 Seq”定义有界终点

同一 missing range 可能对应撤回、过期、清历史或服务端不可返回。不能每次 set/foreground
都立即重启三轮请求：

- 区分 `retryable`（offline、unknown、timeout、SDK transient error）和
  `cloudProvenUnavailable`（在线、明确请求 missing Seq、响应完成但目标 Seq 仍不存在）。
- retryable 保留 `needsCloudRetry`，只在已有恢复触发或有界 cooldown 后续跑。
- cloud-proven unavailable 记录范围、generation、尝试次数和脱敏原因，在同一周边
  upper/lower 证据未变化时不自动紧循环；新实时 Seq、重连或显式用户刷新可开新 generation。
- 不得把 unavailable 行伪造成完整消息，也不得删除 100 或 103 来制造连续。
- 每会话状态有范围/时间上限，route dispose/reset 时释放。

**Verify**：空 cloud-proven 结果到达上限后停止；offline 后 reconnect 会重试；出现 101
或 102 后旧 unavailable 状态收敛；无 Timer/状态无界增长。

### Step 6: 修正 seam 扫描契约

- 若 merge 层能提供真实 old/new join index，`fullScan:false` 时显式传 `seamIndex`，测试
  只检查半径内 pair。
- 若无法可靠给出 seam，删除“局部扫描”声明并显式全扫；不能传 false 却默认全扫。
- replace/search/reset 全扫；realtime append 的检测范围应固定且不随 160 条窗口线性增长。
- correctness 不能依赖性能优化，边界不确定时宁可在受限窗口内全扫。

**Verify**：测试构造 seam 内/外 gap，断言扫描范围与注释一致；大窗口提交不重复触发
同一 unavailable range。

### Step 7: 联合回归和双设备验收

运行定向测试后，用两个账号/设备验证：连续群消息、103 先到、离线后恢复、缺失 Seq
可返回、缺失 Seq 已撤回/不可返回、补洞期间实时到达、切会话/前后台。日志只记录
conversation hash、range、generation、source、resultCount 和 disposition，不记录正文、
完整用户 ID、UserSig。

**Verify**：缺失行可返回时无需离开重进即显示；不可返回时停止有界重试且列表不被
伪 marker 污染；消息顺序、未读、发送状态、滚动位置无回归。

## Done criteria

- [ ] 群 gap 只有一个 fetch/single-flight/commit 入口。
- [ ] SDK 返回的缺失行经 reconciliation writer 进入权威列表，各一次。
- [ ] history 与实时交错不覆盖或重复。
- [ ] C2C 时间间隔不再被当作协议缺口。
- [ ] gap 状态不再伪装为会被过滤的 `V2TimMessage`。
- [ ] retryable 与 cloud-proven unavailable 有明确有界策略。
- [ ] seam 扫描行为与 API/注释一致。
- [ ] focused tests、定向 analyze、format、diff check 通过。
- [ ] 双设备群聊矩阵通过并留存脱敏日志。
- [ ] Scope 外无修改（计划索引除外）。

## STOP conditions

- 092 的 single writer 或 production commit wiring 已被移除/绕过。
- SDK 目标平台不支持 `messageSeqList` 或无法区分 cloud 与 local fallback。
- 同一 Seq 对应不同 msgID；两条都保留并升级协议调查。
- 只能通过删除周边真实消息、伪造消息或无限重试让 range 变连续。
- history clear/撤回边界无法证明，且实现准备擅自标为完整。
- 任何测试出现消息顺序、发送状态、未读、搜索锚点或滚动位置回归。

## Maintenance notes

“发过请求”不是补洞完成条件；唯一完成证据是目标 msgID/Seq 已由 writer 提交，或在线
云端明确返回 unavailable 并进入有界终态。未来新增任何 recovery/gap 入口，都必须复用
同一个 coordinator generation 和 writer transaction，不能直接写 `_messageListMap`。
