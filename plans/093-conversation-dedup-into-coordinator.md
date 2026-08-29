# Plan 093: 保证会话最新消息投影单调前进，禁止旧快照覆盖实时消息

> **Executor instructions**: 严格按步骤执行，每一步运行验证命令并确认预期结果后再进入下一步。不要用延长 debounce、重复 reload、强制刷新或关闭虚拟列表掩盖问题。任何 “STOP conditions” 命中时立即停止并报告。完成后更新 `plans/README.md` 对应状态行。
>
> **Drift check (run first)**:
> `git diff --stat 9f7c46e..HEAD -- lib/src/platform/uikit_conversation_local_bridge.dart lib/src/services/conversation_local/conversation_sync_service.dart lib/src/services/conversation_local/conversation_mutation_event.dart lib/src/services/conversation_local/conversation_field_authority.dart lib/src/services/conversation_local/conversation_mutation_coordinator.dart lib/src/services/conversation_local/conversation_mutation_shadow_bridge.dart lib/src/services/conversation_local/conversation_local_store.dart lib/src/services/conversation_local/conversation_list_notifier.dart test`
>
> 本计划依据 commit `9f7c46e` 上的**未提交现场实现**编写。执行前还必须运行 `git diff --stat -- <上述 in-scope paths>`，逐段核对下面的 Current state；不得 reset、checkout 或覆盖其他人的未提交修改。若相关实现与摘录不一致，STOP。

## Status

- **Priority**: P0
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: none；Plan 094 继续依赖本计划
- **Category**: bug / correctness / tests / tech-debt
- **Planned at**: commit `9f7c46e`, 2026-08-25（基于当日 dirty worktree 现场修订）

## Why this matters

当前存在可复现的会话摘要丢更新：实时入站消息先通过内存补丁显示在会话列表，随后旧 SDK/UIKit 会话对象在持久化去重窗口内替换新对象；新 `lastMessage` 没有进入 Coordinator/SQLite，虚拟列表再次 hydrate 后恢复旧摘要。聊天历史与会话摘要是两条独立投影，因此会出现“聊天页能看到 11:35 新消息，会话列表仍显示昨天消息”。

本计划建立以下不变量：

1. 每条会话事件在任何数据合并前都必须携带明确来源并进入 Coordinator。
2. `lastMessage` 只能按消息语义单调前进；网络/页面响应的到达顺序不是版本。
3. `orderkey` 只用于会话排序，不得与消息时间戳混成 freshness 版本。
4. SQLite 和虚拟 hydrate 都不得把更新的内存 `lastMessage` 回退。
5. UI 通知可以合并，事实事件不能在 reducer 前丢弃。

## Current state

### 1. 实时消息先进行内存补丁，所以列表短暂正确

`lib/src/services/conversation_local/conversation_sync_service.dart:571-573`：

```dart
onRecvNewMessage: (message) {
  _patchInboundConversationPreview(message);
  _onRecvNewMessageForMembershipBridge(message);
},
```

`conversation_sync_service.dart:4020-4069` 把消息设为 `lastMessage`，先 enqueue，再立即 `applyLastMessageLocally`：

```dart
conversation.lastMessage = message;
conversation.orderkey = incomingTs;
_enqueuePersistChanged([conversation], reason: 'send_patch', prepare: true);
ConversationListNotifier.instance.applyLastMessageLocally(
  conversationID: conversation.conversationID,
  message: message,
  ...
);
```

这解释了“先显示”。此乐观 UI 行为必须保留。

### 2. reducer 前的 Map 会丢掉新事件

`conversation_sync_service.dart:4489-4549` 的 `_persistDedupBuffer` 对同一逻辑会话只保留 sequence 最后的 `V2TimConversation`：

```dart
final sequence = ++_persistCommitSequence;
final existingKey = _findPersistDedupBufferKey(id);
...
final keep = existing == null || existingSequence <= sequence
    ? conversation
    : existing;
_persistDedupBuffer[preferredKey] = keep;
```

注释声称“保留先后事件进入 reducer”，实际 Map 只剩一个对象。后到旧快照可以在 32–200ms Timer 窗口内替换实时新对象。

`conversation_sync_service.dart:4778-4842` flush 只提交 Map values，而且把所有来源统一标成 `sdkRealtime`：

```dart
final conversations = _persistDedupBuffer.values.toList(growable: false);
...
merged = await _commitSdkConversationBatch(
  ownerUserId: owner,
  conversations: persistable,
  source: ConversationMutationSource.sdkRealtime,
  allowRecreate: reason.contains('new'),
);
```

`reason` 同时承担延时、来源和 recreate 判定，造成来源语义丢失。

### 3. UIKit changed hook 是重复写入者

`third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_conversation_view_model.dart:550-579` 对字段不同的会话直接 `setAll`，没有 lastMessage 新旧判断，然后调用 `TUIConversationViewModelHooks.onConversationsChanged`。

`lib/src/platform/uikit_conversation_local_bridge.dart:33-38` 又把该对象写回 `ConversationSyncService.onViewModelConversationsChanged`；而 `ConversationSyncService.install()` 已直接注册 SDK `onConversationChanged/onNewConversation`。因此同一个 SDK 变化存在“直接 listener + UIKit mirror hook”两个写入口。

UIKit `onPageLoaded` 仍是有意义的分页来源，必须保留并明确标为 `sdkPage`；`onConversationsChanged` 不得继续成为第二个持久化 writer。

### 4. Coordinator 的版本时钟混用了不同含义

`lib/src/services/conversation_local/conversation_mutation_shadow_bridge.dart:683-689`：

```dart
final timestamp = conversation.lastMessage?.timestamp ?? 0;
final order = conversation.orderkey ?? 0;
return timestamp > order ? timestamp : order;
```

消息时间和 SDK `orderkey` 不是同一种 freshness 证据。旧消息携带较大的排序编码时可能被误判为更新事件。

### 5. Store 有 lastMessage prefer，但救不了“从未落库”的新消息

`lib/src/services/conversation_local/conversation_local_store.dart:_mergeConversationLastMessage` 已使用 `ConversationLastMessagePrefer.preferLastMessage` 合并数据库现有行与 incoming。若实时新事件在 buffer 中已被丢弃，数据库 existing 仍是旧消息，这层无法恢复新消息。

### 6. 虚拟列表直接采用 SQLite page

`lib/src/services/conversation_local/conversation_list_notifier.dart:1057-1065`：

```dart
final page = await ConversationLocalStore.instance.loadConvTypePage(...);
_typeHydrateStart[convType] = start;
_typeHydrate[convType] = page;
```

Feed 在 `conversation_feed_body.dart` 通过 `conversationAtTypeIndex` 读取 `_typeHydrate`。SQLite 仍旧时，hydrate 会把乐观内存摘要重新显示成旧值。

### 7. 现有测试没有验证最终消息

`test/conversation_dedup_middle_state_test.dart` 中 `sdkPage arriving after sdkRealtime keeps realtime authority` 只断言“一次 flush、批次一条”，没有断言最终 `lastMessage.msgID/timestamp/source`，也没有经过 SQLite → hydrate → render projection。因此当前错误实现仍能通过测试。

### Applicable conventions and product boundaries

- 字段权威集中在 `ConversationMutationCoordinator` / `ConversationFieldAuthority`，不要在 UI 新建第三套规则。
- lastMessage 语义合并复用 `ConversationLastMessagePrefer` 与 `GroupTipsMessageHelper.pickPreferredLastMessage`，不要仅按正文、单一 msgID 或到达时间猜测。
- 保留 `ConversationPerfFlags.conversationListSdkPrimary == false` 和虚拟列表；不得靠切换架构 flag 规避。
- 保留 Plan 098 已完成的 read barrier，lastMessage 修复不得恢复旧 unread。
- 不改变 Tencent SDK wire、聊天历史顺序、归档、置顶、免打扰、草稿、钱包、通话和 UI 布局。

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Dirty-state inventory | `git status --short` | 记录现有修改；不覆盖无关文件 |
| Diff hygiene | `git diff --check` | exit 0 |
| Static analysis | `flutter analyze lib/src/platform/uikit_conversation_local_bridge.dart lib/src/services/conversation_local/conversation_sync_service.dart lib/src/services/conversation_local/conversation_mutation_event.dart lib/src/services/conversation_local/conversation_field_authority.dart lib/src/services/conversation_local/conversation_mutation_coordinator.dart lib/src/services/conversation_local/conversation_mutation_shadow_bridge.dart lib/src/services/conversation_local/conversation_local_store.dart lib/src/services/conversation_local/conversation_list_notifier.dart` | 无本计划新增 analyzer error |
| Focused tests | `flutter test test/conversation_preview_monotonic_projection_test.dart test/conversation_dedup_middle_state_test.dart test/conversation_mutation_coordinator_test.dart test/conversation_mutation_shadow_bridge_test.dart test/conversation_list_notifier_incremental_test.dart test/conversation_local_store_sort_test.dart test/conversation_unread_guard_test.dart` | 全部通过 |
| Broader regression | `flutter test test/conversation_sync_reload_coalesce_test.dart test/conversation_refresh_bus_test.dart test/conversation_ui_window_test.dart test/conversation_virtual_tail_window_test.dart test/conversation_single_writer_ui_projection_contract_test.dart` | 全部通过 |
| Static writer audit | `rg -n "onViewModelConversationsChanged|_persistDedupBuffer|source: ConversationMutationSource\.sdkRealtime|reloadFromLocal|applyConversationsFromStore" lib/src third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_conversation_view_model.dart` | 每个剩余 writer/consumer 与本计划 allowlist 一致 |
| Full suite | `flutter test` | 全部通过；若有基线失败，记录与本计划无关的既有证据 |

## Suggested executor toolkit

- 先使用代码链路解释/探索工具确认调用者，再实施；不要依据本计划行号机械修改。
- 使用 `fake_async` 和现有 override/fake Store 模式编写确定性竞态测试，不使用真实网络或 `sleep`。

## Scope

**In scope**（仅允许修改）：

- `lib/src/platform/uikit_conversation_local_bridge.dart`
- `lib/src/services/conversation_local/conversation_sync_service.dart`
- `lib/src/services/conversation_local/conversation_mutation_event.dart`
- `lib/src/services/conversation_local/conversation_field_authority.dart`
- `lib/src/services/conversation_local/conversation_mutation_coordinator.dart`
- `lib/src/services/conversation_local/conversation_mutation_shadow_bridge.dart`
- `lib/src/services/conversation_local/conversation_local_store.dart`（仅 Coordinator commit 的字段选择、lastMessage 防倒退和测试辅助；不重构数据库）
- `lib/src/services/conversation_local/conversation_list_notifier.dart`（仅 hydrate 防回退合并）
- `lib/src/services/conversation_local/conversation_perf_gate_log.dart`（仅脱敏 trace 字段）
- `test/conversation_preview_monotonic_projection_test.dart`（新增）
- 与上述模块直接对应的既有 conversation 测试
- `plans/093-conversation-dedup-into-coordinator.md`、`plans/README.md`（完成时更新状态）

**Out of scope**：

- `third_party/tencent_cloud_chat_uikit` 运行逻辑；本计划在 bridge 取消 UIKit mirror 的持久化权威，不修改 fork 内部 UI 状态机
- `lib/src/conversation.dart` 页面 reload/apply 收口（Plan 094）
- `lib/src/chat.dart` 和聊天消息历史/分页/排序
- `ConversationPerfFlags.conversationListSdkPrimary` 与虚拟列表开关/窗口大小
- SDK 版本、native SDK、wire payload
- 未读产品语义、草稿、pin、mute、archive、folder、membership、删除/tombstone 语义
- 群名/头像权威（Plan 082）
- 通过新增重复 listener、重复 pull、Timer、reload 或 UI 强制刷新兜底

## Git workflow

- Branch: `advisor/093-monotonic-conversation-preview`
- 当前 worktree 很脏：先归属已有修改，只提交本计划明确文件；不得 reset/checkout 用户修改。
- 按逻辑提交：`test: cover conversation preview rollback` → `fix: preserve conversation event authority` → `fix: prevent conversation preview hydration rollback`。
- 不 push、不 merge，除非操作员明确要求。

## Steps

### Step 1: 先建立端到端失败契约和脱敏 trace

新增 `test/conversation_preview_monotonic_projection_test.dart`。必须用真实的 ingress/buffer/Coordinator/Store/Notifier 边界，不得只直接调用 reducer。至少锁定：

1. C2C 旧摘要为 `old/yesterday`；实时 `onRecvNewMessage(new, 11:35)` 先到；旧 UIKit/SDK page 后到同一 flush 窗。最终内存、SQLite、hydrate 都必须是 `new`。
2. 新实时事件与旧 page 的顺序反转，结果仍是 `new`。
3. feed scrolling / active chat 导致 200ms busy debounce 时，旧 page 仍不能覆盖新实时消息。
4. flush 进行中又到新事件，新事件进入当前 per-ID tail 或下一批，最终不丢。
5. restart 模拟：清空 Notifier 内存后从 Store hydrate，仍显示 `new`。
6. `orderkey` 人为设为远大于消息时间戳的旧对象，不能击败新消息。
7. 同 msgID 的 SENDING → SUCC、撤回和 peer-read 升级仍允许；强预览不能被弱 CUSTOM 降级。
8. 同秒不同 msgID：覆盖群 seq 可比较、C2C seq 不可全局比较和无 seq 三种情况，行为与 `ConversationLastMessagePrefer` 一致。
9. 新 lastMessage 到达时 unread 可以按 Plan 098/096 规则前进；同 lastMessage 的旧 unread 不得复活。

同时在 `ConversationPerfGateLog` 增加同一 trace ID 的脱敏阶段日志：`recv`、`local_apply`、`enqueue`、`coordinator_decision`、`sqlite_commit`、`hydrate_merge`。只记录 hashed conversation、msgID hash、timestamp、orderkey、source、sequence、decision；禁止记录正文、真实用户 ID 或群 ID。

**Verify**: 先运行新测试，至少“实时新 → 旧回灌”和“巨大旧 orderkey”两例在修复前稳定失败；记录失败断言，不把预期改成错误现状。

### Step 2: 取消 UIKit changed mirror 的持久化写权威

修改 `UikitConversationLocalBridge.install()`：

- 保留 `onPageLoaded` → `onViewModelPageLoaded`，并继续以 `ConversationMutationSource.sdkPage` 提交。
- `onConversationsChanged` 不再调用 `_persistChanged`。优先移除该持久化 hook；若 UIKit 其他功能要求 hook 存在，只允许发诊断/恢复信号，不能写 Store/Notifier。
- 保留 `TUIConversationViewModel` 内部 `verifyC2CLastMessage`，它属于消息丢推送检测，不是会话摘要 writer。
- 直接 SDK `onConversationChanged/onNewConversation` 是唯一 realtime conversation writer；AdvancedMsg `onRecvNewMessage` 是 realtime lastMessage fallback，两者都走同一个 Coordinator per-ID 队列。

给 writer audit 增加静态契约测试，防止未来重新把 UIKit changed hook 接成持久化旁路。

**Verify**: `rg -n "onViewModelConversationsChanged" lib/src` 只剩兼容定义/测试或完全无生产调用；page-loaded 测试仍通过，C2C lastMessage verify 测试不回归。

### Step 3: 将输入缓冲改成“事件队列”，只合并 UI 通知

在 `conversation_sync_service.dart` 引入私有 typed envelope（可放同文件，除非现有 `conversation_pending_sdk_sync.dart` 更适合）：

```dart
class _PendingConversationEvent {
  final String ownerUserId;
  final int ownerGeneration;
  final String canonicalConversationId;
  final int sequence;
  final ConversationMutationSource source;
  final bool allowRecreate;
  final String reason; // observability only
  final V2TimConversation snapshot;
}
```

要求：

- `_enqueuePersistChanged` 必须接收显式 `source` 和 `allowRecreate`；禁止从 `reason` 推断业务权威。
- buffer 保存每条 envelope；同 canonical ID 的不同事件都进入 Coordinator，不能只保留最后一个 `V2TimConversation`。
- 可以丢弃**完全相同 fingerprint + 相同 source + 相同 owner generation**的重复事件，但必须在测试证明无字段状态变化；不能按 ID 粗去重。
- Timer 只决定何时 flush，flush 按 sequence 交给 Coordinator；不同 ID 可批量，不同来源不得被重标。
- Coordinator/Store 提交完成后的 UI projection 可以按 canonical ID 合并为最终快照后一次 notify，这是允许的 coalescing 边界。
- 队列必须有界：达到上限时立即 flush/分块，禁止删除尚未提交的最新事实。退出登录或 owner generation 变化时取消旧队列，禁止写新账号。
- `_persistPendingReason` 不再决定 source；`allowRecreate` 随 envelope 传播。

完成后删除/重命名误导性的 `_persistDedupBuffer`、`_findPersistDedupBufferKey` 和“latest object wins”逻辑。

**Verify**: 新端到端测试的同窗交错、in-flight 后续事件和切账号用例通过；静态搜索不再出现 `keep.conversationID` 或 `_persistDedupBuffer.values`。

### Step 4: 把 lastMessage freshness 与 orderkey 拆开

修改 mutation event/bridge/coordinator：

- `lastMessage` 的裁决不得继续使用 `max(timestamp, orderkey)`。
- `orderkey` 作为独立 `ConversationMutationField.order` 值和版本处理；它只能影响排序，不直接证明 lastMessage 更新。
- 为 `lastMessage` 建立明确消息锚点，至少包含：normalized timestamp、msgID、seq（如存在）、status、isSelf/方向、source、arrival sequence。可以扩展 `ConversationShadowLastMessage`，不要把 SDK message JSON 整体塞进 reducer。
- canonical comparator 必须复用/对齐 `ConversationLastMessagePrefer`：
  1. 同 msgID 只允许状态、撤回、peer-read 等终态升级；
  2. 不同 msgID 时更高消息时间优先；
  3. 同时间按已有可比较 seq/群规则处理；无法证明更旧时保留已提交值；
  4. `sdkRealtime` 的真实消息事件优先于同锚点的 `sdkPage`；snapshot/cache 不能击败 SDK；
  5. 弱 CUSTOM 不覆盖强预览。
- source authority 只解决同一消息锚点冲突，不能让高权威的**旧消息**覆盖低权威的更新消息。
- unread read barrier 继续绑定 lastMessage 锚点，不复用 orderkey。

如果现有单一 `sourceVersion` 无法表达字段独立版本，应增加 `fieldVersions`/typed field stamp；不要继续用一个 int 给 lastMessage、order、unread、pin 共用。

**Verify**: coordinator/bridge 单测覆盖巨大旧 orderkey、同秒、同 ID 状态升级、realtime/page 来源交错，并断言 snapshot 的最终 msgID/timestamp/source。

### Step 5: 让数据库 commit 只写 Coordinator 已批准字段

审计 `ConversationMutationCoordinator._databasePlanFor` 与 `ConversationLocalStore.commitCoordinatorPlan`：

- `ConversationDatabaseCommitPlan.fieldPatch` 必须只包含 reducer 本次 `changedFields`，不得因 unread/order 被批准就携带整份旧 snapshot 的 lastMessage 覆盖数据库。
- 若仍需 full snapshot 创建新行，创建后必须按 Store 现有 `_mergeConversationLastMessage` 与已提交行合并；已有行更新采用字段 patch/CAS 语义。
- Store 在收到 incoming old lastMessage 时保留 existing，并输出脱敏 `sqlite_lastmsg_rejected_rollback`；不得把拒绝当异常或触发 reload。
- 保留 history-cleared、deleted-preview、revoked、peer-read、draft、pin、mute 和 read barrier 现有语义。
- 一个 Coordinator 事件的状态 stamp 与 SQLite 行提交必须保持同一事务语义；写库失败不得提前推进内存 stamp/idempotency。

**Verify**: 增加“只批准 unread，但 full snapshot 携带旧 lastMessage”的回归测试；最终数据库 lastMessage 必须保持新值。

### Step 6: 给 hydrate 增加最后一道单调合并门

修改 `ConversationListNotifier._ensureTypeIndexHydratedImpl`：加载 page 后，不得直接覆盖同一会话的更新实时内存行。

- 按 `MessageConversationId.sameConversation` 建 current live index。
- 对 page 中同一行复用 `ConversationLastMessagePrefer`、`ConversationUnreadGuard`、本地 pin/name 既有优先规则，生成 merged row。
- 只保护 live 行已证明更新的字段；不要阻止数据库中的合法新消息、删除、归档或排序前进。
- `_typeHydrate`、`_typeIndexSnapshotCache`、`_conversations` 使用同一 merged snapshot，不能三份各自裁决。
- 保留 virtual hydrate 的 start/limit、scroll cache-only、teleport guard 和窗口大小；不得整页 reload 或关闭虚拟列表。
- 当 hydrate 试图回退 lastMessage 时记录脱敏 `hydrate_lastmsg_rejected_rollback`。

这一步是 defense-in-depth，不替代 Step 2–5；即使 SQLite 暂时旧，也不能让用户看见摘要回跳。

**Verify**: restart 场景从 SQLite 读取新值；同进程“内存新、模拟 DB 旧”场景 UI 仍保持新值；`conversation_virtual_tail_window_test.dart` 和 `conversation_ui_window_test.dart` 保持绿色。

### Step 7: 收紧测试，删除虚假绿色断言

修订 `test/conversation_dedup_middle_state_test.dart`：

- 原 `sdkPage arriving after sdkRealtime keeps realtime authority` 不得只断言 batch length；必须断言最终 msgID、timestamp、unread、order 和 source stamp。
- 测试必须经过生产 source tagging，不允许用 `upsertBatchOverride` 绕过 Coordinator 后还声称覆盖 authority。
- 增加 writer allowlist 静态测试：realtime direct listener、AdvancedMsg fallback、UIKit page、snapshot/bootstrap、明确 local intent；UIKit changed mirror 不在 writer 列表。
- 增加一条完整链路测试：local optimistic apply → event queue → Coordinator → Store → force hydrate → feed row conversation，最终均为新消息。

**Verify**: Commands 中 focused + broader regression 全部通过；故意恢复任一“latest sequence wins”“view_model_changed 标 realtime”“max(timestamp, orderkey)”旧代码时，至少一条新测试稳定失败。

### Step 8: 真机验收与发布门禁

iOS/Android 各跑至少以下场景，使用脱敏 trace 对账：

1. App 停留会话列表，对端连续发送两条跨秒文本；摘要和时间持续前进，不回跳。
2. 同秒快速发送多条；最终摘要是实际最后一条。
3. 正在该聊天页收到消息后返回列表；摘要保持新消息，未读为 0。
4. 停在其他聊天页收到消息；目标会话摘要与未读更新，返回列表不回跳。
5. 列表快速滚动、切 Tab、前后台恢复、弱网重连时收到消息。
6. 杀进程重开；SQLite hydrate 后仍显示最新摘要。
7. 群文本、图片、语音、撤回、群 tips；强预览和状态升级正确。

关键日志判据：同 hashed conversation 下，任何 `hydrate/render` 的 lastMessage anchor 都不得小于已提交的 `sqlite_commit` anchor；任何 rejected rollback 都必须能指出 source/anchor，但不能含正文或真实 ID。

**Verify**: 两端验收记录中无摘要回跳；无新增 RenderBox/Sliver、未读复活、顺序跳动或聊天消息缺失。

## Test plan

新增 `test/conversation_preview_monotonic_projection_test.dart`，并扩展：

- `test/conversation_dedup_middle_state_test.dart`
- `test/conversation_mutation_coordinator_test.dart`
- `test/conversation_mutation_shadow_bridge_test.dart`
- `test/conversation_coordinator_commit_contract_test.dart`
- `test/conversation_list_notifier_incremental_test.dart`
- `test/conversation_local_store_sort_test.dart`
- `test/conversation_unread_guard_test.dart`

覆盖矩阵：

- 来源顺序：realtime→page、page→realtime、realtime→snapshot、重复 realtime。
- 生命周期：idle、active chat、feed scrolling、quiet/resume、logout owner switch、restart hydrate。
- 消息：不同 timestamp、同 timestamp/不同 msgID、同 msgID 状态升级、群 seq、C2C 无全局 seq、weak custom、撤回。
- 投影层：pending queue、Coordinator stamp、SQLite row、Notifier main window、type hydrate/cache、最终 feed conversation。
- 相关字段：unread read barrier、order、pin/draft/mute 不回归。

所有测试使用确定性 fake/override，不依赖真实 SDK、网络和 sleep。

## Done criteria

- [x] 每条非完全重复会话事件在 reducer 前不按 conversation ID 丢弃。
- [x] `source` 与 `allowRecreate` 是 typed envelope 字段，不由 reason 字符串推断。
- [x] UIKit `onConversationsChanged` 不再持久化会话摘要；UIKit page 仍以 `sdkPage` 提交。
- [x] lastMessage freshness 不再计算 `max(timestamp, orderkey)`。
- [x] Coordinator 数据库计划只提交批准字段；旧 full snapshot 不能夹带回退 lastMessage。
- [x] SQLite 与 hydrate 均有 lastMessage 单调门控。
- [x] 新端到端测试断言最终 msgID/timestamp/source，并能在恢复旧 bug 时失败。
- [ ] focused tests、broader regression 和 `git diff --check` 全部通过。
- [ ] 定向 `flutter analyze` 无本计划新增 error。
- [ ] 真机覆盖列表可见、聊天内、滚动、重连、重启；无摘要回跳。
- [ ] 未读、草稿、pin/mute/archive、群名、聊天历史和虚拟滚动语义无回归。
- [ ] `git status --short` 证明没有修改 scope 外文件；既有 dirty changes 被保留。
- [x] `plans/README.md` 状态更新。

## Execution record (2026-08-25)

- 已完成实现审计与补齐：SDK 事件队列保留同会话的非重复事件；UIKit
  changed mirror 不再写入；Coordinator 使用明确 source；lastMessage 仅以
  message timestamp（无 timestamp 时以 arrival sequence）作为字段版本，
  `orderkey` 只按独立 sequence 处理；type hydrate 会以
  `ConversationLastMessagePrefer` 保留热投影中更强的新摘要，并发出脱敏
  `hydrate_merge` trace。
- `git diff --check` 已通过。
- focused tests、broader regression、Flutter analyze 和真机验收尚未执行：
  Flutter 需要写入 `/Users/qiu/flutter/bin/cache/engine.stamp`，本次受限授权
  的自动审批服务返回 HTTP 503。该验证恢复前不得将本计划标为“已完成”。

## STOP conditions

出现以下任一项立即停止并报告：

- 执行前现场代码与 Current state 不符，或无法区分已有 dirty changes 的归属。
- 必须修改 SDK/native wire、聊天历史排序、UI 布局或关闭虚拟列表才能让测试通过。
- 发现 UIKit changed hook 是某个平台唯一的 SDK realtime 来源；先提供 listener 注册失败的运行证据，不得直接保留双写。
- 发现 `orderkey` 有正式文档保证与 message timestamp 同一版本域；先给出文档和真机值，再重新评估，不得继续混用猜测。
- lastMessage comparator 无法确定同秒不同消息次序且 SDK 不提供可比较锚点；保守保留现有值并报告，不得按正文、对象地址或随机 FIFO 猜测。
- Store field patch 需要数据库 schema 迁移或改变删除/history-cleared/tombstone 语义；拆分新计划，不在此 improvisation。
- 任一现有 unread、draft、pin、mute、archive、group tip、virtual hydrate 测试失败两次后仍无法在 scope 内合理修复。
- 修复只能靠延长 Timer、重复 sync/reload 或 UI `setState` 强刷。

## Maintenance notes

- 新增会话来源时必须在 writer allowlist 中声明 source、freshness anchor、owner generation 和是否可 recreate；没有声明不得写 Store。
- 只能在 Coordinator/Store commit **之后**合并 UI 通知；不得再次在 ingress 按 ID 合并事实对象。
- `reason` 只用于日志和调度，不得恢复成业务来源或权限判断。
- 评审重点检查三个反模式：`latest callback wins`、`max(timestamp, orderkey)`、`hydrate page direct replace`。
- Plan 094 在本计划完成后继续收口页面级 reload/apply；它不能替代本计划的事件权威和持久化防倒退。
- 后续若启用 `conversationListSdkPrimary`，TabStore 必须复用同一个 lastMessage comparator 和 source envelope，不得另建一套 freshness 规则。
