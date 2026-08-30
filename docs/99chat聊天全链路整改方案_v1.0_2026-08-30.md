# 99chat 聊天全链路整改方案 v1.0

> 版本：v1.0-remediation-plan
> 日期：2026-08-30
> 对照基线：`D:\bf\99chat_chat_full_chain_post_refactor_audit_v1.1.md`（v1.1-full-audit 2026-08-30）
> 架构基线：`docs/腾讯IM模式一_专用消息服务架构设计_重梳版.md`
> 交接基线：`docs/腾讯IM重构_新窗口详细交接_2026-08-30.md`
> 当前 HEAD：`29948b52`（origin/main）
> 性质：分阶段整改实施规划，每个阶段含代码位置、根因、修复路径、验收证据
> 与 v1.1 关系：v1.1 是"问题清单"，本文是"如何修复并验收"

---

## 0. 执行结论

v1.1 审计已确认重构建立了正确的基础设施，但仍处新旧双轨中后段。整改必须按发布阻断权重排序，**先正确性，再性能，最后清理兼容层**。任何"页面能跑通"都不能算作完成。

整改必须严格遵守的不变量：

- `tui_chat_global_model.dart` 中 `resolvedStableIdentity` 修复（line 2427）必须保留。
- 历史、实时、发送、撤回、删除必须经过同一个 `MessageReconciliationWriter` 裁决边界。
- 所有长异步链必须携带 `ownerUserId + accountGeneration + domainGeneration + clearEpoch + Writer Lease fencingToken`。
- 单聊不得使用群 Seq 推理连续性，群消息以服务端 Seq 为第一依据。
- `OutcomeUnknown` 禁自动重发，等待历史/实时/查询认领或用户明确处理。
- Push 只负责唤醒和提示，正式消息必须来自 SDK/历史 Writer。
- A 账号晚到事件不得污染 B 账号（`AccountScopedRuntime` 强隔离）。

整改不是 UI 改造：

- UI 布局、样式、动画和交互保持不变；
- 数据来源从旧链路切到 `Message Core` / `Conversation Core` / `GroupMemberCore`；
- 每个写入权都有 owner、accountEpoch、scope。

---

## 1. 优先级矩阵（按发布阻断权重）

下表是本次整改的硬优先级。任何条目未关闭都不能宣称"达到大用户、大消息量稳定运行"。

| 权重 | 编号 | 简称 | 关闭证据类型 |
|---|---|---|---|
| P0-Critical | B1-1 | 钱包金融卡片走 Outbox | 单元 + 集成 + 真机强杀 |
| P0-Critical | B1-2 | 红包通知走 Outbox | 单元 + 集成 + 真机强杀 |
| P0-Critical | READ-P0-001 | 删除群提示全清逻辑 | 单元 + 集成 |
| P0-Critical | READ-P0-002 | 建 durable ReadReceiptOutbox | 单元 + 跨重启 |
| P0-Critical | READ-P0-003 | 会话已读持久化恢复 | 单元 + 跨重启 |
| P0-Critical | LIFE-P0-001 | 修 socket ready 判定 | 单元 + 集成 |
| P0-Critical | LIFE-P0-002 / MSG-P0-002 | listener 吞错兜底 | 单元 + chaos |
| P0-Critical | ACC-P0-001~004 | AccountScopedRuntime | 切号压力 + 资源归零 |
| P0-Critical | SEND-P0-001/002 | Outbox 真 payload + 跨故障域 | 文本/媒体/卡片强杀 |
| P0-Critical | WALLET-P0-001/002 | WalletPending owner + epoch | 双账号恢复 + 服务端幂等 |
| P0-Critical | HIST-P0-001 | 历史/搜索走统一 Coordinator | 实时 + 搜索 + 上翻并发 |
| P0-Critical | CONV-P0-001 | MessageOrderComparator | property test |
| P0-Critical | MEMBER-P0-001~003 | snapshot + cursor 同事务 | 故障注入 + 完整快照 |
| P0-High | PUSH-P1-001~004 | dedup owner + 稳定 ID | 高消息量 + 跨账号 |
| P0-High | B2 | im10_migration_scan 扫 third_party | CI 门禁 |
| P1 | UI-P1-001~007 / P2-001 | UI 热路径 | 5k 会话 + 100 万历史 |
| P1 | B3 | 巨型文件拆分 | characterization + 拆分 + 视觉回归 |
| P1 | B5 | 撤回/删除 SDK 失败持久化重试 | 单元 + 集成 |
| P2 | B7 | mergePeekWindowWithLiveMemory 锚点 | 并发测试 |
| P2 | B10 | 草稿/置顶/免打扰 ADR | ADR + 单元 |

---

## 2. 整改原则

1. **数据来源唯一**：SDK/HTTP/TCP/本地缓存都只是数据源，不直接拥有 UI 列表写权。
2. **写入权单一**：消息、会话、成员各自一个 Writer/Coordinator，不允许第二个正式写入路径。
3. **状态机显式**：`OutcomeUnknown` / `retryable` / `pausedByLogout` 等状态必须显式，禁止隐式重试。
4. **可恢复载荷**：所有 durable 事件必须能在重启后由 SDK 重叠窗口或本地缓存重建。
5. **owner/epoch 强校验**：所有 Map key、Timer、Future、Stream subscription 必须归属 `AccountScopedRuntime`，close 时销毁。
6. **退避有界**：重试必须指数退避 + 上限 + 死信隔离，禁止无界循环。
7. **日志脱敏**：聊天正文、文件路径、精确经纬度、支付密码、完整 userID/groupID/msgID 不得入日志和埋点。
8. **CI 强门禁**：禁止新增绕过 Writer 的调用；禁止新增第二份 Outbox；禁止新增吞错 `catch (_)`。

---

## 3. 阶段 0：可观测性 + 静态门禁

> 退出条件：所有写入点都有 owner、accountGeneration、domainGeneration；CI 阻断新绕过。

### 3.1 全事件 inventory

- 列出 `tui_chat_global_model.dart` / `tui_chat_separate_view_model.dart` 中所有 listener 回调与对应 `APPLY/IGNORE/DEAD_LETTER` 策略。
- 列出 `lib/src/services/im/` 中所有 `ingest.append` 调用点 + 失败兜底。
- 列出 `third_party/tencent_cloud_chat_uikit/lib/business_logic/` 中所有 `setMessageList` 调用点。

### 3.2 全 Outbox inventory

- 列出所有 `sdk.getMessageManager().createXxxMessage` + `sendMessage` 调用点。
- 标记每个调用点是否经过 `ImOutgoingSendCoordinator`。

### 3.3 修静态门禁 `tool/im10_migration_scan.ps1`

**根因**：当前只扫 `lib/src/**`，漏 `third_party/tencent_cloud_chat_uikit/lib/business_logic/`。

**整改**：

- 扫描路径追加：
  - `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/`
  - `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/`
- 失败模式增加：
  - `setMessageList` 在 production path 调用 > 0 → fail
  - `sdk.getMessageManager().create*Message` 在非 Outbox 路径调用 > 0 → fail
  - `catch (_)` 静默吞错（白名单除外）→ fail
- 失败即 CI 红，禁止合入。

**验收**：CI 运行脚本，绿；人工新增 18 处 setMessageList 直写，CI 红。

### 3.4 关键 metrics

- `chat_writer_commit_ms` P50/P95/P99
- `chat_outbox_prepared_to_sending_ms` P50/P95/P99
- `chat_outcome_unknown_count`（按 owner/card_type）
- `chat_inbox_dead_letter_count`
- `chat_recovery_run_dispatched/deferred`
- `chat_conversation_unread_recompute_count`
- `chat_member_snapshot_age_ms`
- `chat_socket_ready_decision_latency_ms`
- `chat_push_notification_dedup_hit_ratio`

### 3.5 日志脱敏

- 任何 debugPrint/log 不打印 message text、userID、groupID、msgID、文件路径、经纬度、支付密码。
- 加 `redact()` 工具函数统一脱敏；CI 扫描敏感字串。

---

## 4. 阶段 1：发布阻断正确性

> 退出条件：切号、断网、强杀、坏事件不会丢状态、不污染账号、不丢金融消息。

### 4.1 B1-1 钱包金融卡片走 Outbox（P0-Critical）

**现状**：`lib/src/pages/wallet/order/wallet_card_im_sender.dart:94` 直接 `sdk.getMessageManager().createCustomMessage` + `sendMessage`，**没有 Outbox 持久化、没有 OutcomeUnknown 恢复**。

**根因**：业务消息发送未走统一 Coordinator；金融消息丢失可能导致资产记账不一致。

**整改**：

- 把 `WalletCardImSender.send` 改为通过 `ImOutgoingSendCoordinator.instance.send(...)`。
- Outbox 保存完整 payload（`customData`、业务订单快照、`clientOrderId`）。
- 增加 `WalletCardOutbox` 表，与 `message_outbox` 共事务：
  - 列：`client_order_id TEXT PRIMARY KEY`、`operation_id TEXT`、`state INTEGER`、`amount INTEGER`、`recipient TEXT`、`created_at INTEGER`、`updated_at INTEGER`、`fencing_token INTEGER`。
- 进程恢复路径：扫描 `WalletCardOutbox state IN (PENDING, SENDING, OUTCOME_UNKNOWN)`，按 `client_order_id` 幂等重发，**不得**直接调 SDK send。
- 服务端必须返回 `wallet_chat_outbox` 幂等证据（双账号恢复不双发）。

**验收**：
- 单元：mock Coordinator 验证 `WalletCardImSender.send` 走 Outbox。
- 集成：fake SDK 验证 `client_order_id` 幂等。
- 真机强杀：发红包卡片过程中强杀，重启后不重发也不丢发；服务端账目正确。
- 双账号：A 发 → 强杀 → 切 B → 切回 A → 不应误发到 B；服务端账目正确。

**代码位置**：
- 新增：`lib/src/pages/wallet/order/wallet_card_outbox_store.dart`
- 改：`lib/src/pages/wallet/order/wallet_card_im_sender.dart:94`
- 改：`lib/src/pages/wallet/order/wallet_pending_recovery_service.dart:141-147`（resendRetryableImCards 必须经 Outbox）

### 4.2 B1-2 红包通知走 Outbox（P0-Critical）

**现状**：`lib/src/services/red_packet_claim_notice_sender.dart:79` 直接 SDK 自定义消息，无 Outbox。

**整改**：

- 同 4.1，但额外要求：红包通知的 `RedPacketOrderId` 作为 `clientCorrelationId`。
- 服务端必须按 `(owner, red_packet_id, operation_id)` 幂等。

**验收**：同 4.1。

### 4.3 B1-3 语音消息走 Outbox（P1 → 本阶段同步修）

**现状**：`lib/src/services/tencent_voice_to_text_service.dart:124` 直接 SDK。

**整改**：同 4.1；多图/多语音的最终顺序由 Outbox 串行队列保证。

### 4.4 READ-P0-001 删除群提示全清逻辑（P0-Critical）

**现状**：`lib/src/services/group_conversation_unread_helper.dart:92-109` 立即 + 600/1500/3000ms 共 4 次 `clearConversationUnread`，3 秒窗内真实新消息会被全清抹掉。

**根因**：误把"系统提示增未读"当"用户消息增未读"处理；用全清逻辑而非定点扣减。

**整改**：

- 删除 `scheduleClearRepeatedly`。
- 新增 `absorbOneUnreadBump` 已经在 line 18 存在，扩参为 `({required String conversationID, required String effectId})`，**只**对单次 effectId 扣 1：`unread = max(0, unread - 1)`。
- `notification_settings_service.dart` 调用 `scheduleClearAfterGroupCreate` / `scheduleClearForSelfOperatedGroupTips` 的所有路径改为 `absorbOneUnreadBump(effectId: ...)`。
- provider unread/revision 不一致时，以本地 unread + provider revision 校准，**禁止**整会话清零。

**验收**：
- 单元：mock 1 秒内到达 1 条真实消息 + 1 条群提示，unread 应为 1 而非 0。
- 集成：3 秒窗内 5 条真实消息 + 1 条群提示，unread 应为 5 而非 0。

**代码位置**：
- 改：`lib/src/services/group_conversation_unread_helper.dart`
- 改：`lib/src/services/notification_settings_service.dart`（所有调用 scheduleClearRepeatedly 的路径）

### 4.5 READ-P0-002 建 durable ReadReceiptOutbox（P0-Critical）

**现状**：消息已读回执在 SDK 调用前已标记 `needReadReceipt = false`，SDK 失败时永久丢失回执（v1.1 §10.1）。

**根因**：缺少持久化的回执待发表。

**整改**：

- 新增表 `read_receipt_outbox`：
  - 列：`owner_user_id, msg_id, group_id, conversation_id, state, attempt_count, next_retry_at, created_at, updated_at`
  - 索引：`(owner_user_id, state, next_retry_at)`
- 状态机：`PENDING → DISPATCHING → ACKED / RETRY (exponential backoff up to 10 attempts) → DEAD_LETTER`。
- 发送回执前先 `INSERT OR IGNORE`，SDK 成功才 `state = ACKED`。
- 跨重启恢复：扫描 `state IN (PENDING, DISPATCHING, RETRY)`，按 `next_retry_at` 顺序重试。
- 幂等：服务端按 `(owner, msg_id)` 去重，重复 ACK 不影响。

**验收**：
- 单元：mock SDK 失败，state 进入 RETRY；mock 成功，state = ACKED。
- 跨重启：进程杀死后重启，待发回执全部送达。
- 重复 ACK：服务端收到同 `(owner, msg_id)` 多次 ACK 不报错。

**代码位置**：
- 新增：`lib/src/services/im/read_receipt_outbox_store.dart`
- 改：`third_party/.../tui_chat_separate_view_model.dart:7616` 附近的 `_setMsgReadReceipt`

### 4.6 READ-P0-003 会话已读持久化恢复（P0-Critical）

**现状**：`lib/src/services/conversation_unread_clear_service.dart` 本地先清 + 内存重试，进程死亡后已读可能反弹。

**整改**：

- 新增表 `read_outbox`：
  - 列：`owner_user_id, conversation_id, last_read_msg_id, last_read_at_ms, state, attempt_count, next_retry_at`
  - 索引：`(owner_user_id, state, next_retry_at)`
- 进页/离页先 `state = PENDING`；SDK `markC2CMessageAsRead` / `markGroupMessageAsRead` 成功才 `state = ACKED`。
- 跨重启恢复：扫描 `state IN (PENDING, RETRY)`。
- 500 截断：拆分为 server cursor + 本地分页校准。

**验收**：
- 单元：SDK 失败 → state 进入 RETRY。
- 跨重启：进程杀死后重启，会话已读状态不反弹。
- 大会话：2,000 会话全量校准无丢。

**代码位置**：
- 新增：`lib/src/services/im/read_outbox_store.dart`
- 改：`lib/src/services/conversation_unread_clear_service.dart`

### 4.7 LIFE-P0-001 修 socket ready 判定（P0-Critical）

**现状**：`lib/src/services/im_connect_status_service.dart:234-247` `reconcileStaleConnectingAfterColdStart` 12 秒后强制 `_sdkSocketConnected = true`。

**根因**：把"登录态"误当作"长连接成功"。

**整改**：

- 删除 `instance._sdkSocketConnected = true` 强制赋值。
- 只允许 `messageService.addAdvancedMsgListener` 回调中的 `onConnectSuccess`（SDK 提供）进入 READY。
- 超时保持 `CONNECTING` / `DEGRADED` 状态，触发有界重登录（指数退避，上限 3 次）。
- 加 `socket_ready_decision_latency_ms` metric。

**验收**：
- 单元：mock `isImLoggedIn = true` 但无 onConnectSuccess，state 不进入 READY。
- 真机：拔网线 → 登录成功 → 12 秒后 UI 仍显示"连接中"，不显示"已连接"。

**代码位置**：
- 改：`lib/src/services/im_connect_status_service.dart:234-247`

### 4.8 LIFE-P0-002 / MSG-P0-002 listener 吞错兜底（P0-Critical）

**现状**：`lib/src/services/im/tencent_advanced_message_adapter.dart:105, 348` `catch (_) {}` 完全吞掉 listener 入库失败。

**根因**：listener 回调无法返回 Future；一次性事件（修改/撤回/回执）一旦 append 失败无恢复来源。

**整改**：

- 删除 `catch (_)` 静默吞错。
- 替换为：
  ```dart
  } catch (e, st) {
    _onIngestFailure(kind: kind, eventId: eventId, error: e, stack: st);
  }
  ```
- `_onIngestFailure`：
  - 计数告警（metric：`chat_ingest_failure_total{kind}`）
  - 有界内存 fallback（仅对可重放事件，保留最近 N 个）
  - 立即安排 overlap/cursor catch-up
  - 一次性事件（修改/撤回/回执）走独立恢复路径（不可依赖 SDK overlap）

**验收**：
- 单元：mock ingest 抛异常，触发 `_onIngestFailure`。
- chaos：故意坏事件注入 1 万条，Inbox 死信不卡队头。

**代码位置**：
- 改：`lib/src/services/im/tencent_advanced_message_adapter.dart:105, 348`

### 4.9 ACC-P0-001~004 AccountScopedRuntime（P0-Critical）

**现状**：
- `OutgoingMessageSendQueue._tailByConversation` 永久增长，无 clearSession（line 11-50）。
- `TUIChatGlobalModel.clearData()` 未完整清理（v1.1 §9.1）。
- `ChatDraftWriteQueue` 闭包执行时读 owner（v1.1 §9.1）。
- 多个静态 Store/Bus/Timer 各自 reset，无统一 teardown。

**整改**：

- 新增 `lib/src/services/im/account_scoped_runtime.dart`：
  ```dart
  class AccountScopedRuntime {
    final String ownerUserId;
    final int accountGeneration;
    final int domainGeneration;
    final int clearEpoch;
    final WriterLease lease;
    final ImMailboxRouter mailbox;
    final OutgoingSendCoordinator coordinator;
    // ...
    Future<void> close({required String reason});  // teardown barrier
  }
  ```
- 状态机：`CREATED → OPENING → ACTIVE → FREEZING → DRAINING → CLOSED`。
- 每个异步任务创建时捕获 `SessionIdentity`；提交前调用 `canCommit(identity)`。
- `FREEZING` 后拒绝新写，`DRAINING` 只允许旧任务完成持久化。
- logout 必须 `await runtime.close()` barrier 后才激活新账号。
- 所有全局 Map 的 key 必须包含 owner/epoch，或明确归属 runtime 并在 close 时销毁。

**清单**（必须纳入 runtime 管理的状态）：
- 消息提交 generation/token
- 窗口 missing newer/older 与边界
- 窗口 suppress/anchor
- 搜索跳转
- C2C 对方已读时间
- 文件位置/大小
- 取消媒体 ID
- 预加载缓存
- 历史位置
- typing/edit 定时器
- 动画集合
- 滚动/预览状态
- 本地发送序列
- OutgoingMessageSendQueue._tailByConversation
- ChatDraftWriteQueue
- PushMsgKeyDedup._seen
- ConversationPeerReadCoordinator Timer
- _c2cPeerReadTimestampMap
- TUIChatGlobalModel.clearData / TUIChatSeparateViewModel.clearData

**验收**：
- A 账号同时发 100 条消息、拉历史、发送回执、写草稿、下载媒体，立即切 B；释放所有 A 延迟回调，B 状态零污染。
- 账号来回切换 100 次，Timer/Map/stream subscription 数量回到基线。
- 相同 conversationID 在 A/B 同时存在时，草稿、未读、最后消息、下载进度和回执完全隔离。
- 登出时模拟 DB 慢写和 SDK send 慢返回，旧操作不得在新账号成功提示或上屏。

**代码位置**：
- 新增：`lib/src/services/im/account_scoped_runtime.dart`
- 改：`lib/src/services/auth_bootstrap_service.dart`
- 改：`third_party/.../tui_chat_global_model.dart:clearData()`
- 改：`third_party/.../tui_chat_separate_view_model.dart:clearData()`
- 改：`third_party/.../outgoing_message_send_queue.dart`
- 改：`lib/src/services/conversation_local/conversation_local_store.dart`（add clearSession）

### 4.10 SEND-P0-001/002 Outbox 真 payload + 跨故障域（P0-Critical）

**现状**：
- Outbox 主表 + recovery copy 在同一 SQLite 文件（`conversation_local_store.dart:185-186` + `im_ingress_store.dart:192-193`）。
- `im05_persistence.dart` 状态机完整但**真实 payload 不持久化**（只保存 `payloadDigest`）。

**整改**：

- Outbox 增加 `payload BLOB` 列（加密保存完整 `V2TimMessage` + media descriptor）。
- recovery copy **跨故障域**：第二个独立 SQLite 文件（`outbox_recovery.db`）。
- 状态机增加 `preparing → prepared → dispatchIntent → sending → outcomeUnknown → retryable → acknowledged → completed`。
- `OutcomeUnknown` 不得自动重发；恢复路径：
  - 历史认领 → 标记 `completed` 或 `reconciled`。
  - SDK 实时回执 → 标记 `acknowledged`。
  - 用户明确重发 → 进入 `retryable`。
- 主表与恢复副本状态冲突时（`mainMissing` / `mainNotPrepared` / `recoveryCopyMissing` / `identityConflict` / `recoveryConflict` / `recoveryLag`）**禁止**继续发送和 GC。

**验收**：
- 单元：mock SDK 超时，Outbox 进入 `OutcomeUnknown`，不自动重发。
- 真机强杀：发图片过程中强杀，重启后 Outbox 扫描恢复，未发送的卡片重发成功，已发送的不重发。
- DB 损坏：主表损坏，恢复副本完整，能继续发送并最终 reconcile。
- 多图：用户选择 5 张图，最终顺序与选择顺序一致。

**代码位置**：
- 改：`lib/src/services/im/im05_persistence.dart`
- 改：`lib/src/services/im/im05_contracts.dart`
- 改：`lib/src/services/conversation_local/conversation_local_store.dart:185-186`
- 新增：`lib/src/services/im/outbox_recovery_store.dart`

### 4.11 WALLET-P0-001/002 WalletPending owner + epoch（P0-Critical）

**现状**：`lib/src/pages/wallet/order/wallet_pending_recovery_service.dart:99-117` 不传 owner；`:141-147` 直接发无 owner 隔离。

**整改**：

- `WalletPendingStore` 加 `ownerUserId` 列；所有 put/load/remove 必须校验 owner。
- `WalletPendingRecoveryService.recover` 加 `required String ownerUserId` 参数。
- `resendRetryableImCards` 必须经过 4.1 改造后的 WalletCardOutbox。

**验收**：
- 双账号：A 发红包 → 强杀 → 切 B → 切回 A → 不应误发到 B；服务端账目正确。

**代码位置**：
- 改：`lib/src/pages/wallet/order/wallet_pending_store.dart`
- 改：`lib/src/pages/wallet/order/wallet_pending_recovery_service.dart`

### 4.12 HIST-P0-001 历史/搜索走统一 Coordinator（P0-Critical）

**现状**：3 处历史入口（`tui_chat_global_model.dart:4426, 5393` + `tui_search_view_model.dart:645,655,1638`）+ 4 处搜索路径，可直接 SDK 拉取并 setMessageList。

**整改**：

- 所有 `getHistoryMessageList*` 调用必须经过 `history_search_coordinator.dart`。
- 增加 generation 校验：Coordinator 拒绝旧 generation 的历史写入。
- 实时 + 历史并发时，已知 realtime pin 的消息必须在历史窗口保留。
- 上翻分页、搜索落点、回连重拉都走 Coordinator。

**验收**：
- 并发：实时消息到达 + 上翻分页同时进行，无消息丢失或重复。
- 搜索：搜索结果落点走 Coordinator，窗口不被替换。

**代码位置**：
- 改：`third_party/.../tui_chat_global_model.dart:4426, 5393`
- 改：`third_party/.../tui_search_view_model.dart:645, 655, 1638`
- 改：`lib/src/services/im/history_search_coordinator.dart`

### 4.13 CONV-P0-001 MessageOrderComparator（P0-Critical）

**现状**：`tui_chat_global_model.dart:10280-10345` `compareMessagesChronological` 6 段规则，同秒+同发送方+同 seq 仍只能靠 msgID 字典序。

**整改**：

- 新增 `lib/src/services/im/message_order_comparator.dart`，单文件单点：
  ```dart
  class MessageOrderComparator {
    int compare(V2TimMessage a, V2TimMessage b);
  }
  ```
- 比较维度（按优先级）：
  1. group seq（仅群消息，单聊禁用）
  2. provider sequence
  3. monotonic local seq（Outbox 自增）
  4. timestamp（毫秒）
  5. msgID（仅作稳定 tie-breaker）
- 所有排序调用（`getMessageList` / `setMessageList` / 会话预览）必须使用此 Comparator。
- 删除 `compareMessagesChronological` 中的多套私有逻辑。

**验收**：
- property test：随机生成 1 万对消息，comparator 满足 strict weak ordering。
- 集成：同秒+同发送方+同 seq 两条消息，顺序稳定。

**代码位置**：
- 新增：`lib/src/services/im/message_order_comparator.dart`
- 改：`third_party/.../tui_chat_global_model.dart:10280-10345`
- 改：`lib/src/services/conversation_local/conversation_local_store.dart:1396-1401`

### 4.14 MEMBER-P0-001~003 snapshot + cursor 同事务（P0-Critical）

**现状**：
- `group_member_local_store.dart` 有 `replaceSnapshot` 原子事务，但 cursor 在 `group_member_incremental_sync_service.dart:73-80` 用 SharedPreferences 异步，**未与 snapshot 同事务**。
- 首页完整性未显式标记。

**整改**：

- 新增 `snapshot_meta` 表：
  - 列：`owner_user_id, group_id, snapshot_version, snapshot_at_ms, cursor_seq, member_count, complete INTEGER, updated_at_ms`
  - PRIMARY KEY：`(owner_user_id, group_id)`
- snapshot 写入 + cursor 写入 + member_count 同事务。
- `complete` 字段标记首页是否完整。
- UI 订阅 `snapshot_meta`，首页未完整时显示骨架，不显示"空列表"。
- 群成员增量 cursor 改用 `group_member_local_v1.db` 同 DB。

**验收**：
- 中途失败：写入 snapshot + cursor 同一事务原子提交；中途失败可重试。
- cursor crash：cursor 写入成功但成员写入失败 → 回滚 cursor，下次重试。
- 完整快照：10,000 人群一次性快照 + cursor，UI 显示完整。

**代码位置**：
- 改：`lib/src/services/group_local/group_member_local_store.dart`
- 改：`lib/src/services/group_local/group_member_incremental_sync_service.dart`

### 4.15 PUSH-P1-001~004 通知 dedup + 稳定 ID（P0-High）

**现状**：
- `push_msgkey_dedup.dart:13-14` TTL 30 分钟、最多 200 条。
- `im_chat_notification_registry.dart:11` `msgKey.hashCode & 0x7fffffff` 31 位碰撞。
- `im_chat_notification_clear_service.dart:25-38` 进入前台清全部 im_chat。
- registry 仅内存，进程重启依赖平台扫描。

**整改**：

- dedup key 升级：`owner + provider + msgKey` 复合 key。
- 容量按峰值速率设计（≥ 1 万条）；持久化有界环（IndexedDB/SQLite）。
- notificationId 由稳定 ID 表分配（自增 + 碰撞检查），不用 hashCode。
- 前台进入只清"已进入且已读"的会话通知；开关可配置。
- registry 持久化 + 重启 reconcile。

**验收**：
- 高消息量：1 万条/分钟去重不漏。
- 跨账号：A/B 切换后通知不互相抑制。
- 碰撞：msgKey 碰撞率 < 1/10^9。

**代码位置**：
- 改：`lib/src/services/push_msgkey_dedup.dart`
- 改：`lib/src/services/im_chat_notification_registry.dart`
- 改：`lib/src/services/im_chat_notification_clear_service.dart`
- 改：`lib/src/services/notification_settings_service.dart`

### 4.16 B2 静态门禁扫 third_party（P0-High）

**现状**：`tool/im10_migration_scan.ps1` 只扫 `lib/src/**`，漏 `third_party/`。

**整改**（见 3.3）。

---

## 5. 阶段 2：发送可靠性（IM-08 收尾）

> 退出条件：文本/图片/视频/文件/语音/卡片在每个状态点强杀后最终恰好一次。

### 5.1 B1 全部消息类型走 Coordinator

- 所有 12 处绕过路径（v1.1 审计报告 B1）改为 `ImOutgoingSendCoordinator.instance.send(...)`。
- 包括：钱包金融卡片、红包通知、语音、群提示、应用分享、加好友、联系人名片、聊天自定义消息、群创建消息、用户资料消息、朋友圈图片、QR 码。

### 5.2 多图/多语音最终顺序

- Coordinator 串行队列（基于 `operationId` 严格顺序），不得按压缩或上传完成顺序重排。
- 用户选择顺序由 UI 锁定为 `clientCorrelationId` 序列。

### 5.3 OutcomeUnknown adoption

- 冷启动恢复：扫描 `state IN (PENDING, DISPATCHING, OUTCOME_UNKNOWN)`。
- 历史认领 → `completed`。
- SDK 实时回执 → `acknowledged`。
- 用户明确重发 → `retryable`。

### 5.4 MediaSendCoordinator

- 媒体描述符独立存储（managed staging directory），引用计数 + quota。
- 发送中禁止清理。

### 5.5 失败重试

- 指数退避（1s, 2s, 4s, 8s, ... ），上限 5 次。
- 死信隔离（`DEAD_LETTER` 有上限、较长保留、可导出/重放）。

### 5.6 主表与恢复副本状态冲突

- 6 种 conflict（`mainMissing` / `mainNotPrepared` / `recoveryCopyMissing` / `identityConflict` / `recoveryConflict` / `recoveryLag`）必须显式检测。
- 冲突时禁止继续发送和 GC；走人工认领或重置。

**验收**：每条都跑真机强杀矩阵。

---

## 6. 阶段 3：Message Core 单写者（IM-10 收尾）

> 退出条件：CI 中旧写入口为 0；UI 只订阅 snapshot/delta。

### 6.1 MessageRow / WindowSnapshot / RowDelta / ViewportAnchor

- 新增 sealed `MessageRow` 数据结构（独立于 SDK message 类型）。
- 时间行、未读舌头、加载行、撤回占位均为 `MessageRow` 子类。
- `WindowSnapshot`：不可变列表 + revision。
- `RowDelta`：`{messageKey, fields[]}` 增量更新。
- `ViewportAnchor`：滚动位置快照。

### 6.2 UI 壳订阅 snapshot + delta

- `tim_uikit_chat_history_message_list.dart` 不再直接读 `_messageListMap`；订阅 WindowSnapshot + RowDelta。
- 回执、下载进度、发送状态用 RowDelta，不重建整行。

### 6.3 清理 production setMessageList 直写

- 删除 18 处 `setMessageList` 直写（保留 IM-04 已修的 Writer 后兼容投影）。
- 删除 `commitMessageDelta` 外的所有 `_messageListMap[storageKey] = sorted` 直写。

### 6.4 B3 巨型文件拆分（先 characterization 再搬）

- 拆分前先写 characterization tests 锁定现有 UI 行为。
- 按职责拆：
  - `MessageIngressCoordinator`
  - `MessageCommitWriter`
  - `MessageWindowController`
  - `HistoryPaginationController`
  - `ScrollAnchorController`
  - `UnreadReadController`
  - `OutgoingMessageController`
  - `MediaLifecycleController`
  - `MessageRowPresenter`
  - `ConversationProjectionStore`
- 每次只搬一个模块，跑测试 + 视觉回归。

**验收**：CI 旧写入口为 0；UI 视觉回归通过。

---

## 7. 阶段 4：会话单写者与最后消息

> 退出条件：5,000 会话压力下无丢行、排序抖动和未读分叉。

### 7.1 Conversation Writer

- `ConversationCore` 管理 `lastMessage` / `unread` / `draft` / `pin` / `mute` / `delete tombstone`。
- 全部走 Writer，删除 legacy mirror 写入口。

### 7.2 MessageOrderComparator 统一

- 4.13 已实施，此处确保所有会话预览/列表都用此 Comparator。

### 7.3 DB keyset list

- 会话列表用 DB keyset 翻页，避免 offset 深翻页。
- 稳定排序组合索引含 canonical ID tie-breaker。

### 7.4 删除 legacy mirror

- 灰度期间自动比较新旧 projection，但只展示新结果。
- 关闭旧链路前保留可回滚版本。

### 7.5 索引与事务

- 5,000 会话压力下：插入/更新 P99 < 50ms。
- 已读批量：拆 server cursor + 本地分页。

**验收**：5,000 会话 + 2,000 未读并发；同秒乱序 + 删除失败预览回滚完整。

---

## 8. 阶段 5：历史/搜索/恢复收口

> 退出条件：100 万消息单会话仍内存有界，所有并发场景锚点稳定。

### 8.1 HistoryQuery/Coverage 统一

- 所有 history/search/reconnect 走 `history_search_coordinator.dart`。
- coverage interval 和账号 cursor 强校验。

### 8.2 DB 全量有洞扫描

- `im_recovery_worker.dart` 改为公平调度（不只扫前 20 个会话）。
- DB keyset 扫描所有有洞会话。

### 8.3 阅读历史有限双向滑窗

- 历史/搜索使用有限双向滑窗，不常驻全量列表。

### 8.4 索引优化

- `(owner, status, next_retry_at, account_ingress_sequence)` 等 v1.1 §20.3 要求的关键索引补齐。

**验收**：100 万消息单会话内存有界；1 万 Inbox 恢复 + 100 坏事件注入不死队头。

---

## 9. 阶段 6：GroupMemberCore + 钱包

> 退出条件：10,000 人群首屏不拉全量，所有选择器同 revision、无假空列表。

### 9.1 GroupMemberCore

- snapshot meta + cursor + 成员列表同 DB 同事务（4.14 已实施）。
- 所有成员页、@、邀请、通话和钱包选择器切统一 API。
- `tui_group_profile_model.dart:170` `_drainRemainingGroupMemberPages` while loop 改为按需懒加载 + 分页触发。

### 9.2 服务端成员搜索/eligibility

- 群转账接收人服务端校验仍在群内并具备资格。
- 钱包群转账走 GroupMemberCore 派生视图，**不**单独循环 SDK。

### 9.3 WalletPending owner 化（4.11 已实施）

- 服务端 `wallet_chat_outbox` 与业务订单同事务。
- 服务端幂等证据（双账号恢复不双发）。

**验收**：10,000 人群首屏不拉全量；服务端转账合法校验通过。

---

## 10. 阶段 7：删除兼容层与容量验收

> 退出条件：soak/chaos/跨端/真机矩阵通过；灰度完成；旧链路可回滚关闭。

### 10.1 删除旧 listener/no-op、legacy notifier、shadow 写分支

- 删除 `tencent_advanced_message_adapter.dart` 中所有 `catch (_)` 静默吞错。
- 删除 GlobalModel 中所有绕过 Writer 的直写。
- 删除 OutgoingMessageSendQueue 旧路径。

### 10.2 上线 GC、quota、DB migration

- Inbox COMPLETED 分批删除。
- DEAD_LETTER 有上限、较长保留、可导出/重放。
- 启动不做大规模 VACUUM；维护任务有 I/O budget + 前台暂停 + 电量/网络策略。

### 10.3 Soak / Chaos / 跨端 / 真机矩阵

详见 §12。

---

## 11. 验收矩阵

### 11.1 基础门禁（每个 PR）

```bash
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test
tool/im10_migration_scan.ps1   # 必须绿（含 third_party 扫描）
tool/im_gate.ps1               # IM-11 入口
```

同时运行：
- schema migration
- 日志敏感字段扫描
- 依赖漏洞与许可证检查

### 11.2 测试分层

| 层级 | 必测内容 |
|---|---|
| Unit/property | 排序、去重、alias、未读水位、cursor、幂等状态机、金额/成员资格 |
| Store | transaction、migration、索引、GC、磁盘满、库锁、损坏恢复 |
| Fake SDK integration | 重复/乱序/漏回调、错误码、慢回调、同秒消息、分页 cursor 不前进 |
| Widget | 首屏、空态、滚动锚点、键盘、搜索跳转、未读舌头、媒体返回 |
| Multi-device | 两端收发/读、撤回、清历史、离线上线、Push/在线去重 |
| Real SDK | Android/iOS/Web/Desktop 测试账号和真实腾讯云群 |
| Chaos | 每个状态点 kill、断网、切号、低磁盘、时间跳变、后台限制 |
| Soak | 24–72 小时持续收发、重连、媒体、成员变化，观察内存/DB/任务积压 |

### 11.3 负载矩阵

- 5,000 个会话，2,000 个同时未读。
- 单会话 100 万条历史，内存窗口不超过策略上限附近。
- 50 个活跃会话并发突发，至少连续接收 10,000 条。
- 10,000 人群成员、服务端搜索、频繁进退群。
- 10,000 条 Inbox 恢复，其中前 100 条永久坏。
- 10,000 条 Outbox/ReadOutbox 恢复与重复回调。
- 1,000 条回执批次和大量媒体进度事件。
- 账号切换 100 次并释放旧任务。
- Android 后台限制、网络限速、电量低、磁盘满。
- Web 离线 / 弱网 / 跨标签页。
- iOS 后台杀进程和通知合并。

### 11.4 故障矩阵

- 进程强杀：发文本 / 发图片 / 发语音 / 发卡片 / 发红包 / 发名片 / 群提示 / 多图选 5 张。
- 网络断开：发文本 / 发图片 / 发红包 / 撤回 / 已读回执 / 历史拉取。
- 网络超时：发图片 / 拉历史 / 接收消息 / 群成员刷新。
- 切账号：A 发消息中 → 切 B → 切回 A。
- 多设备：A 在线 → B 在线 → A 离线 → A 在线。
- 群成员中途变化：踢人 / 退群 / 转让群主 / 解散群。
- 红包状态：未领 / 已领 / 过期 / 退款。
- 转账状态：未接收 / 已接收 / 过期 / 退款。

---

## 12. 自动化指标（必须接埋点）

### 12.1 计数器

- `chat_writer_commit_total{kind}`
- `chat_outbox_state_transition_total{from, to}`
- `chat_outcome_unknown_total{card_type}`
- `chat_inbox_dead_letter_total`
- `chat_recovery_run_total{result}`
- `chat_ingest_failure_total{kind}`
- `chat_push_notification_total{dedup_hit}`
- `chat_account_scope_close_total{reason}`

### 12.2 直方图

- `chat_writer_commit_ms`
- `chat_outbox_prepared_to_sending_ms`
- `chat_inbox_append_ms`
- `chat_history_pagination_ms`
- `chat_member_snapshot_age_ms`
- `chat_socket_ready_decision_latency_ms`
- `chat_push_decision_ms`

### 12.3 Gauge

- `chat_outbox_pending_count`
- `chat_inbox_dead_letter_count`
- `chat_conversation_unread_recompute_inflight`
- `chat_account_runtime_active_count`

### 12.4 业务级异常事件

- `unread_local_provider_mismatch`
- `conversation_last_message_mismatch`
- `conversation_missing_recreated`
- `history_gap_count`
- `coverage_partial_age`
- `search_jump_fail`
- `member_snapshot_age/coverage/cursor_lag/search_false_empty`
- `wallet_card_pending_age/duplicate_prevented`

### 12.5 告警阈值

- 任一 Inbox dead letter
- oldest pending 超过阈值
- OutcomeUnknown 金融卡片/发送意图超过阈值
- 未读或最后消息连续多次校准不一致
- 同一账号同一会话出现两个 Writer fencing token
- GroupMember cursor 不前进但 hasMore
- SQLite 接近容量/完整性失败
- 切号后检测到旧 epoch commit

### 12.6 隐私

- 日志和埋点只记录 hash/token，不记录聊天正文、文件路径、精确经纬度、支付密码、完整 userID/groupID/msgID。
- 诊断导出需用户授权、加密、有期限，并过滤钱包敏感字段。

---

## 13. 完成定义（Definition of Done）

只有同时满足以下条件，才能把本次重构标记为完成：

1. 所有普通消息事件经过一个 durable ingress 和一个 Message Writer。
2. 事件 inventory 100% 有 APPLY/IGNORE/DEAD_LETTER 策略。
3. 生产 `setMessageList` 和直接绕过 Coordinator 的历史/发送入口清零（CI 门禁绿）。
4. Message/Conversation/GroupMember/Wallet 状态全部 owner + epoch 隔离。
5. Outbox、ReadOutbox、ReadReceiptOutbox、成员 cursor、钱包卡片都通过强杀恢复。
6. 未读、已读、最后消息、会话存在性在跨端/重连后可证明收敛。
7. 历史和搜索不会替换/丢失实时窗口，滚动锚点稳定。
8. 群成员、@、群管理、通话选人、群转账使用同一 GroupMemberCore。
9. 10,000 人群不在首开拉全量，搜索不会假空。
10. 钱包服务端提供交易幂等和聊天卡片 Outbox 证据。
11. P0/P1 清零，SLO、负载、Chaos、真机与 24–72 小时 soak 全部通过。
12. 删除 legacy mirror/kill-switch 依赖前保留可回滚版本和数据迁移方案。
13. UI 截图和交互回归证明视觉壳未被无意改变。

---

## 14. 风险与回滚

### 14.1 阶段回滚开关

每个阶段保留 kill-switch：

- 阶段 0：可关闭新静态门禁（仅记录，不阻断）。
- 阶段 1：可保留旧链路并行（双轨）。
- 阶段 3：可保留 legacy mirror（只读兼容 facade）。
- 阶段 4：可保留旧会话本地库（只读镜像）。
- 阶段 5：可保留历史多入口（仅记录）。
- 阶段 6：可保留旧群成员 SDK 拉取（仅记录）。
- 阶段 7：必须删，但保留数据迁移方案。

### 14.2 数据迁移

- 每个阶段的 Outbox/ReadOutbox/ReadReceiptOutbox schema 变更必须向后兼容。
- 升级前后做 integrity check。
- 大批量写每批 50–200，可取消/让出。

### 14.3 灰度策略

- 新链路灰度 5% → 25% → 50% → 100%。
- 灰度期间自动比较新旧 projection，但只展示新结果。
- 任一指标超阈值立即回滚到上一灰度比例。

---

## 15. 责任分工

按数据域分工，避免两人同时改巨型文件。

### 15.1 开发者 A：消息可靠性与持久化内核

负责：
- AccountScopedRuntime、Inbox/Journal/Effect/Lease
- Outbox、ReadOutbox、ReadReceiptOutbox、WalletCardOutbox
- 消息事件 inventory、append failure、恢复/死信/GC
- HistoryQuery/Coverage、MessageOrderComparator
- DB schema/migration/fault tests
- Message Core metrics

主要目录：`lib/src/services/im/`、消息持久化模块；对 GlobalModel/SeparateViewModel 只提交薄 adapter PR。

### 15.2 开发者 B：Projection、UI 接线、会话、成员与钱包

负责：
- MessageRow、WindowSnapshot、RowDelta、Scroll Anchor
- Conversation Writer/TabStore 性能和 legacy mirror 删除
- GroupMemberCore、各成员/选人 UI 迁移
- WalletStore/WalletPending owner 化与接收人视图
- Widget/滚动/大群/通知体验测试

### 15.3 共享边界

- 第一批 PR 只增加 `contracts/`：AccountScope、MessageCommand、HistoryPage、RowDelta、GroupMemberSnapshot；两人共同 review。
- `tui_chat_global_model.dart`、`tui_chat_separate_view_model.dart`、`chat.dart`、`conversation.dart` 设为共享高冲突文件，每次只允许一个在途 PR 修改。
- A 提供 Store/Writer fake；B 不直接访问 SQLite/SDK。
- B 提供 projection consumer tests；A 不改 UI 视觉和交互。
- 每个阶段合并前跑同一故障矩阵和 source-contract CI。

---

## 16. 文档与代码索引

### 16.1 关键文件

```
lib/src/services/im/
  account_scoped_runtime.dart                ← 阶段 1 4.9
  durable_ingress_gateway.dart               ← Inbox 写入
  im_recovery_worker.dart                    ← 恢复 worker
  im_mailbox.dart                            ← 串行路由
  writer_lease.dart                          ← Writer Lease
  im05_persistence.dart                      ← Outbox + Journal + Checkpoint
  im05_contracts.dart                        ← 状态机契约
  tencent_advanced_message_adapter.dart      ← LIFE-P0-002 吞错点 line 105, 348
  outgoing_send_coordinator.dart             ← 唯一发送入口
  tencent_message_adapter.dart               ← SDK 适配层
  history_search_coordinator.dart            ← IM06 历史搜索
  im_ingress_store.dart                      ← SQLite 适配 line 165-193
  message_order_comparator.dart              ← 阶段 1 4.13
  read_outbox_store.dart                     ← 阶段 1 4.6
  read_receipt_outbox_store.dart             ← 阶段 1 4.5
  outbox_recovery_store.dart                 ← 阶段 1 4.10
lib/src/services/
  conversation_unread_clear_service.dart     ← READ-P0-003
  group_conversation_unread_helper.dart      ← READ-P0-001 line 92-109
  im_connect_status_service.dart             ← LIFE-P0-001 line 234-247
  tencent_voice_to_text_service.dart         ← B1 绕过 line 124
  chat_external_message_sender.dart
  chat_failed_message_retry_service.dart
  push_msgkey_dedup.dart                     ← PUSH-P1-001
  notification_settings_service.dart
  im_chat_notification_registry.dart         ← PUSH-P1-002 line 11
  im_chat_notification_clear_service.dart    ← PUSH-P1-003 line 25-38
  group_local/group_member_local_store.dart
  group_local/group_member_incremental_sync_service.dart
  group_local/group_membership_sync_service.dart
  group_local/group_tip_custom_sender.dart    ← B1 群提示 line 123
  conversation_local/conversation_local_store.dart
  conversation_local/conversation_sync_service.dart
  conversation_local/conversation_tab_store.dart
  conversation_local/conversation_list_notifier.dart
  red_packet_claim_notice_sender.dart        ← B1 红包 line 79
  share_app_service.dart                     ← B1 分享 line 78
lib/src/pages/wallet/order/
  wallet_card_im_sender.dart                 ← B1 钱包金融卡片 line 94
  wallet_card_send_service.dart
  wallet_pending_store.dart                  ← WALLET-P0-001
  wallet_pending_recovery_service.dart       ← WALLET-P0-002
  wallet_card_outbox_store.dart              ← 阶段 1 4.1 新增
lib/utils/custom_message/
  friend_became_friends_message.dart         ← B1 加好友 line 114
  contact_card_message.dart                  ← B1 名片 line 414
lib/src/{chat.dart,create_group.dart,user_profile.dart,qr_code_page.dart}  ← B1
lib/src/pages/moments/moments_image_preview.dart ← B1 朋友圈 line 120
third_party/tencent_cloud_chat_uikit/lib/
  business_logic/view_models/
    tui_chat_global_model.dart               ← 巨型 12,980 行
    tui_chat_separate_view_model.dart        ← 8,538 行
    message_reconciliation_writer.dart
  business_logic/separate_models/
    tui_group_profile_model.dart             ← P0-08 10000 人 line 154, 170
    tui_search_view_model.dart               ← HIST 3 入口 + 搜索 4 路径
  data_services/message/
    outgoing_message_send_queue.dart         ← ACC-P0-001 无 clearSession
    message_service_implement.dart
tool/
  im10_migration_scan.ps1                    ← B2 需扩展扫 third_party
  im_gate.ps1                                ← IM-11 入口
```

### 16.2 不可破坏的不变量（再次列出）

- `tui_chat_global_model.dart` 中 `resolvedStableIdentity` 修复（line 2427）。
- 历史/实时/发送/撤回/删除经过同一个 `MessageReconciliationWriter`。
- 所有长异步链必须携带 `ownerUserId + accountGeneration + domainGeneration + clearEpoch + fencingToken`。
- 单聊不得使用群 Seq 推理连续性，群消息以服务端 Seq 为第一依据。
- `OutcomeUnknown` 禁自动重发。
- Push 只负责唤醒，正式消息必须来自 SDK/历史 Writer。
- A 账号晚到事件不得污染 B 账号。
- 历史消息必须可持续加载，不能因实时或发送中消息被覆盖。
- 关注消息不丢失、不卡顿、不重复、不异常发热。

---

## 17. 版本与维护

### 17.1 版本历史

| 版本 | 日期 | 变更 |
|---|---|---|
| v1.0 | 2026-08-30 | 初版：基于 v1.1 静态审计 + 补充发现的整改方案 |

### 17.2 维护规则

- 任何 P0/P1 修复必须更新本文对应阶段。
- 任何新引入的写入路径必须更新 §3.1 / §3.2 inventory。
- 任何阶段退出条件未达，禁止进入下一阶段。
- 任何条目标记"完成"时，必须附：代码提交 + 自动化结果 + 真机矩阵 + 故障注入结果 + 指标截图，**不能**仅以"页面能跑通"作为证据。
