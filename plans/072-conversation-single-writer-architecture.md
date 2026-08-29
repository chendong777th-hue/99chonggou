# Plan 072: 收敛会话列表为单写入者架构

> **执行器说明**：严格按阶段执行，每个阶段独立提交并完成验证。禁止在发现语义差异时增加新的防抖、fallback、延时或“再刷新一次”来掩盖问题。任何 STOP 条件发生时立即停止并报告。
>
> **漂移检查（首先执行）**：
> `git diff --stat 9f7c46e..HEAD -- lib/src/services/conversation_local lib/src/services/conversation_refresh_bus.dart lib/src/services/conversation_pin_sync_service.dart lib/src/services/group_local/group_membership_sync_service.dart lib/src/conversation.dart lib/src/services/auth_bootstrap_service.dart lib/src/services/im_snapshot_bootstrap_service.dart test`
>
> 当前工作区存在未提交的聊天、媒体、草稿和计划修改。执行器必须保留这些修改，不得 reset、checkout 或覆盖；若本计划涉及的文件已有未提交改动，先逐项归属并报告，确认可以无冲突迁移后再继续。

## 状态

- **执行状态**：进行中；阶段 1–5 已完成代码迁移：SDK listener/typed 分页/UIKit hook、draft、单条与批量已读、pin、mute、群提示未读、好友/群资料、Snapshot/建群/冷归档水合及删除均已进入 Coordinator → Store；数据库已升级 v10，持久 generation/tombstone 可跨重启拦截晚到回流，删除与 tombstone 同事务。阶段 6 已完成 draft、mute、资料、撤回与 pin 成功态的 committed batch 投影，移除对应直接 Notifier/RefreshBus 补刷；免打扰、pin、发消息仅保留带注释和契约测试的 pending/rollback 乐观白名单。剩余启动 reload 白名单、RefreshBus 非正确性用途收口及真机验收
- **优先级**：P0
- **工作量**：L（建议拆成 6 个独立提交，预计多日）
- **风险**：HIGH（核心会话、未读、草稿、置顶、群成员、删除链路）
- **依赖**：065 的草稿 generation 语义必须保留；不依赖 066–071
- **类别**：tech-debt / bug / perf
- **计划基线**：commit `9f7c46e`，2026-08-24

## 为什么必须做

当前会话列表虽然以腾讯 IM SDK 为上游事实来源，但 SDK listener、SDK 分页、UIKit hooks、Snapshot、页面操作、群成员同步、草稿和置顶服务都能直接写 SQLite、Notifier 或 RefreshBus。同一个会话因此可能被旧分页、实时事件和本地操作交错覆盖；现有防抖只能减少刷新次数，不能建立正确顺序。

本计划的目标不是继续修某个症状，而是建立四条架构不变量：

1. 每个 canonical conversation ID 只有一个顺序化写入队列。
2. SQLite 只有一个业务写入入口；Notifier 只消费提交后的最终投影。
3. 每个字段有明确权威来源，旧结果不能整对象覆盖新字段。
4. 删除、退群和登出以 generation/tombstone 使所有晚到结果失效。

完成后的正式链路必须是：

```text
SDK listener / SDK page / local intent / metadata event
                         ↓
ConversationMutationCoordinator
  canonical ID + per-ID generation + field mask + priority
                         ↓
ConversationLocalStore transaction
                         ↓
ConversationUiSnapshot batch
                         ↓
ConversationListNotifier single commit
                         ↓
Feed row-local rebuild / structure rebuild only when required
```

## 当前状态与证据

- `lib/src/services/conversation_local/conversation_sync_service.dart:526-540`：独立 SDK listener 直接把 changed/new/deleted 送入 `_persistChanged/_persistDeleted`。
- `lib/src/services/conversation_local/conversation_sync_service.dart:1694-1701`：全局 `_pendingSdkSync` 通过 `mergePreferStronger` 合并请求；typed C2C/Group 请求只编码在 reason 中，不是结构化待处理集合。
- `lib/src/services/conversation_local/conversation_sync_service.dart:4222-4260`：根据 `conversationListSdkPrimary`，热 listener 可先写 UI，再 mirror SQLite；默认路径则写库后通知 UI，保留两套提交语义。
- `lib/src/services/conversation_refresh_bus.dart:12-72`：全局仅保存一份 `lastReason/lastConversationId`，500ms debounce 和 900ms min interval；无 ID 事件故意保留旧 ID，多个事件不能无损表达。
- `lib/src/conversation.dart:782,1205,1747,3267,5377,5778`：页面本身既 reload Notifier，也直接 upsert store，违反单写入口。
- `lib/src/services/group_local/group_membership_sync_service.dart:2927,3339`：退群会清 pin，但群资料发布仍可直接 upsert 会话。
- `lib/src/services/im_snapshot_bootstrap_service.dart:142-151`：冷启 Snapshot 可直接写库并 reload，与 SDK follow-up 构成另一写入口。
- `lib/src/services/conversation_local/conversation_local_store.dart:3391`：`upsertBatch` 是公开通用入口，被多个服务直接调用；其整对象合并承担了过多字段冲突决策。
- `lib/src/services/conversation_local/conversation_list_notifier.dart:1201,3123`：Notifier 同时提供全量 reload 与增量 apply；调用者自行选择，提交纪律分散。
- `lib/src/services/conversation_local/conversation_perf_flags.dart:412`：`conversationListSdkPrimary=false` 是现有产品边界，本计划不得顺便翻转该开关。

### 必须保持的字段语义

| 字段 | 正式权威 | 合并规则 |
|---|---|---|
| lastMessage / SDK order / SDK unread | 腾讯 SDK | 允许本地 read barrier 防止旧 unread 回灌；旧分页不得覆盖更新的实时事件 |
| local draft | ConversationDraftService | 保留 065 generation；SDK upsert 不得清除用户正在编辑的草稿 |
| pin | 腾讯 pin 为远程权威，本地为 optimistic projection | mutation 失败必须回滚到确认快照；退群/删除清理所有本地 projection |
| group name/avatar | 明确用户修改或 SDK 群资料事件 > 远程群详情 > 本地占位 > conversation fallback | 只 patch 对应字段，不允许旧缓存整对象覆盖 |
| membership | GroupMembershipSyncService | 不完整快照只隐藏；明确退群/被踢/解散产生 tombstone |
| archive/folder/mute | 现有对应服务 | 通过 local intent 事件提交，业务语义不变 |
| deletion | 用户操作或明确 SDK/成员事件 | tombstone 优先于所有旧页和旧 listener 结果 |

## 仓库约定与验证命令

| 用途 | 命令 | 成功标准 |
|---|---|---|
| 差异检查 | `git diff --check` | exit 0 |
| 定向静态检查 | `flutter analyze lib/src/services/conversation_local lib/src/services/conversation_refresh_bus.dart lib/src/services/conversation_pin_sync_service.dart lib/src/services/group_local/group_membership_sync_service.dart lib/src/conversation.dart` | 无本计划新增 error |
| 核心测试 | `flutter test test/conversation_local_store_sort_test.dart test/conversation_list_notifier_incremental_test.dart test/conversation_sync_reload_coalesce_test.dart test/conversation_refresh_bus_test.dart test/conversation_typed_by_filter_meta_test.dart test/conversation_unread_guard_test.dart test/conversation_local_store_draft_test.dart test/conversation_pin_tencent_primary_test.dart test/pending_non_member_group_conversation_test.dart` | 全部通过 |
| 全量测试 | `flutter test` | 全部通过；若存在基线失败，必须记录基线与本计划无关的证据 |

测试风格使用现有 deterministic fake/override 模式，不使用真实网络和 sleep。参考 `test/conversation_sync_reload_coalesce_test.dart` 的 override/fakeAsync、`test/conversation_local_store_sort_test.dart` 的纯模型断言。

## 范围

### 可以修改

- `lib/src/services/conversation_local/` 下的会话同步、存储、Notifier、identity 和新增 coordinator 文件
- `lib/src/services/conversation_refresh_bus.dart`
- `lib/src/services/conversation_pin_sync_service.dart`
- `lib/src/services/group_local/group_membership_sync_service.dart`
- `lib/src/services/im_snapshot_bootstrap_service.dart`
- `lib/src/services/auth_bootstrap_service.dart`
- `lib/src/platform/uikit_conversation_local_bridge.dart`
- `lib/src/conversation.dart` 中会话数据写入/刷新接线
- 对应 `test/` 文件

### 禁止修改

- 腾讯 SDK 版本、wire payload 和 SDK 内部实现
- 聊天消息历史来源、分页、排序和消息内存窗
- 会话列表视觉布局、滑动交互、归档/文件夹产品语义
- 未读含义、草稿产品行为、置顶/免打扰操作含义
- `ConversationPerfFlags.conversationListSdkPrimary` 的默认值
- 钱包、通话、媒体发送和搜索链路

## Git 工作流

- 分支：`codex/072-conversation-single-writer`
- 每个阶段一个可回滚提交；提交风格匹配仓库，例如 `refactor: centralize conversation mutations`
- 不推送、不合并，除非操作员另行要求

## 阶段 1：先写行为契约和竞争测试

在不改变运行逻辑前新增测试，锁定以下场景：

1. 同一会话旧 SDK page 晚于实时 changed 返回，最终 lastMessage/unread/order 使用实时新值。
2. C2C 与 Group typed sync 同时请求，两种类型都保留并各执行一次，不通过 reason 字符串解析。
3. `group_self_removed(A)`、`new_message(B)`、全局资料事件连续到达时，A/B 事件及其 ID 均不丢失、不串 ID。
4. 删除后旧分页/旧 listener 晚到不会恢复会话。
5. 本地清零未读后，旧 SDK unread 回调不能恢复；更新的 SDK unread 可以生效。
6. 发送清草稿后旧草稿保存完成不能恢复；新的用户编辑仍可创建草稿。
7. 群资料旧缓存不能覆盖更高 generation 的 SDK/远程字段。
8. pin optimistic mutation 与远程确认乱序时，最终状态等于最新确认或最新未失败 intent。
9. 等价 group ID 只能形成一个逻辑行、一个队列、一个 tombstone。
10. logout/owner 切换后，旧 owner 的所有异步结果被拒绝。

新增测试建议：

- `test/conversation_mutation_ordering_test.dart`
- `test/conversation_field_authority_test.dart`
- `test/conversation_tombstone_test.dart`
- `test/conversation_owner_generation_test.dart`

**验证**：新增测试先能准确暴露当前竞态；以测试注释记录当前失败原因。不要把预期写成当前错误行为。进入阶段 2 前，已有核心测试必须保持绿色。

## 阶段 2：引入统一事件模型和影子协调器

新增：

- `conversation_mutation_event.dart`
- `conversation_mutation_coordinator.dart`
- `conversation_field_authority.dart`
- `conversation_tombstone_store.dart`（接口先建，持久化在阶段 5）

事件至少包含：

```dart
eventId
ownerUserId
canonicalConversationId
source
kind
fieldMask
sourceVersion
ownerGeneration
conversationGeneration
payload
occurredAt
```

要求：

- canonical identity 必须复用 `MessageConversationId.sameConversation` / 现有 preferred group ID 规则，不再新写字符串去前缀逻辑。
- 每个 canonical ID 独立串行；不同会话允许并行，但 UI commit 统一批处理。
- delete/self-removed 的优先级高于 upsert；metadata patch 不能覆盖 message/unread 字段。
- Coordinator 初期运行 shadow mode：计算目标快照、记录字段级差异，但不写 SQLite/Notifier。
- 日志只记录哈希化会话 key、source/kind/generation/field mask/耗时，不记录正文、真实用户或群 ID。

**验证**：纯 Dart 测试证明同一 ID 严格顺序、不同 ID 不互相阻塞、owner generation 失效、字段优先级确定；shadow mode 不改变 store 与 UI。

## 阶段 3：SDK listener 和分页首先切入协调器

只迁移 SDK 入口：

- `onConversationChanged/onNewConversation/onConversationDeleted`
- typed C2C/Group SDK pages
- `onSyncServerFinish` 触发的补同步
- UIKit conversation hooks 只转发事件，不再直接持久化

将 `_pendingSdkSync` 改成结构化请求集合：

```text
pendingTypes: {c2c, group}
resetByType
forceByType
strongestDrainModeByType
latestOwnerGeneration
```

禁止继续把 `#type=1/#type=2` 当成业务状态。分页结果必须携带 request generation；实时 listener 已提交后，旧分页只允许补充未拥有的字段，不得整对象覆盖。

保留旧写路径作为运行期 kill switch，仅用于完整回滚，不能双写 UI。影子差异连续通过规定场景后，SDK 入口切到 coordinator authoritative mode。

**验证**：阶段 1 的分页/实时乱序、typed sync、owner 切换测试全部通过；一次 SDK batch 只产生一次 SQLite transaction 和一次 UI batch commit。

## 阶段 4：迁移所有本地 mutation，禁止旁路写入

逐个迁移下列来源为 typed local intent：

- draft save/clear
- mark read/unread guard
- pin/unpin
- archive/folder/mute
- group name/avatar patch
- create group/first publish
- delete conversation/history clear shell policy
- Snapshot bootstrap

每迁移一个来源：

1. 先加其事件与字段权威测试。
2. 改调用者只提交 intent。
3. 删除该调用者对 `ConversationLocalStore.upsertBatch/deleteBatch`、`ConversationListNotifier.apply/reload` 的直接调用。
4. 验证没有额外 RefreshBus full reload。

在此阶段给 store 增加写入令牌或 `@visibleForTesting` 守卫，使生产代码只有 Coordinator 能调用底层 transaction。读取 API继续开放。

**验证**：执行 `rg -n "ConversationLocalStore\.instance\.(upsertBatch|deleteBatch)|ConversationListNotifier\.instance\.(applyConversationsFromStore|reloadFromLocal)" lib/src`，结果只能包含 Coordinator、明确的启动只读投影恢复入口及带注释的过渡 allowlist。每个剩余项都必须在计划内列明理由。

## 阶段 5：持久 tombstone 与 generation

新增 owner 隔离的轻量持久状态：

```text
canonicalConversationId
ownerUserId
removedGeneration
removedAt
reason
expiresAt
```

规则：

- 明确 delete/退群/被踢/解散在同一事务中写 tombstone、删会话投影、清本地 pin/草稿/待处理 patch。
- 所有 SDK page、listener、Snapshot 和 deferred event 在写入前检查 tombstone 与 owner generation。
- 只有明确重新建会话、重新入群或更新 generation 的权威事件可以越过 tombstone。
- TTL 清理由低优先级后台任务执行；不得在启动首帧全表扫描。
- logout 递增 owner generation 并清内存队列，旧 Future 完成后只能被丢弃。

**验证**：删除后晚到 page/listener、重启后晚到 Snapshot、退群后 pin reconcile、重新入群四类测试全部通过。

## 阶段 6：单一 UI 投影与删除旧链路

Coordinator transaction 成功后输出不可变的 `ConversationUiSnapshotBatch`：

- upserted snapshots
- deleted canonical IDs
- structureChanged
- changed field masks
- commit generation

Notifier 只接受该 batch：

- 排序键、pin、activeTime 或新增/删除变化才增加 `structureRevision`。
- unread、摘要、草稿、名称、头像变化只失效对应行。
- 群资料 revision 必须进入行指纹或 snapshot revision，不能等待父级偶然 rebuild。
- 完全相同快照不 notify。

随后：

- `ConversationRefreshBus` 不再承载会话数据正确性；若仍用于页面导航/外壳刷新，改为不可串 ID 的 typed event queue。
- 删除 SDK-primary/local-primary 双提交分支中的废弃路径，但保持 `conversationListSdkPrimary=false` 的产品行为。
- 删除 UIKit hook、页面和服务中的直接 store/notifier 写入口。
- 删除仅为旧多入口竞态存在的“再 reload 一次”、延迟补刷和 reason 字符串推断。

**验证**：静态搜索确认单写入口；所有核心与新增测试通过。Profile 场景中一次实时事件最多一次 DB commit、一次 row notify；全量 reload 只允许冷启动投影恢复、明确账户切换或数据库迁移。

## 真机验收矩阵

必须在 iOS 和至少一台 Android 真机覆盖：

1. 冷启动本地列表先显示，SDK 补同步后不闪回旧摘要/群名/未读。
2. 后台 30 分钟积累大量 C2C 与群消息，恢复后会话摘要和未读及时且无整表跳动。
3. 正在聊天时连续收发，聊天页和会话列表最终一致。
4. 同时新建群、收到 C2C、修改群名，两类会话都出现且资料稳定。
5. 删除普通会话后重启、恢复网络、SDK 翻页均不复活。
6. 退群、被踢、解散且原会话已置顶，不出现旧壳回灌。
7. 发送消息后草稿不恢复；发送失败和新编辑仍保留正确草稿。
8. pin/unpin、归档、免打扰、文件夹操作顺序与旧版本一致。
9. 网络断开、恢复、账号退出并切换新账号，旧账号会话绝不进入新账号 UI。
10. 500+ 会话、消息风暴下滚动保持可用，RefreshBus 不触发 SDK 双类型无条件整页同步。

## 完成标准

- [ ] 生产代码只有 Coordinator 可以执行会话业务写事务。
- [ ] 同一 canonical conversation ID 的 mutation 严格按 generation 提交。
- [ ] C2C/Group pending sync 不再通过 reason 字符串表达且不会互相覆盖。
- [ ] 删除/退群有持久 tombstone，晚到 page/listener/Snapshot 不会复活。
- [ ] 字段权威测试覆盖 message、unread、draft、pin、metadata、membership、delete。
- [ ] Notifier 只消费提交后的 snapshot batch，内容变化不触发结构刷新。
- [ ] RefreshBus 不再承担会话数据正确性。
- [ ] `git diff --check`、定向 analyze、核心测试和新增测试通过。
- [ ] 真机十项验收通过，并记录迁移前后 DB commit、UI notify、恢复延迟对比。
- [ ] 删除旧直接写入口和仅为旧竞态存在的补刷代码；没有永久双写。

## STOP 条件

遇到以下任一情况必须停止，不得临时加补丁：

- 需要改变腾讯 SDK 消息/会话语义或翻转 `conversationListSdkPrimary` 才能继续。
- 无法为某个字段确定唯一权威来源。
- shadow snapshot 与现网快照在未读、lastMessage、排序、草稿、pin、membership 任一字段出现无法解释的差异。
- tombstone 会阻止合法重新入群或重新建会话，且没有明确权威 generation 可解除。
- 迁移要求同时改聊天历史、通话、钱包、搜索或媒体发送链路。
- 某阶段必须保留两个生产写入者才能工作。
- 核心回归测试连续两次失败，或只能通过延时/sleep 才通过。

## 回滚策略

- 阶段 2–4 使用单一 cutover flag 在进程启动时确定模式；一次运行内禁止动态切换。
- 回滚只能恢复到完整旧入口，禁止“SDK 走新入口、local intent 走旧入口”的混合模式。
- 数据库 schema 变更必须向前兼容：旧版本忽略新增 tombstone/generation 表，新版本能读取旧会话行。
- 每个阶段独立提交；出现语义回归时回滚整个阶段，不摘取局部 hunk。

## 维护说明

未来新增任何会话字段或业务操作，都必须先在 `ConversationFieldAuthority` 登记权威来源、合并规则和 generation，再通过 Coordinator 接入。代码评审应拒绝任何新的直接 `upsertBatch/deleteBatch/reloadFromLocal` 业务调用；“为了刷新及时再调一次 reload”应视为架构回归。
