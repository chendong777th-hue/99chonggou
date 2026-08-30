# IM-09 草稿/置顶/免打扰/已读 ADR 边界

更新时间：2026-08-30
工作包：IM-09（基于 `docs/腾讯IM模式一_专用消息服务架构设计_重梳版.md` 第 29 节 ADR-005/006/007）
状态：`Proposed` → 待产品/技术共同结论后转 `Adopted`

本文聚焦 IM-04/07/08 已落地的"消息事实流"之外的**会话级偏好字段**：
每个字段必须确定唯一权威（Tencent / 自建 / DeviceSync）、冲突规则、失败回滚、
删除/退出/重新登录/离线恢复语义，以及"每个字段只有一个正式写入者"硬约束。
本文不做实现、不改写代码，只登记 ADR。

---

## 0. 共享硬约束（来自设计文档第 3.4 / 29 节）

1. **单写入者**：每个字段只有一条正式写入路径，其它入口只能提交事件或读取快照。
2. **跨账号 fence**：所有会话级字段读写都必须带 `SessionIdentity(owner, generation)`，晚到回执必须被拒绝。
3. **本地优先 ≠ 本地权威**：DeviceSync 缓存是渲染快照，不是事实源。任何"本地先显示"的字段都必须经显式 sync 回调覆盖。
4. **失败回滚**：每个字段切换状态必须可回滚；UI 立刻更新但事实流异步确认；确认失败必须撤销 UI 并提示。
5. **退出登录/切账号**：会话级字段必须随账号 scope 隔离，不能跨账号串；登出时本地 cache 必须清空，prefs key 必须带 owner 维度。
6. **离线恢复**：重新登录后必须重新从权威源拉取一次会话级字段，不能信任本地旧值。
7. **每个字段必须有一个 Owner Service**：本文档为每个字段指定唯一的 Owner Service，任何其它路径的写都被视为违规。

---

## 1. 草稿（Draft）

### 1.1 当前事实

| 路径 | 当前实现 | 文件 |
| --- | --- | --- |
| UI 输入触发 | `setConversationDraft` 直接调用腾讯 SDK | `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_text_field.dart:362` |
| 数据存储 | `V2TimConversation.draftText` 由腾讯 SDK 管理 | `third_party/tencent_cloud_chat_uikit/lib/data_services/conversation/conversation_services_implements.dart:87` |
| 本地快捷读 | `conversation.draftText` 直接读 SDK 字段 | `lib/src/conversation.dart:4340` / `lib/src/widgets/conversation_feed/conversation_archived_entry_tile.dart:134` |
| 本地库持久化 | `ConversationDraftService` 已存在（只读本地库） | `lib/src/services/conversation_local/conversation_draft_service.dart` |
| 发送后清理 | `ChatDraftController` / `ConversationDraftService.clearDraftForConversationIds` | `lib/src/chat_page/chat_draft_controller.dart:80` |

### 1.2 唯一权威决议

> **草稿的唯一权威是腾讯 IM SDK（`conversation.draftText`）。**
>
> 本地库 `ConversationDraftService` 是渲染快照，不是事实源；只在腾讯 IM 不可达时降级显示。

**理由**：
- 腾讯 IM SDK 已经把 `draftText` 持久化在云端会话对象里，跨设备/跨端是天然同步的。
- 设计文档 ADR-005 标注 `Proposed`，产品语义"是否跨设备同步"应该尊重 SDK 默认行为，避免引入第二份事实。

### 1.3 单写入者

| 操作 | 唯一入口 | 备注 |
| --- | --- | --- |
| 写入草稿 | `TIMUIKitTextField` → `conversationModel.setConversationDraft` | 必须经过 `tui_conversation_view_model.dart:668`，禁止其它路径直调 SDK |
| 清理草稿（发送后） | `ChatDraftController.didSend` → `ConversationDraftService.clearDraftForConversationIds` | UI 端只触发意图，SDK 调用必须经过 Coordinator |
| 读取草稿（列表预览） | `ConversationListNotifier.conversations[i].draftText` | 仅读 |

### 1.4 冲突/失败回滚

- **本地乐观更新**：UI 输入触发即更新本地 `TextEditingController`，立刻可见。
- **SDK 失败**：本地保留草稿但标红，提示"未保存"。
- **退出登录**：草稿不入 prefs，纯云端；本地 `TextEditingController` 状态随页面销毁即丢。
- **重新登录**：从 `getConversationList` 拉回 `draftText`，不读本地旧值。
- **删除会话**：SDK 会清草稿；本地 UI 缓存跟随 conversation 删除。
- **进程杀死**：草稿在 SDK 云端，进程重启后从 `getConversationList` 拉回。

### 1.5 跨账号

`draftText` 跟随会话；会话跟随 owner。`getConversationList` 返回的会话带 owner；草稿读路径必须先校验 owner。

### 1.6 待产品确认

- **Web 平台**：SDK Web 版 `setConversationDraft` 报"feature does not exist"。需要决定 Web 是只读快照、还是禁止显示草稿输入框，还是 mock 一份本地 cache（违反 ADR-001）。
- **离线草稿编辑**：当前 SDK 必须联网才能 `setConversationDraft`。需要决定离线时是否允许本地缓存草稿（违反"单权威"，但工程上常见）。

---

## 2. 置顶（Pin）

### 2.1 当前事实

| 路径 | 当前实现 | 文件 |
| --- | --- | --- |
| UI 入口 | `ConversationPinService.togglePinned` | `lib/src/services/conversation_pin_service.dart:42` |
| 主权威 | 腾讯 SDK `pinConversation`（开关控制） | `lib/src/services/conversation_pin_sync_service.dart:1254` |
| 自建后端 | `ConversationPinApi` REST 调用 | `lib/src/api/conversation_pin_api.dart` |
| 本地缓存 | SharedPreferences + tenant scope + account scope | `lib/src/services/conversation_pin_sync_service.dart:43` |
| 状态机 | "腾讯为主 + 自建跟写"（开关 `conversationPinTencentPrimary`） | `conversation_perf_flags.dart` |
| 跨账号 | `clearForOwner` 清空指定 owner 维度 | `lib/src/services/conversation_pin_sync_service.dart:1380+` |

### 2.2 唯一权威决议

> **置顶存在两个权威，按运行时开关分模式：**
>
> - **`conversationPinTencentPrimary = true`（默认）**：腾讯 IM `pinConversation` 是事实源，自建 REST 是"同写镜像"。冲突时信腾讯并同步自建。
> - **`conversationPinTencentPrimary = false`（灰度）**：自建 REST 是事实源，腾讯 IM 仅渲染快照。冲突时信自建并尝试回写 SDK（允许失败）。

**理由**：
- 设计文档 ADR-007 标注 `Proposed`，产品语义"唯一权威"取决于业务策略。
- 当前实现已经是双权威+开关形态，可以平滑灰度。
- 不强制单一权威会引入"既写腾讯又写自建失败"的中间态，需要 ADR-007 明确接受这个中间态或者强制收敛。

### 2.3 单写入者

| 操作 | 唯一入口 | 备注 |
| --- | --- | --- |
| 切换置顶 | `ConversationPinService.setPinned` | 任何页面（聊天页 / 列表页 / 设置页）只能调这个 |
| 登录后回填 | `ConversationPinSyncService.syncAllOnLogin` | 必须跑完才能允许 UI 显示置顶状态 |
| 跨账号清理 | `ConversationPinSyncService.clearForOwner` | 必须带 owner 维度 |
| UI 渲染 | `TIMUIKitProfileWidget.pinConversationBar` / `ConversationListNotifier.conversations[i].isPinned` | 只读 |

### 2.4 冲突/失败回滚

- **腾讯成功 + 自建失败**：以腾讯为准，本地状态保留腾讯值；自建下次登录时由 `syncAllOnLogin` 重试。
- **腾讯失败 + 自建成功**：开关切回只信自建；UI 立刻更新；腾讯保留旧值。
- **双失败**：UI 不更新，提示用户重试；本地 cache 保留旧值。
- **退出登录**：`clearSession` 清内存 + `clearForOwner(owner)` 清 prefs。
- **重新登录**：`syncAllOnLogin(force=true)` 拉取权威源；本地旧 prefs 与新会话合并（按 conversationID 去重）。
- **删除会话**：本地从 `_pinnedConversationIds` 移除对应 id；腾讯 SDK 自动跟随会话删除。

### 2.5 跨账号

`prefs` 用 `ContactSocialCacheStore.accountScopeForUserId` 作 key；`captureIdentity` 强制带 `SessionIdentity(owner, generation)`；晚到回执必须校验 `_isCurrent(identity)`。

### 2.6 待产品确认

- **置顶上限**：腾讯 SDK 是否有限？超出上限的 UI 行为？
- **置顶顺序**：同 owner 内多个置顶的排序规则（按置顶时间？按最近消息？）。
- **多端置顶顺序冲突**：A 端把 X 置顶到第 1，B 端把 Y 置顶到第 1，sync 后谁是第 1？

---

## 3. 免打扰（Do-Not-Disturb / Mute）

### 3.1 当前事实

| 路径 | 当前实现 | 文件 |
| --- | --- | --- |
| UI 入口 | `_messageService.setC2CReceiveMessageOpt` / `ImGroupReceiveOpt.setGroupReceiveMessageOpt` | `lib/src/conversation.dart:3364` / `:5935` |
| 主权威（会话级） | 腾讯 SDK `V2TimConversation.recvOpt` | 由 SDK 管理 |
| 自建后端（用户级 / 会话级备份） | `ConversationNotifyApi.batchUpdate` REST | `lib/src/api/conversation_notify_api.dart` |
| 登录时回填 | `ConversationNotifySyncService.syncAllOnLogin` | `lib/src/services/conversation_notify_sync_service.dart:62` |
| 跨账号 | 同 pin：基于 prefs + tenant scope | 同 pin 模式 |
| 业务分发通知 | `PushService` / 推送通道过滤 | 不在本文范围 |

### 3.2 唯一权威决议

> **免打扰存在两个权威，按优先级：**
>
> 1. **腾讯 SDK `recvOpt` 是会话级实时权威**（影响 IM SDK 推送和实时消息回调）。
> 2. **自建 REST 是用户级 / 跨设备权威**（影响推送服务、App Badge、跨端一致性）。
>
> **冲突规则**：登录后 `syncAllOnLogin` 强制把腾讯 SDK 拉到自建；用户级开关以自建为准，会话级开关以腾讯为准。

**理由**：
- SDK `recvOpt` 是实时消息/推送过滤的引擎层开关，必须写腾讯。
- 但 App Badge、推送通道过滤需要跨端一致，必须有自建 REST 备份。
- 两份数据必然存在中间态，ADR-007 必须接受。

### 3.3 单写入者

| 操作 | 唯一入口 | 备注 |
| --- | --- | --- |
| 设置 c2c 免打扰 | `setC2CReceiveMessageOpt` 走 `conversation.dart:3364` 的 Service 层入口 | 禁止页面直调 SDK |
| 设置 group 免打扰 | `ImGroupReceiveOpt.setGroupReceiveMessageOpt` | 同上 |
| 同步到自建后端 | `ConversationNotifyApi.batchUpdate` | 由 `ConversationNotifySyncService` 触发 |
| 登录后回填 | `ConversationNotifySyncService.syncAllOnLogin` | 必须跑完 |
| UI 渲染 | `ConversationUnreadUtils.isConversationDisturbed` + `recvOpt` 字段 | 只读 |

### 3.4 冲突/失败回滚

- **腾讯成功 + 自建失败**：UI 显示腾讯状态；自建下次 sync 重试。
- **腾讯失败 + 自建成功**：UI 标记"同步中"；提示用户重试；不允许把自建当成事实源覆盖 UI（避免双权威不一致）。
- **双失败**：UI 不更新，提示重试。
- **退出登录**：`clearSession` 清内存；prefs 由 `clearForOwner` 清。
- **重新登录**：`syncAllOnLogin` 强制把腾讯拉回自建。
- **删除会话**：腾讯自动清；自建列表里删除对应条目。

### 3.5 跨账号

同 pin：`ContactSocialCacheStore.accountScopeForUserId` 作 prefs key。

### 3.6 待产品确认

- **C2C / 群粒度差异**：SDK c2c 和 group 走两条 API；自建是否支持同一粒度？
- **会议群强制免打扰**：`isConversationDisturbed` 对 `groupType == 'Meeting'` 返回 false。是否需要可配置？
- **接收消息但不提醒（`kTIMRecvMsgOpt_Not_Notify`）vs 完全不接收（`kTIMRecvMsgOpt_Not_Receive`）**：产品默认行为？

---

## 4. C2C / 群 已读水位

### 4.1 当前事实

| 路径 | 当前实现 | 文件 |
| --- | --- | --- |
| 会话级未读 | `V2TimConversation.unreadCount`（腾讯 SDK 字段） | 渲染处 `ConversationUnreadUtils.notifiableUnreadCount` |
| 标记会话已读 | `ConversationUnreadClearService.markReadForEditAction` | `lib/src/services/conversation_unread_clear_service.dart:62` |
| SDK 调用：c2c | `MessageService.markC2CMessageAsRead` | `lib/src/services/conversation_unread_clear_service.dart` 内 |
| SDK 调用：群 | `MessageService.markGroupMessageAsRead` | `lib/src/services/group_conversation_unread_helper.dart:68` |
| SDK 调用：所有 | `markAllMessageAsRead` | `conversation_unread_clear_service.dart` |
| 已读回执（我发出消息，对方是否读） | `sendMessageReadReceipts` + V2TimMessageReceipt | 暂未在 UI 中渲染回执 |
| 自建已读 | **未发现独立自建后端** | — |

### 4.2 唯一权威决议

> **已读水位只有腾讯 SDK 一个权威。**
>
> - **会话级未读**（"我还有几条没读"）：腾讯 SDK `unreadCount` 是事实源。
> - **消息级已读**（"我发出的消息对方读没读"）：腾讯 SDK `V2TimMessageReceipt` 是事实源。
> - **App Badge / Tab 角标**：派生自 `unreadCount` 但应用免打扰规则过滤，由 `ConversationUnreadUtils` 单点计算。

**理由**：
- 文档 ADR-006 标注 `Proposed`，但当前实现没有任何自建后端覆盖已读水位，避免引入第二份事实。
- 腾讯 IM 的已读水位 SDK 已经云端同步，跨设备天然一致。

### 4.3 单写入者

| 操作 | 唯一入口 | 备注 |
| --- | --- | --- |
| 标记 c2c 会话已读 | `ConversationUnreadClearService.markReadForEditAction`（C2C 路径） | 内部调 `markC2CMessageAsRead` |
| 标记群会话已读 | `ConversationUnreadClearService.markReadForEditAction`（Group 路径） | 内部调 `markGroupMessageAsRead` |
| 标记所有已读 | `markAllMessageAsRead` | 仅登录后或显式入口 |
| 发送已读回执 | `sendMessageReadReceipts`（聊天页打开对方消息时触发） | 待 UI 落地 |
| App Badge 计算 | `AppBadgeUnreadUtils` → `ConversationUnreadUtils.notifiableUnreadForAggregate` | 只读派生 |

### 4.4 冲突/失败回滚

- **SDK 标记已读失败**：UI 角标不更新；下次进会话自动重试（不需要显式 retry）。
- **多设备同一会话**：以"最新已读"为准；SDK 内部用 seq 排序，无需客户端干预。
- **退出登录**：SDK 自动清当前账号的未读；本地角标由 `clearForOwner` 清。
- **重新登录**：SDK 自动从云端拉回未读；本地角标重算。
- **删除会话**：SDK 自动清未读；UI 列表移除。

### 4.5 单聊 vs 群 差异（IM-04/07 已经明确）

- **C2C**：`unreadCount` 是 1v1 的最后消息未读状态，无 seq 概念。
- **群**：`unreadCount` 是"消息总数 - 我读到的最高 seq"；连续性靠腾讯服务端 seq，不靠本地。
- 任何 `seq` 推理逻辑必须只能在群路径里使用；C2C 路径禁止出现 seq 字段。

### 4.6 待产品确认

- **已读回执 UI**：是否在气泡右侧显示"已读 / 未读"？当前无 UI。
- **撤回 / 编辑 / 删除对已读的影响**：被撤回消息是否计已读？文档 ADR-006 未明确。
- **群已读比例**：是否要显示"5/12 已读"？需要自建后端聚合，不是 SDK 直接给的。

---

## 5. 跨字段硬约束

### 5.1 每个字段只有一个正式写入者

| 字段 | Owner Service | 禁用直调 SDK |
| --- | --- | --- |
| `draftText` | `tui_conversation_view_model.setConversationDraft` | 任何 `setConversationDraft` 直调 |
| `isPinned` | `ConversationPinService.setPinned`（双权威） | 任何页面直调 `pinConversation` |
| `recvOpt`（c2c） | `setC2CReceiveMessageOpt` Service 入口 | 任何 `setC2CReceiveMessageOpt` 直调 |
| `recvOpt`（group） | `ImGroupReceiveOpt.setGroupReceiveMessageOpt` | 任何直调 |
| `unreadCount` | 腾讯 SDK 回调 → `ConversationListNotifier` | 任何 UI 手动修改未读数字 |
| `markC2CMessageAsRead` | `ConversationUnreadClearService` | 任何 `markC2CMessageAsRead` 直调 |
| `markGroupMessageAsRead` | `ConversationUnreadClearService` / `GroupConversationUnreadHelper` | 任何 `markGroupMessageAsRead` 直调 |

### 5.2 删除 / 退出登录 / 重新登录 / 离线恢复统一语义

| 场景 | draftText | isPinned | recvOpt | unreadCount |
| --- | --- | --- | --- | --- |
| 删除会话 | SDK 自动清 | 自建 + 内存 `_pinnedConversationIds` 同时移除 | SDK 自动清；自建列表移除 | SDK 自动清 |
| 退出登录 | 不入 prefs，纯云端 | `clearForOwner(owner)` 清 prefs；内存清 | `clearForOwner` 清 prefs | SDK 自动清 |
| 重新登录 | `getConversationList` 拉回 | `syncAllOnLogin(force=true)` 强制拉 | `syncAllOnLogin` 强制拉 | SDK 自动拉回 |
| 离线恢复 | SDK 不可达时显示本地 `ConversationDraftService` 快照（仅渲染） | SDK 不可达时显示本地 prefs（仅渲染） | SDK 不可达时显示本地 prefs（仅渲染） | SDK 不可达时显示本地 `ConversationListNotifier` 缓存 |
| 切账号 | 渲染旧账号草稿（带 owner badge）；不可写 | 渲染旧账号置顶（带 owner badge）；不可写 | 渲染旧账号免打扰（带 owner badge）；不可写 | 渲染旧账号未读（带 owner badge）；不可写 |

### 5.3 强制 fence 协议（所有字段读写）

每个字段读写都必须在 `SessionIdentityService.instance.isCurrent(identity)` 内执行：

```dart
final identity = SessionIdentityService.instance.capture();
if (!SessionIdentityService.instance.isCurrent(identity)) return;
```

晚到回执（账号已切走）必须直接拒绝，不写入本地也不写腾讯 SDK。

---

## 6. 开放问题（待产品/技术共同结论）

| 序号 | 主题 | 选项 | 推荐 |
| --- | --- | --- | --- |
| Q1 | 草稿是否跨设备同步 | A. 纯腾讯 SDK（默认） B. 自建本地 cache 优先 | **A**（与 1.2 ADR 一致） |
| Q2 | 草稿 Web 端体验 | A. 禁用草稿输入框 B. 走腾讯 SDK 兼容层 C. 临时本地 cache | **A**（最稳） |
| Q3 | 置顶唯一权威 | A. 始终腾讯为主 B. 始终自建为主 C. 运行时开关 | **C**（现状，灰度灵活） |
| Q4 | 置顶顺序 | A. 按置顶时间 B. 按最近消息 C. 二者结合 | **B**（与现有 UI 一致） |
| Q5 | 多端置顶冲突 | A. 后写覆盖 B. 提示用户合并 C. 取并集 | **C**（不丢用户意图） |
| Q6 | 免打扰多端冲突 | A. SDK 为主 B. 自建为主 C. 分层 | **C**（与 3.2 ADR 一致） |
| Q7 | 会议群强制免打扰 | A. 保留强制 B. 可配置 | **A**（保持现状） |
| Q8 | 已读回执 UI | A. 显示在气泡右侧 B. 不显示 C. 仅在详情页 | **C**（最低侵入） |
| Q9 | 群已读比例 | A. 实时显示 B. 不显示 | **B**（避免新引入自建聚合） |
| Q10 | 切账号时旧账号渲染 | A. 完全隐藏 B. 带 owner badge 显示 | **B**（透明度高） |

---

## 7. 实施门禁（进入代码前必须达成）

1. **本 ADR 通过评审**，所有 `Q1-Q10` 有产品确认。
2. 每个字段的 **唯一入口** 抽出独立文件 + `@visibleForTesting` 钩子，便于 IM-10 静态门禁扫描。
3. **fence 协议**强制接入 `SessionIdentityService`。
4. 现有 **直调 SDK** 的入口（`rg 'setConversationDraft|pinConversation|setC2CReceiveMessageOpt|setGroupReceiveMessageOpt|markC2CMessageAsRead|markGroupMessageAsRead' lib`）逐条登记。
5. **单元测试**覆盖：单写者、跨账号拒绝、登出/重登语义、双权威开关切换。

---

## 8. 与其它 IM 阶段的关系

- **IM-04/07/08** 已完成"消息事实流"，本文不涉及。
- **IM-10**：将本 ADR 列出的"单写者入口"迁到独立 Overlay/Row namespace，避免在页面直接调 SDK。
- **IM-11**：跑 `tool/im_migration_scan.ps1` 时，本 ADR 是静态门禁的引用基线。
- **设计文档第 29 节**：ADR-005/006/007 的状态从 `Proposed` → `Adopted` 必须依赖本文评审通过。

---

## 9. 未完成

- 真机验证：双权威切换、跨端冲突、退出登录后再登录的回填顺序、性能（登录后 sync 是否阻塞列表渲染）。
- 多设备验证：A 设备切换置顶后 B 设备的渲染延迟（依赖网络）。
- 大群已读比例聚合是否需要自建后端（与 Q9 绑定）。
- 切账号 fence 的真实场景：账号切换瞬间晚到回执是否能被拒，需要集成测试。
---

## 10. 静态审计快照（2026-08-30）

执行 `rg -n -- '<sdk_api>\s*\(' lib --type dart` 全量扫描，结果如下：

| SDK API | 直调位置数 | 是否已经过 Owner Service | 处置 |
| --- | --- | --- | --- |
| `setConversationDraft` | 0 | ✅ 走 `tui_conversation_view_model.setConversationDraft` | 维持现状 |
| `pinConversation` | 1（`conversation_pin_sync_service.dart:1269`） | ✅ `_pinConversationOnTencent` 是 Owner 内部方法 | 维持现状 |
| `setC2CReceiveMessageOpt` | **4**（`conversation.dart:3371` / `:5942` / `c2c_chat_settings_page.dart:340` / `platform_official_account_service.dart:644`） | ❌ **没有 Owner Service** | **必须新增 `C2cReceiveOptService` 收敛** |
| `setGroupReceiveMessageOpt` | 1（`im_group_receive_opt.dart:90`） | ✅ `ImGroupReceiveOpt` 是 Owner Service | 维持现状 |
| `markC2CMessageAsRead` | 0 | ✅ 全走 `ConversationUnreadClearService` | 维持现状 |
| `markGroupMessageAsRead` | 2（`conversation_unread_clear_service.dart:1073` / `group_conversation_unread_helper.dart:68`） | ✅ 两个 Owner Service | 维持现状 |
| `sendMessageReadReceipts` | 0 | ⚠️ UI 未落地 | IM-10 后再处理 |

### 10.1 必须修复（IM-10 之前）

**新增 `C2cReceiveOptService`**（`lib/src/services/conversation_local/c2c_receive_opt_service.dart`），
把 `setC2CReceiveMessageOpt` 的所有调用收敛到一个入口，对标 `ImGroupReceiveOpt` 的实现风格：

- 必须带 `SessionIdentityService` fence
- 必须带 `AccountScopedConversationKey`
- 必须有 `@visibleForTesting` 钩子
- 必须新增单元测试：单写者、跨账号拒绝、登出后拒绝

待修改的 4 处直调：
1. `lib/src/conversation.dart:3371` —— 替换为 `C2cReceiveOptService.set(userID, opt)`
2. `lib/src/conversation.dart:5942` —— 同上
3. `lib/src/pages/c2c_chat_settings_page.dart:340` —— 同上
4. `lib/src/services/platform_official_account_service.dart:644` —— 同上

### 10.2 其它 ADR 边界清单（供 IM-11 静态门禁）

```
rg -n -- 'setConversationDraft\s*\(' lib third_party        # 草稿唯一入口
rg -n -- 'pinConversation\s*\(' lib third_party             # 置顶唯一入口
rg -n -- 'setC2CReceiveMessageOpt\s*\(' lib                 # c2c 免打扰唯一入口
rg -n -- 'setGroupReceiveMessageOpt\s*\(' lib              # group 免打扰唯一入口
rg -n -- 'markC2CMessageAsRead\s*\(' lib                    # c2c 已读唯一入口
rg -n -- 'markGroupMessageAsRead\s*\(' lib                 # group 已读唯一入口
rg -n -- 'sendMessageReadReceipts\s*\(' lib                # 已读回执唯一入口
```

每条命令的命中位置必须全部位于 §7 表格中指定的 Owner Service 内；其它位置出现就是 IM-11 静态门禁违规。