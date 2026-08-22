# Plan 049: 已发送成功的自己消息不得被旧历史页 / 120 窗裁掉

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt below to the live files. If
> `collectUncorrelatedInFlightOutgoing` is already invoked for `replace: false`,
> or `isPreviewAheadOfCachedHistory` already treats "preview not in list" as
> ahead, mark those steps DONE / adjust and report — do not duplicate.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED（保留自己消息不得复活 018 双气泡；暖窗门禁不得改成「只要开过聊天就永远不预热其它会话」）
- **Depends on**: plans/045-sender-missing-own-sent.md（已完成，必须保持绿）；plans/018-outgoing-image-dual-bubble.md（已完成，必须保持绿）
- **Category**: bug
- **Planned at**: working tree 2026-08-22（NO_GIT）
- **Issue**: omit

## Why this matters

发送者刚发出的消息本端当时看得见、对端一直看得见，回会话列表再进同一会话后本端气泡没了。会话预览 `lastMessage` 仍是那条（IM `code=0` + 预览 patch 成功）。045 只修了「当时看不见」：`replace: true` 时从 **previous** 保住 *SENDING* / 比 incoming 更新的 *SEND_SUCC*。复现日志（`docs/控制台输出.md`，会话 `c2c_rqwm8onw3j`，过滤 `[OutgoingVisible]`）证明丢失发生在 **045 之后**：

1. 首屏已有自己的 `11111`（22→32 条仍在）。
2. 一页 20 条旧历史以 **`replace=false`** 合入：`32 → 51`，`newestSelf` 从 `11111` 变成更早的 `0`。随后 `mark_initial_history_loaded conv=rqwm8onw3j`（裸 userID）。
3. 回列表再进：`lastMessage` 仍是 `11111`，内存最新自己已是 `0`。`shouldResetLatest=false`，没有 `remove_message_list`。
4. 本轮新发 `--------------` 离开时还在；后台继续 20 条一页往上补，**`160 → 120`** 后 `hasTracked: true → false`。

045 的 retain **根本没跑**（只挂在 `replace && previous.isNotEmpty`）。暖调度用 `isActiveChat`（要求 `_routeVisible`），进页转场 / `deactivate` 时 route 不可见就会继续灌窗。再进页 `canSkipOpenRebootstrap` 在「预览 tip 不在列表里、但 timestamp ≤ 列表头」时仍判暖窗可用，不会把 `lastMessage` 拼回去。

产品意图：自己发出且已成功的气泡，在用户仍看最新端（或再进同一会话）时必须还在。对端可见不能代替本端列表。

## Current state

聊天列表是 **newest-first 反转列表**。不要翻转。045 / 018 已落地，不要回滚。

**045 retain 只覆盖 replace** —
`third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`

`setMessageList`（约 6002–6026）：

```dart
final previous = _mergedAliasMessageList(conversationID);
var incomingForMerge = messageList;
if (replace && !isDeleteMsg && previous.isNotEmpty) {
  final extras = collectUncorrelatedInFlightOutgoing(
    previous: previous,
    incoming: messageList,
  );
  // ...
}
```

`collectUncorrelatedInFlightOutgoing`（约 7820–7873）：只收 `isSelf` 且未被 incoming 关联的行；条件是 *SENDING* / live placeholder，或 *SEND_SUCC* 且比 incoming 最新一条更新。`previous.isEmpty` 时返回空。018 已 swap 的占位必须靠 `messagesCorrelateForDedup` / id / msgID / stableId 被 `coveredByIncoming` 掉，**不得**再插回去。

`mergePeekWindowWithLiveMemory`（约 7878–7928）：对 existing 里未覆盖的自己消息，只留 *SENDING* 或比 peek 窗最新更新的行。*SEND_SUCC* 若被误判「不比窗新」（锚在旧页 / 列表头不是 newest-first 直觉）就会丢掉。日志 32→51 的写入是 **`replace=false`**，不走这条 helper，走 `setMessageList` 默认拼接 + `dedupeMessages` + `_applyMessageMemoryWindow`。

**内存窗裁到 120** —
`third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/chat_message_window_policy.dart`：`targetSize = 120`，`softMax = 160`。超过 160 才 trim。`_applyMessageMemoryWindow`（约 5897–5958）：`preferLatest` 仅在 `forcePreferLatest || !isActive || position==bottom || inTwoScreen`。活跃会话且 `notShowLatest` / `awayTwoScreen` 时按**旧锚点**裁，会砍 newest-first 头部（刚发出的自己消息）。日志 `160→120` + `hasTracked true→false` 就是这条。

**暖窗在打开的聊天上仍写入** —
`lib/src/services/conversation_history_warm_scheduler.dart` 约 944–951 与约 1109–1111：

```dart
if (ActiveChatRegistry.instance.isActiveChat(cacheKey) ||
    ActiveChatRegistry.instance.isActiveChat(conversation.conversationID)) {
  return;
}
// ...
if (ActiveChatRegistry.instance.isActiveChat(cacheKey)) {
  return;
}
```

`lib/src/services/active_chat_registry.dart` 约 65–86：`isActiveChat` = `sameConversation` **且** `_routeVisible`。`matchesOpenConversation` 只比会话 ID，不看 route。进页 `deactivate` / 转场时 `routeVisible=false`，暖调度仍会 `setMessageList` + `markInitialHistoryLoaded`（日志里的裸 `rqwm8onw3j`）。`sameConversation` 已把 `c2c_x` 与裸 `x` 当成同一会话（`normalizeComparableKey` 去 `c2c_` 前缀）；**不要**再手写去前缀。

**再进页暖跳过不认「预览 tip 不在列表」** —
`lib/src/utils/conversation_preview_history_sync.dart`：

- `isWarmWindowReadyForOpen`（约 59–82）：已 loaded、非空、`!isPreviewAheadOfCachedHistory`。
- `isPreviewAheadOfCachedHistory`（约 262–283）：预览已在列表 → 不领先；否则仅当 `previewTs > cached.first.timestamp` 才算领先。预览 *不在列表* 且 `previewTs <= headTs` 时返回 **false** → `canSkipOpenRebootstrap` 仍为 true。日志再进页：`lastMessage=11111`，`newestSelf=0`，没有 `bootstrap_replace` / `bootstrap_local_first`。

`ChatHistoryPeekBootstrap.apply`（`lib/src/services/chat_history_peek_bootstrap.dart`）在 `canSkip` 时不会把 `conversation.lastMessage` 拼进首屏。

**静默归档切窗** —
`lib/src/services/silent_archive_service.dart` 约 218–224：`mergeHistoricalWithInMemory` 后若 `merged.length > requestedCount` 则 `merged.sublist(0, requestedCount)`。`mergeHistorical` 已是 newest-first，`sublist(0, n)` 留的是新端。不要改成从尾部切。若执行时发现列表已不是 newest-first，STOP。

**约定（照着写）**

- 会话相等：app 侧 `MessageConversationId.sameConversation`；UIKit 侧 `TUIChatGlobalModel.isSameConversationIdForHistory`。禁止 `==` / 手剥 `c2c_`。
- 契约测试风格：`test/sender_own_sent_visible_contract_test.dart`（045）、`test/conversation_preview_history_sync_test.dart`、`test/message_ordering_test.dart` 的 `_msg`。
- 018：`_swapOutgoingMessage` 仍 `replace: true`；retain 必须把已关联占位当成 covered。
- 诊断探针 `OutgoingVisibleProbe` / `[OutgoingVisible]` **可以留着**，不要当本计划的修复手段，也不要删。

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| 本计划契约 | `flutter test test/sender_own_sent_visible_contract_test.dart test/conversation_preview_history_sync_test.dart test/active_chat_registry_test.dart` | all pass |
| 045 + 018 不得回退 | `flutter test test/sender_own_sent_visible_contract_test.dart test/outgoing_image_bubble_dedupe_contract_test.dart test/chat_media_optimistic_send_contract_test.dart test/message_ordering_test.dart` | all pass |
| 暖跳过 / 预览领先 | `flutter test test/conversation_preview_history_sync_test.dart` | all pass |
| 触及文件静态检查 | `flutter analyze --no-fatal-infos --no-fatal-warnings <touched files>` | exit 0（info/warning OK） |

本工作区可能**没有 `.git`**。不要 `git init`。不要 push。

## Suggested executor toolkit

- 优先给 `collectUncorrelatedInFlightOutgoing` / `isPreviewAheadOfCachedHistory` 写**真实单测**，不要只扫源码字符串。
- 宿主不能派 SubAgent 时，在主会话直接改。

## Scope

**In scope**（只改这些）：

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
  — `setMessageList` 在 **replace 与非 replace** 都跑 retain；内存窗 trim 掉 previous 最新自己时补回；可选：`mergePeekWindowWithLiveMemory` 对未覆盖的 *SEND_SUCC* 自己消息与 retain 同一口径
- `lib/src/services/conversation_history_warm_scheduler.dart`
  — 往内存灌窗的跳过条件改用 `matchesOpenConversation`（或 `hasOpenChat && sameConversation`），**不要**再用要求 `routeVisible` 的 `isActiveChat`
- `lib/src/utils/conversation_preview_history_sync.dart`
  — 预览 tip 的 msgID/id **不在**缓存列表里即视为领先（不要只比 timestamp）
- `lib/src/services/chat_history_peek_bootstrap.dart`
  — 首屏 commit 前：若 `conversation.lastMessage` 是自己的且不在即将写入的列表里，拼进 newest 端
- `test/sender_own_sent_visible_contract_test.dart`（扩展）
- `test/conversation_preview_history_sync_test.dart`（扩展）
- `test/active_chat_registry_test.dart`（可选：暖调度源码扫描或 registry 行为补充）
- `plans/README.md`（本行状态）

**Out of scope**（即使看起来相关也禁止动）：

- 018 关联 key / `_swapOutgoingMessage` / FIFO 猜图
- 045 的 pin 别名匹配、发送栈 **await** `reloadNewest`、C2C `isSelf` 镜像改写
- 改 `ChatMessageWindowPolicy.targetSize` / `softMax`（120/160）数值
- 关掉内存窗 / 取消上翻历史
- 会话列表 `uiSlidingWindowBudget = 120`（那是 **Feed** 预算，不是聊天消息窗）
- 删除或扩大 `[OutgoingVisible]` 探针到全站
- 钱包、通话、未读语义、搜索 API

## Git workflow

- 本工作区常无 `.git`。有 git 时分支名 `advisor/049-retain-acked-self-across-history-pages`。
- 不要 push / 不要开 PR，除非操作员明确要求。
- 不要 `git init`。

## Steps

### Step 1: 扩展 retain —— `replace: false` 也要跑

在 `setMessageList` 里，把

```dart
if (replace && !isDeleteMsg && previous.isNotEmpty)
```

改成：**只要** `!isDeleteMsg && previous.isNotEmpty` 就调用 `collectUncorrelatedInFlightOutgoing(previous: previous, incoming: messageList)`，把 extras 拼进 `incomingForMerge`（replace 时拼到 incoming 前或后均可，最终必须再 `dedupeMessages` + `sortMessagesNewestFirst`，与现网 replace 路径一致）。

不要改 `collectUncorrelatedInFlightOutgoing` 的 018 covered 规则。不要对 *SEND_SUCC* 且 **不比** incoming 最新更新、且已被关联的旧自己消息回插。

在 `test/sender_own_sent_visible_contract_test.dart` 增加：

- `replace: false` 语义的纯函数测试：previous 含 ts=200 的自己 *SEND_SUCC* `11111`，incoming 为 20 条更旧（最新 ts=100），extras 必须含 `11111`。
- incoming 已含同一 `msgID` / 同一 client id 的 SDK 回执时 extras 为空（018 / 045 已有「同 id 不回插」，保持）。

**Verify**: `flutter test test/sender_own_sent_visible_contract_test.dart` → all pass，含新用例。

### Step 2: 内存窗 trim 之后补回被砍的最新自己

`_applyMessageMemoryWindow` 返回后、写入 `_messageListMap` 前：若 `previous` 里存在未被 incoming/sorted 关联的自己 *SENDING* 或比 **trim 前** newest 更新/相等的自己 *SEND_SUCC*（复用 `collectUncorrelatedInFlightOutgoing(previous: previous, incoming: sorted)`），把它插回 `sorted` 再 sort+dedupe。

目标：日志里的 `160→120` 不得再把 `--------------` 裁掉。不要把 `targetSize` 改成 160+。不要 `preferLatest=true` 全局覆盖上翻历史（用户停在 `notShowLatest` 时仍按锚点裁，但 **conversation tip / 刚发出的自己** 必须留下或标 `memoryWindowMissingNewer` 且再进页能从 `lastMessage` 恢复 —— Step 3–4）。

若 trim 掉的是更旧的自己消息、incoming 最新已超过它：不要回插（已有测试 `retain ignores older acked self`）。

**Verify**: 在 `sender_own_sent_visible_contract_test.dart` 增加「newest-first 178 条、自己最新在下标 0、`trimToWindow(preferLatest: false, anchor 在旧端)` 之后仍含该自己消息」——可以测 `ChatMessageWindow.trimToWindow` + 你们的 splice helper。`flutter test test/sender_own_sent_visible_contract_test.dart third_party/tencent_cloud_chat_uikit/test/chat_message_window_test.dart` → all pass。

### Step 3: 暖调度：打开中的会话禁止灌内存

`conversation_history_warm_scheduler.dart` 两处 `isActiveChat(...)` 跳过（约 944 与 1109）：改成 `matchesOpenConversation(cacheKey) || matchesOpenConversation(conversation.conversationID)`（第二处同样检查 conversationID，不要只查 cacheKey）。

`isActiveChat` 仍用于通知抑制 / 未读 bump，**不要**改 `ActiveChatRegistry.isActiveChat` 的 `routeVisible` 语义。

在 `test/active_chat_registry_test.dart` 或新的源码扫描测试中断言：暖调度灌窗前的 skip 调用了 `matchesOpenConversation`。更稳：给 scheduler 抽一个 `@visibleForTesting static bool shouldSkipMemoryFillForOpenChat(...)` 再单测：

- `enter('c2c_alice')` + `updateRouteVisible(false)` → skip fill for `alice` 与 `c2c_alice`
- 未 enter 任何聊天 → 不 skip
- enter 的是 `c2c_bob` → 不 skip `c2c_alice`

**Verify**: `flutter test test/active_chat_registry_test.dart` 以及你新增的 skip 测试 → all pass。

### Step 4: 预览 tip 不在列表 = 领先；bootstrap 拼 lastMessage

`isPreviewAheadOfCachedHistory` / `isPreviewAheadOfCachedRefs`：在 `isMessageVisibleInList` / `isRefVisibleInList` 为 false 时返回 **true**（删掉「只有 ts > head 才领先」这条窄条件，或改为：不可见则领先；可见则不领先）。

这会让 `lastMessage=11111` 而列表没有该 msgID 时 `canSkipOpenRebootstrap` 为 false。

然后在 `ChatHistoryPeekBootstrap.apply` 即将 `setMessageList(..., replace: true)` 之前（local-first 与 cloud merge 两处 commit）：

```dart
// 伪代码：last 为自己且不在 messages 里 → 插到 newest 端
if (last != null &&
    last.isSelf == true &&
    !ConversationPreviewHistorySync.isMessageVisibleInList(last, messages)) {
  messages = TUIChatGlobalModel.sortMessagesNewestFirst(
    TUIChatGlobalModel.dedupeMessages(<V2TimMessage>[last, ...messages]),
  );
}
```

不要用「时间戳比列表头旧就丢弃 lastMessage」。不要把对端的 lastMessage 在已有更新自己消息时覆盖整表。

在 `test/conversation_preview_history_sync_test.dart` 增加：

- 预览 `msgID=11111, ts=200`，缓存头 `msgID=0, ts=100`（或头 ts≥200 但列表无 11111）→ `isPreviewAheadOfCachedHistory == true`
- 预览就在缓存里 → 仍为 false（回归现有「已在列表则不领先」）

**Verify**: `flutter test test/conversation_preview_history_sync_test.dart` → all pass，含新用例。

### Step 5: 回归 018 / 045 并对照探针语义

跑 Commands 表里的 018+045 套件。不要改 018 测试期望来「迁就」retain。

对照 `docs/控制台输出.md` 的失败模式（执行者用单测等价，不必真机）：

| 日志事件 | 修复后单测必须保证 |
|----------|-------------------|
| `32→51 replace=false` 后 newestSelf 从 `11111` 变 `0` | previous 的未关联 *SEND_SUCC* 仍在 extras / 最终列表 |
| `160→120` 后 `hasTracked true→false` | trim 后 tip 自己消息仍在 |
| 再进页 `lastMessage=11111` 且列表无此 id | `isPreviewAhead == true`，bootstrap 会拼入 |

**Verify**: Commands 表第二行全部绿。

## Test plan

新/扩测试（最低）：

1. `collectUncorrelatedInFlightOutgoing`：`replace: false` 合入更旧 20 条时保留更新的自己 *SEND_SUCC*。
2. 同 msgID / 同 client id 的 SDK 行已在 incoming → 不回插（018）。
3. 内存窗按旧锚 trim 后仍保留 previous 最新自己 *SEND_SUCC*。
4. `isPreviewAheadOfCachedHistory`：tip 不在列表即为领先（即使 ts ≤ head）。
5. 暖调度 skip：`routeVisible=false` 时仍跳过对当前打开会话的内存灌窗。

模式：`test/sender_own_sent_visible_contract_test.dart`、`test/conversation_preview_history_sync_test.dart`。

## Done criteria

- [x] Step 1–4 的 Verify 命令均为绿
- [x] `flutter test test/outgoing_image_bubble_dedupe_contract_test.dart test/chat_media_optimistic_send_contract_test.dart` 绿
- [x] `setMessageList` 在 `replace: false` 路径也能调用 `collectUncorrelatedInFlightOutgoing`（读源码确认，不要只靠 replace 分支）
- [x] 暖调度灌窗 skip 不再单独依赖 `isActiveChat`（`rg "isActiveChat\\(cacheKey\\)" lib/src/services/conversation_history_warm_scheduler.dart` 在 fill 路径上应为 0；通知类用途不在本文件）
- [x] 未改 018 key、未在发送栈 await `reloadNewest`、未改 120/160 常量、未改 C2C `isSelf`
- [x] 未改 in-scope 以外的文件（`git status` 或工作区对照）
- [x] `plans/README.md` 本行改为已完成或按评审者要求保持 TODO

## STOP conditions

- 「当前状态」摘录已对不上（045 retain 形态变了、暖调度文件拆走）。
- 某步 Verify 连续失败两次。
- 修复看起来必须改 018 swap、044 分页闩、或把 `softMax`/`targetSize` 改掉才能过测试。
- `mergeHistoricalWithInMemory` / 归档 `sublist` 的列表**不是** newest-first（改切窗方向前 STOP）。
- `matchesOpenConversation` 会导致**其它**未打开会话也不再预热（实现过宽：必须按 conversationId 匹配，不能 `hasOpenChat` 就 skip 全世界）。

## Maintenance notes

- 之后任何「20 条一页写入 `_messageListMap`」的新路径（归档、hydrate、校对）都必须经过 `setMessageList` 或同一套 retain。不要绕过 global model 直接改 map。
- 评审重点：018 双气泡、上翻历史是否还能离开最新端、未打开会话的列表预热是否还在。
- `[OutgoingVisible]` 是复现探针，修好后可另开计划拆除；本计划不负责拆除。
- 真机复核（操作员，非本计划门禁）：对 `rqwm8onw3j` 发一条 → 立刻回列表再进 → 气泡仍在；再发一条并停留到后台补页（日志出现 `inputCount=20` / `nextCount=120`）→ 最新自己仍在。
