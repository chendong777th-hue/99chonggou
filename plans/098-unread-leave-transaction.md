# Plan 098: 让单会话已读清零、离页持久化与底部角标成为同一个可等待事务

> **Executor instructions**: 按步骤执行；每一步都运行验证命令。出现 STOP
> 条件时停止并报告，不要扩大修改范围。完成后更新 `plans/README.md` 状态。
>
> **Drift check（首先执行）**：
> `git diff --stat 9f7c46e..HEAD -- lib/src/conversation.dart lib/src/chat.dart lib/src/services/conversation_unread_clear_service.dart lib/src/services/conversation_local/conversation_list_notifier.dart lib/src/services/conversation_local/conversation_unread_aggregate.dart test`
> 这些文件当前已有未提交修改；必须逐段比对下方摘录，禁止回退用户改动。

## Status

- **Execution**: complete. Single-row clear now publishes the unread aggregate
  delta synchronously; leave finalization is generation-scoped single-flight,
  retries after failure, and chat-return hydrate waits for the local commit.
- **Priority**: P0
- **Effort**: M
- **Risk**: MED
- **Depends on**: none；`096-unread-anchor-race` 是后续 SDK 回灌加固
- **Category**: bug
- **Planned at**: commit `9f7c46e`, 2026-08-25

## Why this matters

当前单条会话 `zeroUnreadLocally` 只让会话行清零，然后延迟从 Store 重算底部总未读；它没有像批量清零那样同帧扣减聚合值。因此会出现“行红点清了、底部数量仍在”。离开聊天时又有两个 finalize 调用者：`Chat.dispose` 先 unawaited 启动，列表页返回后再次调用时，因为会话 ID 已提前加入完成集合，会直接返回而不等待第一次本地写库；紧接着的虚拟列表 hydrate 就可能读到旧 unread，把红点重新带回来。

完成后，同一次聊天会话的 finalize 必须是 single-flight Future：第一个调用者执行，其他调用者等待同一 Future；只有本地 unread=0 和 read anchor 已持久化后，列表才允许强制 hydrate。SDK clean 仍可后台重试，但不得阻塞返回动画。

## Current state

- `lib/src/services/conversation_local/conversation_list_notifier.dart:4038-4090`：单条清零记录了 `unreadBefore`，但只调用 `scheduleRefresh(reason: 'zero_unread')`。
- 同文件 `:4109-4163`：批量清零已经计算 `ConversationUnreadDelta`，先 `applyNotifiableDeltas` 同帧更新底部角标，再从 Store 校准；这是本计划必须复用的范式。
- `lib/src/services/conversation_unread_clear_service.dart:325-370`：`_leaveFinalizedSessionIds.add(id)` 在任何 await 之前发生；第二个调用者只能看到 `already_finalized`，无法等待正在执行的持久化。
- `lib/src/chat.dart:8849-8899`：`dispose` 中 unawaited 调用 `finalizeConversationLeaveOnce`。
- `lib/src/conversation.dart:3128-3145`：路由返回后先 `_scheduleVirtualFeedHydrateAfterChatReturn`，后 await `_finalizeConversationLeave`，顺序与所需事务相反。
- `lib/src/services/conversation_unread_clear_service.dart:373-402`：打开时同步清 UI/内存锚点，Store 写入通过 unawaited 执行；必须保留“导航不被 SQLite 阻塞”的体验。

## Commands you will need

- 定向分析：`flutter analyze lib/src/conversation.dart lib/src/chat.dart lib/src/services/conversation_unread_clear_service.dart lib/src/services/conversation_local/conversation_list_notifier.dart lib/src/services/conversation_local/conversation_unread_aggregate.dart`，预期无本计划新增 error。
- 核心测试：`flutter test test/conversation_unread_clear_service_test.dart test/conversation_unread_aggregate_test.dart test/conversation_unread_guard_test.dart test/conversation_unread_merge_foreground_test.dart test/chat_leave_patch_catch_up_test.dart`，预期全部通过。
- 差异检查：`git diff --check`，预期 exit 0。

## Scope

**In scope**：

- `lib/src/services/conversation_local/conversation_list_notifier.dart`
- `lib/src/services/conversation_unread_clear_service.dart`
- `lib/src/conversation.dart`
- `lib/src/chat.dart`（仅 finalize 调用契约；若无需改则不动）
- 对应 `test/` 文件

**Out of scope**：SDK unread 定义、消息已读回执 UI、置顶/归档/排序、消息历史窗口、腾讯 SDK 版本、全选已读产品语义。

## Git workflow

- 分支建议：`codex/098-unread-leave-transaction`
- 逻辑提交顺序：测试 → 聚合同帧扣减 → finalize single-flight → 返回时序。
- 不提交、不推送，除非操作员明确要求。

## Steps

### Step 1: 先锁定两个可复现竞态

新增或扩展测试，至少覆盖：

1. 聚合初值为 5，目标会话可通知未读为 3；调用 `zeroUnreadLocally` 后，不等待 debounce，聚合立即变为 2。
2. 目标会话已经是 0 时，重复调用不重复扣减。
3. 两个调用者同时 finalize 同一会话；底层本地写用 Completer 暂停，第二个 Future 在 Completer 完成前不得完成，底层写只执行一次。
4. 第一次 finalize 失败时不得永久标记完成；下一次调用可以重试。

测试模式参考 `test/conversation_unread_aggregate_test.dart` 与 `test/conversation_unread_clear_service_test.dart`。必要时只增加 `@visibleForTesting` override/counter，不引入真实 SQLite 或网络。

**Verify**：新增测试在实现前精确暴露第 1、3 项失败；既有测试保持绿色。

### Step 2: 单条清零同帧更新底部聚合

在 `ConversationListNotifier.zeroUnreadLocally` 修改目标行前，计算 `ConversationUnreadUtils.notifiableUnreadCount(current)` 和群/单聊类型；成功清零后构造一个 `ConversationUnreadDelta(oldNotifiable → 0)`，调用 `ConversationUnreadAggregate.instance.applyNotifiableDeltas`。随后保留 `scheduleRefresh(reason: 'zero_unread')` 作为 Store 最终校准。

要求：若行被免打扰或业务规则使 notifiable unread 为 0，不得扣减聚合；同一调用只处理命中的唯一规范会话，发现等价 alias 同时存在两行则 STOP 并交给会话去重计划处理。

**Verify**：运行 unread aggregate/clear tests；立即扣减、重复调用幂等均通过。

### Step 3: 将 finalize 改成可共享、可失败重试的 single-flight

把“开始即加入 `_leaveFinalizedSessionIds`”改为两阶段状态：

- `_leaveFinalizeInFlightById[id]` 保存当前 Future；后来的调用返回并 await 同一个 Future。
- 只有本地 `markConversationReadLocally` 成功后才写入 completed 集合。
- task 失败时从 in-flight 移除且不写 completed，允许重试。
- `beginConversationChatSession(id)` 清 completed；不得取消一个仍在执行的旧 finalize。若出现同 ID 新会话在旧 finalize 未完成前开始，使用递增 session generation/token 隔离，不能让旧任务把新会话标记完成。
- `resetCoordinatorStateForTesting` 同时清理新增 map/generation。

SDK clean 保持后台调度；single-flight 的“完成”只要求本地列表、read anchor 和 Store unread=0 已落地。

**Verify**：并发调用共享 Future、失败重试、连续两次打开同一会话的 generation 测试全部通过。

### Step 4: 返回列表时先等待本地已读事务，再强制 hydrate

在 `Conversation._handleOnConvItemTaped` 的 route 返回路径调整顺序：

1. await `_finalizeConversationLeave`；如果 `Chat.dispose` 已启动，它会等待同一 single-flight。
2. 确认 mounted。
3. 再执行 `_scheduleVirtualFeedHydrateAfterChatReturn`、可见性日志和头像预热。

不要等待 SDK clean，不要让返回转场等待网络。保留 `openOrReuseAppChat` 的“只有真实聊天 route pop 才完成”契约。

**Verify**：增加契约测试断言 hydrate 的调用顺序严格晚于 local finalize completion；`test/app_chat_route_session_reuse_test.dart` 继续通过。

### Step 5: 与 096 的 SDK 回灌防护联调

执行 `plans/096-unread-anchor-race.md` 时，以本计划的新 single-flight/read generation 为边界；SDK 旧快照同 lastMessage 需被 read anchor 拒绝，新 lastMessage 的真实未读必须放行。不要在本计划复制 096 的 guard 逻辑。

**Verify**：`flutter test test/conversation_unread_guard_test.dart test/conversation_unread_merge_foreground_test.dart` 全部通过。

## Done criteria

- [ ] 单条清零后底部聚合在同一同步调用内扣减，无需等待 220ms Store debounce。
- [ ] 两个 finalize 调用者等待同一 Future；本地持久化只执行一次。
- [ ] finalize 失败可重试，新聊天 generation 不被旧完成污染。
- [ ] chat return hydrate 严格发生在本地 finalize 完成之后。
- [ ] 核心测试、定向 analyze、`git diff --check` 全部通过。
- [ ] 没有修改 Scope 外文件（计划索引除外）。

## STOP conditions

- 需要等待网络 SDK clean 才能完成返回列表。
- 等价 conversation alias 在 Notifier 中同时存在，导致一次清零会扣两次聚合。
- 本地 Store 没有可测试的写入完成边界，且需要重构 Coordinator 才能提供。
- 新消息 lastMessage 已前进时仍被清成 0。
- 现场代码与摘录不一致且无法保留现有未提交改动。

## Maintenance notes

以后任何“单条未读变更”都必须同时产出 `ConversationUnreadDelta`，底部聚合只把 Store 扫描当校准，不当即时 UI 更新源。任何幂等 async API 若已有任务在执行，后来的调用者必须等待该任务，不能把“已开始”误当成“已完成”。
