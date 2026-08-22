# Plan 050: 补旧历史必须按别名读窗，不得把 20 条旧页盖掉 newest tip

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt below to the live files. If
> `_mergeWithInMemoryHistory` already uses `mergedAliasMessageList`, or
> `_commitHistoricalMessages` already commits the full merged window with
> `replace: true`, mark those steps DONE / adjust and report — do not duplicate.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED（补旧必须还能往上接页；不得把 `_storageConversationId` 改回带 `c2c_`，SDK/归档要裸 userID；049 retain / 018 swap 必须保持绿）
- **Depends on**: plans/049-retain-acked-self-across-history-pages.md（已完成，必须保持绿）；plans/018-outgoing-image-dual-bubble.md（已完成，必须保持绿）
- **Category**: bug
- **Planned at**: working tree 2026-08-22（NO_GIT）
- **Issue**: omit

## Why this matters

049 之后发送者 tip 仍会「变历史」：进页时 newestSelf 是刚发的 `9`，后台补旧几轮后变成更早的 `0` / `11111`。复现日志（`docs/控制台输出.md`，会话 `c2c_rqwm8onw3j`，过滤 `[OutgoingVisible]`）：

1. 进页前 / 进页时内存已有 20→32 条，newestSelf=`9`（msgID `…2245723238`，ts=1787389303）。
2. `enter_bootstrap_decision` 的 `lastMessage` 是另一条 `0`（`…2245723239`）。随后 `scheduleWarmOpenHistoryReconcile` 启动往旧处补页。
3. 补旧 commit：`set_list_merge_retain incomingCount=20`，incoming newestSelf=`2`（ts=1787388721，旧页）；`prevCount` 却是别名上的真列表（20/48），prev newestSelf=`9`。`retainCount=8/39/49` 回收的是 8721–8747 那一簇旧自己消息，**不含** `9`。
4. `set_list_committed` 后 newestSelf 变成 `0` 或 `11111`。`mark_initial_history_loaded conv=rqwm8onw3j`（裸 userID）而 `set_list_* conv=c2c_rqwm8onw3j`。

根因不是 049 retain「没跑」，而是 **UIKit 分模型用裸 `rqwm8onw3j` 读 `messageListMap[conversationID]`，读空后只把 20 条旧页交给 `setMessageList`**。`setMessageList` 经 `canonicalHistoryStorageKey` / `_mergedAliasMessageList` 找到 `c2c_` 真窗，再 `replace: false` 把旧页和真窗拼在一起。049 retain 按「比 incoming 这页新」回收自己消息，真 tip 一旦被 `messagesCorrelateForDedup` 判成 covered，旧簇就被抬到 newest 端。用户看到的就是历史记录在变。

产品意图：后台补旧只能**在 newest 端之下加更早的页**，不得改写或替换当前 newest tip。

## Current state

聊天列表是 **newest-first 反转列表**。不要翻转。049 / 045 / 018 已落地，不要回滚。

**分模型故意存裸 ID（不要改这个函数的剥前缀）** —
`third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`

`init`（约 648–650）与 `_storageConversationId`（约 1269–1288）：

```dart
// 消息列表 / hydrate / 归档一律用裸会话 ID（@TGS#…），勿带 group_。
conversationID = _storageConversationId(convID);

static String _storageConversationId(String? raw) {
  // … group_ / c2c_ / GROUP / C2C 前缀剥掉，C2C 变成裸 userID
}
```

SDK / 归档 API 的 `userID` 必须是裸 id。**禁止**为修本 bug 让 `conversationID` 改回 `c2c_…`。

**补旧读窗用了别名，commit 合并没有** —
同文件 `_fillTowardOlderHistory`（约 2062–2066）已经 `messageListMap[convId] ?? rawMessageList(convId)`。`rawMessageList` 是别名感知的，所以**能**从 `c2c_` 取到 32/48 条、算出 oldest 锚、拉到更旧的 20 条。

但 `_mergeWithInMemoryHistory` / `_commitHistoricalMessages`（约 1390–1436）只读 **`messageListMap[conversationID]`**（裸 key，常为 null）：

```dart
List<V2TimMessage> _mergeWithInMemoryHistory(List<V2TimMessage> fetched) {
  return TUIChatGlobalModel.mergeHistoricalWithInMemory(
    existing: globalModel.messageListMap[conversationID],
    fetched: fetched,
  );
}

void _commitHistoricalMessages(...) {
  final merged = replaceWithPeekWindow
      ? TUIChatGlobalModel.mergePeekWindowWithLiveMemory(
          existing: globalModel.messageListMap[conversationID],
          fetched: fetched,
        )
      : _mergeWithInMemoryHistory(fetched);
  globalModel.setMessageList(
    conversationID,
    merged,
    needResetNewMessageCount: false,
    replace: replaceWithPeekWindow, // 补旧为 false → incoming 只有 20 条旧页
  );
}
```

`existing == null` 时 `mergeHistoricalWithInMemory` 直接返回 fetched（20 条旧页）。然后 `setMessageList(bareId, those20, replace: false)`。

**`setMessageList` 写的是别名合并后的真窗** —
`third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`

- `canonicalHistoryStorageKey`（约 1909–1923）：C2C → `c2c_<uid>`。
- `_mergedAliasMessageList` / 公开的 `mergedAliasMessageList`（约 1940–1958）：合并所有 `isSameConversationIdForHistory` 桶。
- `setMessageList`（约 6018–6026）：`previous = _mergedAliasMessageList(...)`；`!isDeleteMsg && previous.isNotEmpty` 时跑 049 的 `collectUncorrelatedInFlightOutgoing`。
- `rawMessageList`（约 2329–2363）：别名感知读；**空 list** 会继续找非空别名。

分页加载已经用对了：`tui_chat_history_pagination_load.dart` 约 956–958：

```dart
List<V2TimMessage> _aliasAwareInMemoryList(TUIChatSeparateViewModel model) {
  return model.globalModel.mergedAliasMessageList(model.conversationID);
}
```

补旧 / peek commit **没有**走这条。这就是要对齐的口径。

**049 retain 在 incoming=旧页时会抬旧 tip** —
`collectUncorrelatedInFlightOutgoing`：自己消息、incoming 未关联、且 *SENDING* 或比 **incoming 里时间上最新的一条**更新。incoming 是 20 条旧页时，几乎所有更晚的自己消息都进 extras。真 tip 若被 `messagesCorrelateForDedup` 判 covered，就不会进 extras，sort 后 newestSelf 变成 extras 里次新的旧自己（日志里的 `0` / `11111`）。**不要改 retain 谓词、不要改 018 correlate。** 修好 existing 之后 incoming 应是「真窗 ∪ 旧页」，retainCount 对已在 incoming 里的 tip 应为 0。

**进页 skip** —
`lib/src/chat.dart` 约 4032–4047：`canSkipOpenRebootstrap` 为 true 时不跑 `ChatHistoryPeekBootstrap.apply`，只 `scheduleWarmOpenHistoryReconcile()`。`isPreviewAheadOfCachedHistory`（049）在 `isMessageVisibleInList` 为 false 时已是领先；`isSameMessage` 仍走 `messagesCorrelateForDedup`。本计划**不改** correlate。只加一条契约：同秒不同 SDK msgID 的 `0` vs `9` 必须 `isPreviewAhead == true`。若现网已绿，本步只留测试。

**静默归档 `sublist(0, n)`** 仍是 newest-first 头切。不要改切向。

**约定（照着写）**

- 读内存窗：`globalModel.mergedAliasMessageList(conversationID)` 或 `rawMessageList`。禁止在 commit/merge 路径写 `messageListMap[conversationID]` 当 existing。
- 会话相等：`TUIChatGlobalModel.isSameConversationIdForHistory` / `canonicalHistoryStorageKey`。禁止手剥 `c2c_` 后再去 map 里取列表。
- 契约测试风格：`test/conversation_message_cache_key_test.dart`、`test/sender_own_sent_visible_contract_test.dart`、`test/message_ordering_test.dart` 的 `_msg`。
- `[OutgoingVisible]` 探针留下，不要当修复手段，也不要删。

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| 本计划契约 | `flutter test test/conversation_message_cache_key_test.dart test/sender_own_sent_visible_contract_test.dart test/conversation_preview_history_sync_test.dart` | all pass |
| 049 + 018 不得回退 | `flutter test test/sender_own_sent_visible_contract_test.dart test/outgoing_image_bubble_dedupe_contract_test.dart test/chat_media_optimistic_send_contract_test.dart test/message_ordering_test.dart` | all pass |
| 触及文件静态检查 | `flutter analyze --no-fatal-infos --no-fatal-warnings <touched files>` | exit 0（info/warning OK） |

本工作区可能**没有 `.git`**。不要 `git init`。不要 push。

## Suggested executor toolkit

- 用 `TUIChatGlobalModel.mergeHistoricalWithInMemory` + `mergedAliasMessageList` 写**真实单测**，不要只扫源码字符串。
- 宿主不能派 SubAgent 时，在主会话直接改。

## Scope

**In scope**（只改这些）：

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
  — `_mergeWithInMemoryHistory`、`_commitHistoricalMessages` 的 existing；补旧 commit 改为写入**已 merge 的全表**且 `replace: true`；`_fillTowardOlderHistory` 读 existing 改为 `mergedAliasMessageList`（不要 `messageListMap[convId] ??`，空 list 会挡住别名）
- `test/conversation_message_cache_key_test.dart`（扩展）和/或 `test/sender_own_sent_visible_contract_test.dart`（扩展）
- `test/conversation_preview_history_sync_test.dart`（只加「同秒不同 msgID 的 lastMessage 仍领先」；现网已绿则只留测试）
- `plans/README.md`（本行状态）

**Out of scope**（即使看起来相关也禁止动）：

- `_storageConversationId` 的剥前缀行为（SDK `userID` / 群短码依赖它）
- 049 `collectUncorrelatedInFlightOutgoing` 谓词、trim 后 restore、暖调度 `shouldSkipMemoryFillForOpenChat`
- 018 关联 key / `_swapOutgoingMessage` / FIFO 猜图
- 045 pin 别名、发送栈 await `reloadNewest`、C2C `isSelf` 镜像
- `ChatMessageWindowPolicy` 120/160
- `messagesCorrelateForDedup` / `_c2cCrossSourceCorrelate` / `_c2cPreviewEchoCorrelate`
- `call_bubble_normalize`（日志 28→26 是通话气泡去重，另案）
- 关掉 `_fillTowardOlderHistory` / 取消上翻历史
- 钱包、通话、未读语义、搜索 API

## Git workflow

- 本工作区常无 `.git`。有 git 时分支名 `advisor/050-alias-aware-older-history-commit`。
- 不要 push / 不要开 PR，除非操作员明确要求。
- 不要 `git init`。

## Steps

### Step 1: merge / peek existing 必须别名感知

在 `tui_chat_separate_view_model.dart` 把

```dart
existing: globalModel.messageListMap[conversationID]
```

从 `_mergeWithInMemoryHistory` 与 `_commitHistoricalMessages` 的 `mergePeekWindowWithLiveMemory` **两处**改成：

```dart
existing: globalModel.mergedAliasMessageList(conversationID)
```

`_fillTowardOlderHistory` 里取 existing 的

```dart
globalModel.messageListMap[convId] ??
    globalModel.rawMessageList(convId) ??
    const <V2TimMessage>[]
```

改成：

```dart
globalModel.mergedAliasMessageList(convId)
```

不要改文件里其它 `messageListMap[...]`（hydrate / preview / 锚点解析不在本计划）。

在 `test/conversation_message_cache_key_test.dart` 或 `test/sender_own_sent_visible_contract_test.dart` 增加（需要 `setupServiceLocator` 时照 `conversation_preview_history_sync_test.dart`）：

1. `setMessageList('c2c_alice', [tipSelf ts=200, ...older], replace: true)`。
2. `messageListMap['alice']` 为 null 或空；`mergedAliasMessageList('alice')` 含 tip。
3. `mergeHistoricalWithInMemory(existing: messageListMap['alice'], fetched: 20条 ts<=100)` 的结果**不含** tip（这是当前 bug 的对照，断言「裸桶 existing 会丢掉 tip」）。
4. `mergeHistoricalWithInMemory(existing: mergedAliasMessageList('alice'), fetched: 同一 20 条)` 的结果**仍含** tip，且 newest-first 头是 tip。

**Verify**: `flutter test test/conversation_message_cache_key_test.dart test/sender_own_sent_visible_contract_test.dart` → all pass，含新用例。读源码确认 `_mergeWithInMemoryHistory` 已无 `messageListMap[conversationID]`。

### Step 2: 已 merge 的全表用 replace: true 写入

`_commitHistoricalMessages` 在 existing 修好后，`merged` 已是「别名真窗 ∪ fetched」。此时再 `replace: false` 会把全表当 incoming 再和 previous 拼一次（日志那种 `incomingCount=20` 应消失；即使 incoming 已是全表，二次 concat 也无益）。

把

```dart
replace: replaceWithPeekWindow,
```

改成 **`replace: true`**（两个分支都已经产出完整窗：peek merge 或 historical merge）。不要传 `memoryWindowPreferLatest: true`。不要改 `needResetNewMessageCount: false`。

源码扫描：`_commitHistoricalMessages` 体内 `replace: replaceWithPeekWindow` 应为 0。

**Verify**: 同 Step 1 测试仍绿。再跑 `flutter test test/message_ordering_test.dart` → `mergeHistoricalWithInMemory` / `mergePeekWindowWithLiveMemory` 用例仍过。

### Step 3: lastMessage 同秒不同 msgID 仍领先（测试门禁）

在 `test/conversation_preview_history_sync_test.dart` 增加：

- 预览 `msgID=…-200-2, text=0, ts=200, isSelf`
- 缓存头 `msgID=…-200-1, text=9, ts=200, isSelf`
- `isPreviewAheadOfCachedHistory == true`
- 预览就在缓存里（同一 msgID）→ 仍为 false（回归 049）

若测试已绿：**不要**改 `isSameMessage` / correlate。若失败，只许改 `isPreviewAheadOfCachedHistory`：在两边都有非空 msgID 且 `isSameRef` 为 false 时，**先**当领先，再考虑 correlate——但必须保持现有用例 `same timestamp correlating content is not ahead`（归档 key vs SDK msgID 靠 correlate 判同一条）为绿。若改 ahead 会弄红该用例，**STOP**，不要改 correlate，把冲突写进报告。

**Verify**: `flutter test test/conversation_preview_history_sync_test.dart` → all pass。

### Step 4: 回归 018 / 045 / 049

跑 Commands 表第二行。不要改 018 / 049 测试期望来迁就 commit。

对照日志失败模式（用单测等价，不必真机）：

| 日志事件 | 修复后单测必须保证 |
|----------|-------------------|
| `incomingCount=20` + prev newestSelf=`9` + retain 抬出 `0`/`11111` | 别名 existing 非空时 merge 结果仍含 ts 更新的自己 tip |
| `mark_initial_history_loaded conv=rqwm8onw3j` 同时 `set_list conv=c2c_…` | commit 读 existing 不再只看裸 key 的 map 槽 |
| 049 `replace:false` 旧页 retain | 仍绿；本计划用全表 `replace: true`，不再把「仅旧页」当 incoming |

**Verify**: Commands 表第二行全部绿。

## Test plan

新/扩测试（最低）：

1. 真窗只在 `c2c_alice`、裸 `alice` 槽为空时，`mergedAliasMessageList('alice')` 含 newest self。
2. `mergeHistorical(existing: map['alice'], fetched: 旧20)` 丢掉 tip（对照）；`existing: mergedAliasMessageList` 保留 tip。
3. 预览 tip 与缓存头同秒不同 SDK msgID → `isPreviewAhead == true`；同 msgID → false。
4. 049 / 018 套件不回退。

模式：`test/conversation_message_cache_key_test.dart`、`test/sender_own_sent_visible_contract_test.dart`、`test/conversation_preview_history_sync_test.dart`。

## Done criteria

- [x] Step 1–4 的 Verify 命令均为绿
- [x] `_mergeWithInMemoryHistory` 与 `_commitHistoricalMessages` 的 peek existing 使用 `mergedAliasMessageList`（读源码，不要只靠 replace 分支）
- [x] `_commitHistoricalMessages` 的 `setMessageList` 为 `replace: true`（已 merge 全表）
- [x] `_fillTowardOlderHistory` 不再用 `messageListMap[convId] ?? rawMessageList` 作为 existing
- [x] 未改 `_storageConversationId` 剥前缀、未改 049 retain 谓词、未改 018 key、未改 120/160、未改 C2C `isSelf`
- [x] 未改 in-scope 以外的文件
- [x] `plans/README.md` 本行改为已完成或按评审者要求保持 TODO

## STOP conditions

- 「当前状态」摘录已对不上（commit 已别名感知、或分模型不再剥 `c2c_`）。
- 某步 Verify 连续失败两次。
- 修复看起来必须改 018 correlate、关掉 retain、改 `_storageConversationId`、或停掉 `_fillTowardOlderHistory` 才能过测试。
- `mergeHistoricalWithInMemory` 的列表**不是** newest-first。
- Step 3 为让「0 vs 9」领先而弄红「归档 vs SDK 同内容不领先」，且除改 correlate 外无解。
- `mergedAliasMessageList` 会把**其它会话**的消息并进来（实现过宽：必须仍走 `isSameConversationIdForHistory`）。

## Maintenance notes

- 之后任何「按 `conversationID` 读 `messageListMap` 再 `setMessageList`」的新路径（归档 reconcile、hydrate、cloud gap fill）都必须用 `mergedAliasMessageList` / `rawMessageList`。分页已经如此（`_aliasAwareInMemoryList`）。
- 评审重点：补旧后 newest tip 不变；用户上滑仍能接上更旧页；未打开会话的列表预热仍在；018 双气泡。
- `call_bubble_normalize` 的条数变化不在本计划。
- 真机复核（操作员，非本计划门禁）：对 `rqwm8onw3j` 进页看到最新自己 → 停在最新端等到补旧（日志 `toward_local_fill_commit` / `inputCount` 不再是「20 条旧页 + retain 抬旧 tip」）→ newest 气泡仍是刚进页那条；回列表再进仍在。
