# Plan 051: C2C 补旧按 lastMsg / 时间接页，不得用群 seq 裁脊柱

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt below to the live files. If C2C cloud peek
> already trusts all accumulated IDs (not only `localOnly`), or
> `shouldMergeOlderPage` already has a `useSeqContiguity: false` path used by
> `_fillTowardOlderHistory` for C2C, mark those steps DONE / adjust and
> report — do not duplicate.

## Status

- **Priority**: P0
- **Status note**: 已完成（working tree 2026-08-22）
- **Effort**: M
- **Risk**: MED（群历史仍必须按 seq 裁脊柱 / 拒月份级旧本地；C2C 必须还能用 lastMsg 往上接页；049 retain / 018 swap / 050 别名 commit 必须保持绿）
- **Depends on**: plans/050-alias-aware-older-history-commit.md（已完成，必须保持绿）；plans/049-retain-acked-self-across-history-pages.md（已完成，必须保持绿）；plans/018-outgoing-image-dual-bubble.md（已完成，必须保持绿）
- **Category**: bug
- **Planned at**: working tree 2026-08-22（NO_GIT）
- **Issue**: omit

## Why this matters

050 之后 newest tip 不再被 20 条旧页盖掉。用户复现（`docs/控制台输出.md`，会话 `c2c_rqwm8onw3j`，过滤 `[OutgoingVisible]`）：**最后约 20 条对，20 条之前不对。**

1. 进页第一下 `replace` 成 21 条（SDK 无 `lastMsg` 的最新页），newestSelf=`…4104329943`（图，`seq=3347538080`）。这是对的。
2. 随后 `21→33`（`replace=false` 每次 +1）再后台补旧 `33→42→62→…`。第一页旧历史只净增 **9** 条（33→42），不是「紧挨着的上一页约 20 条」。
3. 同一 C2C 里后来发出的字是 `seq=2220862942`。两套 seq 差约 10 亿——这是腾讯 C2C **按发送方各自编号**，不是群那种会话单调 seq。

代码已经知道这一点：`compareMessagesChronological` 对 C2C **不用** seq。但补旧仍把 C2C 当群：`keepNewestContiguousSpine` 见 `newerSeq - olderSeq > 1` 就裁；`shouldMergeOlderPage` / `connects` 用整窗 `minSeq/maxSeq`。结果是两种失败叠在一起：

- 合法上一页（时间紧挨、seq 空间不同）被 **拒**（`newerMinSeq - olderMaxSeq` 远大于 `pageSize+1`）。
- 对不上的旧页因两套 seq **区间重叠**（`newerMinSeq <= olderMaxSeq`）被 **焊上**。

产品意图：C2C 往上补旧只认 **SDK `lastMsg` 链 + 时间/msgID 重叠**。群路径保持现有 seq 脊柱。最新 20 条下面必须是真正的上一页，不能跳、不能焊另一截。

## Current state

聊天列表是 **newest-first 反转列表**。不要翻转。018 / 045 / 049 / 050 已落地，不要回滚。

**排序已经按 C2C 不用 seq（不要改）** —
`third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart` `compareMessagesChronological`（约 6693–6702）：

```dart
    // In C2C chats seq is per-sender and NOT chronological, so it must not be used
    // here — fall through to timestamp ordering instead.
    final aGroupSeq = !aLocalTimeline && _hasGroupSeqOrdering(a);
    final bGroupSeq = !bLocalTimeline && _hasGroupSeqOrdering(b);
```

**Peek 只在 localOnly 的 C2C 避开 seq 裁脊柱** —
`third_party/tencent_cloud_chat_uikit/lib/data_services/message/message_history_peek_loader.dart` `_loadOlderPagedImpl`（约 219–235）：

```dart
      // C2C 的 seq 按发送方各自编号，冷启动只读本地时不能按群 seq 连续性裁脊柱，
      // 否则库里已有的十几条会只剩最新 1 条，首屏干等云端。
      if (localOnly && _isC2c(userID: userID, groupID: groupID)) {
        for (final message in accumulated) {
          final id = _messageId(message);
          if (id.isNotEmpty) {
            trustedIds.add(id);
          }
        }
      }
      spine = RoamingContiguousWindow.keepNewestContiguousSpine(
        ascending: accumulated,
        trustedIds: trustedIds,
        idOf: _messageId,
        seqOf: _messageSeq,
        timestampSecOf: _timestampSec,
      );
```

`_fillTowardOlderHistory` 走的是 `loadOlderLocalThenCloudResult`（`localOnly: false`）。未进 trusted 的本地条跨发送方 seq 会被 `keepNewestContiguousSpine` 裁掉，`takeNewest(spine, count)` 交出去的就不是完整上一页。

`_fetchBatchWithComplete`（约 365–399）也会算 spine，但 **`messageList` 返回的是 `union`**。真正裁窗的是上面这段外层循环。不要去「改成返回 spine」当本计划修复。

**SDK：C2C 只能用 `lastMsg`，不能用 `lastMsgSeq`** —
`third_party/tencent_cloud_chat_sdk/lib/manager/v2_tim_message_manager.dart`（约 870–877）：

```
- 拉取 C2C 消息，只能使用 lastMsg 作为消息的拉取起点
- 如果同时指定了 lastMsg 和 lastMsgSeq，SDK 优先使用 lastMsg
```

`_fillTowardOlderHistory`（约 2073–2094）仍把 C2C 的 `oldest.seq` 传进 `lastMsgSeq`，并用默认 `shouldMergeOlderPage`（seq 门禁）：

```dart
      final peek = await MessageHistoryPeekLoader.loadOlderLocalThenCloudResult(
        messageService: _messageService,
        count: fetchCount,
        userID: userID,
        groupID: groupID,
        lastMsgID: oldest.msgID,
        lastMsgSeq: int.tryParse(oldest.seq?.toString() ?? '') ?? -1,
        lastMsg: oldest,
      );
      final canMerge = RoamingContiguousWindow.shouldMergeOlderPage(
        newer: existingAsc,
        older: peek.messageList,
        pageSize: fetchCount,
        idOf: _historyMessageId,
        seqOf: HistoryPaginationAnchor.messageSeq,
        timestampSecOf: _historyTimestampSec,
      );
```

**`shouldMergeOlderPage` / `connects` 把 C2C 两套 seq 当成一条会话轴** —
`third_party/tencent_cloud_chat_uikit/lib/ui/utils/roaming_contiguous_window.dart`：

- `connects`（约 285–294）：`newerMinSeq <= olderMaxSeq` 直接 true。C2C 窗里同时有 `2.2B` 和 `3.3B` 时，月份级旧页也会「连得上」。
- `shouldMergeOlderPage`（约 157–168）：两边都有 seq 且 `newerMinSeq > olderMaxSeq` 时，只允许差 `pageSize+1`。合法 C2C 上一页（自己 seq 2.2B、当前窗 min 3.3B）会被拒。
- `keepNewestContiguousSpine`（约 329–336）：相邻 `newerSeq - olderSeq > 1` 且 older 不在 `trustedIds` → `break`。

群用例必须保持：`third_party/tencent_cloud_chat_uikit/test/roaming_contiguous_window_test.dart` 的「近云端页接受 / 月份级旧本地拒绝」以及 `message_history_peek_loader_test.dart` 里 **`groupID: 'g1'`** 的短云页补洞。

**050 commit 口径（不要改）** —
`_mergeWithInMemoryHistory` / `_commitHistoricalMessages` 已用 `mergedAliasMessageList`，补旧 `replace: true`。`_storageConversationId` 仍剥 `c2c_`。

**进页 `21→33` +1** 很像 `CallBubbleInsertService._rehydrateMaxRecords = 12`。本计划 **不修** 通话气泡回灌。那是另案。

**约定（照着写）**

- 新参数默认必须保持群行为：`useSeqContiguity: true`（或等价「不传 = 群」）。
- C2C 判定与 peek 现有 `_isC2c` 一致：`userID` 非空且 `groupID` 空。
- 契约测试风格：`third_party/tencent_cloud_chat_uikit/test/roaming_contiguous_window_test.dart` 的 `_Msg`；`message_history_peek_loader_test.dart` 的 `_msg` / `_FakeHistoryService`。
- `[OutgoingVisible]` 探针留下，不要删。

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| 本计划窗/peek 契约 | `flutter test third_party/tencent_cloud_chat_uikit/test/roaming_contiguous_window_test.dart third_party/tencent_cloud_chat_uikit/test/message_history_peek_loader_test.dart` | all pass |
| 050 + 049 + 018 不得回退 | `flutter test test/conversation_message_cache_key_test.dart test/sender_own_sent_visible_contract_test.dart test/conversation_preview_history_sync_test.dart test/outgoing_image_bubble_dedupe_contract_test.dart test/chat_media_optimistic_send_contract_test.dart test/message_ordering_test.dart` | all pass |
| 触及文件静态检查 | `flutter analyze --no-fatal-infos --no-fatal-warnings <touched files>` | exit 0（info/warning OK） |

本工作区可能**没有 `.git`**。不要 `git init`。不要 push。

单独分析 UIKit 分模型文件可能因 `tencent_cloud_chat_demo` URI 报既有错。以 **app 测试套件** 和上表 UIKit **单测文件** 为准，不要为隔离错误去改 package 边界。

## Suggested executor toolkit

- 用 `RoamingContiguousWindow.shouldMergeOlderPage` / `keepNewestContiguousSpine` 写**真实单测**，不要只扫源码字符串。
- 宿主不能派 SubAgent 时，在主会话直接改。

## Scope

**In scope**（只改这些）：

- `third_party/tencent_cloud_chat_uikit/lib/ui/utils/roaming_contiguous_window.dart`
  — `shouldMergeOlderPage`、`connects`（仅加默认 true 的 `useSeqContiguity`；false 时不看 seq，只看 msgID 重叠 + 时间窗）
- `third_party/tencent_cloud_chat_uikit/lib/data_services/message/message_history_peek_loader.dart`
  — C2C（含 cloud，不限 `localOnly`）把 accumulated id 标 trusted；C2C 打 SDK 时 `lastMsgSeq` 固定 `-1`（仍传 `lastMsg` / `lastMsgID`）
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
  — `_fillTowardOlderHistory`：C2C 调 `shouldMergeOlderPage(..., useSeqContiguity: false)`；C2C `lastMsgSeq: -1`（与 peek 内清零重复也可以，必须至少一处对 C2C 生效）
- `third_party/tencent_cloud_chat_uikit/test/roaming_contiguous_window_test.dart`（扩展）
- `third_party/tencent_cloud_chat_uikit/test/message_history_peek_loader_test.dart`（扩展）
- `plans/README.md`（本行状态）

**Out of scope**（即使看起来相关也禁止动）：

- `_storageConversationId` 剥前缀、050 `mergedAliasMessageList` commit、`replace: true`
- 049 retain 谓词、trim restore、暖调度 `shouldSkipMemoryFillForOpenChat`
- 018 关联 key / `_swapOutgoingMessage` / FIFO 猜图
- 045 pin / await `reloadNewest` / C2C `isSelf` 镜像
- `compareMessagesChronological` / `_hasGroupSeqOrdering`（已经对 C2C 不用 seq）
- `ChatMessageWindowPolicy` 120/160
- `CallBubbleInsertService` / `call_bubble_normalize` / 进页 +1 回灌
- 关掉 `_fillTowardOlderHistory`、改 `initialOpenFetchCount`、改群 `keepNewestContiguousSpine` 默认语义
- `absorbOlderBatch` / `mergeLocalCloudTakeNewest` 的默认参数（除非为编译必须把 `useSeqContiguity` 默认 true 往下传；**不要**改群测试期望）
- 钱包、通话音频、未读语义、搜索 API

## Git workflow

- 本工作区常无 `.git`。有 git 时分支名 `advisor/051-c2c-older-history-no-seq-spine`。
- 不要 push / 不要开 PR，除非操作员明确要求。
- 不要 `git init`。

## Steps

### Step 1: `shouldMergeOlderPage` / `connects` 增加 C2C 开关

在 `roaming_contiguous_window.dart` 给 `shouldMergeOlderPage` 和 `connects` 增加：

```dart
bool useSeqContiguity = true,
```

默认 **true**。现有群测试不改调用即可绿。

`useSeqContiguity == false` 时：

1. `connects` **只**用 msgID 重叠（现有 `newerIds.contains`）。不要走 `newerMinSeq <= olderMaxSeq` / `== 1` / `olderCloudBacked` 的 seq 分支。
2. `shouldMergeOlderPage`：先 `connects(..., useSeqContiguity: false)`；若 false，再用**现有**「无 seq」时间分支（约 161–167）：`newerMinTs - olderMaxTs` 在 `(0, roamingCoverageDays * 86400]` 则 true。时间重叠（`olderMaxTs >= newerMinTs` 且差不超过同一 90 天上限）也视为可接（同秒 / 上一页与窗边缘重叠）。**不要**再跑 `seqPageSlack`。

群默认路径一行都不要改逻辑。

在 `roaming_contiguous_window_test.dart` 增加（用 `_Msg`）：

1. **C2C 合法上一页**：newer `seq=3347538080..3347538099`, `ts=20000..20019`；older `seq=2220862940..2220862959`, `ts=19980..19999`；无共享 id。`shouldMergeOlderPage(..., pageSize: 20)` 默认（群）为 **false**（seq 差远大于 21）。`useSeqContiguity: false` 为 **true**。
2. **C2C 月份级断开**：older `ts=1000..1019`（相对 newer 超过 90 天），seq 仍是两套空间。`useSeqContiguity: false` 为 **false**。
3. 现有 `shouldMergeOlderPage accepts a near cloud page and rejects months-old local` **保持绿**（不传新参数）。

**Verify**: `flutter test third_party/tencent_cloud_chat_uikit/test/roaming_contiguous_window_test.dart` → all pass，含新用例。

### Step 2: Peek loader — C2C 云补旧也信任 accumulated id；C2C `lastMsgSeq=-1`

在 `message_history_peek_loader.dart`：

1. 把

```dart
if (localOnly && _isC2c(userID: userID, groupID: groupID)) {
```

改成

```dart
if (_isC2c(userID: userID, groupID: groupID)) {
```

注释改成：C2C seq 按发送方编号；**本地或云端**都不能按群 seq 裁脊柱，否则上一页会被切成不连续的一小截。

2. 凡打到 `getHistoryMessageListWithComplete` 的 C2C 请求，`lastMsgSeq` 传 **-1**。仍传 `lastMsg` / `lastMsgID`。外层翻页游标的 seq 在 C2C 也当作 -1（不要用 `oldest.seq` 再问 SDK）。群路径继续传真实 `cursorSeq`。

在 `message_history_peek_loader_test.dart` 增加（照现有 `_FakeHistoryService` / `_msg`，**必须 `userID:` 非空且不要 `groupID`**）：

- 构造 20 条「上一页」：偶数条 `seq=2220862940+i`，奇数条 `seq=3347538000+i`，`timestamp` 连续递增且都小于锚点。
- `localPages` / `cloudPages` 在 `lastMsgID == 锚点 msgID` 时返回这 20 条（cloud 可与 local 相同，或 cloud 少几条、local 补齐）。
- `loadOlderLocalThenCloudResult(count: 20, userID: 'alice', lastMsgID: 锚点, lastMsg: 锚点消息)`。
- 期望：`messageList.length == 20`，20 个 msgID 都在，**不是**只剩最新 1～几条。
- 现有 `groupID: 'g1'` 用例期望一字不改。

若假服务按 `lastMsgSeq` 分桶：C2C 调用必须在 `lastMsgSeq == -1`（或 `<= 0`）时仍能命中上一页；不要要求 C2C 带上 `3347538080` 才能取到页。

**Verify**: `flutter test third_party/tencent_cloud_chat_uikit/test/message_history_peek_loader_test.dart` → all pass。读源码：C2C trusted 循环不再被 `localOnly &&` 包住；C2C fetch 的 `lastMsgSeq` 为 -1。

### Step 3: `_fillTowardOlderHistory` 对 C2C 关闭 seq 门禁

在 `tui_chat_separate_view_model.dart` 的 `_fillTowardOlderHistory`：

- `conversationType == ConvType.c2c`（或 `userID != null && groupID == null`，与 peek `_isC2c` 同义）时：
  - `lastMsgSeq: -1`
  - `shouldMergeOlderPage(..., useSeqContiguity: false)`
- 群：保持现在的 `lastMsgSeq` 解析 + 默认 `useSeqContiguity`。

不要改 `mergedAliasMessageList`、`replace: true`、`oldestSdkPaginationAnchor`、`_commitHistoricalMessages`。

可选：在 `test/sender_own_sent_visible_contract_test.dart` 源码扫描 `_fillTowardOlderHistory` 段，断言含 `useSeqContiguity: false` 与 C2C `lastMsgSeq: -1`。已有 050 扫描风格就沿用；没有也不要新开无关文件。

**Verify**: 读 `_fillTowardOlderHistory`：C2C 两处都已改。`flutter test test/sender_own_sent_visible_contract_test.dart` → pass。

### Step 4: 回归 018 / 045 / 049 / 050 与群 peek

跑 Commands 表第二行 + Step 1/2 的 UIKit 测试。不要改那些测试期望来迁就 C2C。

对照日志（用单测等价，不必真机）：

| 日志 / 现象 | 修复后单测必须保证 |
|-------------|-------------------|
| 最后 20 条对、再往上不对 | C2C 上一页（时间连续、seq 两套）`shouldMerge(useSeqContiguity: false)==true`，默认群门禁仍可 false |
| `33→42` 只 +9 | C2C peek `userID` + 跨发送方 seq 的 20 条旧页完整返回 |
| 月份级旧本地焊上 | `useSeqContiguity: false` 且时间差 > 90 天 → false（群「拒月份级旧本地」仍绿） |
| 050 tip 被旧页盖掉 | 050 套件仍绿；本计划不改 commit existing |

**Verify**: Commands 表三行全部绿。

## Test plan

新/扩测试（最低）：

1. `shouldMergeOlderPage`：C2C 两套 seq + 时间相邻 → 仅 `useSeqContiguity: false` 为 true；月份级断开为 false；群近页/旧本地用例不改。
2. `MessageHistoryPeekLoader`：`userID` C2C、`lastMsg` 锚、20 条跨发送方 seq 的上一页完整返回；`groupID: 'g1'` 短云页补洞仍绿。
3. 018 / 049 / 050 套件不回退。

模式：`roaming_contiguous_window_test.dart`、`message_history_peek_loader_test.dart`。

## Done criteria

- [x] Step 1–4 的 Verify 命令均为绿
- [x] `shouldMergeOlderPage` / `connects` 新参数默认 true；群测试未改期望
- [x] Peek C2C 在 **非** `localOnly` 时也把 accumulated id 标 trusted
- [x] C2C 打 SDK 的 `lastMsgSeq` 为 -1；仍传 `lastMsg` / `lastMsgID`
- [x] `_fillTowardOlderHistory` 对 C2C 使用 `useSeqContiguity: !isC2cFill`（C2C 为 false）
- [x] 未改 `_storageConversationId`、049 retain、018 key、050 commit、120/160、`compareMessagesChronological`、通话气泡回灌
- [x] 未改 in-scope 以外的文件
- [x] `plans/README.md` 本行改为已完成或按评审者要求保持 TODO

## STOP conditions

- 「当前状态」摘录已对不上（C2C cloud 已 trust-all，或 `shouldMergeOlderPage` 已有等价开关且 fill 已接上）。
- 某步 Verify 连续失败两次。
- 修复看起来必须改 018 correlate、关掉 retain、改 `_storageConversationId`、停掉 `_fillTowardOlderHistory`、或改群 `keepNewestContiguousSpine` 默认语义才能过测试。
- 为让 C2C 绿而改红 `groupID: 'g1'` peek 用例，或改红「近云端页接受 / 月份级旧本地拒绝」。
- `useSeqContiguity: false` 在时间差超过 `roamingCoverageDays` 时仍合并（焊月份级两截）。
- `mergeHistoricalWithInMemory` 的列表**不是** newest-first。
- `mergedAliasMessageList` 被改得并进**其它会话**。

## Maintenance notes

- 之后任何「用 `RoamingContiguousWindow` seq 判断能不能接页」的新路径，对 C2C 必须传 `useSeqContiguity: false` 或走 peek 的 C2C trusted-all。群继续默认 seq。
- 评审重点：最新 20 条下面是时间上的上一页；群短云页仍丢月份级旧本地；050 tip 不变；用户上滑仍能接页。
- **推迟（不要在本计划做）**：进页 `21→33` 的 +1（通话气泡回灌 / 其它单条 insert）。050 skip bootstrap 拼 `lastMessage`。发送 `signature_unchanged` 丢掉预插入。
- 真机复核（操作员，非本计划门禁）：对 `rqwm8onw3j` 进页确认最新约 20 条 → 等补旧或上滑 → **紧挨着的上一页**是当时真实对话（不是跳号/另一截）；newest tip 仍是进页那条。
