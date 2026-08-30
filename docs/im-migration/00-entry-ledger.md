# IM-00 入口账本

状态：`BASELINE_CAPTURED`（2026-08-29）

这份账本是腾讯 IM 消息领域重构的第一份入口清单。它登记的是当前代码事实，不代表这些入口已经符合最终架构。`formal` 表示当前代码可能直接改变正式消息/会话投影；`read` 表示只读或诊断；`compatibility` 表示迁移期间暂时保留，但必须最终归入 Adapter 或 Writer 白名单。

## 账号和会话边界

| 入口 | 当前职责 | 账号/会话边界 | 当前判断 | 目标替代 |
| --- | --- | --- | --- | --- |
| `lib/src/services/session_identity.dart:SessionIdentityService` | 登录账号与 generation | 账号级 | `formal-boundary` | 由 `AccountScopedConversationKey` 和事件 Envelope 复用，不删除 |
| `lib/src/utils/message_conversation_id.dart:MessageConversationId` | C2C/群会话解析和类型校验 | 会话级 | `formal-normalizer` | 由统一 scope Adapter 调用，禁止页面另造解析 |
| `lib/src/services/conversation_local/conversation_sync_service.dart` | SDK Listener、历史、会话写入、兼容补偿 | 当前账号 + 会话 | `formal-multiplexed` | `TencentMessageAdapter -> EventEnvelope -> Mailbox -> Writer` |
| `lib/src/services/conversation_local/conversation_local_store.dart` | 会话持久化、未读/摘要/元数据 | owner + conversation key | `formal-store` | `ConversationProjector` 单一写入者 |

## 消息和 SDK 入口

| 文件 | 符号/区域 | 入口类型 | 当前写入对象或副作用 | 账号/代数风险 | 迁移结论 |
| --- | --- | --- | --- | --- | --- |
| `third_party/tencent_cloud_chat_uikit/lib/data_services/message/message_service_implement.dart` | `messageListMap` | formal/compatibility | SDK Service 内存历史缓存 | 没有统一领域 Envelope | 迁入 History Adapter；旧缓存不得成为第二 Writer |
| 同上 | `getHistoryMessageListV2`、`getHistoryMessageList`、`getHistoryMessageListWithComplete` | formal input | SDK 本地/云端历史返回 | LOCAL/CLOUD 和 Web 实际来源需证明 | 只允许 Adapter 调用并生成 `HistoryProof` |
| 同上 | `addAdvancedMsgListener`、`removeAdvancedMsgListener` | formal input | SDK 消息 Listener | 重复注册和账号切换风险 | 普通聊天唯一 Listener；通话信令独立 namespace |
| 同上 | `sendMessage` | formal effect | 腾讯发送 Future、`onSyncMsgID` | Future 超时可能重复发送 | 由 Outbox/Message Adapter 统一发起，禁止页面直调 |
| `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart` | `_messageListMap`、`setMessageList` | formal writer | TUIKit 正式消息列表 | 历史、实时、页面均可进入 | 过渡期仅作 Writer 兼容发布器，最终单一 Writer |
| 同上 | `bindOutgoingSyncMsgId` | formal mutation | 临时消息到正式 `msgID` 绑定 | 可能绕过 operation/correlation | 改成 Envelope 事件，由 Writer 接管 |
| 同上 | `sendMessage(onSyncMsgID: ...)` | adapter bridge | SDK `onSyncMsgID` 回调转交给 Adapter | 旧调用方未传回调时仍保留兼容绑定 | Adapter 传回调时不再直接改 TUIKit 列表 |
| `lib/src/chat.dart` | `messageListMap` 读取、`setMessageList` 写入、历史加载方法 | formal/compatibility | 聊天页消息窗口 | view generation 与领域 generation 混用风险 | 页面改为命令/只读 Snapshot |
| `lib/src/conversation.dart` | 会话页消息/历史相关调用 | read/compatibility | 会话预览与加载 | 页面旁路历史和摘要写入 | 改为 Conversation/History Coordinator |
| `lib/src/services/chat_external_message_sender.dart` | `sendCreatedMessage` | formal effect | 外部入口发送并补会话摘要 | 页面外发送缺少统一 Outbox 身份 | 接入统一 `OutgoingIdentityContract` |
| `lib/src/services/chat_failed_message_retry_service.dart` | 失败消息重试 | formal effect | SDK 重发/状态 | 未确认发送不能自动补发 | 迁入 Outbox，`OutcomeUnknown` 禁止自动重发 |
| `lib/src/services/archive_im_local_persist_service.dart` | 历史导入/本地清理/SDK 历史 | compatibility | 本地归档与 SDK 消息 | 归档假消息可能混入正式列表 | 归档作为独立来源，经 Writer 和 Barrier |

## Listener 命名空间

| 文件 | namespace | 是否普通聊天消息事实 | 迁移要求 |
| --- | --- | --- | --- |
| `lib/src/services/conversation_local/conversation_sync_service.dart` | `chat`（目标） | 是 | 只保留一个普通聊天 SDK Listener，统一进入 Mailbox |
| `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart` | `chat`（当前 TUIKit 入口） | 是 | 迁移期列入兼容白名单，不能和 App Listener 双写正式状态 |
| `lib/src/services/livekit_call_signaling.dart` | `call-signaling` | 否 | 保留独立 Listener、去重和状态机；不能进入普通 Message Writer |

## 当前扫描对象和可重复命令

```powershell
pwsh -File tool/im_migration_scan.ps1
pwsh -File tool/im_migration_scan.ps1 -OutputJson docs/im-migration/00-entry-ledger.generated.json
```

脚本逐行登记 `messageListMap`、`setMessageList`、历史 API、Advanced Listener 和 `sendMessage`。它输出脱敏相对路径、行号、类别和当前分类，不输出正文、UserSig、令牌或媒体路径。`-EnforceAdapterBoundary` 在 IM-02 之后启用；在当前阶段启用会按设计发现旧入口，不能把这种失败误判成代码回归。

`00-entry-ledger.generated.json` 是可重新生成的机器账本，不手工编辑；提交前应检查其中没有凭据或业务正文。Markdown 表格保留关键责任归属，JSON 覆盖扫描到的逐行入口。

## IM-00 迁移判定

1. `SessionIdentityService` 和 `MessageConversationId` 是可复用边界，不另建第二份账号或会话规范化。
2. `conversation_sync_service.dart` 当前职责过宽，不能直接升级为最终 Writer；它必须拆成 Adapter、Ingress、Coordinator 和 Projector。
3. `TUIChatGlobalModel.setMessageList` 当前仍是正式消息状态出口；本阶段不删除，后续必须改成唯一 Writer 的兼容发布器。
4. `livekit_call_signaling.dart` 的高级消息监听是通话专用事实源，迁移时只做 namespace 隔离，不做普通聊天合并。
5. 所有 `unawaited` 不自动视为消息事实：下一阶段按事件来源、账号代数、scope、是否修改正式 Store 逐条归类。

## IM-02 第一批交付

- `lib/src/services/im/tencent_message_adapter.dart` 提供窄 SDK Port、发送和历史 Adapter。
- 发送前由 Adapter 唯一注入 `99chat.outgoing.v1`；已有业务 `cloudCustomData` 置于 `business`，不覆盖。
- SDK `onSyncMsgID` 在传入 Adapter 回调时转换为 `chat` namespace 的 `EventEnvelope<OutgoingIdentityContract>`；事件携带账号/领域代数、scope、operationId 和入口序号。
- Web 的 LOCAL 请求在 Adapter 中映射为 CLOUD；`HistoryProof` 记录请求来源与实际来源，`isFinished` 只关闭当前方向窗口。
- 现有 `MessageServiceImpl` 的旧绑定仅在未提供 Adapter 回调的兼容调用中保留，不能作为新链路完成标志。

## IM-03 当前交付（部分完成）

- `ConversationLocalImIngressStore` 已复用现有 `ConversationLocalStore` 的 SQLite 事务；Web 通过 IndexedDB 实现同一 `ImIngressStore` 契约。
- `message_event_inbox`、`message_writer_lease`、`message_ingress_counter` 已在数据库 v15 创建，并具备主键、账号/会话入口序号唯一约束和租约记录。
- `DurableIngressGateway.append` 在一个持久化事务内完成 Inbox 幂等检查、账号序号、scope 序号和 Inbox 插入；Inbox 只保存 metadata/hash/recoveryRef，不保存 SDK 消息正文。
- `ImWriterLeaseService` 使用条件替换、单调 fencing token 和心跳续租；`ConversationSyncService` 的 MessageCore 在实时会话激活时竞争 Lease，失租/切账号会停止 Listener 和新领域提交。
- `TencentAdvancedMessageAdapter` 是普通聊天唯一 SDK Advanced Listener 接入点；消息回调按 `SDK broker -> Adapter -> Durable Inbox -> Mailbox -> 兼容会话投影` 处理，`call-signaling` 保持独立。
- Inbox 状态推进已接入当前实时兼容投影：`PREPARED`（durable Inbox 行）→ `PROCESSING` → `METADATA_COMMITTED` → `PROJECTION_PUBLISHED` → `COMPLETED`，每次推进均携带当前 Lease owner/fencing token 条件。
- 定向验证为 `24 tests PASS`；覆盖生产 SQLite 重开幂等、Adapter 注册一次/注销、旧 fencing token 拒绝、Web IndexedDB 文件静态分析和 Recovery Worker 的正式消息恢复边界。

本阶段仍未完成：

1. 旧 TUIKit `messageListMap` / `setMessageList` 仍是兼容发布和部分正式写入口，唯一 Message Writer 尚未接管全部历史/实时/页面路径。
2. `PROCESSING` 失败后的 durable Recovery Worker 已接入，但 Commit Journal、Projection Checkpoint、effect ledger 和崩溃阶段恢复尚未实现。
3. 所有会话/消息正式事务尚未统一在运行时校验同一 fencing token；当前接入重点是普通实时 Listener 和其兼容会话投影。
4. Outbox、加密恢复副本、历史 Coverage/搜索 Coordinator、已读/草稿/置顶/免打扰 Coordinator 尚未完成，不能把 IM-03 误报成整体重构完成。
