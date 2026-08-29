# Plan 102: 让批量已读水位单调推进并禁止旧 SDK 快照复活气泡

> **Executor instructions**: 严格按步骤执行并运行每个验证命令。禁止用延长
> grace、重复 reload、强制 UI 清零或关闭 SDK 同步掩盖问题。命中 STOP 条件时
> 停止并报告。完成后更新 `plans/README.md`。
>
> **Drift check（首先执行）**：
> `git diff --stat 9f7c46e..HEAD -- lib/src/services/conversation_unread_clear_service.dart lib/src/services/conversation_local/conversation_local_store.dart lib/src/services/conversation_local/conversation_sync_service.dart lib/src/services/conversation_local/conversation_unread_guard.dart lib/src/services/conversation_local/conversation_mutation_shadow_bridge.dart lib/src/services/conversation_local/conversation_list_notifier.dart lib/src/services/conversation_local/conversation_unread_aggregate.dart lib/src/services/conversation_local/conversation_tab_store.dart test`
> 当前工作区很脏；逐段核对现场代码，禁止 reset、checkout 或覆盖他人修改。

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: 093（字段级 Coordinator 权威）；纠偏 096；保留 098 离页事务语义
- **Category**: bug / correctness / tests
- **Planned at**: commit `9f7c46e`, 2026-08-25（基于 dirty worktree 与真机日志）

## Why this matters

真机日志证明 scopeAll/group 本地清除和腾讯 SDK 类型清理均成功，但 SDK 会话快照
随后重新写入 unread。代码已建立包含 msgID、seq、timestamp、orderKey、version 的
read barrier，却在持久化预处理看到 `unreadCount > 0` 时、比较消息是否真正越过水位
之前调用 `_clearReadCleared`。旧快照与真实新消息因此失去判别依据。

完成后必须满足：同锚点或更旧快照不能复活未读；只有可证明 lastMessage 已前进的
消息才能消费 barrier 并增加未读；SQLite、Coordinator、Notifier、聚合角标、离屏
hydrate 和重启恢复保持同一结论。

## Current state

- 日志 `pasted-text.txt:608-622`：本地清 8 个群会话、33 条未读，SDK `group`
  返回 `sdkCode=0`；`:627,636,643,649` 又出现 unread，且 merge 时
  `readClearedAtMs=0`。
- `conversation_local_store.dart:_readClearedAtForPersistedRow` 在非活跃会话
  incoming unread 大于 0 时直接 `_clearReadCleared`。
- `upsertBatch` 先调用上述函数，后调用 `_mergeConversationUnread`；后者的 exact
  anchor/timestamp replay 防护因此读不到 barrier。
- `_resolvedReadClearedAtMs` 只查精确 key；`readBarrierFor` 支持
  `MessageConversationId.sameConversation`，ID alias 语义不一致。
- `markConversationsReadLocallyBatch` 已为每个会话建立 anchor 并通过 Coordinator
  提交 `unread: 0`。问题不是没写 SQLite，而是后续 ingress 过早撤销水位。
- 原生端批量范围/写入走 SQLite；UI 读取 `ConversationListNotifier._conversations`。
  `_memoryByOwner` 仅是 Web 分支。`conversationListSdkPrimary` 默认 false。
- 096 已有 `ConversationReadBarrier`/`resolveSdkUnreadAgainstReadBarrier`；必须扩展同一
  模型，不新增第二套 guard。098 的行/聚合即时清零和 leave single-flight 不得回退。

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Inventory | `git status --short` | 记录已有修改，不覆盖无关文件 |
| Authority audit | `rg -n "_clearReadCleared|recordReadClearedAnchor|resolveSdkUnreadAgainstReadBarrier|_mergeConversationUnread|readClearedAt" lib/src/services/conversation_local` | 所有消费点责任明确 |
| Analyze | `flutter analyze lib/src/services/conversation_unread_clear_service.dart lib/src/services/conversation_local/conversation_local_store.dart lib/src/services/conversation_local/conversation_sync_service.dart lib/src/services/conversation_local/conversation_unread_guard.dart lib/src/services/conversation_local/conversation_mutation_shadow_bridge.dart lib/src/services/conversation_local/conversation_list_notifier.dart lib/src/services/conversation_local/conversation_unread_aggregate.dart lib/src/services/conversation_local/conversation_tab_store.dart` | 无新增 error |
| Tests | `flutter test test/conversation_unread_clear_service_test.dart test/conversation_unread_guard_test.dart test/conversation_unread_merge_foreground_test.dart test/conversation_unread_aggregate_test.dart test/conversation_mutation_coordinator_test.dart test/conversation_mutation_shadow_bridge_test.dart test/conversation_pending_sdk_sync_test.dart` | 全部通过 |
| Hygiene | `git diff --check` | exit 0 |

## Scope

**In scope**：

- `lib/src/services/conversation_unread_clear_service.dart`
- `lib/src/services/conversation_local/conversation_local_store.dart`
- `lib/src/services/conversation_local/conversation_sync_service.dart`
- `lib/src/services/conversation_local/conversation_unread_guard.dart`
- `lib/src/services/conversation_local/conversation_mutation_shadow_bridge.dart`
- `lib/src/services/conversation_local/conversation_list_notifier.dart`
- `lib/src/services/conversation_local/conversation_unread_aggregate.dart`
- `lib/src/services/conversation_local/conversation_tab_store.dart`（只保持 future SDK-primary 契约）
- 对应 `test/` 文件与脱敏日志字段

**Out of scope**：SDK 协议/版本、聊天历史/发送/媒体、数据库替换、现在翻开
SDK-primary、改变真实新消息的未读语义、增加 Timer/reload 兜底、迁移群通知/好友申请。

## Git workflow

- Branch: `codex/102-monotonic-read-watermark`
- 提交顺序：失败测试 → Store 裁决 → ingress/Coordinator → UI 投影/重启 → 日志。
- 不 push、不合并，除非操作员明确要求。

## Steps

### Step 1: 用真实 SQLite 链路锁定回弹

新增 `test/conversation_mark_all_read_watermark_test.dart`，经过批量服务、SyncService/
Coordinator、Store commit、Notifier 投影，禁止只测私有 merge：

1. 群会话 `lastMessage=A, seq=100, unread=20` 执行 scopeAll/group；SQLite、
   Notifier、aggregate 均为 0，并存在 anchor A/version。
2. 提交同 A/seq=100/unread=20 的晚到 SDK 快照；所有投影仍为 0，barrier 保留。
3. 更旧 msgID/seq/timestamp/orderKey 仍保持 0。
4. 真实新 B/seq=101/unread=1 必须变 1，并消费或推进 barrier。
5. C2C 覆盖同秒不同 msgID，禁止使用跨发送者 seq 作为全局顺序。
6. 裸 ID、`group_` ID、community `@TGS#` ID 只形成一个逻辑水位。
7. SDK type clean 完成前后注入旧快照均不得回弹。

**Verify**：修复前“同锚点旧快照”稳定失败，并证明 barrier 在 merge 前消失。

### Step 2: 建立唯一 barrier 消费入口

- `_readClearedAtForPersistedRow` 不得因 `incoming.unreadCount > 0` 直接清 barrier；它只
  解析当前水位。
- barrier 只能在“incoming 已证明越过 anchor”的单一入口被消费。
- 裁决复用 `ConversationReadBarrier` 的 msgID、seq、timestamp、orderKey、version。
- 顺序必须是 canonicalize ID → 读取 barrier → 裁决 → 持久化；禁止先 clear 再比较。
- `unreadCount > 0` 本身永远不是消息前进证据。
- Store fallback 若绕过 `resolveSdkUnreadAgainstReadBarrier`，改为调用同一纯裁决函数。

**Verify**：`_clearReadCleared` 每个生产调用都能证明消息前进、用户清理或账号清理；
不存在“仅 unread>0”清 barrier。

### Step 3: 统一会话 ID 的 watermark key

建立 Store 内部 canonical read-key helper，让 `_readClearedAtMs`、
`_readClearedLastMsgId`、`_readBarriers`、SQLite conversation ID 与 Coordinator canonical ID
共用。兼容读取旧 alias，写入收敛到 canonical key；SDK 对外裸 ID 参数保持不变。

**Verify**：Step 1 三种 ID 形态及重启/hydrate 测试通过，不出现分裂 barrier。

### Step 4: 批量已读原子持久化每会话 watermark

- 从同一 SQLite 事务行读取 lastMsgId、seq、timestamp、orderKey，为 preview 命中的每个
  会话建立 barrier/version。
- 同一 commit 写 `unread_count=0`、`read_cleared_at` 和完整 durable barrier。
- Coordinator unread field stamp 与 barrier.version 使用同一版本域。
- `markViewModelReadLocally` 只能做幂等兼容投影；`via=noop` 是预期，不是第二次事实写。
- 类型级 SDK clean 只更新 pending/confirmed 状态，不能删除每会话 barrier。
- 如需 schema 迁移，扩展现有 meta/coordinator state 并兼容 DB v10；不新增第二张真源表。

**Verify**：清空进程 cache、重开数据库后，旧快照仍被拒绝；迁移测试通过。

### Step 5: 收敛全部 snapshot ingress

核对 SDK changed/new、登录 page、前台/重连、cloud catch-up、compatibility recovery、
UIKit page mirror 和 Store fallback。每个来源携带 `ConversationMutationSource`，先做同一
watermark 裁决，再进 Coordinator/SQLite；UI 不得直接写 SDK unread。

增加静态契约测试枚举生产 `.unreadCount =` 和 Store upsert 入口，防止新增旁路。

**Verify**：每个 ingress 回放旧 A 都为 0，真实新 B 都为 1。

### Step 6: 统一 UI committed projection

SQLite commit 产生一次 typed UI batch；Notifier `_conversations`、`_typeHydrate`、
TabStore 和 Aggregate 消费同一裁决结果。拒绝旧 snapshot 时不发 unread delta；新消息只
发一次 `0 -> 1`。Store 扫描只校准，不能在短窗口发布旧值。

**Verify**：可见行、离屏 hydrate、群总角标和重启结果一致；每事件一次 notify/delta。

### Step 7: 增加可证明决策的全版本脱敏日志

每次裁决记录 source、incoming/previous unread、anchor/incoming msgID hash、seq、
timestamp、orderKey、barrier/mutation version、operationId 与 decision：
`reject_same_anchor|reject_older|accept_newer|keep_zero|clear_user_intent`。
Release 禁止完整 ID、正文、头像 URL和可能含用户数据的 SDK desc。formatter 写纯单测。

**Verify**：受控回放中旧快照明确 reject、新消息明确 accept，同 operationId 串起本地
commit、SDK clean 与 snapshot。

### Step 8: 联合回归和真机验收

覆盖单聊/普通群/community/归档，selected/scopeAll/archivedAll，高速入站、乱序/重复，
SDK 成功/失败/-10113，前后台/重连/杀进程/多设备，可见/离屏/免打扰。双账号积累未读
后全部已读，再高速发送；旧气泡不得回弹，操作后的真实新消息正常计数，重启结果一致。

**Verify**：Commands 全通过并保存脱敏决策日志。工具链权限失败必须标记 BLOCKED，
不能以静态检查代替行为验证。

## Done criteria

- [ ] 同 anchor、更旧或无法证明推进的 SDK snapshot 不能让 0 回弹。
- [ ] 可证明更新的真实消息能使 unread 从 0 变 1。
- [ ] 批量已读原子持久化每会话完整 watermark/version。
- [ ] 会话 ID alias 不分裂 barrier。
- [ ] 所有 ingress 走同一裁决。
- [ ] SQLite、Notifier、hydrate、TabStore、aggregate 一致。
- [ ] 杀进程重启后旧快照仍不能复活气泡。
- [ ] 全版本日志可关联且已脱敏。
- [ ] analyze、定向/迁移/全量测试和 `git diff --check` 通过。
- [ ] Scope 外无修改（计划索引除外）。

## Execution record (2026-08-25)

- 已完成 Store 侧核心裁决：`unreadCount > 0` 不再清除 read barrier；SDK
  snapshot 只有消息 timestamp 或可比较 seq 超过 anchor 才能消费 barrier。
  `orderkey` 保持排序用途，不能单独证明一条新消息。
- 批量已读查询现在读入 `raw_json` 和 `order_key`，从 SQLite 行恢复完整
  lastMessage anchor 后建立 per-conversation barrier；旧 alias cache 读取也会按
  `MessageConversationId.sameConversation` 兼容归并。
- Store fallback merge 复用同一个 `resolveSdkUnreadAgainstReadBarrier`，不再有
  未经裁决的 Store 写入路径清理 barrier。
- 已新增同锚点大 `orderkey` 回放与 community group alias 回放测试。
- `git diff --check` 已通过。Flutter 定向测试/analyze 未执行：Flutter SDK
  缓存写入授权的自动审批服务返回 HTTP 503，必须恢复授权后补跑，不能据此标记完成。

## STOP conditions

- 无法用 identity/seq/timestamp/orderKey 证明 incoming 是否越过 anchor。
- C2C 被迫用跨发送者 seq 作为全局顺序。
- 真实新消息被持续压成 unread=0。
- 必须翻开 SDK-primary、关闭虚拟列表或增加第二 writer 才能通过。
- 完整 barrier 只能靠新增第二张真源表持久化。
- 093 的 writer/source 收口与本计划冲突。
- 草稿、置顶、归档、免打扰、lastMessage 或消息顺序回归。
- 测试连续两次失败且 scope 内无法合理修复。

## Maintenance notes

`unreadCount` 永远只是投影；评审必须追问它对应哪条 lastMessage、相对哪个 watermark、
来自哪个 source/version。未来启用 SDK-primary 时继续消费同一 committed projection，
不能在 TabStore 复制规则。新增 SDK ingress 必须先加入旧/新 snapshot 契约测试。
