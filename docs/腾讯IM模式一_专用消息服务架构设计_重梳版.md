# 腾讯 IM 模式一：专用消息服务架构设计（重梳版）

> 版本：v2.3-review
> 适用项目：99chat Flutter 客户端 + Tencent Cloud Chat SDK + 自建业务后端
> 评审基线：当前项目工作树，参考提交 `9f7c46e`
> 文档状态：架构评审稿，暂不代表已经完成代码迁移

> 本次修订重点：补齐运行时唯一 Writer 的 Lease / fencing 协议、跨 Isolate/进程入口序号原子分配、退出登录与切账号期间的 Pending Outbox 规则、Outbox 加密恢复副本双写状态机，以及普通消息窗口的增量 Snapshot 与视口锚点保持协议；同步补充测试、灰度和 ADR 门禁。
>
> 本次补充基线（2026-08-29）：项目方已确认当前腾讯 IM 为最高套餐。下列官方文档明确声明的能力均纳入本次重构的可用能力范围；文档明确写出的平台限制仍然有效，例如 Web 没有真正的本地历史/本地搜索，Web 不使用群 `lastMsgSeq`。`SDK_DOC_SUPPORTED` 表示 SDK 和套餐层面可以采用，`CODE_INTEGRATED` 表示当前仓库已经接入，`RUNTIME_VERIFIED` 才表示当前版本、目标平台和真实账号已经完成现场验证，三者不得混写。

## 0. 文档目的

当前项目的问题不是缺少某一个缓存或某一个刷新函数，而是同一份业务状态同时受到多个数据源、多个 Listener、多个异步任务和多个页面入口影响。消息已读/未读、最后一条消息、历史加载、发送接管、群消息排序和消息合并问题，都可能由同一个根因引起：

```text
多个来源进入多个写入者
        ↓
异步完成顺序不等于业务顺序
        ↓
局部修补互相覆盖
        ↓
消息、会话摘要、未读状态逐渐分叉
```

本方案的目标不是再添加一个“更大的全局状态类”，而是重新定义：

1. 哪些是数据来源，哪些只是事件来源；
2. 哪些字段有资格成为事实；
3. 哪些事件必须串行处理；
4. 哪一次提交才算完成；
5. 哪些旧入口必须关闭；
6. 发生崩溃、断网、超时和乱序后如何恢复。

## 1. 核心结论

### 1.1 总体方向

保留腾讯 IM 作为消息基础设施，但在客户端建立一个真正的消息中台边界：

```text
页面 / 会话页 / 推送 / 后台恢复
                ↓ 只产生命令或意图
        App MessageService
                ├── Command / Effect ──→ Tencent SDK Adapter
                │                              ↓ SDK Result
                └── Event Router ←─────────────┘
                         ↓
                  Account / Conversation Mailbox
                         ↓
                  Reducer + Message Writer
                         ↓
                   Durable Commit
                         ↓
                    UI Snapshot
```

腾讯 IM 继续负责：

- 正式消息正文和正式 `msgID`；
- 在线、离线、多端投递；
- 云端历史；
- 群消息基础 Seq；
- 正式撤回结果；
- SDK 本地消息库；
- 基础会话和基础已读能力。

客户端负责：

- 把 SDK 回调和历史响应转换为标准事件；
- 对同一账号、同一会话的事件串行裁决；
- 管理发送中的 Outbox；
- 管理历史覆盖、缺口和恢复；
- 管理本地已读意图和已读水位；
- 从消息提交结果派生会话摘要；
- 发布不可变 UI Snapshot。

### 1.2 最重要的架构判断

当前最大风险不是腾讯 SDK 本身，而是“单一 Writer”还没有成为生产环境唯一的正式状态出口。当前代码中仍存在：

- SDK 消息服务自己的 `messageListMap` 和 `sendingMessage`；
- `TUIChatGlobalModel.messageListMap`；
- 多处 `setMessageList`；
- 聊天页直接读取和改写消息列表；
- 多个 `V2TimAdvancedMsgListener` 注册者；
- 历史、实时、发送、归档、通话、群提示各自的旁路；
- 会话本地 Store、Notifier、Tab Store 和 SDK 会话监听并存。

因此，不能把本方案理解成“新增 MessageService”。正确目标是：

> 最终所有正式状态只能由一个领域提交管线产生，其他模块只能提交事件、读取快照或执行外部副作用。

## 2. 范围与非目标

### 2.1 本次架构范围

- 单聊和群聊普通消息；
- 文本、图片、视频、语音等发送操作；
- 本地历史、云端历史、实时消息的合并；
- 群 Seq 缺口和历史补洞；
- 发送中、发送失败、发送超时和进程重启恢复；
- 已读水位、会话未读和最后一条消息；
- 撤回、本地删除、清空历史、删除会话；
- 通话气泡、群提示、时间线、未读线等 UI 辅助行；
- 登录、切账号、前后台、SDK 重连和 UserSig 刷新；
- 会话摘要和会话列表局部投影；
- 客户端本地元数据持久化；
- 自建后端 IM Gateway 的边界和幂等规则。

### 2.2 明确非目标

- 不重写腾讯 IM 的消息路由和离线投递；
- 不直接修改腾讯 SDK 本地数据库；
- 不在 App SQLite 中复制一份完整消息正文作为第二事实库；
- 不用自建长连接替换腾讯 IM；
- 不通过强制 `unread=0`、无条件 `replace` 或无限重试制造表面稳定；
- 不一次性推倒重写所有聊天页面；
- 不在本阶段引入 Kafka 等重型消息中间件；
- 不把通话结果、钱包结果、订单状态伪装成 IM 消息事实；
- 不把本地 UI 辅助内容写成会参与历史连续性的正式消息。

## 3. 当前项目基线与问题定位

### 3.1 当前数据来源分类

当前项目中的“数据源”需要先分成三类，不能继续把它们统称为消息来源。

| 类型 | 当前来源 | 是否能成为正式消息事实 | 处理方式 |
| --- | --- | --- | --- |
| 权威事实源 | 腾讯 SDK 正式消息、本地 SDK 历史、腾讯云历史、正式撤回结果 | 是 | 进入 Message Writer 裁决 |
| 事件输入源 | SDK Listener、历史 Future、发送回调、已读回调、Timer、页面命令、生命周期 | 否 | 转成 Typed Event，进入 Mailbox |
| 展示投影源 | Flutter 内存列表、会话列表、未读角标、通话气泡、群提示、时间线 | 否 | 只能从提交结果派生 |

Outbox 是一个特殊来源：它可以保存“尚未被腾讯正式接管的发送操作和正文”，但不能把自己保存的内容冒充正式历史消息。

### 3.2 当前代码中的关键旁路

#### 消息服务持有独立消息状态

`MessageServiceImpl` 当前有独立的 `messageListMap` 和 `sendingMessage`，历史查询结果返回前还会拼接这些本地数据：

- `third_party/tencent_cloud_chat_uikit/lib/data_services/message/message_service_implement.dart:78-81`
- `third_party/tencent_cloud_chat_uikit/lib/data_services/message/message_service_implement.dart:180-289`

这会让 Repository 查询和 UI 发送状态混在一起。历史响应、发送中消息和正式 SDK 消息可能被不同入口分别合并。

#### `setMessageList` 仍然是广泛可调用的写入口

当前 `TUIChatGlobalModel.setMessageList` 仍负责合并、去重、排序、内存裁窗和通知：

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart:9198-9223`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart:9317-9368`

静态检索仍发现聊天页、分页、失败重试、通话气泡、群提示、归档和多个 UIKit 模块直接调用它。只要这些调用继续存在，MessageReconciliationWriter 就不是唯一生产出口。

#### Writer 的会话 Key 还没有账号隔离

当前 Writer 的 `_canonicalKey` 主要做 `trim()`，状态 Map 以字符串会话 Key 保存：

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_writer.dart:517-529`

这不足以防止以下问题：

- 切账号后旧事件进入新账号；
- 裸 ID、`c2c_`、`group_`、`TGS#` 别名进入不同桶；
- Outbox、Coverage、已读水位和会话投影使用不同 Key；
- 同一物理会话出现两份内存状态。

#### Adapter 反向依赖 UI GlobalModel

SDK 发送回调中的 `onSyncMsgID` 当前通过 `serviceLocator` 直接调用 `TUIChatGlobalModel.bindOutgoingSyncMsgId`：

- `third_party/tencent_cloud_chat_uikit/lib/data_services/message/message_service_implement.dart:753-764`

Adapter 应该只发出“SDK 已分配正式身份”的事件，不应知道 UI GlobalModel。

#### 高级消息 Listener 有多个注册者

当前至少有以下独立注册路径：

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart:2706-2728`
- `lib/src/services/conversation_local/conversation_sync_service.dart:628-658`
- `lib/src/services/notification_settings_service.dart:105-109`
- `lib/src/services/livekit_call_signaling.dart:48-57`

同一个 SDK 消息可能同时触发消息列表更新、会话预览更新、通知判断、群成员同步和通话处理。各路径又大量使用 `unawaited`，完成顺序不可控。

#### 本地辅助内容仍使用 `V2TimMessage`

通话气泡使用 `local_call_bubble_*` 身份：

- `lib/src/services/call_bubble_insert_service.dart:65-69`
- `lib/src/services/call_bubble_insert_service.dart:270-275`

群提示会构造本地 `V2TimMessage` 并写回消息列表：

- `lib/src/services/group_local/group_local_tips_service.dart:1034-1078`

归档逻辑还会在内存消息上改写 `msgID`：

- `lib/src/services/archive_im_local_persist_service.dart:709-766`

这些操作会污染正式消息去重、历史边界、最后一条消息和群 Seq 判断。

#### 会话协调器仍处于 Shadow 阶段

当前 `ConversationMutationCoordinator` 的注释明确表示它是 Phase-1/2 shadow coordinator，只用于测试和影子比较：

- `lib/src/services/conversation_local/conversation_mutation_coordinator.dart:224-232`

这说明会话领域尚未完成唯一生产写入者切换。

#### 历史证明等级仍不够完整

当前 `MessageHistoryProofKind` 只有 `none`、`transportObserved` 和 `serverContinuity`：

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_history_coverage.dart:9-18`

当前 `resolve()` 只能根据请求前后网络状态推导 `transportObserved`：

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_coordinator.dart:50-78`

这只能证明请求有机会到达服务器，不能证明会话历史连续，更不能证明本地列表已经完整。

#### 群消息重排仍需要权威 Rebase

当前群消息缓冲器在激活时以最新 Seq + 1 作为期望值：

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/inbound_reorder_buffer.dart:46-52`

超时会释放超前消息并触发补洞：

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/inbound_reorder_buffer.dart:138-156`

但补洞完成后的 `expectedSeq` 重建规则、已释放消息保留规则、自发消息和实时消息的统一顺序裁决，需要在架构层明确。

## 4. 必须长期保持的不变量

以下不变量是迁移完成的必要条件，不是建议项。

### 4.1 数据权威不变量

1. 正式消息正文、正式 `msgID` 和正式撤回结果以腾讯 IM 为准。
2. Outbox 只能代表未完成的发送操作，不能成为正式历史正文的第二事实源。
3. 会话最后一条消息必须来自正式消息提交结果，不从任意页面列表猜测。
4. 资金、订单、好友关系、群资料和通话终态必须由对应业务领域负责，IM 卡片只做展示入口。

### 4.2 写入不变量

1. 每个领域只有一个正式提交者。
2. 页面、Listener、Timer、网络 Future 和 SDK Adapter 不能直接写 UI 状态。
3. 同一账号、同一会话的事件必须经过同一个 Mailbox 串行处理。
4. Writer 不执行网络请求，不依赖 `BuildContext`，不负责页面生命周期。
5. 所有提交都必须有单调的 `commitRevision`。

### 4.3 顺序不变量

1. 事件到达顺序不等于消息业务顺序。
2. 历史请求完成顺序不等于历史边界顺序。
3. 群聊正式顺序以服务端 Seq 为第一依据。
4. 单聊不能使用群 Seq 连续性推理。
5. 发送中的消息只能按本地发送序显示，正式接管后按正式消息顺序裁决。
6. 任何历史结果都只能合并或在明确的权威窗口协议下替换，空结果不能清空已有事实。

### 4.4 生命周期不变量

每个事件必须携带账号代数和领域代数；只有确实属于页面、历史请求或发送操作的事件，才携带对应的专用代数：

- `accountGeneration`：登录账号和账号会话代数；
- `domainGeneration`：消息领域和 SDK 会话代数，页面关闭不能推进它；
- `viewSessionGeneration`：聊天页面、滚动、高亮和搜索跳转代数；
- `historyRequestGeneration`：一次历史请求或补洞请求的代数；
- `sendOperationGeneration`：一次发送操作的代数；
- `clearEpoch`：当前设备的历史可见性周期，不是页面代数，也不是发送操作代数。

正式实时消息只能因 `accountGeneration` 或 `domainGeneration` 失效而拒绝；页面关闭、页面切换和滚动位置变化不得拒绝正式实时消息。旧页面结果只能阻止 UI 提交，不能阻止消息事实、会话摘要、Outbox 终态或正式消息身份绑定落库。

## 5. 目标架构分层

### 5.1 Adapter 层

唯一负责腾讯 SDK 访问：

- 获取本地历史；
- 获取云端历史；
- 注册和注销唯一 SDK Listener；
- 发消息；
- 查询发送结果；
- 撤回、删除和已读上报；
- 下载或上传媒体；
- 获取 SDK 会话快照。

Adapter 不知道页面、Notifier、会话列表和业务 UI。

### 5.2 Ingress 层

把所有外部输入转换为统一事件：

- `RealtimeMessageReceived`；
- `HistoryPageLoaded`；
- `SendRequested`；
- `SendProgressed`；
- `SendAcknowledged`；
- `SendOutcomeUnknown`；
- `MessageRevoked`；
- `ReadIntentRaised`；
- `SdkUnreadSnapshotObserved`；
- `ConversationSnapshotObserved`；
- `ClearHistoryRequested`；
- `LifecycleChanged`；
- `RecoveryRequested`。

Ingress 不直接修改 Store。

### 5.3 Router 和 Mailbox 层

使用以下逻辑 Key 路由事件：

```text
AccountScopedConversationKey
  = ownerUserId + canonicalConversationId
```

同一 Key 内部保证串行；不同会话允许并行，但必须有全局背压和资源上限。

Mailbox 是逻辑上的串行化边界，不代表每个会话永久占用一个重量级对象：

- 有事件时按 `AccountScopedConversationKey` 懒创建；
- 空闲且没有未完成副作用时自动驱逐；
- 状态保存在持久化 Store / 投影游标，不能只保存在 Mailbox 对象；
- 每个账号设置活跃 Mailbox 上限；
- 历史网络请求发出后释放 Mailbox，不在队列中等待网络；
- 请求结果重新作为事件进入同一 Mailbox；
- 驱逐前必须保留未提交事件、Outbox 任务和恢复引用。

### 5.4 Reducer / Writer 层

Reducer 只处理纯状态变换：

- 正式消息去重；
- 乐观消息接管；
- 历史和实时合并；
- 撤回 Tombstone；
- 群 Seq 缺口；
- Coverage 更新；
- Outbox 状态推进；
- 已读水位推进；
- 会话摘要 Delta；
- UI 行生成。

网络查询、SQLite 写入、媒体上传和通知播放属于副作用层，不放入 Reducer。

### 5.5 Durable Commit 层

将状态变更和元数据提交作为一个可恢复单元：

```text
Event Inbox
    ↓
Committed Message Projection Metadata
    ↓
Coverage / Cursor / Outbox / Watermark / Tombstone
    ↓
Commit Checkpoint
    ↓
Immutable Snapshot + Summary Delta
```

UI 只能消费已经提交的 Snapshot。若提交中断，重启时从 Inbox 或 Journal 继续处理。

## 6. 统一事件模型

### 6.1 EventEnvelope

所有进入消息领域的事件必须使用类型化 Envelope。代数不是一个可以被任意复用的整数；不同代数只对声明了该代数的事件生效。

```dart
class EventEnvelope {
  final String eventId;
  final String eventNamespace;
  final EventKind kind;
  final AccountScopedConversationKey? scope;
  final String ownerUserId;
  final int accountGeneration;
  final int domainGeneration;
  final String? viewInstanceId;
  final String? surfaceId;
  final int? viewSessionGeneration;
  final int? historyRequestGeneration;
  final int? sendOperationGeneration;
  final int clearEpoch;
  final int accountIngressSequence;
  final int scopeIngressSequence;
  final int? providerSequence;
  final int? sourceRevision;
  final int? membershipRevision;
  final String? operationId;
  final EventSource source;
  final EventAuthority authority;
  final HistoryProofKind proof;
  final CursorSnapshot? cursor;
  final int observedAtMs;
  final Object payload;
}
```

字段和适用范围：

| 字段 | 作用 | 页面关闭后是否影响正式实时消息 |
| --- | --- | --- |
| `accountGeneration` | 防止旧账号、旧 UserSig、旧登录会话写入当前账号 | 会影响 |
| `domainGeneration` | 防止消息领域或 SDK 会话重置后的旧事件写入 | 会影响 |
| `viewInstanceId` | 标识具体页面实例，防止多个合法 View 相互误伤 | 不影响 |
| `surfaceId` | 标识会话列表、聊天窗、搜索预览等承载面 | 不影响 |
| `viewSessionGeneration` | 防止旧页面滚动、高亮、搜索跳转结果改写当前页面 | 不影响 |
| `historyRequestGeneration` | 防止旧分页、around、gapFill 返回覆盖新请求 | 不影响 |
| `sendOperationGeneration` | 防止旧发送 Future 或回执改写新的发送尝试 | 不影响正式实时消息 |
| `clearEpoch` | 配合 `HistoryVisibilityBarrier` 控制当前设备的历史可见性 | 不影响发送终态接管 |
| `accountIngressSequence` | 账号级确定性入口序号和诊断顺序 | 不代替消息业务顺序 |
| `scopeIngressSequence` | 同一优先级、同一 scope 的稳定重放顺序 | 不代替消息业务顺序 |
| `providerSequence` | 腾讯明确提供的群 Seq 等来源序号 | 只在 Provider 契约允许时使用 |
| `sourceRevision` | 事件来源的业务版本、成员版本或回执版本 | 由对应领域解释 |
| `membershipRevision` | 群成员关系或退群/解散状态的版本 | 用于裁决旧群消息 |

约束：

- SDK 正式实时消息必须有 `accountGeneration`、`domainGeneration`、入口序号，可有 `providerSequence` 和 `sourceRevision`，不得依赖 `viewSessionGeneration`；
- 页面滚动、高亮和搜索跳转事件必须有 `viewSessionGeneration`，只能影响页面投影；
- 页面事件还必须带匹配的 `viewInstanceId + surfaceId`，只能提交到对应 View；
- 历史事件必须有 `historyRequestGeneration` 和请求指纹；
- 发送回执、正式身份绑定和 Outbox 事件必须有 `sendOperationGeneration` 或可恢复的 `operationId`；
- `providerSequence` 不能替代腾讯正式消息顺序规则，入口序号也不能被当成群消息 Seq；
- `membershipRevision` 只用于群成员关系准入，不能替代消息 Seq；
- `observedAtMs` 只用于延迟和诊断，不能作为事件处理顺序或新旧判断依据。

入口序号的分配规则：

- `accountIngressSequence` 由账号级 Ingress Coordinator 单调分配，所有来源共用一个持久化序号分配器；
- `scopeIngressSequence` 在同一账号、同一 canonical scope 内单调分配，用于相同优先级事件的确定性排序和重放诊断；
- 序号必须在事件进入暂存 Buffer / Inbox 前分配，重启后从已持久化最大值继续，不能按 `observedAtMs` 重新排序；
- `providerSequence` 只有腾讯明确提供并由 Adapter 原样保存时才可使用；它负责证明群消息业务顺序，不能由 App 入口序号伪造；
- 入口序号只解决本地接收和重放的确定性，不替代群 Seq、服务器时间、正式 `msgID` 或来源业务版本。

### 6.2 事件 ID 和幂等

事件处理采用“至少一次输入、幂等提交”，不宣称网络层 exactly-once。

- SDK 重复回调：使用稳定事件指纹去重；
- 历史重复页面：使用请求代数、游标和页面指纹去重；
- 发送回执重复：使用 `operationId` 和正式 `msgID` 去重；
- 撤回重复：使用 `msgID + revokeRevision` 去重；
- 已读重复：只接受更高水位；
- 生命周期重复：只推进状态机，不重复执行全量恢复。

### 6.3 事件有效性检查顺序

Mailbox 处理事件时先检查账号、命名空间、幂等和领域代数，再按事件类型执行不同准入规则。禁止把“会话当前已存在”作为所有事件的统一前置条件。

| 事件类型 | 必须校验 | 会话不存在时的处理 | 不能做的事 |
| --- | --- | --- | --- |
| 正式实时消息 | `accountGeneration + domainGeneration`、消息身份、来源版本 | 允许创建会话壳，再提交消息事实和摘要 | 不能因页面未打开或会话壳尚未创建而丢弃 |
| 明确退群/解散后的旧消息 | 账号、领域、`membershipRevision`、会话 Tombstone | 按成员版本和 Tombstone 边界拒绝旧消息 | 不能只看会话是否存在 |
| 用户本地删除会话后收到的新实时消息 | 账号、领域、消息来源版本 | 消费旧 Tombstone，创建新会话壳并提交新消息 | 不能让旧删除阻断新消息 |
| 旧历史分页、latest 或 around 返回 | `historyRequestGeneration`、cursor、page fingerprint、Tombstone 和可见屏障 | 不得仅凭旧分页重新创建已删除会话 | 不能绕过 Tombstone 或 `HistoryVisibilityBarrier` |
| 发送回执和正式身份绑定 | 账号、`operationId`、`sendOperationGeneration`、Outbox 是否可恢复 | 以 Outbox 为准完成认领，不要求聊天页面存在 | 不能因页面关闭或旧 `clearEpoch` 丢弃终态 |
| 页面滚动、高亮、搜索跳转 | `viewSessionGeneration`、目标 scope 和 locator | 页面已关闭则只丢弃 UI 操作 | 不能回写消息事实或会话摘要 |

通用检查顺序为：

1. 先解析并冻结事件的 `ownerUserId`，且 `ownerUserId + eventNamespace + eventId` 未重复；普通消息、历史和 UI 事件必须属于当前活动账号；发送终态和正式身份绑定允许属于已退出的旧账号，但只能匹配该账号已存在的 `operationId`，进入隔离 Operation Inbox；
2. 正式消息事实校验当前活动账号的 `accountGeneration + domainGeneration`；发送操作事件校验 Outbox 捕获的账号、`operationId + sendOperationGeneration`。旧账号操作事件不得发布到当前账号 Snapshot；
3. 只校验当前事件声明的专用代数，不把页面代数用于实时消息；
4. 历史和 UI 投影事件检查 `clearEpoch` 及 `HistoryVisibilityBarrier`；
5. 发送终态和正式身份绑定先完成操作状态，再判断当前 UI 是否可见；
6. 校验 cursor、来源、成员版本和 Tombstone；
7. 最后进入 Reducer / Writer。

### 6.4 Event Router 的优先级通道

唯一 SDK Listener 进入 Router 后，不能让所有事件排在一条普通 FIFO 队列中。至少拆分为：

```text
唯一 SDK Listener
        ↓
    Event Router
    ├── Urgent Control Lane
    │   来电、账号失效、撤回、发送终态、UserSig异常
    ├── Realtime Message Lane
    │   普通实时消息、群 Seq 事件、已读回执
    ├── History Bulk Lane
    │   本地历史、云端分页、gapFill、around-message
    └── Background Projection Lane
        预热、索引、非必要会话刷新、媒体预取
```

通道只是调度优先级，不是多个正式状态源。进入同一会话后，正式消息仍然必须由同一个 Writer 提交。

### 6.5 视图实例与页面代数

仅使用 `scope + viewSessionGeneration` 仍不足以覆盖宽屏和多窗口场景。同一账号可能同时存在会话列表、右侧聊天页、搜索页、悬浮预览、窄屏路由和宽屏保留实例，因此页面代数必须绑定视图实例：

```text
ViewIdentity {
  viewInstanceId
  surfaceId
  viewSessionGeneration
}
```

示例 `surfaceId`：

```text
mobile_main_chat
desktop_c2c_pane
desktop_group_pane
search_preview
```

规则：

- `viewInstanceId` 标识具体的 Stateful 页面实例，实例销毁后不能复用；
- `surfaceId` 标识承载面，同一 scope 可以同时有多个 surface；
- `viewSessionGeneration` 只裁决该实例自己的滚动、加载行、高亮和搜索跳转；
- 正式消息只提交一次，所有 View 从同一 Snapshot 消费；
- 一个 View 过期不能撤销另一个仍有效 View 的 UI 操作，更不能影响正式消息事实和会话摘要。

要求：

- 控制通道不能被大群历史批次阻塞；
- 历史批次可以延迟或合并，但不能静默丢失；
- 同一会话的最终提交保持单一 revision 顺序；
- 副作用执行可以按优先级调度，状态裁决不能绕过 Mailbox；
- 每个通道有独立队列深度、延迟和丢弃策略指标。

## 7. 统一会话身份

### 7.1 CanonicalConversationId

所有模块禁止自行拼接或截取会话 ID。统一由 `ConversationIdentityResolver` 产生：

```text
C2C：c2c:<transportPeerId>
群聊：group:<transportGroupId>
```

SDK 使用的原始 ID、业务展示 ID 和内部 canonical ID 必须分开保存。

### 7.2 AccountScopedConversationKey

Coverage、Outbox、ReadWatermark、Tombstone、MessageStore、ConversationStore 必须使用同一个账号作用域 Key：

```text
<ownerUserId>::<canonicalConversationId>
```

不能出现以下做法：

- Writer 使用裸会话 ID；
- Outbox 使用 `group_` 前缀；
- 页面使用原始 SDK ID；
- Coverage 使用另一个别名；
- 切账号时只清理其中一个 Map。

### 7.3 身份迁移规则

若历史代码存在裸 ID、`c2c_`、`group_` 或 `TGS#` 别名：

1. 入口处统一解析；
2. 只允许 canonical Key 进入领域状态；
3. 旧 Key 只作为一次性迁移读取入口；
4. 迁移成功后不再向旧 Key 写入；
5. 旧 Key 的读写次数必须有指标，归零后删除兼容代码。

## 8. 消息状态模型

### 8.1 AuthoritativeMessageRecord

正式消息记录至少包含：

```text
canonicalConversationId
serverMsgId
clientCorrelationId
operationId
senderId
messageType
payloadReference
serverTimestamp
groupSeq（仅群聊可用）
status
sourceRevision
revokeState
```

正式消息的正文由腾讯 SDK 提供或恢复。App 元数据数据库只保存必要索引、状态和引用，不复制全部正文。

### 8.2 OutgoingOperation

发送操作至少包含：

```text
operationId
ownerUserId
conversationKey
messageType
payloadReference
clientCorrelationId
state
retryCount
nextRetryAt
sdkMsgId
createdAt
updatedAt
```

### 8.2.1 OutgoingIdentityContract

发送操作必须有一组可以跨进程、跨平台和跨 SDK 历史重新认领的身份字段：

```text
OutgoingIdentityContract {
  operationId
  clientCorrelationId
  sdkLocalId
  serverMsgId
  messageType
  payloadFingerprint
}
```

字段规则：

- `operationId` 是 App Outbox 的持久化操作身份；
- `clientCorrelationId` 是命名空间化、不可复用的业务关联号，不能使用时间戳或递增序号单独生成；
- `sdkLocalId` 是 SDK 创建消息后返回的本地身份，只能作为辅助认领条件；
- `serverMsgId` 是正式消息身份，获得后优先于所有临时身份；
- `messageType` 必须参与指纹和认领条件，不能把文本、图片、视频、语音或自定义消息混为同一类；
- `payloadFingerprint` 使用按消息类型规范化后的内容摘要，媒体至少包含受控文件校验和，不能只使用文件名。

`clientCorrelationId` 的传输契约：

1. 优先写入腾讯正式消息的 `cloudCustomData`，使用 17.4.2 定义的 `99chat.outgoing.v1` JSON envelope；不得写入 UserSig、令牌、明文敏感数据或完整正文；
2. `localCustomData` 只能作为本机辅助提示，不能作为跨设备、云端历史或重启恢复依据；
3. 文本、图片、视频、语音、自定义消息必须分别验证是否能在 Android、iOS、Web 的正式消息和历史读取结果中读回同一关联号；
4. 自定义消息的业务数据不能被覆盖，关联字段应与业务 payload 使用明确的版本化外层结构合并；
5. 官方文档支持只说明可以采用该字段；在三端和每种消息类型的读回验证完成前，Adapter 不得把 correlation 标记为 `stable`，只能按 `PARTIAL` 运行时证据降级。

SDK 成功但 Future 超时或返回结果未知时，认领顺序为：

```text
clientCorrelationId
  → sdkLocalId / serverMsgId
  → 目标会话
  → 有限时间窗
  → messageType + payloadFingerprint
```

只能在唯一候选同时满足会话、身份和指纹约束时完成 Outbox 接管。只找到相同文本、文件名、时间或发送者不能认领；正式消息没有可读 correlation 时也不能放宽为模糊合并：

```text
OutcomeUnknown
  → 禁止自动重发
  → 查询 SDK 正式身份和受控历史窗口
  → 仍无法唯一确认时要求用户手动决定
```

这份契约是发送可靠性的一部分，必须进入 SDK 能力矩阵、发送结果审计和杀进程/超时测试。

### 8.3 LocalMessageOverlay

本地辅助内容单独建模：

- 通话生命周期气泡；
- 群成员变更提示；
- 操作失败提示；
- 正在输入；
- 本地系统提示。

Overlay 不参与：

- 正式消息 `msgID` 去重；
- 群 Seq 连续性；
- Coverage 关闭；
- 正式最后一条消息判断；
- Outbox 接管。

### 8.4 MessageRow

最终 UI 列表由 Row Builder 生成：

```dart
sealed class MessageRow {}

class BusinessMessageRow extends MessageRow {}
class LocalOverlayRow extends MessageRow {}
class TimeDividerRow extends MessageRow {}
class UnreadDividerRow extends MessageRow {}
class LoadingRow extends MessageRow {}
class ErrorRow extends MessageRow {}
```

这样可以保留现有 UI 展示能力，同时避免把 UI 辅助行伪装成腾讯正式消息。

### 8.5 MessageMutation

消息修改和消息引用必须使用统一的派生变更模型，不能由页面直接修改目标消息对象：

```text
MessageMutation {
  targetMessageId
  mutationId
  mutationType
  sourceRevision
  payload
}
```

真正修改已有正式消息状态的 `mutationType` 至少覆盖：

```text
edit
reaction
receiptChange
businessCardChange
revoke
delete
```

这些类型必须携带稳定的 `targetMessageId`、`sourceRevision` 和变更 payload，进入目标会话 Mailbox，由 Writer 按正式身份幂等提交。

回复、引用和转发通常会创建一条新的正式消息，不能建模成对原消息的修改：

```text
OutgoingMessageCommand {
  operationId
  clientCorrelationId
  messageType
  payloadReference
  replyReference
  quoteSnapshot
  forwardSource
  mergedForwardManifest
}
```

其中 `replyReference`、`quoteSnapshot`、`forwardSource` 和 `mergedForwardManifest` 只描述新消息对原消息的引用。引用消息必须保存稳定的 `targetMessageId` 和有限展示快照，不能依赖目标消息仍在当前内存窗口；原消息的排序、正文和去重身份不因引用而改变。

## 9. 唯一提交器设计

### 9.1 Writer 的唯一职责

`MessageReconciliationWriter` 是正式消息状态的唯一提交器，但必须满足两个前提：

1. 所有正式输入都先进入同一 Mailbox；
2. 所有旧的 `setMessageList` 生产路径都被关闭或降级为 Snapshot 发布适配器。

Writer 负责：

- generation 和 epoch 校验；
- 消息身份合并；
- 正式消息去重；
- 乐观消息接管；
- 历史与实时并发；
- 删除和撤回 Tombstone；
- 稳定排序；
- Coverage 变更；
- 内存窗口裁剪；
- 单次 revision 提交。

### 9.2 MessageCommitResult

每次正式提交必须返回不可变结果：

```dart
class MessageCommitResult {
  final AccountScopedConversationKey scope;
  final int commitRevision;
  final int accountGeneration;
  final int domainGeneration;
  final int scopeIngressSequence;
  final int? sourceRevision;
  final int clearEpoch;
  final List<AuthoritativeMessageRecord> changedMessages;
  final MessageBoundary? oldest;
  final MessageBoundary? newest;
  final HistoryCoverage coverage;
  final ReadWatermark readWatermark;
  final ConversationSummaryDelta summaryDelta;
  final MessageWindowSnapshot windowSnapshot;
  final MessageRowDelta rowDelta;
  final CommitDurability durability;
}
```

会话摘要、未读投影和聊天 UI 必须消费同一个 `MessageCommitResult`，不能分别重新扫描消息列表。`windowSnapshot` 是当前窗口的不可变结构共享快照，`rowDelta` 是相对上一窗口 revision 的增量；不得为了发布一次实时消息而复制全部历史 `List<MessageRow>`。

### 9.3 提交冲突规则

- 正式 `msgID` 优先于本地临时 ID；
- 正式撤回优先于旧历史页；
- 较新的业务版本优先于旧缓存；
- 更高群 Seq 优先于到达时间；
- `accountGeneration` 和 `domainGeneration` 只用于领域准入；页面 generation 只用于页面投影；
- 更高已读水位优先于旧 SDK 快照；
- 群聊正式顺序先比较 Provider Seq，再比较来源版本；入口序号只用于同级事件确定性处理和诊断；
- 明确失败不能被普通重试结果覆盖；
- 结果不确定不能直接转为失败。

### 9.4 Runtime Writer Ownership Contract

“每个 scope 只有一个 Writer”不仅是类职责约束，还必须是运行时互斥约束。Flutter 主 Isolate、后台 Push Isolate、原生后台任务、第二个 Flutter Engine 或残留旧进程不得同时成为正式领域写入者。

运行时角色固定为：

```text
DurableIngressGateway
  多来源可以调用，只负责原子追加 Inbox / Wake Record

MessageCore Owner
  每个账号同一时刻只有一个，持有 WriterLease
  负责 Router / Mailbox / Writer / Recovery / SnapshotPublisher

Background Handler
  只能追加最小持久化入口并唤醒 Owner
  禁止直接修改 Projection / Coverage / Watermark / Tombstone / Outbox 终态
```

Writer 所有权至少包含：

```text
WriterLease {
  ownerUserId
  leaseOwnerId
  fencingToken
  acquiredAt
  expiresAt
  heartbeatAt
}
```

规则：

1. `fencingToken` 每次接管单调递增；每次领域元数据事务、Projection Checkpoint 发布和外部 Effect 派发前都必须校验当前 token；
2. 失去 Lease、账号 generation 变化或心跳超时的旧 Owner 必须停止新的领域提交和 SDK 副作用；已经返回的 SDK 结果只能重新封装为带原账号、`operationId` 的事件；
3. SQLite 自身的单写事务只能防止物理并发写，不能证明逻辑上只有一个 Writer，因此不能用“SQLite 会排队”代替 Lease 和 fencing；
4. 后台 Handler 可以通过 `DurableIngressGateway` 做短事务，但只能写 Inbox / Wake Record；正式状态必须由取得 Lease 的 MessageCore 重放后提交；
5. `accountIngressSequence` 和 `scopeIngressSequence` 必须在 Inbox 插入的同一个数据库事务中从持久化计数器原子分配；禁止先在内存 `++`、随后再写 Inbox；
6. 入口追加、序号分配和幂等主键冲突必须在同一事务中完成。重复事件返回原记录，不得消耗第二个可见业务顺序；
7. 同一账号出现多个 Owner 候选时，未取得 Lease 的实例只能请求唤醒现任 Owner，不得建立第二套 Mailbox 或 Recovery 链路。

推荐持久化两类运行时记录：账号级 Writer Lease，以及账号级/会话级 Ingress Counter。Lease 接管必须使用比较并交换或等效事务；仅凭进程内单例、Service Locator 或静态变量不构成跨 Isolate/进程互斥。

## 10. 历史加载和 Coverage Ledger

### 10.1 三种历史状态

每次历史结果必须分别记录：

```text
requestedSource：调用者请求的来源
actualSource：实际返回数据的来源
proof：本次结果具备的证明等级
```

例如请求云端但网络中断后返回本地缓存：

```text
requestedSource = cloud
actualSource = local
proof = none
```

不得把它标记成 cloud verified。

### 10.2 证明等级

建议使用四级证明：

| 等级 | 含义 | 能否关闭 Coverage |
| --- | --- | --- |
| `transportObserved` | 观察到云端传输响应 | 不能 |
| `boundedWindowComplete` | 本次请求窗口边界完整 | 只能关闭当前窗口 |
| `conversationBoundaryComplete` | 当前方向到达明确会话边界 | 可关闭当前方向 |
| `serverContinuity` | 服务端提供明确连续性证明 | 可进入 verified |

`isFinished=true` 只说明当前 SDK 请求没有更多结果，不能自动等同 `conversationBoundaryComplete`。

### 10.2.1 SDK 调用与 Proof 映射

Proof 必须由 Adapter 根据具体 SDK 调用类型、实际返回来源和腾讯 SDK 契约生成，不能由上层看到 `isFinished` 就自行升级。

每个 Proof 必须带版本信息，避免 SDK 行为变化后旧证明规则永久影响 Coverage：

```text
sdkAdapterVersion
sdkCapabilityVersion
proofPolicyVersion
```

版本变化后，旧 Coverage 可以继续作为历史记录读取，但不能自动升级新请求的证明等级；需要按新的 Proof Policy 重新验证。

| SDK 调用类型 | `isFinished` 能证明什么 | 允许关闭的范围 |
| --- | --- | --- |
| `LOCAL_OLDER` | 本地 SDK 当前读取方向到底 | 不能关闭云端方向 |
| `LOCAL_LATEST` | 本地最新窗口已经读取 | 不能证明云端最新或历史完整 |
| `CLOUD_OLDER` | 本次云端 older 请求的窗口结果 | 按 Adapter 对来源、cursor 和边界的证明关闭当前方向范围 |
| `CLOUD_LATEST` | 本次云端 latest 请求的最新窗口结果 | 只能确认最新窗口，不能证明更旧历史到底 |
| `CLOUD_NEWER` | 从给定锚点向后的本次窗口结果 | 只能更新 newer continuation，不能关闭全历史 |
| `gapFill` | 指定缺口的本次补洞结果 | 只能关闭对应缺口，不能关闭全历史 |
| `around-message` | 目标消息附近窗口 | 只能支持目标定位，不能改变全局 Coverage |

适配器必须同时返回：`actualSource`、`proof`、`cursor`、返回边界、`isFinished`、请求指纹和错误分类。没有这些信息时只能标记 `partial`。

### 10.3 Coverage 记录

Coverage 需要保存：

```text
scope
oldestVisible
newestVisible
olderCursor
newerCursor
openHoles
closedRanges
  lastProof
  lastActualSource
  lastRequestGeneration
  sdkAdapterVersion
  sdkCapabilityVersion
  proofPolicyVersion
  clearEpoch
coverageRevision
updatedAt
```

对于不连续的历史范围，建议以独立的 `coverage_range` 记录保存，不长期依赖一个不断增大的 JSON 字段。每个 range 至少有：

```text
rangeId
scope
direction
startIdentity
endIdentity
startSeq
endSeq
cursor
proof
closed
generation
pageFingerprint
sdkAdapterVersion
sdkCapabilityVersion
proofPolicyVersion
```

### 10.3.1 HistoryVisibilityBarrier

`clearEpoch` 只表示清空操作发生过多少次，不能单独表达“哪些消息对当前设备不可见”。每个 scope 必须持久化历史可见屏障：

```text
HistoryVisibilityBarrier {
  scope
  clearEpoch
  hiddenBeforeMessageId
  hiddenBeforeSeq
  hiddenBeforeTimestamp
  boundaryPageFingerprint
  clearDomainRevision
  postClearObservedMsgIDs
  postClearObservedRange
  postClearObservedRevision
  barrierState
  createdAt
}
```

规则：

1. 清空时在同一 SQLite 事务中读取当前明确的最后一条消息边界，并递增 `clearEpoch`；
2. 群聊优先使用 `hiddenBeforeSeq`，单聊使用正式消息身份和服务器时间边界；
3. 后续 SDK 历史仍可以读取，但 Message Writer 在最终提交前必须过滤屏障以前的消息；
4. 搜索本地索引、云端搜索结果和 around 补窗也必须应用同一屏障；
5. 屏障以后的新实时消息正常进入消息事实和会话摘要，不使用设备本地时间判断新旧；
6. “本地清空历史”和“服务端删除历史”是不同命令。前者只改变当前设备投影，后者必须等待服务端确认并记录独立的删除版本；
7. 页面重开或进程重启生成新请求时，仍然必须读取并执行已持久化屏障，不能因为新请求携带新的 `clearEpoch` 就重新加载旧历史。

`postClearObservedMsgIDs` 是屏障尚未获得连续性证明期间的受控观察集，不是永久消息索引。集合达到上限后，必须冻结并转入有界重校验，不能继续无限增长：

- 只记录屏障建立以后、尚未被页面连续性证明覆盖的新正式消息；
- 必须有按 scope 配置的最大数量和最大存活时间，推荐先设置硬上限（例如 1024 个 ID、24 小时），再依据真实账号数据调优；
- 接近上限时优先执行连续性校验，并在同一事务中把已证明的 ID 集合压缩为 `postClearObservedRange`、`postClearObservedRevision` 或等价的范围证明；
- 达到上限仍无法证明时，停止向该集合追加新 ID，冻结当前集合并切换为带 `scopeIngressSequence`、时间窗和正式身份的有界重校验任务；屏障保持 `partial`，未证明信息不能被覆盖；
- 校验失败时保留未证明信息并重新调度边界重叠读取、群 Seq 补洞或 C2C Coverage 校验；不能直接截断最早的 ID，也不能用“集合已满”推断历史安全；
- 任何集合压缩、范围替换和 GC 都必须记录 revision、时间和 Proof 版本，避免新请求或旧快照复活屏障以前的消息。

### 10.3.2 C2C 屏障比较规则

单聊没有群 Seq，不能使用 opaque `msgID` 的字符串大小，也不能只依赖秒级时间戳。C2C 屏障至少保存：

```text
C2CVisibilityBarrier {
  boundaryMsgID
  boundaryServerTimestamp
  boundaryPageFingerprint
  clearDomainRevision
  postClearObservedMsgIDs
  postClearObservedRange
  postClearObservedRevision
  barrierState
}
```

规则：

1. 优先在 SDK 返回的页面中找到 `boundaryMsgID`，依据边界消息的页面相邻关系判断前后；
2. 找不到边界消息时，只能标记 `partial`，继续执行重叠读取和 Coverage 校验；
3. 禁止对 opaque `msgID` 做大小排序；
4. 同一时间戳的多条消息必须使用正式身份和已知页面顺序裁决；
5. 清空后实时收到的正式消息必须标记为屏障以后，不能被旧历史时间戳过滤掉；
6. 无法证明前后关系时保持 `partial`，不能错误隐藏新消息，也不能把旧消息重新作为可见事实。

### 10.4 首屏流程

原生端：

```text
打开聊天壳
  ↓
读取 SDK LOCAL 最近窗口
  ↓
提交 localSnapshot / provisional
  ↓
允许首帧和用户交互
  ↓
后台请求 CLOUD latestWindow
  ↓
合并并更新 Coverage
```

Web 端：

```text
打开聊天壳
  ↓
标记 cloudPending
  ↓
请求云端历史
  ↓
提交 latestWindow
```

Web 云端请求不能伪装成本地快照。

### 10.5 空结果规则

空结果必须区分：

- 请求确实到达云端且证明当前方向到底；
- 网络错误；
- SDK 错误；
- 云端请求退化为本地结果；
- 旧 generation 结果；
- clearEpoch 不匹配结果。

只有第一种可以关闭对应方向的 Coverage。任何空结果都不能直接清空消息列表。

### 10.6 搜索历史消息与精确定位

搜索历史消息必须支持从搜索结果直接打开目标会话，并定位到目标消息所在位置。这里的“定位成功”必须是目标消息自身被加载并在 UI 中找到，不能仅仅是加载了目标附近的一段历史。

当前项目并非完全没有消息搜索：`TUIChatSearchViewModel` 已经调用腾讯 SDK 的本地和云端搜索接口，聊天路由和消息列表也已经有 `MessageAnchor`、搜索状态以及按目标消息加载附近历史的基础实现。当前缺少的是应用级统一服务和可恢复边界，不能让页面直接把 SDK 搜索结果当作最终定位状态。

建议新增独立的 `MessageSearchService`：

```text
MessageSearchService
├── LocalSearchRepository
├── CloudSearchRepository
├── SearchIndexer
├── SearchCoverage
├── MessageLocator
└── SearchPermissionPolicy
```

职责边界：

- `LocalSearchRepository`：查询 SDK 本地可搜索内容或 App 派生索引；
- `CloudSearchRepository`：查询腾讯云端搜索或自建后端授权搜索；
- `SearchIndexer`：维护派生索引，不拥有消息正文事实；
- `SearchCoverage`：记录本地索引覆盖范围、云端游标和重建状态；
- `MessageLocator`：把搜索结果转成 `SearchJumpCommand`，并驱动 `loadAround`；
- `SearchPermissionPolicy`：校验账号、群成员关系、消息权限和撤回状态。

搜索范围至少包括：

- 当前会话本地搜索；
- 全局本地搜索；
- 当前会话云端搜索；
- 全局云端搜索；
- 搜索结果到消息页的定位；
- 撤回、删除后的索引失效；
- 索引重建和异常恢复。

搜索索引是派生投影，必须可以从腾讯正式消息和业务权限重新构建，不能反过来成为第二份消息真相。

#### 标准流程

```text
搜索结果
  ↓ 携带 SearchJumpCommand
打开或复用目标会话
  ↓
按目标身份读取 LOCAL 附近窗口
  ↓ LOCAL 不足
按 cursor / msgID / seq 请求 CLOUD around-message
  ↓
进入同一 Message Mailbox
  ↓
Writer merge，不能清除实时消息和发送中消息
  ↓
确认目标消息精确存在
  ↓
等待列表布局稳定
  ↓
按稳定 Row Key 居中滚动并高亮
  ↓
释放搜索期间的内存裁窗抑制
```

#### SearchJumpCommand

搜索结果不能只传关键词、列表下标或一份临时 `V2TimMessage`。必须携带不可变定位锚点：

```text
scope
canonicalConversationId
conversationType
  serverMsgId
  clientLocalId（可选）
  groupSeq（群聊可选但推荐）
  viewInstanceId
  surfaceId
  viewSessionGeneration
  serverTimestamp
senderId
messageType
searchRequestId
source
```

定位优先级：

1. 正式 `serverMsgId` 精确匹配；
2. 群聊使用 `serverMsgId + groupSeq` 交叉确认；
3. 发送中的本地消息使用 `clientLocalId + operationId`；
4. 没有正式身份时才允许使用 `timestamp + senderId + messageType`，并且必须检查唯一性。

不能使用“同一秒、同一发送者、同一消息类型”的模糊匹配作为最终成功条件。

#### 定位成功条件

只有同时满足以下条件才允许把状态设置为 `success`：

- 当前会话 scope 与搜索结果一致；
- 当前账号和会话 generation 仍然有效；
- `MessageRow` 中存在目标正式消息；
- 目标 `serverMsgId` 或有效本地身份精确匹配；
- 列表滚动指标已经完成布局；
- 目标消息已经进入可见区域；
- 高亮操作已经绑定到目标稳定 Row Key。

目标附近的消息只能说明“around window loaded”，不能说明定位成功。特别是群 Seq 在允许范围内的近似命中，只能用于继续补窗，不能结束搜索定位状态。

#### 搜索期间的窗口规则

- 搜索定位期间暂时禁止内存窗口把目标区域裁掉；
- 历史补窗只能 merge，不得用旧搜索窗口 replace 当前实时状态；
- 禁止搜索路径调用 `_beginHistoryWindowReplace` 或使用 `setMessageList(..., replace: true)` 替换正式消息列表；
- `around-message` 的结果必须转换为 `SearchJumpCommand`，携带 `historyRequestGeneration` 和 `viewSessionGeneration`，进入目标会话的同一 Writer；
- 实时消息和发送中的消息必须继续进入同一 Writer；
- 定位完成后才恢复普通的最新端/最老端裁窗策略；
- 搜索定位不应自动清除会话未读，是否已读由正常 ReadCoordinator 规则决定；
- 搜索失败时必须明确提示“无法定位到原消息”，不能静默跳到最近消息并伪装成功。

#### 失败分类

```text
目标已在当前窗口
目标在本地 SDK，可补窗
目标需要云端 around 查询
云端查询成功但目标被撤回
云端查询成功但目标无权限或已不存在
请求超时，结果未知
旧 generation / clearEpoch 结果
```

其中“目标不存在”和“请求结果未知”必须展示不同的状态。结果未知时可以重试，不能直接认定消息不存在。

## 11. 实时消息和消息排序

### 11.1 实时消息流程

```text
SDK Listener
  ↓
唯一 Adapter 标准化
  ↓
RealtimeMessageReceived
  ↓
Account/Conversation Mailbox
  ↓
Message Writer
  ↓
MessageCommitResult
  ├── Chat Snapshot
  ├── Conversation Summary Delta
  ├── Unread Delta
  └── Coverage / Diagnostics
```

Listener 回调中禁止：

- 重型 JSON 解析；
- 整表排序；
- 直接写 SQLite；
- 直接写 `messageListMap`；
- 直接修改页面 State；
- 直接触发多个全量同步。

### 11.2 群聊顺序

群聊排序规则：

1. 正式群 Seq 是第一顺序依据；
2. 同 Seq 出现多个不同正式 `msgID` 时，记录协议冲突，不静默丢弃；
3. 没有有效 Seq 的本地 Overlay 不参与群连续性；
4. 群 Seq 缺口进入 Coverage；
5. gapFill 只能合并，不能替换整个消息窗口；
6. 补洞完成后调用 `rebaseFromAuthoritativeHistory`，重建 `expectedSeq`；
7. 超时释放的超前消息必须通过正式身份去重；
8. 自发消息必须进入同一 Writer，不能有独立的排序旁路。

### 11.3 单聊顺序

单聊不能使用群 Seq 判断连续性。排序依据按优先级为：

1. 已确认的服务端时间和正式身份；
2. SDK 返回的历史边界；
3. 发送中的本地 `sendOrdinal`；
4. 稳定的消息身份；
5. Event ingest sequence 只作为最后的稳定兜底。

单聊不得因为历史 Future 晚完成而重置已经显示的新消息。

### 11.4 大群消息策略

大群实时洪峰时：

- 接收事件必须完整保留；
- UI 更新可以批量合并；
- 同一会话可以在一个短批窗口内合并多个事件；
- 只能丢弃重复的 UI 通知，不能丢正式消息、撤回、发送结果和补洞事件；
- 超过队列容量时进入背压或落盘，不能静默丢弃。

## 12. 发送与 Outbox

### 12.1 发送状态机

```text
Created
  ↓
Preparing
  ↓
Prepared
  ↓ 主库与恢复副本均已持久化
DispatchIntent
  ↓ 再次校验 Writer fencingToken
Sending
  ├── SDK success ─────────→ Acknowledged
  ├── 明确业务拒绝 ────────→ FailedTerminal
  ├── 可恢复错误 ──────────→ Retryable
  └── 超时/连接中断 ───────→ OutcomeUnknown

OutcomeUnknown
  ├── 查到正式 msgID ──────→ Acknowledged
  ├── 证明未发送且可重试 ──→ Retryable
  └── 明确拒绝或本地数据损坏 → FailedTerminal

Retryable → Prepared → DispatchIntent → Sending（新的 dispatchAttemptId）
Acknowledged → AdoptFormalMessage → Completed
Created / Preparing / Prepared → PausedByLogout
PausedByLogout → Prepared（同账号重新登录）
PausedByLogout → AbandonedByUser（用户明确清除恢复数据）
```

`Prepared` 和 `DispatchIntent` 同时属于发送状态与持久化安全边界：`Prepared` 证明 SDK 尚不得调用；`DispatchIntent` 表示 SDK 可能已经调用，崩溃恢复必须按 `OutcomeUnknown` 查询，不能自动重发。`AbandonedByUser` 只表示用户明确放弃本地恢复证据，不能伪装成腾讯侧“确定未发送”。

### 12.2 发送流程

1. 生成全局唯一 `operationId` 和稳定 `clientCorrelationId`；
2. 先写入主 Outbox 和加密恢复副本，双方到达 `Prepared`；
3. 在 Writer 中提交乐观记录；
4. 主库和恢复副本记录同一个 `dispatchAttemptId + DispatchIntent`；
5. 再次校验 Writer fencing token 后，通过 Adapter 调用腾讯 SDK；
6. SDK 回执、`onSyncMsgID`、实时回调和历史回查都转为事件；
7. Writer 负责把乐观记录接管为正式 `msgID`；
8. 提交正式消息和会话摘要；
9. 确认正式状态持久化后再标记 Outbox 完成；
10. 进程重启时恢复未终态 Outbox。

### 12.3 发送安全边界

- 同一 `operationId` 只能有一个发送决策；
- SDK Future 超时不等于失败；
- 重试前先查询是否已经被 SDK 接管；
- 媒体本地文件不存在时必须明确失败；
- 不能因为点击重试多次就创建多个正式操作；
- 正式消息已出现但本地回执丢失时，必须通过历史或实时消息完成接管；
- 清理 Outbox 必须晚于正式消息和投影提交。

## 13. 已读、未读和会话摘要

### 13.1 已读四层模型

```text
localReadIntent
  用户已经看到并满足已读条件

sdkReadReported
  已向腾讯 SDK 发起或完成已读上报

sdkUnreadSnapshot
  SDK 当前返回的会话未读快照

effectiveReadWatermark
  本地最终用于 UI 和业务判断的单调水位
```

旧 SDK 快照不能降低已经确认的本地已读水位。只有真正越过有效水位的新消息才能增加未读。

### 13.2 ReadWatermark

每个会话保存：

```text
lastReadMessageId
lastReadSeq（群聊）
lastReadTimestamp
watermarkRevision
reportedToSdkAt
source
accountGeneration
```

更新规则：

1. 页面只提交“已读意图”；
2. ReadCoordinator 判断是否满足可见条件；
3. 只允许水位单调前进；
4. 上报腾讯 SDK 是异步副作用；
5. 会话列表消费提交后的 `UnreadDelta`；
6. SDK 旧快照只能被记录，不能复活已清除角标。

### 13.3 最后一条消息

会话摘要拆成两个层次：

```text
authoritativeSummary
  正式消息摘要，来自 MessageCommitResult，可持久化

optimisticSummaryOverlay
  发送中的即时预览，来自 Outbox，不是正式事实
```

用户点击发送后，会话列表可以立即显示：

```text
[发送中] 你好
```

但该内容只能作为 `optimisticSummaryOverlay`。发送成功后由正式消息摘要接管；明确失败后显示失败状态或清除；结果未知时保留待确认状态，不能直接当成失败或正式成功。

正式会话摘要只能由 `MessageCommitResult.summaryDelta` 产生：

```text
正式消息提交
  ↓
计算 newest authoritative message
  ↓
生成 lastMessageId / timestamp / preview
  ↓
只 patch 目标会话行
```

以下内容不能直接成为会话最后一条正式消息：

- 本地通话气泡；
- 未持久化群提示；
- 发送中的临时消息；
- 旧页面缓存；
- SDK 过期会话快照；
- 历史请求返回顺序。

如果产品需要展示本地通话或群提示，应作为独立 Overlay Preview，并明确它不是正式消息摘要。当前代码的发送预览主要在 SDK 发送成功后的 `messageDidSend` 回调中触发，后续应把发送中预览迁入 Outbox 投影，而不是继续由页面异步 patch 会话行。

## 14. 撤回、删除与清空历史

### 14.1 撤回

撤回必须创建 Tombstone：

```text
scope
serverMsgId
reason
sourceRevision
createdAt
```

旧历史页再次返回该消息时，Tombstone 优先，不能让已撤回消息复活。

### 14.2 本地删除

本地删除只影响当前设备投影，不能伪装成服务端撤回。删除和撤回必须使用不同事件类型和不同指标。

### 14.3 清空历史

每次清空历史都必须创建或更新对应 scope 的 `HistoryVisibilityBarrier`，而不是只增加一个内存 epoch：

```text
clearEpoch = clearEpoch + 1
hiddenBeforeMessageId = 当前正式最后一条消息.msgID
hiddenBeforeSeq = 当前正式最后一条消息.seq（群聊）
hiddenBeforeTimestamp = 当前正式最后一条消息.serverTimestamp
createdAt = 当前服务器时间或受信本地时间
```

`clearEpoch` 是可见性周期版本，`HistoryVisibilityBarrier` 才是可执行的历史下界。所有历史、预热、搜索和 UI 投影任务都携带开始时的 `clearEpoch`，但最终是否可见必须由 Writer 对持久化屏障再次判断。

发送操作必须使用独立的 `sendOperationGeneration` 和 `operationId`：

```text
发送图片
  ↓ SDK 实际已经成功
清空聊天记录，clearEpoch + 1
  ↓ 晚到的发送回执
完成正式 msgID 接管
更新 Outbox = Acknowledged / Completed
  ↓
根据发送操作创建时间、正式服务器身份和清空屏障决定是否进入当前投影
```

因此，旧 `clearEpoch` 的发送回执不能被简单拒绝：

- 必须更新 Outbox 的最终状态；
- 必须持久化 SDK 正式身份绑定；
- 必须防止用户重试造成重复正式发送；
- 可以根据清空边界阻止该消息重新出现在当前 UI；
- 不能让 Outbox 永久停留在 `Sending` 或 `OutcomeUnknown`。

发送操作必须保存 `createdBeforeClearEpoch` 或等价的可见性标记，使“业务操作完成”和“当前投影是否显示”成为两个独立判断。清空、关闭页面、页面代数变化都不能撤销正式身份接管。

清空本地历史不等于删除云端历史；删除会话还需要 Conversation Tombstone 防止旧分页重新灌入。

## 15. 生命周期与恢复

### 15.1 会话状态

```text
Idle
  ↓ open
ServingLocal
  ↓ local committed
ReconcilingCloud
  ├── verified ───────→ Ready
  ├── partial/failed ──→ Incomplete
  └── offline ─────────→ OfflineServing

Ready / Incomplete / OfflineServing
  ↓ background
Suspended
  ↓ foreground
RecoveryPending
  ↓
ServingLocal / ReconcilingCloud
```

### 15.2 全局恢复入口

只允许 `RecoveryCoordinator` 编排：

- 登录完成；
- SDK 登录完成；
- SDK 服务器同步完成；
- 网络恢复；
- App 回前台；
- 切换账号；
- UserSig 刷新；
- SDK 重连；
- 被踢下线后重新登录。

各业务 Service 不再分别启动全量 Timer、全量刷新和重复补偿。

### 15.3 恢复顺序

```text
验证当前账号和 SDK 登录状态
  ↓
尽早挂载唯一 SDK Listener
  ↓
实时事件进入暂存 Buffer / Mailbox，不直接发布未裁决状态
  ↓
恢复 Journal / Outbox / Barrier / Coverage / Watermark / Tombstone
  ↓
依据最后确认消息边界和 Coverage，从 SDK 本地库重叠读取最新窗口
  ↓
本地历史与暂存实时事件通过同一 Writer 合并
  ↓
发布本地 Snapshot
  ↓
后台云端校验和缺口修复
```

Listener 必须先接入，但恢复期间只允许事件进入暂存 Buffer / Mailbox，不得绕过 Writer 发布状态。暂存事件、SDK 本地历史和后续云端结果必须在同一会话 Writer 中按正式 `msgID` 幂等合并；群聊还要按 Seq 检查和补洞，单聊按边界、页面指纹和 Coverage 校验。

恢复期间不允许旧账号或旧会话任务写入当前 Mailbox。发送终态回执和正式身份绑定仍按 `operationId` 进入操作状态处理；只有它对应的当前 UI 投影需要再次经过 `clearEpoch` 可见性判断。页面关闭或最后一个 View 销毁都不能卸载正式消息接收，也不能拒绝实时消息。

### 15.4 数据灾难恢复

恢复必须按事实来源分层，不能把 App 元数据库、SDK 本地库、云端历史和搜索索引视为同一份数据：

| 故障 | 可恢复来源 | 处理 |
| --- | --- | --- |
| App 元数据库损坏，SDK 本地库正常 | SDK 正式消息、Outbox 受控副本 | 重建 App 元数据和 Projection，保留正式身份，Outbox 逐项核验 |
| SDK 本地库损坏，云端历史正常 | 云端历史和消息搜索 | 重新建立本地 SDK 库，按 Coverage 和 Barrier 恢复 |
| App 元数据库和 SDK 本地库都不可用 | 云端历史、服务端 Outbox、用户命令 | 进入受控重建；无法证明的范围标记 `partial`，不能伪造完整历史 |
| Outbox 损坏 | 用户重新发起的命令或服务端命令状态 | 停止自动重试，禁止无 `operationId` 的补发 |
| 加密密钥丢失 | 密钥托管恢复或不可恢复错误 | 不得把密文当空正文，不得继续发送 |
| Search Index 损坏 | 正式消息事实和权限 | 删除并重建索引，搜索期间明确降级 |
| 单表损坏 | 同表重建源和 Journal | 只重建受影响表，校验 revision 后再发布 |
| 整库损坏 | 备份、SDK、云端和服务端 Outbox | 新库分阶段恢复，先事实和操作，再投影和索引 |

Outbox 的保护等级必须高于普通投影缓存，不能在“清理缓存”时一起删除。恢复过程中如果无法证明发送命令是否已经被 SDK 接管，必须保持 `OutcomeUnknown` 并查询正式身份，不能直接重试。

### 15.5 退出登录、切账号与 Pending Outbox

退出登录和切账号是账号作用域切换，不等于所有未决发送操作已经失败。处理顺序固定为：

```text
冻结旧账号新命令和自动重试
  ↓
递增 accountGeneration，撤销旧 WriterLease
  ↓
按旧 ownerUserId 封存 Inbox / Journal / Outbox / 恢复副本
  ↓
处理或隔离晚到的 SDK 回执
  ↓
建立新账号作用域和新的 WriterLease
```

旧账号 Outbox 状态必须按发送边界分类：

| 退出时状态 | 处理 |
| --- | --- |
| `Created / Preparing / Prepared`，尚无 `DISPATCH_INTENT` | 转为 `PausedByLogout`，禁止后台偷偷发送；同账号重新登录后可以恢复 |
| 已记录 `DISPATCH_INTENT`、`Sending` 或 Future 结果未知 | 转为或保持 `OutcomeUnknown`，只允许查询和认领，禁止自动重发 |
| `Acknowledged`，正式身份尚未完成投影 | 保存正式身份和旧账号 scope，等待同账号恢复后完成投影 |
| `Completed / FailedTerminal / Cancelled` | 按保留期进入正常 GC，不因切换账号改变结论 |

约束：

- SDK 调用必须捕获调用开始时的 `ownerUserId + accountGeneration + operationId`。晚到结果不能使用“当前登录账号”重新归属；
- 当前已切换到其他账号时，旧账号晚到结果只能写入旧账号的隔离 Operation Inbox / 恢复副本，不得创建当前账号消息、会话摘要或通知；
- 重新登录同一账号后，先恢复其 Journal、Outbox 和正式身份认领，再开放自动重试；
- 登录其他账号时，不得解密、展示、发送或清理旧账号 payload；不同账号的数据密钥、目录、Lease、Counter 和 Snapshot 必须完全隔离；
- 普通“退出登录”不得先删除存在未决 Outbox 的密钥。用户明确选择“清除该账号本地数据”时，必须提示会永久失去未决发送的恢复和防重证据；确认后先标记 `AbandonedByUser` 并完成审计，再按策略销毁；
- 账号被踢下线、UserSig 失效和主动退出登录使用同一安全状态机，但产品提示可以不同。

## 16. 本地持久化设计

### 16.1 数据库边界

App 数据库只保存消息元数据和操作状态：

- `message_event_inbox`；
- `message_commit_journal`；
- `message_outbox`；
- `message_history_coverage`；
- `message_history_range`；
- `message_history_visibility_barrier`；
- `message_read_watermark`；
- `message_tombstone`；
- `message_projection_checkpoint`；
- `message_media_operation`；
- `conversation_projection`。

腾讯 SDK 的消息正文和 SDK 本地消息库继续由 SDK 维护。

历史可见屏障必须独立持久化，不能只存在于页面或 Writer 内存：

```sql
CREATE TABLE message_history_visibility_barrier (
  owner_user_id TEXT NOT NULL,
  scope TEXT NOT NULL,
  clear_epoch INTEGER NOT NULL,
  hidden_before_message_id TEXT,
  hidden_before_seq INTEGER,
  hidden_before_timestamp INTEGER,
  boundary_page_fingerprint TEXT,
  clear_domain_revision INTEGER,
  post_clear_observed_msg_ids TEXT,
  post_clear_observed_range TEXT,
  post_clear_observed_revision INTEGER,
  barrier_state TEXT NOT NULL DEFAULT 'active',
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY(owner_user_id, scope)
);
```

### 16.2 Event Inbox

```sql
CREATE TABLE message_event_inbox (
  owner_user_id TEXT NOT NULL,
  event_id TEXT NOT NULL,
  event_namespace TEXT NOT NULL,
  conversation_id TEXT,
  event_kind INTEGER NOT NULL,
  operation_id TEXT,
  account_generation INTEGER NOT NULL,
  domain_generation INTEGER NOT NULL,
  view_instance_id TEXT,
  surface_id TEXT,
  view_session_generation INTEGER,
  history_request_generation INTEGER,
  send_operation_generation INTEGER,
  clear_epoch INTEGER NOT NULL,
  account_ingress_sequence INTEGER NOT NULL,
  scope_ingress_sequence INTEGER NOT NULL,
  provider_sequence INTEGER,
  source_revision INTEGER,
  membership_revision INTEGER,
  payload_hash TEXT NOT NULL,
  recovery_mode INTEGER NOT NULL,
  recovery_ref TEXT,
  payload_ciphertext TEXT,
  status INTEGER NOT NULL,
  observed_at INTEGER NOT NULL,
  committed_at INTEGER,
  PRIMARY KEY(owner_user_id, event_namespace, event_id)
);

CREATE INDEX idx_message_event_scope
ON message_event_inbox(owner_user_id, conversation_id, status);
```

`payload_hash` 只用于幂等和完整性校验，不能承担重放职责。每条事件必须明确自己的恢复策略：

| 事件 | Inbox 保存内容 | 崩溃恢复方式 |
| --- | --- | --- |
| SDK 正式实时消息 | 事件指纹、正式 `msgID`、会话身份、最后确认消息边界和 Coverage 引用 | 保存最后确认边界和 Coverage；重启后从 SDK 本地库重叠读取最新窗口，按正式 `msgID` 幂等去重，再进入 Writer；群聊按 Seq 检查和补洞，单聊按边界、页面指纹和 Coverage 校验 |
| 历史分页结果 | 请求参数、cursor、方向、page fingerprint | 重新请求或从 SDK 本地库重新读取，不能把半页当完整页 |
| 发送操作 | 由 Outbox 持久化正文或受控引用 | 读取 Outbox，查询 SDK 是否已接管，再决定重试或认领 |
| 媒体发送 | 媒体操作 ID、持久文件引用、校验和 | 从 App 管理的媒体副本恢复上传或进入明确失败 |
| 已读、撤回、清空命令 | 完整且可重放的命令参数 | 重启后继续执行或幂等确认 |
| UI 通知事件 | 可不落盘 | 丢失后由最新 Snapshot 重新派生 |

不建议把每条 SDK 实时消息的完整正文复制进 App Inbox。这样会增加数据库写入、发热和存储压力，也会形成第二份消息正文。正式消息恢复只依赖“最后确认边界 + Coverage + SDK 本地库重叠读取 + 正式身份幂等去重”；没有其他恢复来源的发送、媒体和命令才保存完整参数或受控引用。

`recovery_mode` 至少包括：

```text
sdkBoundaryReplay
sdkOverlapReplay
historyRequest
outboxPayload
managedMediaFile
commandArguments
ephemeralUi
```

`recovery_ref` 必须能在重启后解析，不能是 Dart 对象地址、内存 Map Key 或临时 Future。

### 16.3 Commit Journal

Commit Journal 记录的是一次元数据提交和投影发布的协议状态，不是普通日志。至少包含：

```sql
CREATE TABLE message_commit_journal (
  owner_user_id TEXT NOT NULL,
  journal_id TEXT NOT NULL,
  event_namespace TEXT NOT NULL,
  event_id TEXT NOT NULL,
  scope TEXT,
  commit_revision INTEGER NOT NULL,
  state TEXT NOT NULL,
  metadata_revision INTEGER,
  projection_revision INTEGER,
  side_effect_revision INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY(owner_user_id, journal_id),
  UNIQUE(owner_user_id, event_namespace, event_id)
);

CREATE TABLE message_commit_effect (
  owner_user_id TEXT NOT NULL,
  effect_id TEXT NOT NULL,
  journal_id TEXT NOT NULL,
  effect_kind TEXT NOT NULL,
  state TEXT NOT NULL,
  attempt_count INTEGER NOT NULL DEFAULT 0,
  last_error TEXT,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL,
  PRIMARY KEY(owner_user_id, effect_id)
);
```

本方案选择“方案 A：Inbox 本身代表 Prepared”，不再设计一个无法可靠落盘的 Journal `PREPARED` 状态：

```text
Inbox 事件持久化完成 = PREPARED
  ↓
SQLite 主事务标记 Inbox = PROCESSING
  ↓
更新 Coverage / Outbox / Watermark / Tombstone / Barrier
  ↓
写入 commitRevision 和 Projection Checkpoint
  ↓
Journal = METADATA_COMMITTED
```

因此 `message_commit_journal.state` 的可持久化状态只包括 `METADATA_COMMITTED`、`PROJECTION_PUBLISHED` 和 `COMPLETED`；`PREPARED` 是 Inbox durable 行代表的恢复锚点，不是 Journal 单独的一行。Inbox 事件写入成功与 Journal 元数据提交必须分别可观测，不能在文档中声明一个代码不会写入的状态。

状态只能按以下方向推进：

```text
Inbox durable row = PREPARED
  ↓ SQLite 主事务完成
METADATA_COMMITTED
  ↓ Snapshot 已发布
PROJECTION_PUBLISHED
  ↓ 客户端允许的持久化副作用完成或明确排队
COMPLETED
```

一次提交的 SQLite 事务必须包含：

```text
SQLite transaction
├── Event Inbox = PROCESSING
├── 更新 Coverage / Outbox / Watermark / Tombstone / Barrier
├── 写入 commitRevision
├── 写入 Projection Checkpoint
└── Journal = METADATA_COMMITTED
COMMIT
↓
发布不可变内存 Snapshot
↓
Journal = PROJECTION_PUBLISHED
↓
按 effectId 执行 Badge、本地通知、应用内通知和 best-effort 声音/震动等客户端副作用
↓
Journal = COMPLETED
```

崩溃恢复规则：

| 崩溃位置 | 恢复动作 |
| --- | --- |
| Inbox 持久化前 | 按事件来源重新产生事件；SDK 正式消息使用最后确认边界重叠读取，历史使用请求参数，发送/命令使用 Outbox |
| Inbox durable 行已存在（`PREPARED`），SQLite 事务前 | 按 `event_namespace + event_id` 幂等重放 |
| SQLite 事务完成后 | 读取 Journal 和 Projection Checkpoint，重建 Snapshot，不重复元数据提交 |
| Snapshot 发布后、Journal 未完成 | 按 `commitRevision` 校验投影；副作用按 `effectId` 幂等补偿 |
| 副作用执行中进程退出 | 读取副作用账本继续执行，不能用“Snapshot 已发布”推断声音或推送已经执行 |

客户端 Journal 只管理以下副作用：Badge 绝对值、本地通知展示/取消、应用内通知状态，以及 best-effort 的声音/震动。每项副作用必须有独立的 `effectId` 和执行状态。

远程 Push 不属于客户端 Journal，固定走：

```text
服务端 Outbox
  → 腾讯 Push / APNs / JPush
  → OS 展示
```

系统推送展示、远程 Push 的重试和服务端投递状态由服务端/腾讯/厂商链路负责，不能用客户端 Snapshot 或 Journal 状态推断，也不能在客户端 Journal 中重复登记为待执行副作用。

### 16.4 Outbox

```sql
CREATE TABLE message_outbox (
  operation_id TEXT PRIMARY KEY,
  owner_user_id TEXT NOT NULL,
  conversation_id TEXT NOT NULL,
  client_correlation_id TEXT NOT NULL,
  message_type INTEGER NOT NULL,
  payload_reference TEXT NOT NULL,
  media_local_ref TEXT,
  encryption_version INTEGER,
  key_id TEXT,
  cipher_algorithm TEXT,
  nonce TEXT,
  content_checksum TEXT,
  state INTEGER NOT NULL,
  sdk_message_id TEXT,
  retry_count INTEGER NOT NULL DEFAULT 0,
  next_retry_at INTEGER,
  created_at INTEGER NOT NULL,
  updated_at INTEGER NOT NULL
);

CREATE INDEX idx_message_outbox_ready
ON message_outbox(owner_user_id, state, next_retry_at);
```

Outbox 不得保存 UserSig、管理员密钥、访问令牌和不必要的完整远程媒体地址。

`payload_reference` 的语义必须固定，不能只是内存引用。推荐：

```text
inlineEncryptedText:<payloadId>
managedFile:<fileId>
sdkAdoptionRef:<clientCorrelationId>
```

`operation_id` 必须是全局唯一 UUID（或同等强度的不可预测唯一标识）。如果实现不能保证全局唯一，则 Outbox 主键必须改为 `owner_user_id + operation_id` 的复合主键，并额外保留全局幂等 Key。

文字正文需要受控持久化或加密保存；媒体引用必须指向 App 管理的持久文件，不能指向系统可能随时清理的临时目录。发送完成、明确失败或取消后，只有满足保留策略才允许清理对应数据。每个引用都需要保存版本、校验和、创建时间和清理状态。

### 16.4.1 Outbox 存储保护 ADR

本方案选择：**单库 + 加密恢复副本**。

| 方案 | 本方案决策 | 原因 |
| --- | --- | --- |
| 单库 | 不单独拆 Operations DB | Outbox、消息元数据和 Barrier 可以在同一 SQLite 事务中原子提交 |
| 独立 Operations DB | 暂不采用 | 跨库提交需要 Saga，增加发送接管和崩溃恢复的不确定性 |
| 单库 + 加密恢复副本 | 采用 | 保留事务简单性，同时让 Outbox 和发送 payload 具备整库损坏后的受控恢复来源 |

恢复副本不是第二份消息事实，也不是可供 UI 直接读取的投影；它只保存恢复所需的最小加密记录，包括 `operationId`、`clientCorrelationId`、目标会话、消息类型、payload 引用/密文、指纹、状态版本和校验和。禁止写入 UserSig、令牌、管理员密钥和不必要的明文正文。

发送前的持久化顺序必须是：

```text
写入主 SQLite Outbox = Prepared
  ↓
写入加密恢复副本 = Prepared
  ↓ 两者均成功
主库和恢复副本写入相同 dispatchAttemptId + DISPATCH_INTENT
  ↓ 两侧 Intent 一致且 fencingToken 有效
调用 SDK Adapter
  ↓
主库和恢复副本分别记录 SDK 结果/OutcomeUnknown
```

主库或恢复副本任一写入失败，都不得调用 SDK。SDK 调用后若恢复副本暂时写失败，主库 Outbox 保持唯一运行时权威，标记 `recoveryLag`、禁止清理 payload，并阻止自动重发；待副本追平后才允许进入正常 GC。整库恢复时必须比较主库、恢复副本和 SDK 正式身份，无法唯一证明的操作保持 `OutcomeUnknown`，不能把恢复副本直接当作发送成功证明。

未来如果要拆出独立 Operations DB，必须重新提交 ADR，明确跨库 Journal、补偿顺序、双写失败和回滚兼容性后才能实施。

### 16.4.2 Recovery Copy Consistency Protocol

加密恢复副本必须位于主 SQLite 文件之外的独立损坏域，推荐使用 App 私有目录中的加密追加日志或独立加密 Key-Value Ledger，并通过平台密钥保护。它主要防护主 SQLite 文件损坏、错误迁移或表级重建，不承诺在卸载 App、设备丢失或整个沙盒被删除后仍可恢复；这些场景只能依赖腾讯正式消息、云历史和服务端命令状态。

恢复副本默认排除普通系统/云备份；如业务需要跨设备备份，必须单独通过隐私、安全和密钥恢复评审。恢复副本不得与主库共用同一 SQLite 页，也不得被“清理缓存”入口删除。

最小记录包含：

```text
OutboxRecoveryRecord {
  ownerUserId
  operationId
  clientCorrelationId
  recoveryRevision
  dispatchAttemptId
  state
  dispatchIntentAt
  payloadReferenceOrCiphertext
  payloadHash
  sdkLocalId
  serverMsgId
  resultCode
  checksum
  updatedAt
}
```

恢复副本状态只允许向前推进：

```text
COPY_PREPARED
  → DISPATCH_INTENT
  → RESULT_RECORDED | OUTCOME_UNKNOWN
  → RECONCILED
  → GC_ELIGIBLE
```

SDK 调用前使用以下保守协议：

```text
主库写 Prepared
  ↓
副本写 COPY_PREPARED 并确认持久化
  ↓
主库写 dispatchAttemptId + DISPATCH_INTENT
  ↓
副本写相同 dispatchAttemptId + DISPATCH_INTENT 并确认持久化
  ↓ 两侧 Intent 一致
再次校验 Writer fencingToken
  ↓
调用 SDK Adapter
```

`DISPATCH_INTENT` 表示“SDK 可能已经被调用”，不是发送成功。任意一侧存在 Intent 而结果不完整，恢复后都必须保守进入 `OutcomeUnknown`，先按 `OutgoingIdentityContract` 查询和认领，不能因为另一侧仍是 Prepared 就自动补发。

双写差异恢复矩阵：

| 主库 | 恢复副本 | 恢复动作 |
| --- | --- | --- |
| `Prepared` | 不存在 | SDK 尚不得调用；补建并校验副本后才可继续 |
| 不存在/主库损坏 | `COPY_PREPARED` | 重建主库 Prepared；校验 payload 和账号后才可继续 |
| `DISPATCH_INTENT` | `COPY_PREPARED` 或不存在 | `OutcomeUnknown`；禁止自动重发，查询正式身份 |
| `Prepared` | `DISPATCH_INTENT` | `OutcomeUnknown`；以更保守的较高状态为准 |
| 两侧 Intent 的 `dispatchAttemptId` 不一致 | 任意 | 标记 `recoveryConflict`，停止自动发送并告警 |
| 主库已有 SDK 结果 | 副本仍是 Intent | 主库保持运行时权威，标记 `recoveryLag`，补写副本后再允许 GC |
| 主库损坏 | 副本已有结果 | 先校验 checksum、correlation 和 SDK 正式身份，再重建主库；副本本身不能证明正式成功 |
| payloadHash / checksum 不一致 | 任意 | 停止发送和清理，进入人工或受控修复 |

GC 必须同时满足：主库和恢复副本均已 `RECONCILED`、正式身份或终态已经持久化、Journal 无待执行引用、超过安全保留期。任何一项不满足都不能删除 payload、密钥版本或恢复记录。

### 16.5 Projection Checkpoint

每个 Snapshot 需要保存：

```text
scope
commitRevision
lastJournalId
coverageRevision
watermarkRevision
barrierRevision
projectionVersion
updatedAt
```

重启后先校验 Projection Checkpoint，再依据最后确认消息边界和 Coverage 决定是否从 SDK 本地库重叠读取最新窗口。Projection Checkpoint 只表示 App 投影提交进度，不能被解释为 SDK 消息增量 checkpoint。

### 16.6 CommitDurability 与持久化失败降级

所有提交结果必须显式带有 `CommitDurability`，禁止 SQLite 写入失败时仍以“已持久化”对外承诺：

```text
durable
  App 元数据和 SDK 正式消息事实均可恢复

sdkRecoverable
  App 元数据提交失败，但正式消息仍可从 SDK 恢复

volatile
  当前仅内存可见，不能宣称已持久化

failed
  关键操作无法安全继续
```

处理规则：

| 场景 | 处理 | 对用户的承诺 |
| --- | --- | --- |
| 收到正式 SDK 消息，App 元数据库写失败 | 保留 SDK 可恢复快照，记录待重建标记，重试元数据提交 | 显示为 `sdkRecoverable`，不能静默丢消息 |
| Outbox 无法在调用 SDK 前持久化 | 不调用 SDK 发送，记录失败原因 | 明确提示“本地存储异常，暂时无法发送” |
| Outbox 已持久化，SDK 调用结果未知 | 保留 `OutcomeUnknown`，查询 SDK 正式身份后再决定 | 不能直接提示失败，也不能重复发送 |
| Coverage / Projection 写入失败 | 保留可恢复请求和边界，降级为 `partial` | 不能宣称历史已完整 |
| 数据库磁盘已满、损坏或事务超时 | 停止新的关键写入，进入受控恢复/修复流程 | 不能继续产生无 operationId 的发送 |
| 仅 UI Snapshot 发布失败 | 从已提交 revision 重建 Snapshot | 不影响正式消息事实 |

收到 SDK 正式消息时，SDK 本地库已经持久化并不等于 App 元数据提交成功；两者必须在 Snapshot 中分别表达。用户发送消息时，Outbox 无法先落盘就不得调用腾讯 SDK，否则进程重启后没有 `operationId` 保护，可能重复发送。

### 16.7 数据库版本、迁移、回滚和清理

数据库生命周期必须独立于业务代码版本管理，至少保存：

```text
schemaVersion
projectionVersion
migrationState
minimumReadableVersion
minimumWritableVersion
```

`migrationState` 至少包括：

```text
PENDING
RUNNING
COMMITTED
FAILED
ROLLBACK_REQUIRED
```

迁移规则：

1. 先创建兼容表和索引，再切换写入口；
2. 旧会话 Key 通过 `ConversationIdentityResolver` 批量映射为 canonical Key，保留迁移映射直到新版本稳定；
3. 迁移每批提交并记录 checkpoint，进程在 `RUNNING` 阶段退出后可以继续，不重复已完成批次；
4. 迁移期间首屏只读取旧结构或兼容视图，不能被大账号全量迁移阻塞；
5. 新版本回滚前必须满足 `minimumReadableVersion`，否则进入只读恢复，不允许直接覆盖旧表；
6. 影子运行数据必须带 `projectionVersion` 和 owner，确认回滚窗口结束后才允许清理；
7. 表和索引按迁移阶段创建，先验证读兼容，再打开写入，最后删除旧入口。

GC 只能按以下条件执行：

| 数据 | 清理条件 |
| --- | --- |
| `COMPLETED` Inbox | Checkpoint 稳定且超过保留期 |
| `COMPLETED` Journal | 所有效果完成，且回滚窗口结束 |
| Coverage Range | 相邻范围已合并且 Proof 版本一致 |
| Outbox payload | 正式接管完成且超过安全期 |
| 媒体副本 | 发送完成/取消且无引用 |
| Tombstone | 不早于腾讯历史保留范围和本地恢复窗口 |
| Visibility Barrier | 不能因为普通缓存清理删除 |
| Search Index | 可从正式消息重建，并按账号和权限清理 |

### 16.8 加密和密钥管理

`inlineEncryptedText` 和 `payload_ciphertext` 必须使用受平台保护的账号数据密钥：

- Android 根密钥保存在 Android Keystore；
- iOS 根密钥保存在 Keychain；
- 每个账号使用独立的数据加密密钥，切换账号不能复用另一账号密钥；
- App 数据库只保存密文、`keyId`、密钥版本和算法元数据，不保存根密钥；
- 推荐保存 `encryptionVersion`、`keyId`、`cipherAlgorithm`、`nonce`、`ciphertext`、`contentChecksum`；
- 密钥轮换使用新版本加密后再原子替换，旧密钥只在迁移窗口内可读；
- 系统备份恢复后密钥缺失时，密文必须进入不可解密状态并提示恢复失败，不能当作空正文；
- 解密失败不得继续调用发送接口，不得把空文本发送出去；
- 日志禁止输出密文、明文、根密钥和可反推出密钥的引用。

密钥清理必须晚于 Outbox、媒体副本、Journal 和恢复窗口。退出登录时只清理当前账号密钥和受策略允许的密文，不得误删其他账号数据。

## 17. SDK Adapter 和 Listener 边界

### 17.1 唯一 Listener

应用层只注册一个统一的高级消息 Listener。它负责：

1. 校验当前账号和 SDK 会话；
2. 标准化回调；
3. 生成 EventEnvelope；
4. 投递到对应 Mailbox；
5. 记录事件延迟和去重结果。

消息、会话、通知、通话、群成员服务都订阅标准事件，不再直接注册腾讯 Listener。

### 17.2 Adapter 不反向依赖业务 UI

禁止：

```text
TencentMessageRepository
  → serviceLocator<TUIChatGlobalModel>()
  → 修改页面消息列表
```

允许：

```text
TencentMessageRepository
  → SendAcknowledged Event
  → Message Mailbox
  → Writer 接管正式身份
```

### 17.3 SDK 错误处理

每个 SDK 调用必须返回标准结果：

```text
success
retryableFailure
terminalFailure
outcomeUnknown
offlineDeferred
```

不要让上层通过解析错误字符串来猜测是否已经发送成功。

### 17.4 SDK 能力基线矩阵

架构中的能力必须区分“SDK/套餐可用”和“本项目代码已完成接入”。

在本项目中，凡官方文档明确提供且项目方已确认最高套餐可用的能力，均可以进入实现计划并作为目标能力采用；只有进入生产事实链路时，才需要再满足控制台、代码和运行时 Proof 门禁。

运行时能力成为正式事实源前必须同时满足三个条件：

1. 当前 vendored SDK 有明确 API 或平台实现；
2. 当前腾讯套餐、控制台配置、账号权限和消息保留策略允许使用；
3. 当前目标平台经过真机或真实 Web 环境验证，并保存原始返回、错误码、游标和边界消息。

只满足第 1 项时标记为 `SDK_DOC_SUPPORTED`，不能升级为 `CODE_INTEGRATED` 或 `RUNTIME_VERIFIED`。代码中存在同名方法也不能证明它已经接入统一 Adapter，更不能证明它具有同样的平台语义。

#### 17.4.1 项目方已确认的 SDK / 套餐基线

项目方已确认：当前使用腾讯 IM 最高套餐；凡是下表官方文档明确列出的能力，本项目均按“SDK 和套餐支持”纳入设计与实施范围，不再因为套餐等级把它们标记为 `UNKNOWN` 或作为架构阻塞项。

这项确认只解决“能不能使用腾讯能力”，不替代下面三类工作：

1. 确认当前 vendored SDK、TUIKit 和 Web 适配层已经把能力接到本项目的 `TencentMessageAdapter`；
2. 确认控制台插件、云端搜索、历史保留期和消息权限已经在目标 SDKAppID 上打开；
3. 确认运行时返回值、游标、正式 `msgID`、`cloudCustomData` 和页面行为符合本架构的 Proof 规则。

官方能力基线：

| 能力 | 官方依据 |
| --- | --- |
| `CloudCustomData` 消息格式、云端保存和读回 | [消息格式 / CloudCustomData](https://cloud.tencent.com/document/product/269/125773) |
| Flutter 文本、图片、语音、视频、自定义消息发送 | [Flutter 发送消息](https://cloud.tencent.com/document/product/269/75317) |
| Web 消息发送及 `cloudCustomData` | [Web 消息发送](https://cloud.tencent.com/document/product/269/75316) |
| Flutter 完整客户端 API | [Flutter API 文档](https://cloud.tencent.com/document/product/269/51940) |
| Flutter 云端历史和本地历史 | [Flutter 历史消息](https://cloud.tencent.com/document/product/269/75323) |
| Web 历史消息 | [Web 历史消息](https://cloud.tencent.com/document/product/269/75322) |
| Flutter 本地消息搜索 | [Flutter 本地消息搜索](https://cloud.tencent.com/document/product/269/75438) |
| Web 搜索的平台限制 | [Web 消息搜索](https://cloud.tencent.com/document/product/269/105927) |
| Web 云端搜索 | [Web 云端搜索](https://cloud.tencent.com/document/product/269/95415) |
| 云端搜索开通 | [插件市场 / 云端搜索开通指引](https://cloud.tencent.com/document/product/269/92648) |
| 云端搜索 FAQ | [云端搜索 FAQ](https://cloud.tencent.com/document/product/269/114751) |
| 云端搜索费用 | [增值服务计费说明](https://cloud.tencent.com/document/product/269/110762) |
| 历史消息保存时间和控制台配置 | [IM 功能配置](https://cloud.tencent.com/document/product/269/38656) |
| Flutter 会话草稿 | [Flutter 会话草稿](https://cloud.tencent.com/document/product/269/75382) |
| Flutter 会话置顶 | [Flutter 会话置顶](https://cloud.tencent.com/document/product/269/75377) |
| Flutter 消息免打扰 | [Flutter 消息免打扰](https://cloud.tencent.com/document/product/269/75355) |
| C2C / 群已读位置 | [Flutter 会话介绍](https://cloud.tencent.com/document/product/269/75365) |

本项目的能力状态从单一枚举改为分层表达：

```text
SDK_DOC_SUPPORTED
  官方文档和已确认的最高套餐支持，可以进入实现计划

CONSOLE_ENABLED
  目标 SDKAppID 已开通所需插件、权限或保留配置

CODE_INTEGRATED
  当前仓库已有 Adapter 调用和结果归一化

RUNTIME_VERIFIED
  真实平台、真实账号、真实网络条件已经保存 Proof

PLATFORM_UNAVAILABLE
  官方文档明确说明当前平台没有该语义
```

因此，“SDK 支持”不再阻止 Phase 2、Phase 4 或 Phase 5 开工；但是在对应能力成为正式事实源以前，仍必须完成 `CONSOLE_ENABLED`、`CODE_INTEGRATED` 和 `RUNTIME_VERIFIED` 的门禁。未完成 Proof 时可以开发和影子运行，但不能把结果写成 `complete`、`serverContinuity` 或“已送达”。

#### 当前依赖事实

当前项目的依赖关系是：

```text
root pubspec.yaml
  tencent_cloud_chat_sdk: ^8.7.7201
  dependency_overrides -> third_party/tencent_cloud_chat_sdk

third_party/tencent_cloud_chat_sdk/pubspec.yaml
  version: 8.9.7545

third_party/tencent_cloud_chat_uikit/pubspec.yaml
  version: 5.0.1+4

tencent_cloud_chat_push
  8.9.7538
```

因此能力验证必须以本地 override 的 SDK `8.9.7545`、当前 TUIKit `5.0.1+4`、当前 Push 插件 `8.9.7538` 和实际构建产物为准。Push 插件与 SDK 版本不完全相同，必须单独验证兼容性，不能仅凭版本号推断。

#### 能力矩阵

证据等级：

- `SDK_DOC_SUPPORTED`：官方文档和项目方已确认的最高套餐支持，可以进入实现；
- `CONSOLE_ENABLED`：目标 SDKAppID 已完成所需控制台、插件、权限或保留配置；
- `CODE_INTEGRATED`：当前仓库已有统一 Adapter 调用、结果归一化和错误映射；
- `RUNTIME_VERIFIED`：目标平台、真实账号和真实网络条件已经保存完整 Proof；
- `PLATFORM_UNAVAILABLE`：官方文档明确说明当前平台没有该语义；
- `PARTIAL`：只能证明部分范围，不能用作完整能力承诺。

下表的“支持状态”回答 SDK 和套餐能否采用；“当前代码状态”回答仓库是否已经完成切换。这两个状态必须分开维护。

| 能力 | Android SDK 能力 | iOS SDK 能力 | Web SDK 能力 | 当前仓库接入状态 | 实施规则 | 控制台、权限、保留要求 | 平台降级方案 |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 本地历史 | `SDK_DOC_SUPPORTED`，Flutter 原生 `getHistoryMessageList` | `SDK_DOC_SUPPORTED`，Flutter 原生接口 | `PLATFORM_UNAVAILABLE`，Web 无真正本地历史语义 | `PARTIAL`：`message_service_implement.dart` / `tim_message_manager.dart` 有调用，但尚未进入统一 Adapter | Android/iOS 首屏走 SDK LOCAL；Web 必须标记 `cloudPending` | SDK 本地库、会话类型和平台存储；Web 无本地库 | Web 只能展示云端加载态，不能伪装本地快照 |
| 云端历史 | `SDK_DOC_SUPPORTED` | `SDK_DOC_SUPPORTED` | `SDK_DOC_SUPPORTED`，Web 通过远端消息接口 | `PARTIAL`：Flutter `getHistoryMessageListV2`、Web `getMessageList` 已有路径，但尚未统一收口 | 最高套餐纳入范围；仍需在目标 SDKAppID 确认保留和权限 | 保留时长、群类型、账号权限和网络状态必须进入 Proof | 超时/权限/过期消息进入明确 `partial` 或 `historyUnavailable` |
| 本地搜索 | `SDK_DOC_SUPPORTED`，Flutter `searchLocalMessages` | `SDK_DOC_SUPPORTED`，Flutter `searchLocalMessages` | `PLATFORM_UNAVAILABLE`，Web 官方不提供真正本地搜索 | `PARTIAL`：`tui_search_view_model.dart` 已有 SDK 本地/云端入口，尚未收口到 `MessageSearchService` | 原生本地 SDK 库搜索范围进入 Proof | Web 不允许把云搜结果标为 local | Web 使用云端搜索或受控派生索引，并标记来源 |
| 云端搜索 | `SDK_DOC_SUPPORTED`，Flutter 云端搜索 | `SDK_DOC_SUPPORTED`，Flutter 云端搜索 | `SDK_DOC_SUPPORTED`，Web 云端搜索插件 | `PARTIAL`：当前 TUIKit 已有 `searchCloudMessages` 调用，但尚未进入统一 Adapter | 目标 SDKAppID 需开通插件/索引和权限；费用、索引范围、保留期按控制台记录 | 搜索结果必须重新鉴权，不能替代消息事实 | 云搜不可用时使用腾讯查询或后端授权搜索，并标记来源 |
| 按 `msgID` 查找 | `SDK_DOC_SUPPORTED`，`findMessages` | `SDK_DOC_SUPPORTED`，`findMessages` | `PARTIAL`，依赖 Web `findMessage` 语义 | `PARTIAL`：原生和 Web 均已有入口，但当前页面仍有旁路 | 需验证跨窗口、撤回和过期消息 | 结果必须带正式身份和会话作用域 | 使用带正式身份的有界 around 查询 |
| 按群 Seq 加载附近历史 | `SDK_DOC_SUPPORTED`，`lastMsgSeq` | `SDK_DOC_SUPPORTED`，`lastMsgSeq` | `PLATFORM_UNAVAILABLE`，Web 不使用 `lastMsgSeq` | 原生 `getHistoryMessageListV2` 有参数路径；Web 需另走 cursor/msgID | 需验证返回是否包含 anchor、群类型和权限 | 不把 Web cursor 假装成 Seq | 使用 `msgID` / cursor 的有界方向分页，保持 `partial` |
| LOCAL / CLOUD 实际来源 | SDK 文档支持 LOCAL/CLOUD 请求策略 | SDK 文档支持 LOCAL/CLOUD 请求策略 | Web 以云端历史为主 | `PARTIAL`：调用类型不能证明实际来源 | Adapter 必须记录网络状态、请求模式和实际返回证据 | 无法证明实际来源时 `proof = none` | 只关闭本次窗口 Coverage，不关闭全历史 Coverage |
| `isFinished` / `isCompleted` | `SDK_DOC_SUPPORTED`，但 Adapter 映射需统一 | `SDK_DOC_SUPPORTED`，但 Adapter 映射需统一 | `SDK_DOC_SUPPORTED`，使用 Web `isCompleted` | `PARTIAL`：部分适配器按数量推导 `isFinished` | 必须按 SDK 版本、接口类型和边界消息验证 | 不需要额外套餐能力；只需记录版本和接口语义 | 只能关闭本次窗口，不能关闭全历史 Coverage |
| Outgoing correlation 读回 | `SDK_DOC_SUPPORTED`，`cloudCustomData` 可随正式消息保存 | `SDK_DOC_SUPPORTED`，`cloudCustomData` 可随正式消息保存 | `SDK_DOC_SUPPORTED`，发送 API 支持 `cloudCustomData` | `PARTIAL`：发送链路已有字段，但正式 Adapter/历史回读闭环未完成 | 文本、图片、视频、语音、自定义消息统一使用同一协议；不得依赖 `localCustomData` 跨设备 | 当前代码仍需完成统一注入、读回和 Proof | 读回缺失或候选不唯一时保持 `OutcomeUnknown`，禁止自动重发 |
| 精确 SDK checkpoint | `PLATFORM_UNAVAILABLE` / 未发现公开精确接口 | `PLATFORM_UNAVAILABLE` / 未发现公开精确接口 | `PLATFORM_UNAVAILABLE` / 未发现公开精确接口 | 当前 SDK 源码没有可直接依赖的消息增量 checkpoint 契约 | 不得自行假设或伪造 checkpoint | 无可开通的精确 checkpoint 配置 | 保存最后确认边界，重启后重叠读取、`msgID` 幂等、群 Seq 补洞、C2C Coverage 校验 |
| 历史保留时长 | `SDK_DOC_SUPPORTED`，具体天数以控制台配置为准 | `SDK_DOC_SUPPORTED`，具体天数以控制台配置为准 | `SDK_DOC_SUPPORTED`，具体天数以控制台配置为准 | `PARTIAL`：已有历史错误和空结果路径，但未绑定配置 Proof | 最高套餐不等于固定保留天数；必须记录 SDKAppID 控制台实际值 | 不猜测超保留期数据存在 | 超出实际保留期进入明确 `partial` / `historyUnavailable` |

矩阵中的 `CODE_INTEGRATED` 只表示当前项目存在调用路径，不代表统一 Adapter、网络、权限、套餐和结果语义已经通过验证。没有真实证据时不得写入 `serverContinuity` 或 `conversationBoundaryComplete`。

#### 17.4.2 `cloudCustomData` 外发身份协议

本项目采用腾讯官方 `cloudCustomData` 作为“外发操作与正式消息之间的可读关联元数据”。它不是第二份消息正文，也不是安全存储。所有文本、图片、视频、语音和自定义消息都必须使用同一个协议版本，不能因为消息类型不同而改用不同的关联规则。

发送前由唯一 `TencentMessageAdapter` 注入版本化 JSON：

```json
{
  "schema": "99chat.outgoing.v1",
  "operationId": "opaque-operation-id",
  "clientCorrelationId": "opaque-correlation-id",
  "messageKind": "text|image|video|sound|custom",
  "payloadFingerprint": "non-reversible-fingerprint",
  "createdAtMs": 0
}
```

字段规则：

| 字段 | 规则 | 用途 |
| --- | --- | --- |
| `schema` | 必填，未知版本按 `partial` 解析 | 版本兼容和灰度识别 |
| `operationId` | 全局唯一、不得复用、不得包含可推断业务信息 | Outbox、重启恢复和防重复发送 |
| `clientCorrelationId` | 稳定且不可复用 | SDK 回执、实时消息和历史回查的关联 |
| `messageKind` | 必须与实际 SDK 消息元素类型一致 | 防止同一操作跨类型误认领 |
| `payloadFingerprint` | 只用于候选校验，不可单独认领 | 排除错误消息 |
| `createdAtMs` | 只用于有限时间窗，不作为唯一身份 | 限制查询范围 |

禁止写入 `cloudCustomData`：

- UserSig、访问令牌、管理员密钥或任何可恢复凭据；
- 私聊正文、完整媒体路径、银行卡、钱包和手机号；
- 依赖本地设备才能解释的 Dart 对象或页面对象；
- 会导致第三方看到内部业务权限的明文字段。

发送接入矩阵：

| 消息类型 | Flutter 目标 API | Web 目标 API | 统一要求 |
| --- | --- | --- | --- |
| 文本 | `createTextMessage` + `sendMessage` | Web 文本发送接口 | `cloudCustomData` 在发送前注入 |
| 图片 | `createImageMessage` + `sendMessage` | Web 图片发送接口 | 关联数据不放本地文件路径 |
| 视频 | `createVideoMessage` + `sendMessage` | Web 视频发送接口 | 上传、发送和接管共用 `operationId` |
| 语音 | `createSoundMessage` + `sendMessage` | Web 语音发送接口 | 时长属于消息类型校验，不替代正式身份 |
| 自定义 | `createCustomMessage` + `sendMessage` | Web 自定义消息发送接口 | 业务数据与关联元数据分层编码 |

关联数据的唯一写入边界是 Adapter。页面、TUIKit `MessageServiceImpl`、Outbox 恢复器和自定义发送器都不得自行拼接第二种格式。SDK Future、`onSyncMsgID`、实时 Listener、历史结果和搜索定位结果均必须转换成事件，再由 Writer 按以下顺序认领：

```text
operationId + clientCorrelationId
  → 正式 serverMsgId / SDK localId
  → 会话 scope + messageKind
  → 有界时间窗
  → payloadFingerprint
  → 唯一候选才允许 AdoptFormalMessage
```

搜索结果如果没有完整 `cloudCustomData`，只能用正式 `serverMsgId` 加载消息并重新确认，不能用搜索返回的临时对象直接完成外发接管。任一字段缺失、冲突或候选数量不为一，都保持 `OutcomeUnknown`，不得自动补发。

当前代码已有 `cloudCustomData` 解析和部分发送参数，但 `message_service_implement.dart` 仍在 SDK 回调中直接绑定 `TUIChatGlobalModel`。因此本协议落地后，必须把字段注入、回执转换和正式身份绑定一起迁入 Adapter/Writer，不能只给页面增加一个字段。

#### 17.4.3 历史、搜索和平台分流契约

历史和搜索必须按平台能力选择来源，并把实际来源写入 `HistoryProof`：

| 场景 | Android / iOS | Web | Writer 处理 |
| --- | --- | --- | --- |
| 聊天首屏 | 先读 SDK 本地窗口，再请求云端最新窗口 | 直接请求云端，先发布 `cloudPending` | 本地/云端都是事件，统一 merge |
| 普通上拉旧消息 | SDK 历史接口按方向分页 | Web 历史接口按 cursor/hopping 分页 | 只能 prepend merge，不能整窗 replace |
| 回底加载新消息 | SDK 本地/云端窗口按最后确认边界重叠读取 | Web 云端分页 | 以正式身份去重并保持 Anchor |
| 当前会话本地搜索 | SDK 本地搜索 API | 不提供真正本地搜索 | 结果只作为定位命令，不是消息事实 |
| 当前会话/全局云搜索 | SDK 云端搜索 | 云端搜索插件 | 结果重新鉴权，再通过 `loadAround` |
| 群聊附近消息 | 原生可使用 `lastMsgSeq` 的接口路径 | 不使用 `lastMsgSeq` | Web 使用 `msgID`/cursor 有界降级 |

原生端的 LOCAL/CLOUD 请求必须记录请求模式和实际返回证据；不能因为接口名包含 `LOCAL` 或 `CLOUD` 就直接写入最终 Proof。Web 的 `isCompleted` 必须在 Adapter 中显式映射为窗口完成状态，但只能关闭当前方向窗口，不能宣称全历史完整。

云端搜索属于可用能力，但必须满足：目标 SDKAppID 已开通插件/索引、搜索结果经过当前账号和群成员权限复核、结果带会话与正式消息定位信息、索引不可用时有明确降级。云端搜索索引始终是派生数据，不能替代腾讯正式消息，也不能绕过 `HistoryVisibilityBarrier`。

#### 17.4.4 会话草稿、置顶、免打扰和已读能力

项目方确认上述能力均属于当前最高套餐和官方 SDK 文档支持范围，因此可以直接进入 `ConversationCommandCoordinator` 和 `ReadCoordinator` 的实现计划：

| 能力 | SDK 正式操作 | 目标唯一写入者 | 必须保留的语义边界 |
| --- | --- | --- | --- |
| 草稿 | 会话草稿读写 | `DraftCoordinator` | SDK 支持操作不等于跨设备语义；旧快照不能覆盖新 generation 草稿 |
| 置顶 | 会话置顶读写 | `ConversationCommandCoordinator` | SDK 返回成功后才提交正式状态，失败必须回滚乐观状态 |
| 免打扰 | 会话免打扰读写 | `ConversationCommandCoordinator` | 与系统通知策略分开；不能直接等同于消息事实 |
| C2C 已读 | `c2cReadTimestamp` 相关会话能力 | `ReadCoordinator` | 由有效已读水位裁决，旧 SDK 快照不能回退水位 |
| 群已读 | `groupReadSequence` 相关会话能力 | `ReadCoordinator` | 群按 Seq，单聊不得套用群 Seq |

SDK API 只能提供执行和回读能力；是否跨设备同步、冲突由哪一侧解决、退出账号后是否保留草稿，仍由第 18.3 节产品 ADR 决定。ADR 未通过前可以完成当前设备语义和 SDK Adapter，但不得擅自接入 `DeviceSyncService` 双写。

#### 17.4.5 官方文档能力到本项目实现的判断规则

本项目后续评审统一按下面的四步判断，不再把“文档支持”“当前代码调用”“运行时成功”混成一个结论：

```text
官方文档 + 最高套餐确认
  → SDK_DOC_SUPPORTED：允许排期和设计
  → CONSOLE_ENABLED：目标 SDKAppID 配置完成
  → CODE_INTEGRATED：统一 Adapter 已接入
  → RUNTIME_VERIFIED：现场 Proof 可复现
```

对应规则：

1. `SDK_DOC_SUPPORTED` 的能力可以进入正式开发，不需要再向项目方重复确认套餐是否支持；
2. `CONSOLE_ENABLED` 只记录插件、索引、历史保留、权限等服务端开关，不把截图或口头确认当作代码完成；
3. `CODE_INTEGRATED` 必须能从页面命令追踪到 Adapter，再追踪到 SDK Result 和 EventEnvelope；
4. `RUNTIME_VERIFIED` 必须保存平台、SDK/TUIKit/Push 版本、账号类型、网络状态、请求摘要、结果码、游标和边界消息；
5. 官方文档明确的 Web 限制直接登记为 `PLATFORM_UNAVAILABLE`，不为了追求表格“全支持”而自行实现同名伪语义；
6. 没有 Proof 的能力仍可影子运行，但恢复、Coverage、发送接管和用户提示必须使用保守状态。

#### 能力验证记录

每个平台和能力都必须保存一条可追溯记录：

```text
capabilityName
platform
sdkVersion
adapterVersion
accountType
packageOrConsoleConfig
networkStateBefore / networkStateAfter
requestParametersHash
actualSource
resultCode / resultDesc
cursor
isFinished
boundaryMessageIds
rawEvidenceRef
verifiedAt
```

验证必须覆盖：空库、有本地库、断网、弱网、权限不足、消息超过保留期、撤回消息、群 Seq 缺口、重复请求和进程重启。只有记录完整且结果稳定，才允许把矩阵单元从 `SDK_DOC_SUPPORTED`、`CONSOLE_ENABLED` 或 `CODE_INTEGRATED` 改为 `RUNTIME_VERIFIED`。

### 17.5 NotificationCoordinator

推送和通知是提示入口，不是消息事实源。当前项目的通知链路至少包含：

```text
notification_settings_service.dart
push_msgkey_dedup.dart
push_notification_router.dart
ios_apns_push_service.dart
android_jpush_service.dart
local_system_notification_service.dart
app_badge_sync_service.dart
incoming_call_push_handler.dart
push_focus_service.dart
Tencent Push Listener
SDK realtime message Listener
```

这些入口必须收口到一个 `NotificationCoordinator`：

```text
NotificationCoordinator
├── RealtimeNotificationIngress
├── OfflinePushIngress
├── PushIdentityNormalizer
├── PushDeduplicator
├── ForegroundPolicy
├── BackgroundPolicy
├── NotificationTapRouter
├── BadgeProjector
├── ActiveConversationSuppressor
└── CallPushPriorityLane
```

统一流程：

```text
APNs / JPush / Tencent Push / SDK realtime
              ↓
     PushIdentityNormalizer
              ↓
     msgKey / callId / eventId 去重
              ↓
     NotificationPolicy
       ├── 当前会话前台：不显示系统通知
       ├── App 前台其他会话：Banner + 声音
       ├── App 后台：系统通知
       ├── App 被杀：OS 推送
       └── 来电：VoIP / CallKit 优先通道
```

硬性规则：

- 推送只负责唤醒和提示，不成为消息事实；
- 点击推送后仍由 SDK / MessageService 加载正式消息；
- Push 和 SDK 实时消息到达顺序不确定，必须进入同一消息身份去重边界；
- 相同消息不能同时出现系统通知和应用内 Banner 双提示；
- 当前聊天页的 push-focus 必须携带有限期的 scope 和 message locator，过期后重新加载正式消息，不能长期持有页面对象；
- 徽标只来自正式未读投影，不能从推送数量累加；
- 来电进入独立的紧急通道，不能被大群历史批次阻塞。

Journal 中的副作用按语义区分：

| 副作用 | 执行语义 |
| --- | --- |
| 数据库写入 | 至少一次 + 幂等 |
| Badge 设置绝对值 | 幂等 |
| 本地通知按固定 `notificationId` 展示 | 幂等覆盖 |
| 通知取消 | 幂等 |
| 声音/震动 | 最多一次或 best-effort，不能承诺崩溃后 exactly-once |
| 远程系统 Push | 由服务端 / OS 负责，不属于客户端 Journal |
| 页面 Banner | 从当前 Snapshot 派生，不需要崩溃重放 |

声音和震动不是天然幂等副作用。即使有 `effectId`，进程在播放之后、标记完成之前退出，重启也只能选择“可能重复”或“可能遗漏”之一；产品语义必须明确为最多一次或 best-effort。

### 17.6 SDK 升级兼容和能力探测

每次启动和每次 SDK 适配层升级都记录：

```text
sdkVersion
adapterVersion
capabilityVersion
proofPolicyVersion
schemaVersion
```

升级流程：

1. 启动时探测平台实际实现和接口可用性；
2. 用旧策略和新策略对同一组受控请求执行影子 Proof 对比；
3. 对 `isFinished`、LOCAL/CLOUD 来源、Web fallback、搜索结果和 around 边界记录差异；
4. 新 SDK 未通过能力基线前，只能使用保守 `partial` 降级；
5. 不得直接沿用旧 SDK 的 Coverage 证明；
6. 通过灰度和真实账号验证后，才提升 `proofPolicyVersion`。

## 18. 会话领域架构

### 18.1 会话摘要只接受 Delta

ConversationStore 不重新扫描完整聊天列表。它只接受：

```text
conversationKey
lastMessageId
lastMessageTimestamp
preview
unreadDelta
shouldReorder
sourceCommitRevision
```

### 18.2 会话字段权威

| 字段 | 正式权威 | 允许写入者 |
| --- | --- | --- |
| 最后一条正式消息 | MessageCommitResult | ConversationProjector |
| 未读角标 | ReadWatermark + SDK 快照裁决 | ReadCoordinator |
| 草稿 | 当前账号会话 Store | DraftCoordinator |
| 置顶/免打扰 | 腾讯 SDK 正式结果 | ConversationCommandCoordinator |
| 归档/分组 | 业务服务或本地业务 Store | Business Conversation Projector |
| 群名称/头像 | GroupMetadataStore | Group Metadata Coordinator |
| 通话预览 | CallStore | Call Overlay Projector |

一个字段只能有一个正式写入者，其他模块只能产生事件或读取投影。

### 18.3 多设备状态语义矩阵

多设备同步必须先定义产品语义，再决定是否接入 `DeviceSyncService`。设备同步和腾讯 SDK 不得同时写同一个正式字段：

| 状态 | 仅当前设备 | 账号跨设备 | 权威来源 |
| --- | --- | --- | --- |
| 普通消息 | 否 | 是 | 腾讯 IM |
| 已读 | 否 | 视 SDK 能力验证 | SDK + ReadCoordinator |
| 本地清空历史 | 是 | 否 | 本机 `HistoryVisibilityBarrier` |
| 服务端删除历史 | 否 | 是 | 服务端确认版本 |
| 草稿 | 待产品决定 | 待产品决定 | ConversationStore |
| 归档/分组 | 否 | 建议是 | 自建后端 / Business Conversation Projector |
| 发送失败 | 是 | 通常否 | 本机 Outbox |
| 置顶/免打扰 | 否 | 建议是 | 腾讯 SDK 或明确业务服务 |
| 搜索索引 | 派生 | 可分别重建 | 非事实源 |
| Visibility Barrier | 是 | 默认否 | 本机 Barrier Store |

以下多设备语义是产品决策门禁，不是实现人员可以自行选择的默认值：

| 待定字段 | 必须完成的 ADR | ADR 至少要明确 |
| --- | --- | --- |
| 草稿 | Draft Sync ADR | 是否跨设备同步、冲突合并规则、删除和离线恢复语义 |
| 已读 | Read Sync ADR | SDK 能力证据、权威水位、设备间回退规则和隐私边界 |
| 置顶/免打扰 | Conversation Preference ADR | 腾讯 SDK 与业务服务的唯一权威、冲突版本和失败回滚 |

对应字段进入实施阶段前必须先通过 ADR，并把结论写入 DeviceSync schema 和事件契约。ADR 未通过时，开发人员不得自行扩大同步范围、选择权威来源或增加第二个写入口；实现只能保持当前设备本地语义并记录未决状态。

`device_sync_service.dart` 只能同步已经明确标记为跨设备的字段，并携带账号、版本和来源。它不能：

- 写入腾讯正式消息正文、正式 `msgID` 或群 Seq；
- 覆盖 MessageCommitResult 派生的最后一条消息；
- 用跨设备状态覆盖本机 Visibility Barrier；
- 与腾讯 SDK 同时推进已读、置顶或免打扰字段；
- 将搜索索引当作可同步的消息事实。

同一字段出现 DeviceSync 和 Tencent SDK 双写时，必须先停用其中一个写入口，并记录冲突而不是按到达时间覆盖。

## 19. 性能、背压和流畅度

单写入者不等于一定流畅，Mailbox 仍需要资源边界。

### 19.1 推荐预算

| 场景 | 目标 |
| --- | --- |
| 聊天壳首帧 | 不等待云历史、群资料全量刷新和媒体元数据 |
| 单批消息提交 | 一次合并、一次 revision、一次必要通知 |
| 实时单消息 | 不复制全历史，不整表重排会话列表 |
| 大群洪峰 | 批量提交，UI 通知合并，正式事件不丢 |
| 会话行更新 | 只 patch 目标行 |
| 历史分页 | 解码、合并、持久化和图片预取分阶段执行 |
| 长时间运行 | 队列、Timer、内存窗口和媒体任务有上限 |

### 19.2 优先级通道

统一入口之后还需要分通道调度，不能把所有事件放入单一普通 FIFO：

```text
Event Router
├── Urgent Control Lane
│   来电、撤回、发送终态、账号失效、UserSig异常
├── Realtime Message Lane
│   普通实时消息、群 Seq、已读回执
├── History Bulk Lane
│   历史分页、gapFill、around-message
└── Background Projection Lane
    预热、索引、非必要会话刷新、媒体预取
```

大群一次进入几千条离线消息时，控制事件不能排在历史批次后面。通道只负责调度优先级，不能形成多个正式消息 Store；同一会话的正式状态仍由同一个 Writer 提交。

### 19.3 Mailbox 背压规则

每个会话定义：

- 最大内存事件数；
- 最大持久化 Inbox 数；
- 批量提交窗口；
- 实时消息优先级；
- 发送回执优先级；
- 撤回和删除优先级；
- 缺口修复优先级；
- 队列超限处理方式。

允许合并或丢弃：

- 重复 UI 通知；
- 重复的预取任务；
- 同一会话连续的无效刷新信号。

禁止丢弃：

- 正式消息事件；
- 发送结果；
- 撤回和删除事件；
- Outbox 状态事件；
- Coverage 缺口修复事件；
- 已读水位推进事件。

### 19.4 主线程边界

以下工作不能阻塞输入、滚动和页面转场：

- 大批量 JSON 解码；
- 全量 SQLite 写入；
- 远程媒体上传；
- 原图解码；
- 旧历史深度排序；
- 群成员全量刷新；
- 全量会话排序。

### 19.5 SLO 与灰度阈值

Phase 0 必须先采集真实基线，再冻结发布阈值。不能用未经测量的固定数字掩盖设备、平台和账号规模差异：

| 指标 | 必须采集 | 灰度停止条件 |
| --- | --- | --- |
| 本地首屏 | p50 / p95 / p99 | 超过冻结基线的 p95/p99 阈值，或阻塞首帧 |
| 云端校验 | p95 / 超时率 | 超过阈值且无法降级为明确 `partial` |
| 实时消息提交 | p95 / p99 | 正式消息提交延迟持续超阈值，或发生静默丢失 |
| 重复消息率 | 按正式 `msgID` 统计 | 出现无法解释的重复正式消息 |
| 搜索定位 | 精确成功率、未知率 | 成功率低于冻结目标，或静默跳到错误消息 |
| 裁窗恢复 | 失败率 | 任何正式消息无法通过 SDK / Cloud 恢复 |
| Outbox 未知状态 | 数量、持续时间 | 未知状态不能收敛，或出现无 operationId 重发 |
| Writer 所有权 | Lease 冲突、接管、旧 token 拒绝数 | 出现两个有效 Owner、旧 token 提交成功或入口序号重复/回退 |
| Outbox 恢复副本 | recoveryLag、冲突、校验失败 | 副本冲突后仍自动发送，或未追平就清理 payload |
| 消息窗口稳定性 | Anchor 恢复失败、Delta revision 冲突、整窗复制次数 | 普通滚动跳底、丢窗口，或单消息触发全历史复制 |
| Mailbox 积压 | 最大深度、持续时间 | 超过容量且没有背压/落盘，或丢正式事件 |
| 持续聊天 | 30 分钟、2 小时内存和温度 | 持续增长、发热或明显掉帧 |
| 数据库写入 | 错误率和错误分类 | 关键写入失败后仍继续无保护发送 |

灰度自动停止条件必须包含：正式消息丢失率大于零、重复正式发送、已读水位回退、搜索错误定位、Barrier 失效、推送双提示、数据库恢复失败或账号数据串号。阈值由基线配置版本管理，阈值变更本身需要评审和审计。

### 19.6 Message Window、Row Delta 与视口保持

消息事实集合、内存消息窗口和 UI 当前可见区域是三个不同概念：

```text
Authoritative Facts
  可从 SDK / Cloud 恢复的正式消息事实

MessageWindowSnapshot
  当前加载到内存、允许 UI 消费的有界窗口

ViewportAnchor
  某个 View 当前看到的位置和像素偏移
```

推荐契约：

```text
MessageWindowSnapshot {
  scope
  windowRevision
  orderedRowKeys
  rowByKey
  oldestBoundary
  newestBoundary
  protectedRanges
}

MessageRowDelta {
  baseWindowRevision
  targetWindowRevision
  inserts
  updates
  removes
  moves
}

ViewportAnchor {
  viewInstanceId
  surfaceId
  rowKey
  pixelOffset
  capturedAtWindowRevision
}
```

发布规则：

1. `MessageCommitResult` 发布不可变 `windowSnapshot + rowDelta`；实现必须使用结构共享、分段列表、索引映射或等效机制，不能因单条实时消息重新复制全部历史；
2. `rowDelta.baseWindowRevision` 必须等于 View 当前 revision。若不一致，View 丢弃 Delta 并请求最新完整窗口引用，不能在旧列表上强行 patch；
3. Row Key 必须来自稳定身份：正式消息优先 `serverMsgId`，发送中消息使用 `operationId`，Overlay 使用命名空间化本地身份；禁止把列表下标作为 Key；
4. UI 在历史 prepend、around 加载、实时插入、撤回、删除和裁窗前捕获 `ViewportAnchor`，布局完成后按同一 `rowKey + pixelOffset` 做补偿；
5. 普通上拉历史只能 merge 到窗口，不能 replace 当前实时端、发送中消息或当前 View Anchor；
6. 裁窗必须保护当前可见区及缓冲区、搜索目标、未读线、发送中消息和正在播放/交互的消息。被保护范围解除后才能按预算驱逐；
7. 锚点消息被撤回、删除或因权限不可见时，按同一 revision 中最近的存活前邻居、后邻居顺序选择替代锚点；不能无条件跳到底部；
8. 多个 View 各自维护 ViewportAnchor，一个 View 的滚动和销毁不能修改另一个 View，也不能改变正式 MessageWindow；
9. 内存压力导致窗口缩小时，只能丢内存 Row 和派生媒体，不得删除 Coverage、Boundary、Tombstone 或正式恢复证据；再次滚动到被裁区域时按边界恢复；
10. 进程重启后是否恢复上次滚动位置属于产品能力；若选择恢复，持久化的只能是账号作用域稳定 Row Key 和有限偏移，不能保存列表下标或 Dart 对象引用。

会话列表仍只消费 `ConversationSummaryDelta` patch 目标行；聊天消息窗口消费 `MessageRowDelta`。两者都不得为一次消息提交触发全表重建和全列表排序。

## 20. 可观察性和安全

### 20.1 必须记录的指标

客户端：

- `event_inbox_lag_ms`；
- `mailbox_queue_depth`；
- `mailbox_overflow_count`；
- `writer_lease_conflict_count`；
- `writer_lease_takeover_count`；
- `stale_fencing_reject_count`；
- `ingress_sequence_conflict_count`；
- `commit_latency_ms`；
- `outbox_recovery_lag_count`；
- `outbox_recovery_conflict_count`；
- `viewport_anchor_restore_failure_count`；
- `row_delta_revision_mismatch_count`；
- `commit_revision_gap`；
- `stale_generation_reject_count`；
- `clear_epoch_reject_count`；
- `duplicate_event_count`；
- `duplicate_message_count`；
- `coverage_hole_count`；
- `history_page_latency_ms`；
- `history_source_mismatch_count`；
- `outbox_pending_count`；
- `outcome_unknown_count`；
- `send_ack_latency_ms`；
- `read_watermark_regression_count`；
- `summary_projection_mismatch_count`；
- `window_restore_failure_count`；
- `first_local_visible_ms`；
- `cloud_verified_ms`。

服务端：

- UserSig 签发成功率和延迟；
- IM 命令入队和重试；
- 幂等 Key 冲突；
- 腾讯 Server API 错误码；
- 回调验签失败和重复回调；
- 业务 Outbox 积压；
- 每用户、每群、每租户限流命中。

### 20.2 日志边界

允许记录：

- 脱敏会话 Hash；
- 事件类型；
- source、authority、proof；
- generation、epoch、revision；
- 消息数量；
- 安全指纹；
- cursor 和耗时；
- 错误码。

禁止记录：

- UserSig；
- 完整访问令牌；
- 私聊正文；
- 完整可搜索用户 ID；
- 本地媒体绝对路径；
- 银行卡、钱包和手机号等敏感业务字段。

### 20.3 身份隔离

后端区分：

```text
businessUserId
publicUserId
transportUserId
```

腾讯 IM 使用不可推断、不可直接搜索的 `transportUserId`。前端不能通过简单替换展示文本来解决 SDK 本地库中的身份暴露问题。

## 21. 自建后端 IM Gateway

自建后端的职责是统一业务命令和腾讯服务端 API，不是建立第二个普通消息正文库。

### 21.1 推荐模块

```text
im-gateway/
├── auth/
├── identity/
├── command/
├── tencent/
├── callback/
├── template/
├── idempotency/
├── outbox/
├── audit/
└── metrics/
```

### 21.2 服务端发送

业务服务统一发送内部命令：

```http
POST /internal/v1/im/messages
Idempotency-Key: <business-command-id>
```

响应 `ACCEPTED` 只能表示命令已经可靠入队，不代表腾讯已经最终投递。最终结果由 Worker、腾讯回调和幂等状态更新完成。

### 21.3 业务事务 Outbox

关键业务采用：

```text
业务事务
  ├── 更新订单/钱包状态
  └── 写入 im_command_outbox

事务提交后
  └── Worker 调用 IM Gateway
```

不能出现“业务成功但通知命令没有入队”。

### 21.4 服务端接口契约

#### UserSig 会话接口

```http
POST /v1/im/session
Authorization: Bearer <app-token>
```

响应至少包含：

```json
{
  "transportUserId": "opaque_transport_id",
  "userSig": "<opaque-secret>",
  "sdkAppId": 123456,
  "expiresAt": 1788000000,
  "sessionRevision": 18
}
```

规则：

- UserSig 只能由服务端生成；
- 客户端不能持有管理员密钥；
- 同一账号刷新请求必须单飞；
- `sessionRevision` 变小的响应不能覆盖当前会话；
- 过期前刷新，刷新失败进入受控重试；
- 退出登录后清理本地会话凭据和旧账号 generation。

#### IM 命令状态机

```text
Created
  → Accepted
  → Dispatching
  → ProviderAccepted
  → DeliveryConfirmed
  → ReadConfirmed

ProviderAccepted
  → FailedTerminal

Accepted / Dispatching
  → RetryableFailure
  → Dispatching
```

状态语义必须严格区分：

- `ProviderAccepted`：腾讯接口接受了发送请求或返回成功；
- `DeliveryConfirmed`：只有腾讯提供明确的对端投递证明时才允许进入；
- `ReadConfirmed`：只有明确的已读回执才能进入，不能由发送成功推断；
- `FailedTerminal`：明确的业务拒绝或不可恢复失败。

`ACCEPTED` 只表示命令已经可靠落入服务端 Outbox，不表示腾讯已最终投递。`ProviderAccepted` 也不能直接命名为 `Delivered`。每个命令使用业务幂等 Key，Worker 重试不能产生第二个业务命令。

#### 腾讯回调安全

回调必须：

1. 校验来源、签名、SDKAppID 和时间窗口；
2. 用腾讯事件 ID 或稳定指纹幂等去重；
3. 拒绝过期重放；
4. 原始回调保存到受限审计区并设置保留期；
5. 快速返回腾讯，复杂业务异步处理；
6. 记录验签失败、重复、延迟、重试和终态失败。

#### 机器人、桥接和搜索

- 机器人和桥接客户端必须通过同一 IM Gateway，不得绕过身份映射和审计；
- 服务端搜索只返回经过权限过滤的定位元数据；
- 云端搜索索引属于派生索引，不能取代腾讯消息事实；
- 搜索结果必须携带会话、正式消息身份、时间/Seq 和索引版本；
- 用户退群、消息撤回或权限变化后，搜索结果必须重新鉴权；
- 索引重建期间允许降级为腾讯查询，但不能返回未授权结果。

## 22. 分阶段迁移方案

### Phase 0：冻结行为和建立基线

任务：

- 盘点所有 `setMessageList`；
- 盘点所有历史 API 和 SDK Listener；
- 盘点所有 SQLite 写入口；
- 盘点所有 `unawaited` 的消息、会话、未读和恢复任务；
- 为每个入口标记领域、来源、写入对象和 generation；
- 建立单聊、群聊、发送、已读、最后一条消息、历史加载基线；
- 建立大群和弱网性能基线。

退出条件：所有正式写入入口都有责任归属，没有无法解释的入口。

### Phase 0.5：统一身份和事件契约

任务：

- 建立 `AccountScopedConversationKey`；
- 建立 `EventEnvelope`；
- 建立标准 SDK Result；
- 建立 Event Inbox 的幂等字段；
- 建立 SDK 能力基线矩阵，区分 `SDK_DOC_SUPPORTED`、`CONSOLE_ENABLED`、`CODE_INTEGRATED`、`RUNTIME_VERIFIED`、`PARTIAL` 和 `PLATFORM_UNAVAILABLE`；
- 建立 `viewInstanceId + surfaceId + viewSessionGeneration` 页面身份；
- 先不改变 UI，只把事件标准化。

退出条件：同一会话的所有来源可以映射到同一个 scope，且事件可以判断是否过期。

### Phase 1：Mailbox 和 Writer 影子运行

任务：

- 所有事件进入 Mailbox；
- 建立账号级 WriterLease、fencing token 和 MessageCore Owner；
- 后台 Isolate / 原生任务统一改为 DurableIngressGateway，只追加 Inbox / Wake Record；
- Writer 只计算不发布正式 UI；
- 旧结果和新结果对比数量、身份、顺序、Coverage、摘要和未读；
- 为每种差异记录原因，而不是只记录“不一致”。

退出条件：核心场景新旧结果一致，剩余差异都有明确业务解释；多 Isolate / 多 Engine 同时唤醒时只有一个有效 Owner，旧 token 不能提交。

### Phase 1.5：持久化提交和恢复

任务：

- 建立 Event Inbox；
- 账号级和 scope 级入口序号在 Inbox 事务中原子分配；
- 建立 Commit Journal；
- 建立 Projection Checkpoint；
- 明确崩溃点恢复顺序；
- 完成发送中、历史中、清空历史中、切账号中的重启恢复。

退出条件：任意提交阶段进程退出后，重启不会丢正式消息、发送结果、撤回和已读水位。

### Phase 2：历史链路切换

任务：

- 本地首屏、云端 latest、older、newer、gapFill 都进入 Writer；
- 建立 `MessageWindowSnapshot + MessageRowDelta`，历史 prepend 保持普通 ViewportAnchor；
- 删除 SDK MessageService 的本地发送列表拼接职责；
- 云端空结果按 proof 处理；
- Coverage range 可持久化、可恢复。

退出条件：本地有数据、新设备空库、云端超时、历史和实时并发场景均不丢、不重、不清窗。

### Phase 3：实时和排序切换

任务：

- 只保留一个 SDK 消息 Listener；
- 实时事件进入 Mailbox；
- 群 Seq 缺口统一补洞；
- 增加 `advanceTo` 和 `rebaseFromAuthoritativeHistory`；
- 自发消息不再绕过 Writer。

退出条件：大群洪峰、历史并发、跨设备同步和自发消息场景不重排错误、不静默丢消息。

### Phase 4：Outbox 和媒体切换

任务：

- 统一文字、图片、视频、语音的 `operationId`；
- 增加 `OutcomeUnknown`；
- 完成主 Outbox 与加密恢复副本的 `DISPATCH_INTENT`、差异恢复和 GC 协议；
- 完成退出登录、切账号、被踢下线期间 Pending Outbox 的冻结与同账号恢复；
- 统一乐观气泡和正式接管；
- 删除重复媒体发送管线；
- 验证多图反向完成和进程重启恢复。

退出条件：不存在双气泡、空气泡、成功后重进消失和重复正式发送。

### Phase 5：已读、摘要和会话切换

任务：

- `MessageCommitResult` 生成摘要 Delta；
- ReadCoordinator 管理水位；
- 会话列表只接受目标行 Patch；
- ConversationMutationCoordinator 从 shadow 切为正式写入者；
- 旧 SDK 快照不再覆盖本地有效水位。

退出条件：聊天页、会话预览、未读、撤回最后一条消息和草稿状态一致。

### Phase 6：Overlay 和 UI Row 切换

任务：

- 通话气泡迁移到 CallStore + Overlay；
- 群提示迁移到 GroupTipStore + Overlay；
- 时间线、未读线和加载行迁移到 Row Builder；
- 合成内容不再写入正式消息列表。

退出条件：合成行不影响正式去重、排序、Coverage 和最后一条消息。

### Phase 7：关闭旧旁路并灰度

任务：

- 正式 UI 只消费 Snapshot；
- 页面不再直接调用 SDK 历史、Listener 和 `setMessageList`；
- Adapter 以外不再直接调用腾讯消息 API；
- 旧旁路改为只读或删除；
- 只保留一个进程启动级回滚开关。

退出条件：静态扫描只剩允许列表中的适配入口，运行时没有第二个正式 Store。

### 22.1 可直接执行的工作包

下面的工作包是本方案的实施拆分。每个工作包都必须独立可回滚、独立验证；未达到退出条件不得进入下一个依赖工作包。目标文件路径是建议归属，实施前必须先搜索当前仓库是否已有同职责实现；如果已有实现，扩展该实现，不得再创建第二套同名状态源。

| 工作包 | 对应阶段 | 主要当前入口 | 主要交付物 | 依赖 |
| --- | --- | --- | --- | --- |
| `IM-00` 入口账本与基线 | Phase 0 | `chat.dart`、`conversation.dart`、`conversation_sync_service.dart`、TUIKit 消息模型 | 写入口账本、事件来源表、测试账号基线、静态门禁脚本 | 无 |
| `IM-01` 领域契约与能力注册表 | Phase 0.5 | 现有 `message_commit_coordinator.dart`、`message_history_coverage.dart` | `EventEnvelope`、canonical scope、`OutgoingIdentityContract`、`HistoryProof`、Capability Registry | `IM-00` |
| `IM-02` SDK Adapter 与唯一事件入口 | Phase 0.5/1 | `message_service_implement.dart`、Web message manager、各页面直调 SDK | 统一历史、搜索、发送、已读、草稿、置顶、免打扰 Adapter；唯一 Listener | `IM-01` |
| `IM-03` Durable Ingress、Inbox 与 WriterLease | Phase 1/1.5 | Flutter 主 Isolate、Push、原生任务、启动恢复 | `DurableIngressGateway`、账号/会话 Mailbox、Lease/fencing、入口序号和 Event Inbox | `IM-01` |
| `IM-04` 消息 Writer 正式化 | Phase 1/2/3 | `tui_chat_global_model.dart`、`message_reconciliation_writer.dart` | 单一 Message Writer、群 Seq Rebase、`MessageCommitResult`、Snapshot/Delta | `IM-02`、`IM-03` |
| `IM-05` Journal、Projection 和 Outbox 恢复 | Phase 1.5/4 | 现有本地数据库、发送/重试/清理服务 | Inbox、Commit Journal、Projection Checkpoint、主 Outbox + 加密恢复副本 | `IM-03`、`IM-04` |
| `IM-06` 历史 Coverage 与搜索定位 | Phase 2 | `conversation_sync_service.dart`、`tui_search_view_model.dart`、Web history loader | LOCAL/CLOUD 分流、Coverage、Barrier、云搜、`SearchJumpCommand`、`loadAround` | `IM-02`、`IM-04`、`IM-05` |
| `IM-07` 实时、推送和排序收口 | Phase 3 | `conversation_sync_service.dart`、Push 服务、`livekit_call_signaling.dart` | Chat Listener 单入口、Push 去重、群补洞、通知策略；保留独立通话信令命名空间 | `IM-03`、`IM-04` |
| `IM-08` Outbox 与多媒体发送收口 | Phase 4 | `chat_external_message_sender.dart`、失败重试、TUIKit separate model | 五类消息统一发送状态、`OutcomeUnknown`、媒体接管、反向完成和切账号恢复 | `IM-02`、`IM-05` |
| `IM-09` 已读、摘要和会话单写入 | Phase 5 | `conversation_mutation_coordinator.dart`、shadow bridge、`conversation_sync_service.dart` | ReadCoordinator、ConversationProjector、草稿/置顶/免打扰唯一写者 | `IM-04`、`IM-06`、产品 ADR |
| `IM-10` Overlay、Row 和页面只读化 | Phase 6 | `chat.dart`、`conversation.dart`、`call_bubble_insert_service.dart`、群提示服务 | `MessageRow`、Overlay Store、`MessageWindowSnapshot + RowDelta`、页面只消费 Snapshot | `IM-04`、`IM-09` |
| `IM-11` 旧旁路删除与灰度 | Phase 7 | 全仓静态扫描结果 | 删除/隔离旧入口、启动级回滚开关、灰度报告和灾难恢复记录 | `IM-05` 至 `IM-10` |

#### `IM-00` 入口账本与基线

1. 搜索并登记所有 `setMessageList`、`messageListMap` 写入、`getHistoryMessageList*`、`addAdvancedMsgListener`、SDK `sendMessage`、会话 Store/Notifier 写入和消息领域 `unawaited` 任务。
2. 对每个入口记录：文件、符号、调用方、账号作用域、会话 Key、事件类型、当前写入对象、是否正式事实、generation、是否允许保留以及替代入口。
3. 对 `livekit_call_signaling.dart` 单独登记为通话信令事件。它使用高级消息 Listener 不代表它可以与普通聊天消息共用去重、排序或 Message Writer；迁移时必须保留独立 `call-signaling` 命名空间。
4. 冻结以下基线：单聊/群聊首屏、上拉、回底、搜索定位、文本/图片/视频/语音/自定义消息发送、已读、草稿、置顶、免打扰、撤回、清空、切账号、推送点击和前后台恢复。

交付文件建议为 `docs/im-migration/00-entry-ledger.md` 和 `docs/im-migration/00-baseline.md`。这两个文件只保存脱敏路径、哈希、数量、版本、错误码和原始证据引用，不保存 UserSig、正文或媒体绝对路径。

**退出门禁**：账本覆盖全部正式写入口；每个 `addAdvancedMsgListener` 都能说明属于聊天、通话或其他命名空间；`flutter test` 和 `flutter analyze` 的现状结果已记录；所有基线场景都有可重复步骤和预期结果。

#### `IM-01` 领域契约与能力注册表

建议在 `lib/src/services/im/contracts/` 下归档以下类型，或并入仓库已有等价类型：

```text
account_scoped_conversation_key.dart
event_envelope.dart
outgoing_identity_contract.dart
message_mutation.dart
history_proof.dart
message_commit_result.dart
sdk_result.dart
sdk_capability_registry.dart
```

所有契约必须携带 `ownerUserId`、canonical conversation scope、账号/领域 generation 和事件命名空间。`EventEnvelope` 必须区分 Provider Seq 与 account/scope ingress sequence，不能用一个自增字段同时表示两种顺序。

能力注册表必须使用 17.4 的分层状态：官方文档和最高套餐支持的能力先登记为 `SDK_DOC_SUPPORTED`；控制台已开通后为 `CONSOLE_ENABLED`；Adapter 接通后为 `CODE_INTEGRATED`；真实环境证据完整后才为 `RUNTIME_VERIFIED`。Web 本地历史和 Web 本地搜索登记为 `PLATFORM_UNAVAILABLE`，不允许通过自建缓存把它们重新命名成本地 SDK 能力。

**退出门禁**：契约单测覆盖账号串线、旧 generation、重复 event、空会话 Key、C2C/群类型混用和未知 capability；没有任何契约依赖 `TUIChatGlobalModel` 或 Flutter 页面对象。

#### `IM-02` SDK Adapter 与唯一事件入口

目标是把腾讯 SDK 的调用和项目领域状态彻底隔离：

```text
Message / Conversation command
  → TencentMessageAdapter
  → Tencent SDK / Web SDK
  → SdkResult<T>
  → EventEnvelope
  → Account / Conversation Mailbox
```

Adapter 必须统一封装：

- Flutter 和 Web 的文本、图片、视频、语音、自定义消息发送；
- `cloudCustomData` 注入和正式消息读回；
- 原生 LOCAL/CLOUD 历史、Web 云端历史和 `isCompleted`；
- 原生本地搜索、原生/ Web 云端搜索及 Web 本地搜索降级；
- 原生群 `lastMsgSeq` 附近历史和 Web `msgID`/cursor 附近历史；
- C2C `c2cReadTimestamp`、群 `groupReadSequence`；
- 草稿、置顶和免打扰；
- SDK Listener、`onSyncMsgID`、发送 Future 和错误码。

Adapter 不得导入 `TUIChatGlobalModel`、`Chat`、`Conversation` 或任何页面状态类。`message_service_implement.dart` 当前的 `onSyncMsgID -> bindOutgoingSyncMsgId` 必须先改为发出带 `operationId`、`clientCorrelationId`、会话 scope 和账号信息的事件，正式绑定由 Writer 完成。

**退出门禁**：全仓 raw SDK 历史/搜索/发送/会话命令调用只有 Adapter 白名单允许；每种消息类型都有 `cloudCustomData` 注入测试；Web 的云端来源和 `isCompleted` 映射有单测；Adapter 错误返回使用枚举，业务层不解析错误字符串。

#### `IM-03` Durable Ingress、Inbox 与 WriterLease

实现账号级 `MessageCore Owner` 和 scope 级 Mailbox。主 Isolate、Push Isolate、原生后台任务和第二 Flutter Engine 都只能通过 `DurableIngressGateway` 追加最小事件或唤醒记录。

必须先在同一持久化事务中完成：幂等主键检查、账号级入口序号分配、scope 级入口序号分配和 Inbox 插入。Lease 接管使用比较并交换或等效事务；所有领域事务、Checkpoint 发布和 SDK Effect 派发前校验 fencing token。SQLite 物理单写不能替代逻辑 Lease。

**退出门禁**：并发唤醒只产生一个有效 Owner；旧 token 的提交被拒绝；入口序号无重复、无回退；Inbox 重放不会产生第二个可见业务顺序；页面关闭不会导致正式实时事件丢失。

#### `IM-04` 消息 Writer 正式化

以现有 `message_reconciliation_writer.dart` 的裁决逻辑为基础，把最终发布职责也收进 Writer。`TUIChatGlobalModel.setMessageList` 不再是独立事实写入口；在过渡期只能作为 Writer 的兼容发布器，并受白名单和单向调用约束。

Writer 处理顺序固定为：账号和 generation 校验、Barrier 校验、正式身份去重、群 Seq 缺口/重叠判断、Mutation 分类、Outbox 接管、Coverage 更新、摘要 Delta 生成、Snapshot/RowDelta 发布和 Journal 完成。回复、引用、转发、合并转发按 `OutgoingMessageCommand` 创建新消息；编辑、回应、回执、业务卡片、撤回和删除才是 `MessageMutation`。

**退出门禁**：历史、实时、发送、撤回和清空并发测试通过；同一正式 `msgID` 只出现一次；群补洞后能 Rebase；单聊不使用群 Seq；`MessageCommitResult` 同时供摘要、未读和 UI 使用；单条消息不复制全部历史 Row。

#### `IM-05` Journal、Projection 和 Outbox 恢复

先完成 Inbox、Commit Journal、Projection Checkpoint，再切换正式发送。Journal 至少支持 `PREPARED`、`METADATA_COMMITTED`、`PROJECTION_PUBLISHED`、`COMPLETED`，并对 Badge、应用内通知、声音/震动等副作用使用独立 effect ledger 和幂等 Key。

Outbox 必须实现主库与独立损坏域的加密恢复副本：双方都达到 `Prepared` 后才能生成 `dispatchAttemptId` 和 `DispatchIntent`；任一侧出现 `DispatchIntent`，恢复时只能查询、认领或进入 `OutcomeUnknown`，禁止自动补发；副本落后、checksum 冲突或状态反向时禁止发送和 GC。

**退出门禁**：在每个 Journal 阶段杀进程都能恢复；主库损坏、副本损坏、两者同时不可用均有明确结果；数据库磁盘满时不会产生无 Outbox 保护的 SDK 发送；低存储、加密密钥轮换和旧版本回滚测试通过。

#### `IM-06` 历史 Coverage 与搜索定位

聊天页面不再直接调用历史 API。`conversation_sync_service.dart`、归档历史服务、TUIKit 搜索 ViewModel 和 Web loader 都改为向 `MessageSearchService`/`HistoryCoordinator` 发命令。

首屏按平台分流：Android/iOS 先提交 SDK 本地窗口，再异步请求云端；Web 先提交 `cloudPending`，直接请求云端。所有结果进入同一个 Mailbox 和 Writer。搜索结果只能产生 `SearchJumpCommand`；目标消息正式存在、进入可见 Row、布局完成并绑定稳定 Row Key 后，才报告定位成功。禁止 `_beginHistoryWindowReplace` 或 `replace: true` 覆盖当前实时和 Outbox 窗口。

**退出门禁**：本地有数据、新设备空库、云端超时、云端空结果、Web 无本地历史、云搜索引不可用、群 Seq 缺口、撤回/删除和权限变化测试通过；搜索失败不会静默跳最近消息；Web 云搜结果重新鉴权。

#### `IM-07` 实时、推送和排序收口

普通聊天消息只保留一个 SDK Advanced Message Listener，并将实时、Push、点击通知和历史回查送入同一消息身份去重边界。通话信令仍可使用独立 Listener，但必须使用独立 `eventNamespace = call-signaling`，不能把通话事件当作普通消息事实。

Push 只负责唤醒和提示；当前会话不显示系统通知，其他会话不产生系统通知/Banner 双提示，徽标只从正式未读投影派生，来电进入优先级通道，不被大群历史阻塞。

**退出门禁**：Listener 重复注册检测通过；Push 和 SDK 实时重复只产生一次正式消息和一次通知决策；前后台、冷启动、点击通知、网络重连和来电并发测试通过。

#### `IM-08` Outbox 与多媒体发送收口

统一文字、图片、视频、语音、自定义消息的 `operationId`、`clientCorrelationId`、`messageKind`、`payloadFingerprint` 和状态机。媒体准备、上传、SDK 发送、`onSyncMsgID`、实时回执、历史认领都必须由同一操作串联；页面不得再创建第二个乐观气泡。

SDK Future 超时、回执乱序、回执先于 Future、断网、进程被杀、多图反向完成和切账号期间晚到回执全部进入同一 Outbox 状态机。无法证明唯一正式身份时保持 `OutcomeUnknown`，给用户人工处理入口，禁止自动重发。

**退出门禁**：没有双气泡、空气泡、成功后重进消失和重复正式发送；多图顺序、字节、质量、上传协议和失败重试语义不变；切到 B 账号后 A 的晚到事件不污染 B，重新登录 A 可继续认领。

#### `IM-09` 已读、摘要和会话单写入

`ConversationMutationCoordinator` 在通过产品 ADR 后从 shadow 过渡为正式 Conversation Writer。`conversation_mutation_shadow_bridge.dart` 的 `authoritativeSdkCommitEnabled`、`upsertBatchOverride` 和兼容回退必须按阶段关闭，不能长期同时保留两条正式写路径。

ReadCoordinator 只接受已读意图并推进单调水位；SDK 已读上报是异步副作用。草稿、置顶和免打扰通过已确认的 SDK API 执行，但其跨设备语义必须分别由 ADR 决定；任何字段不得由 DeviceSync 和 SDK 双写。

**退出门禁**：旧 SDK 会话快照不能复活未读；最后一条消息、未读、撤回最后一条消息和草稿一致；置顶/免打扰失败回滚；同一字段只有一个正式写入者。

#### `IM-10` Overlay、Row 和页面只读化

通话气泡、群提示、时间线、未读线、加载行和发送中状态都使用各自 Overlay/Row 命名空间。`call_bubble_insert_service.dart`、群提示服务和页面中的 `setMessageList` 兼容路径必须迁移为 Overlay 或 Writer 事件，不能进入正式历史边界、Coverage 或最后一条消息。

消息窗口发布 `MessageWindowSnapshot + MessageRowDelta`，页面只消费快照和增量。历史 prepend、实时插入、撤回、删除和裁窗前后保持 `ViewportAnchor`；多 View 各自拥有 anchor；revision 不匹配时请求最新窗口，不在旧列表上强行 patch。

**退出门禁**：Overlay 不污染正式消息数量和摘要；普通滚动不跳底；搜索目标和发送中消息受保护；单条消息不触发全表排序；双 View、裁窗和锚点恢复测试通过。

#### `IM-11` 旧旁路删除与灰度

按照 23.1 静态门禁重新扫描：`setMessageList`、`getHistoryMessageList`、`addAdvancedMsgListener`、`messageListMap` 写入、raw SDK send/history/search/read/command 调用、整窗 replace、完整 Row 列表复制和领域 `unawaited`。

每个保留入口必须登记白名单、调用方向、责任人和删除版本。灰度顺序为自动化测试账号、内部账号、小会话量账号、大群账号、5%、20%、50%、100%。回滚只能在进程启动时整体切回旧链路，不能出现新链路写消息、旧链路写摘要的半回滚。

**最终退出门禁**：静态扫描只剩 Adapter、唯一 Listener 和明确的只读兼容入口；自动停止条件没有触发；回滚、Outbox、Coverage、Watermark、Journal 和跨账号恢复演练全部留有证据。

### 22.2 工作包依赖与执行顺序

```text
IM-00
  ↓
IM-01 ───────────────┐
  ↓                  │
IM-02 ─→ IM-03 ─→ IM-04 ─→ IM-05
                         ├─→ IM-06 ─→ IM-09
                         ├─→ IM-07
                         └─→ IM-08
IM-04 + IM-09 ─→ IM-10
IM-05 + IM-06 + IM-07 + IM-08 + IM-09 + IM-10 ─→ IM-11
```

执行原则：

1. `IM-00` 和 `IM-01` 只建立事实、契约和基线，不改变正式 UI 行为；
2. `IM-02` 先收口 Adapter 和事件，旧入口暂时保留但必须进入白名单；
3. `IM-03`、`IM-04` 先影子计算，再让 Writer 获得正式发布权；
4. `IM-05` 完成后才允许切换有副作用的发送和恢复；
5. `IM-06`、`IM-07`、`IM-08` 必须在消息 Writer 已可幂等提交后分别迁移历史、实时、Outbox；
6. `IM-09` 需要产品 ADR；SDK 有 API 不能替代跨设备产品决定；
7. `IM-10` 最后处理页面和合成行，避免 UI 重构掩盖事实链路问题；
8. `IM-11` 只有在自动化、真机、性能、故障和灰度证据完整后执行。

### 22.3 代码边界和明确停止条件

本次客户端重构的代码边界是当前仓库的 `lib/`、`third_party/tencent_cloud_chat_sdk`、`third_party/tencent_cloud_chat_uikit`、`test/` 和必要的 `tool/`。第 21 章的 IM Gateway 只有契约和客户端调用边界；没有提供后端仓库路径前，不实施服务端代码、数据库迁移、回调处理或腾讯管理员 API。

任何实施者遇到以下情况必须停止并记录，不得自行猜测：

- 本地 override 的 SDK、TUIKit、Push 插件版本与 17.4 记录不一致；
- 官方文档与当前 SDK 方法签名或平台实现不一致；
- `cloudCustomData` 在任一消息类型无法随正式消息历史读回；
- 发现第二个模块仍然需要直接写正式消息、摘要或未读；
- 无法区分普通聊天 Listener 与通话信令 Listener；
- 主库和恢复副本无法唯一判断 SDK 是否已被调用；
- 产品 ADR 未决定草稿、已读、置顶/免打扰的跨设备语义；
- 实施需要修改本节列出的客户端边界之外的后端或原生工程，且没有对应工作包批准。

## 23. 迁移门禁和回滚

### 23.1 静态门禁

必须能执行并得到明确允许列表：

```text
搜索所有 setMessageList 调用
搜索所有 getHistoryMessageList 调用
搜索所有 addAdvancedMsgListener 调用
搜索所有 messageListMap 写入
搜索所有 ConversationStore / Notifier 写入口
搜索所有消息领域 unawaited 异步任务
搜索所有后台 Push Isolate / 原生后台任务 / Flutter Engine 入口
搜索所有 SDK sendMessage 调用和 Outbox 状态写入口
搜索所有完整 MessageRow 列表复制、replace 和全量排序入口
```

在仓库根目录执行以下静态扫描；每次迁移阶段都必须保存输出，结果为零不代表“没有问题”，而是必须核对是否漏扫。Phase 7 前允许列表之外不得出现正式写入：

```powershell
rg -n --glob '*.dart' 'setMessageList\s*\(' lib third_party
rg -n --glob '*.dart' 'getHistoryMessageList(V2)?\s*\(' lib third_party
rg -n --glob '*.dart' 'addAdvancedMsgListener\s*\(' lib third_party
rg -n --glob '*.dart' '_messageListMap\s*\[' lib third_party
rg -n --glob '*.dart' '\.sendMessage\s*\(|create(Text|Image|Video|Sound|Custom)Message' lib third_party
rg -n --glob '*.dart' 'replace\s*:\s*true|List<MessageRow>|List<V2TimMessage>' lib third_party
rg -n --glob '*.dart' 'unawaited\s*\(' lib third_party
```

每条扫描结果登记 `entryId`、文件、符号、命名空间、正式/影子/只读状态、允许保留阶段和计划删除版本。消息 SDK 的 raw 调用只允许出现在 Adapter 白名单；通话信令 Listener 必须登记 `call-signaling` 命名空间，不得因“只保留一个聊天 Listener”而误删通话能力。

代码工作包完成后至少执行：

```powershell
flutter test
flutter analyze
git diff --check
git status --short
```

如果全量 `flutter analyze` 仍受历史问题影响，必须记录基线错误、执行本次变更相关文件的定向分析，并证明新增错误数为零；不能把历史失败直接宣称为本次工作包通过。真机/Web Proof、进程杀死、网络切换和控制台配置验证不能由静态命令替代。

门禁要求：

- 页面不能直接调用 SDK 历史 API；
- 页面不能直接注册 SDK Listener；
- 页面不能直接写正式消息列表；
- Adapter 不能反向依赖 UI；
- 只有 Writer 能提交正式消息；
- 只有当前 WriterLease 的 fencing token 能提交领域事务和派发 SDK Effect；
- 后台 Handler 只能调用 DurableIngressGateway；
- 入口序号只能由持久化事务分配；
- 只有 ConversationProjector 能提交摘要；
- 只有 ReadCoordinator 能推进有效已读水位；
- UI 消息列表只能消费 `MessageWindowSnapshot + MessageRowDelta`，旧整窗 replace 只能存在于明确的只读兼容白名单。

### 23.2 灰度顺序

```text
自动化测试账号
  → 内部测试账号
  → 小会话量账号
  → 大群和大消息量账号
  → 5%
  → 20%
  → 50%
  → 100%
```

### 23.3 自动停止条件

出现以下任一情况，立即停止扩大灰度：

- 正式消息数量少于 SDK 可恢复结果且无法解释；
- 发送成功后重进会话消失；
- 历史页覆盖实时消息；
- 群 Seq 缺口补洞后仍然扩大；
- 本地裁窗后无法恢复；
- 出现两个有效 MessageCore Owner、旧 fencing token 提交成功或入口序号重复/回退；
- Outbox 主库与恢复副本冲突后仍发生自动发送；
- 退出登录或切账号后发生旧账号 payload 发送、展示或串号；
- 普通历史 prepend、撤回或裁窗导致视口无条件跳底或丢失当前窗口；
- 未读水位回退；
- 最后一条消息和聊天内容不一致；
- 出现双气泡或重复正式发送；
- 切账号发生数据串号；
- 回滚需要新旧两条链路同时写入。

### 23.4 回滚原则

- 开关只能在进程启动时确定；
- 影子模式可以双计算，但只能有一条链路发布正式状态；
- 回滚必须整体回到旧链路；
- 不允许新链路写消息、旧链路写摘要这种半回滚；
- 新增数据库字段必须兼容至少一个旧版本；
- 回滚前必须演练 Outbox、Coverage、Watermark 和 Journal 的兼容读取。

## 24. 测试与验收清单

### 24.1 消息完整性

- 连续收发 500 条，数量、身份、顺序一致；
- 历史加载期间接收实时消息；
- 历史加载期间发送消息；
- 多个历史请求乱序完成；
- SDK 重复返回同一页；
- 云端空结果、超时和临时错误；
- 本地 20 条、云端 1000 条；
- 新设备本地完全为空；
- 群消息缺 Seq 后补齐；
- 单聊不使用群 Seq 连续性；
- 本地 Overlay 不污染正式消息边界；
- 清空历史后旧请求结果被拒绝。

### 24.2 发送可靠性

- 发送中杀进程后恢复；
- SDK 回执晚于历史响应；
- SDK 回执早于发送 Future 完成；
- 发送 Future 超时进入 `OutcomeUnknown`；
- 查询到正式消息后完成接管；
- 文本、图片、视频、语音、自定义消息分别验证 `cloudCustomData` correlation 写入、正式消息读回和历史读回；
- Android、iOS、Web 分别验证同一 `OutgoingIdentityContract` 的字段一致性；
- SDK 已接受但 Future 超时，按 correlation、SDK localID、serverMsgID、会话、时间窗和 payload 指纹查询；
- 只有唯一候选允许接管，相同文本、文件名或时间不能认领；
- 正式消息没有 correlation 或候选不唯一时保持 `OutcomeUnknown`，禁止自动重发并要求用户手动决定；
- 多图反向完成；
- 断网发送和网络恢复；
- 重复点击重试；
- 媒体文件缺失明确失败；
- 同一 `operationId` 不重复正式发送；
- 在主库 Prepared、副本 Prepared、两侧 `DISPATCH_INTENT`、SDK 调用前后和结果回写阶段分别杀进程；
- 主库和恢复副本状态反向、`dispatchAttemptId` 不一致、checksum 不一致时停止自动发送；
- 任意一侧已经出现 `DISPATCH_INTENT` 时，重启后只查询和认领，不自动补发；
- 恢复副本写入失败时不调用 SDK，副本追平前不清理 payload。

### 24.3 已读和会话

- 前台打开后旧 SDK 快照不复活未读；
- 已读水位之后的新消息正常增加未读；
- 单聊最后一条消息实时更新；
- 群聊最后一条消息实时更新；
- 撤回最后一条消息后摘要正确；
- Overlay 不成为正式最后一条消息；
- 草稿不被旧快照覆盖；
- 置顶和免打扰失败回滚正确。

### 24.4 生命周期

- A/B 会话快速切换；
- 切账号后旧请求晚到；
- 清空历史时请求正在进行；
- 前后台快速切换；
- UserSig 过期和刷新；
- SDK 重连和云端补偿并发；
- 被踢下线后重新登录；
- 进程在 Journal 每一个阶段退出；
- 前台 Flutter Engine、后台 Push Isolate 和原生后台任务同时唤醒，只产生一个 MessageCore Owner；
- Writer Lease 过期接管时旧 Owner 的后续提交被 fencing token 拒绝；
- 多来源同时写 Inbox 时账号级、scope 级入口序号无重复、无回退；
- 退出登录时存在 `Prepared`、`DISPATCH_INTENT`、`Sending`、`OutcomeUnknown` 和 `Acknowledged` 操作；
- 切到 B 账号后 A 账号晚到回执只进入 A 的隔离操作记录，不污染 B 的消息和会话；
- 重新登录 A 后恢复未决认领，不重复发送；明确清除 A 数据时执行 `AbandonedByUser` 和审计规则。

### 24.5 性能和压力

- 大群离线消息批量到达不逐条刷新；
- 会话列表高速滚动时消息写入不打断手势；
- 聊天首帧不等待云端、群成员和媒体全量任务；
- 30 分钟持续聊天内存窗口稳定；
- Mailbox 队列达到上限时不丢正式事件；
- 图片只解码当前屏和受控预取范围；
- 回前台不会启动多个全量恢复链路；
- 普通上拉历史 prepend 后当前首个可见 Row 和像素偏移稳定；
- 实时插入、撤回、删除和窗口裁剪时 ViewportAnchor 不无条件跳到底部；
- 锚点消息消失时按前邻居、后邻居规则稳定回退；
- `rowDelta.baseWindowRevision` 不匹配时丢弃旧 Delta 并恢复最新窗口；
- 单条实时消息提交不会复制全部历史 Row 或触发全表排序；
- 同一会话双 View 独立保持锚点和滚动位置。

### 24.6 SDK 能力与平台验收

- 17.4 列出的官方文档能力按 `SDK_DOC_SUPPORTED` 纳入实现范围，不能再以套餐等级为理由阻塞排期；
- Android、iOS、Web 分别执行本地历史、云端历史、本地搜索、云端搜索和 around 测试；
- 文本、图片、视频、语音、自定义消息分别验证 `cloudCustomData` 写入、正式消息读回、历史读回和超时认领；
- 草稿、置顶、免打扰、C2C 已读和群已读分别验证 SDK 调用、结果归一化、失败回滚和账号隔离；
- 记录 SDK 版本、TUIKit 版本、Push 插件版本、套餐、权限、网络状态和原始返回；
- 证明 Web 的 `searchLocalMessages` 不得被标记为本地搜索；
- 验证 Web 不支持 `lastMsgSeq` 时的有界方向分页降级；
- 验证 `isFinished`、Web `isCompleted`、实际来源和网络退化的映射；
- 验证消息超过云端保留期、无权限、撤回、群 Seq 缺口和重复请求；
- SDK 升级后执行旧/新 Proof 影子对比，未通过时只能使用 `partial`。

### 24.7 异常、推送与数据生命周期

- 磁盘已满、SQLite 损坏、事务超时、schema 迁移中杀进程；
- 回滚到旧版本并验证 `minimumReadableVersion`；
- Android Keystore、iOS Keychain 或账号数据密钥丢失；
- Push 与 SDK 实时消息重复到达；
- App 被杀后点击通知冷启动；
- iOS VoIP Push 与 IM 消息反向到达；
- 当前聊天会话不弹系统通知，其他会话不出现系统通知和 Banner 双提示；
- 本地清空后第二台设备仍保留历史，服务端删除在确认前不能伪装成功；
- 同一会话在宽屏两个视图同时显示，互不误伤页面代数；
- 腾讯云历史超过保留期；
- 用户退群后搜索旧结果重新鉴权；
- 系统时间被修改；
- 低存储空间下媒体发送、媒体副本清理和 Outbox 恢复；
- 主 SQLite 损坏但恢复副本完整、恢复副本损坏但主库完整、两者同时不可用三类恢复演练；
- 普通缓存清理不会删除 Pending Outbox、恢复副本、Barrier 或必要密钥；
- 退出登录和切账号不会误删其他账号恢复副本或解密其 payload。

## 25. 当前代码迁移映射

这一节按当前仓库代码做“现状 -> 目标”的对照，不代表这些目标已经完成切换。某些模块已经有 shadow coordinator、commit plan 或过渡桥，但正式 writer、UI 读取和旧旁路仍然并存，必须结合第 28 节一起看。

| 当前模块 | 当前问题 | 目标归属 |
| --- | --- | --- |
| `message_service_implement.dart` | SDK 查询、发送缓存和 UI 状态混合 | `TencentMessageRepository` + Adapter |
| `tui_chat_global_model.dart` | 消息内存、排序、裁窗、实时和页面通知混合 | Writer / MessageStore / SnapshotPublisher |
| `message_reconciliation_writer.dart` | 已有裁决能力，但入口仍未完全收口 | 保留为唯一正式 Message Writer |
| `message_history_coverage.dart` | 已有范围模型，证明等级和持久化还需补强 | CoverageCoordinator + Range Store |
| `mobile_async_commit_guard.dart` / `message_commit_coordinator.dart` | 已有页面、会话和操作代数，但共用提交防护，不能作为正式消息领域 Envelope | 拆分 DomainGeneration、ViewSessionGeneration、HistoryRequestGeneration、SendOperationGeneration |
| `inbound_reorder_buffer.dart` | 已有群消息缓冲，缺少权威 Rebase | GroupOrderingCoordinator |
| `conversation_sync_service.dart` | Listener、同步、写库和预览混合 | SDK Event Ingress + ConversationProjector |
| `conversation_mutation_coordinator.dart` | 当前仍是 Shadow | 正式 Conversation Single Writer |
| `call_bubble_insert_service.dart` | 本地通话气泡进入消息列表 | CallStore + LocalOverlay |
| `group_local_tips_service.dart` | 本地群提示进入消息列表 | GroupTipStore + LocalOverlay |
| `archive_im_local_persist_service.dart` | 归档逻辑改写内存正式身份 | Archive Adapter 只提交事件 |
| `tui_search_view_model.dart` | 已有 SDK 本地/云端搜索，但缺少应用级搜索覆盖和恢复协议 | MessageSearchService |
| `tui_chat_separate_view_model.dart::_beginHistoryWindowReplace` | 搜索 around 仍可能整窗 `replace: true`，会覆盖实时消息和发送中气泡 | 删除正式替换旁路，改为 `SearchJumpCommand + Message Mailbox + Writer merge` |
| `notification_settings_service.dart` / `push_notification_router.dart` / `push_msgkey_dedup.dart` | 推送配置、去重和路由分散，可能与 SDK 实时消息重复提示 | NotificationCoordinator |
| `ios_apns_push_service.dart` / `android_jpush_service.dart` / `local_system_notification_service.dart` | 平台通知执行和业务通知策略混合 | Platform Notification Adapter + NotificationCoordinator |
| `app_badge_sync_service.dart` / `incoming_call_push_handler.dart` / `push_focus_service.dart` | 徽标、来电和点击聚焦没有统一副作用语义 | BadgeProjector + CallPushPriorityLane + NotificationTapRouter |
| `device_sync_service.dart` | 跨设备同步字段边界未完全声明，可能与 SDK 双写 | DeviceSyncCoordinator + State Ownership Matrix |
| `pubspec.yaml` / `third_party/tencent_cloud_chat_sdk` | SDK、TUIKit、Push 版本和平台能力需要基线证明 | SDK Capability Registry + Proof Policy |
| `message_anchor.dart` / `tim_uikit_chat_history_message_list.dart` | 已有定位锚点和滚动能力，需要严格精确命中 | MessageLocator + RowAnchor |
| `chat.dart` | 页面直接读写消息和承担编排 | MessageService Facade + Snapshot 消费 |

## 26. 最终完成标准

只有全部满足以下条件，才认为数据源重构完成：

- [ ] 所有消息事件经过统一 Adapter 和 EventEnvelope；
- [ ] EventEnvelope 已区分 `accountGeneration`、`domainGeneration`、`viewSessionGeneration`、`historyRequestGeneration` 和 `sendOperationGeneration`；
- [ ] 页面关闭不会拒绝正式实时消息；
- [ ] 实时消息允许创建会话壳，历史分页不能绕过 Tombstone 重建会话；
- [ ] 每个 scope 持久化 `HistoryVisibilityBarrier`，Writer 和搜索都执行历史可见下界；
- [ ] C2C Barrier 不比较 opaque `msgID` 字符串，不用秒级时间戳单独裁决边界；
- [ ] 每个账号、每个会话只有一个 Mailbox；
- [ ] 正式消息只有一个 Writer；
- [ ] 每个账号运行时只有一个持有效 Lease 的 MessageCore Owner，旧 Owner 的提交会被 fencing token 拒绝；
- [ ] 后台 Push Isolate、原生任务和第二 Flutter Engine 只能追加 Durable Ingress，不直接写正式领域状态；
- [ ] 账号级和 scope 级入口序号在 Inbox 插入事务中原子分配，重启、并发和 Lease 接管后不重复、不回退；
- [ ] 页面不直接调用 SDK 历史、Listener 和正式消息写入口；
- [ ] SDK MessageService 不再拼接 UI 发送状态；
- [ ] 正式消息、Outbox、Overlay 和 MessageRow 已分离；
- [ ] MessageMutation 只修改编辑、回应、回执、业务卡片、撤回和删除等已有消息状态；
- [ ] 回复、引用、转发和合并转发使用 `OutgoingMessageCommand` 创建新消息，不修改原消息；
- [ ] 会话 Key 统一使用账号作用域 canonical Key；
- [ ] Coverage 具备 cursor、range、proof、generation 和 epoch；
- [ ] 群消息补洞完成后可以权威 Rebase；
- [ ] 搜索结果可以按正式身份打开目标会话并精确定位；
- [ ] 搜索定位只在目标消息实际可见后报告成功；
- [ ] 搜索失败、权限不足和请求未知状态不会静默跳到最近消息；
- [ ] Outbox 支持 `OutcomeUnknown` 和杀进程恢复；
- [ ] 主 Outbox 与加密恢复副本具备 `dispatchAttemptId`、`DISPATCH_INTENT`、差异恢复矩阵和保守防重协议；
- [ ] 恢复副本位于主 SQLite 之外的独立损坏域，副本落后或冲突时禁止自动重发和 GC；
- [ ] 退出登录、切账号和被踢下线时 Pending Outbox 按发送边界冻结，晚到回执不污染新账号；
- [ ] 已读水位单调且不会被旧 SDK 快照复活；
- [ ] 最后一条消息由 MessageCommitResult 派生；
- [ ] 会话协调器已经从 Shadow 切换为唯一正式写入者；
- [ ] Event Inbox、Commit Journal 和 Projection Checkpoint 可恢复；
- [ ] Inbox durable 行明确代表 `PREPARED`，Commit Journal 具备 `METADATA_COMMITTED`、`PROJECTION_PUBLISHED`、`COMPLETED` 和崩溃恢复协议；
- [ ] Journal 副作用使用独立 effect ledger 和幂等 Key；
- [ ] 客户端 Journal 只管理 Badge、本地通知、应用内通知和 best-effort 声音/震动，远程 Push 由服务端/OS 负责；
- [ ] Event Inbox 按事件类型保存恢复模式和可解析引用，不依赖 `payload_hash` 重放；
- [ ] Event Inbox 主键包含 `owner_user_id + event_namespace + event_id`；
- [ ] EventEnvelope 具备账号级、scope 级入口序号，并区分 Provider Seq 与入口序号；
- [ ] 发送状态使用 `ProviderAccepted`、`DeliveryConfirmed`、`ReadConfirmed`，不把 API 成功称为 Delivered；
- [ ] OutgoingIdentityContract 能在发送超时后按 correlation 和正式身份安全认领，无法唯一确认时保持 `OutcomeUnknown`；
- [ ] Proof 保存 SDK Adapter、SDK Capability 和 Proof Policy 版本；
- [ ] SDK 正式消息可按最后确认边界和 Coverage 重叠读取恢复，发送/媒体/命令可从持久化数据恢复；
- [ ] `clearEpoch` 不会阻断发送终态和正式身份接管，只控制当前投影可见性；
- [ ] `postClearObservedMsgIDs` 有数量和时间上限，证明后压缩为范围/版本，超限不会静默丢保护信息；
- [ ] 大群压力下正式事件不丢，UI 更新可批量合并；
- [ ] MessageCommitResult 使用 `MessageWindowSnapshot + MessageRowDelta`，单消息提交不复制全部历史 Row；
- [ ] 普通历史 prepend、实时插入、撤回、删除和裁窗均保持 ViewportAnchor，不会无条件跳底或丢窗口；
- [ ] 多 View 分别维护锚点，Row Delta revision 不匹配时可以安全恢复最新窗口；
- [ ] Event Router 具备控制、实时、历史和后台投影优先级通道；
- [ ] SDK 能力矩阵已按 Android、iOS、Web、SDK 版本、套餐权限和真实账号完成验证；
- [ ] NotificationCoordinator 已统一 Push、SDK 实时消息、去重、前后台策略、点击路由和来电优先级；
- [ ] `CommitDurability` 能区分 `durable`、`sdkRecoverable`、`volatile` 和 `failed`；
- [ ] 数据库迁移、回滚、GC、加密和密钥轮换均有可恢复协议；
- [ ] DeviceSync 与腾讯 SDK 对同一字段不存在未定义双写；
- [ ] 草稿、已读、置顶/免打扰在进入多设备实施阶段前均已通过对应产品 ADR；
- [ ] 每个发布版本都有 SDK 能力探测、Proof 影子对比和灾难恢复演练；
- [ ] Mailbox 支持懒创建、空闲驱逐、活跃上限和状态持久化；
- [ ] MessageSearchService 支持本地/云端搜索、索引覆盖、权限校验和 `loadAround`；
- [ ] 搜索 around 不再调用 `_beginHistoryWindowReplace`，不再使用 `replace: true` 覆盖正式消息列表；
- [ ] 旧旁路已经删除或进入只读适配白名单；
- [ ] 回滚开关完成真实演练；
- [ ] 自动化测试、真机回归、性能基线和灰度指标全部通过。

## 27. 推荐的第一步

不要先修改具体的已读、最后一条消息或群排序逻辑。第一步应当只做一件事：

> 建立当前所有事件和写入口的完整账本，并用统一的 `AccountScopedConversationKey + EventEnvelope + Mailbox` 把它们映射起来。

完成账本后，再以消息提交链路为第一切入点，依次完成：

```text
事件收口
  → 消息 Writer 正式化
  → Commit Journal
  → 历史 Coverage
  → Outbox
  → 已读和摘要
  → Overlay / UI Row
  → 关闭旧旁路
```

这样可以先解决“谁有权写”的问题，再解决“怎么显示”和“怎么优化”的问题，避免继续在多个状态源上叠加补丁。

## 28. 当前代码补充说明（按项目路径）

> 这一节不是新目标，而是把“当前代码已经做到哪里、还差哪一口气”说清楚。它用于把上面的架构稿落到真实仓库路径，避免把影子协调器误认为正式切换。

### 28.1 已经落地的基础设施，但还不等于正式切换

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_commit_coordinator.dart`
  - 已有 `MessageMutation`、`MessageMutationBatch`、`CommittedMessageFacts`、`onCommittedBatch` 和 `onCommittedFacts`。
  - 现在的职责仍是收束一次提交边界，不是写数据库，也不是派生会话摘要，更不是替代消息列表写入。
  - 它已经把“提交结果”和“事实派生”拆开了，但宿主还没有把这个拆分真正接到正式 writer 上。

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/message_reconciliation_writer.dart`
  - 已经把历史、实时、tombstone、覆盖层和 `clearEpoch` 串成一个一致的消息裁决器。
  - 但文件注释已经说明：最终 `records` 仍由调用者通过现有 message-list writer 发布，所以它现在还是裁决器，不是完整的持久化出口。

- `lib/src/services/conversation_local/conversation_mutation_coordinator.dart`
  - 目前仍是 `shadowOnly = true` 的 Phase-1/2 shadow coordinator。
  - 它会串行化事件、保存 shadow snapshot、判定重复和过期，但明确不写数据库，也不通知 UI。

- `lib/src/services/conversation_local/conversation_mutation_shadow_bridge.dart`
  - `authoritativeSdkCommitEnabled = true` 时，SDK 会话变更已经走 `prepareSdkConversationCommits -> commitCoordinatorSdkUpsertPlansBatchResult`。
  - `commitSnapshotConversations`、`commitSdkHydratedConversations`、`commitCreatedConversation` 都收口到同一条提交链。
  - 这说明会话侧已经具备正式提交路径的雏形，但 shadow bridge 仍在扮演过渡层，不是唯一真源。

- `lib/src/services/conversation_local/conversation_sync_service.dart`
  - `_commitSdkConversationBatch` 会先读取 durable state，再提交 coordinator plan，最后才回传 `ConversationSdkCommittedBatch`。
  - 这一步比早期直接 upsert 更接近正式写入，但代码里仍保留 `upsertBatchOverride`、kill switch 和兼容回退，因此还没有完全关掉旧路径。

### 28.2 仍然存在的正式写入口和旁路

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
  - `setMessageList` 仍会做合并、去重、排序、裁窗、记签名、增量修正和通知。
  - `bindOutgoingSyncMsgId` 仍直接改 `_messageListMap`，把 SDK 分配的正式 `msgID` 绑定到 UI 全局模型里。
  - 这说明消息领域的最终状态仍然不是唯一 writer，`TUIChatGlobalModel` 还是正式状态出口之一。

- `third_party/tencent_cloud_chat_uikit/lib/data_services/message/message_service_implement.dart`
  - `getHistoryMessageListV2` / `getHistoryMessageList` 仍把 `messageListMap` 和 `sendingMessage` 拼在一起返回。
  - `sendMessage` 的 `onSyncMsgID` 还直接回调 `TUIChatGlobalModel.bindOutgoingSyncMsgId`。
  - 也就是说，SDK repository、发送中态和 UI 全局模型仍然缠在一起，离“只发事件、不直接写状态”还有一段。

- `lib/src/conversation.dart` 和 `lib/src/chat.dart`
  - 页面层还在直接读取 `ConversationLocalStore`、调用 `ConversationSyncService`、触发 `refreshConversationItem`、`patchConversationLastMessage`、`syncNextPage` 和历史清理。
  - 这不是坏事，但它说明页面编排、投影刷新和数据提交还没有彻底分离，页面仍承担一部分协调责任。

### 28.3 正式切换门禁

1. 必须列明哪些模块只是 shadow / adapter，哪些模块已经取得正式 WriterLease 并成为唯一 writer。
2. 消息侧切换前必须明确 `setMessageList`、`bindOutgoingSyncMsgId`、发送缓存拼接和历史 merge 的替代路径与删除版本。
3. 会话侧切换前必须明确 `ConversationMutationCoordinator` 何时从 `shadowOnly` 变为正式写入者，以及哪些兼容回退会被删除。
4. 后台 Isolate / 多 Engine 入口、Outbox 恢复副本、退出登录未决发送和 MessageWindow 锚点协议必须先通过故障测试，不能只完成接口定义。

### 28.4 建议把本 MD 的阅读顺序改成

- 先看第 25 节，知道当前模块如何映射到目标架构。
- 再看本节，知道哪些能力已经存在、哪些只是过渡。
- 最后看第 27 节，按“事件收口 -> 消息 Writer 正式化 -> 会话 / 历史 / Outbox / 摘要 -> 关闭旧旁路”的顺序开工。

## 29. ADR 与未决事项登记

架构结论、产品语义和 SDK 能力必须分开管理。`Adopted` 表示架构方向已经确定，不代表代码已经完成；`Proposed` 在指定阶段前必须得到产品和技术共同结论；`SDK_DOC_SUPPORTED` 表示官方文档和项目方确认的最高套餐支持，可以进入实现；`EvidencePending` 只表示控制台配置或运行时 Proof 仍未完成。

| ADR | 主题 | 状态 | 实施门禁 |
| --- | --- | --- | --- |
| ADR-001 | Outbox 使用单主库 + 加密恢复副本 | `Adopted` | Phase 1.5 前实现双写状态机、差异恢复和 GC 测试 |
| ADR-002 | Runtime WriterLease + fencing | `Adopted` | Phase 1 正式发布前完成多 Isolate / 多 Engine 争抢与接管测试 |
| ADR-003 | 退出登录与切账号 Pending Outbox | `Adopted` | Phase 3/4 前完成状态迁移、晚到回执和账号隔离测试 |
| ADR-004 | MessageWindowSnapshot + RowDelta + ViewportAnchor | `Adopted` | Phase 2/6 前完成历史 prepend、裁窗和双 View 测试 |
| ADR-005 | Draft Sync | `Proposed` | Phase 5 前确定是否跨设备、冲突和删除语义 |
| ADR-006 | Read Sync | `Proposed` | Phase 5 前取得 SDK 能力证据并确定权威水位 |
| ADR-007 | Conversation Preference Sync | `Proposed` | Phase 5 前确定置顶/免打扰的唯一权威和失败回滚 |
| CAP-001 | `cloudCustomData` correlation 三端读回 | `SDK_DOC_SUPPORTED` / `EvidencePending` | 官方发送和消息格式已支持；Phase 4 前仍需完成文本、图片、视频、语音和自定义消息的三端运行时 Proof |
| CAP-002 | 云历史、搜索、保留期与 Proof 映射 | `SDK_DOC_SUPPORTED` / `EvidencePending` | 官方能力和最高套餐已确认；Phase 0 仍需记录目标 SDKAppID 的插件、保留配置、权限、网络和真实账号 Proof |
| CAP-003 | 草稿、置顶、免打扰、C2C/群已读 API | `SDK_DOC_SUPPORTED` / `EvidencePending` | 官方 API 已支持；Phase 5 前完成 Adapter 接入、失败回滚、单写入者和跨设备语义验证 |

每条 ADR 必须记录 owner、评审日期、关联代码路径、灰度开关、回滚方式和证据链接。状态变化需要更新本表和对应章节，不能只在聊天记录或口头评审中决定。

### 29.1 项目方已确认项与实施前仍需提供项

以下内容已经确认，不需要再作为 SDK 能力问题反复讨论：

- 当前腾讯 IM 为最高套餐；
- 17.4 所列官方文档明确支持的能力均纳入实施范围；
- Flutter 文本、图片、视频、语音、自定义消息发送均按统一 `cloudCustomData` 协议设计；
- Flutter 原生本地历史、本地搜索、云端历史、云端搜索、草稿、置顶、免打扰和已读 API 均可排期实现；
- Web 云端历史和云端搜索可排期实现；Web 本地历史、本地搜索和群 `lastMsgSeq` 仍按官方平台限制处理。

为了不靠猜测进入真实切换，实施者在相应工作包开始前只需要取得以下项目输入：

| 输入 | 用于哪个工作包 | 具体要求 |
| --- | --- | --- |
| 目标 SDKAppID 和环境标识 | `IM-00`、`IM-02`、`IM-06` | 只需非敏感标识；UserSig、管理员密钥不得写入仓库或文档 |
| 控制台能力截图或导出记录 | `IM-00`、`IM-06`、`IM-09` | 云端搜索插件/索引、历史保留、消息权限、已读/会话配置；记录配置时间和环境 |
| 测试账号与测试数据安排 | `IM-00`、`IM-05`、`IM-08` | 至少两个可互发账号、一个群、Android/iOS/Web 运行环境；凭据只通过安全渠道提供 |
| 产品 ADR 结论 | `IM-09` | 草稿、已读、置顶/免打扰是否跨设备同步，冲突、删除、离线恢复和退出账号语义 |
| 自建后端仓库路径 | 第 21 章 | 需要实施 Gateway、UserSig、回调或服务端 Outbox 时提供；没有路径则只做客户端契约 |
| 真机和 Web 验收窗口 | `IM-06` 至 `IM-11` | 网络切换、进程杀死、磁盘/数据库故障、Push 冷启动和多账号切换的现场时间 |

上述输入不改变 SDK 支持结论，只决定何时可以把对应能力从 `SDK_DOC_SUPPORTED` 推进到 `CONSOLE_ENABLED`、`CODE_INTEGRATED` 和 `RUNTIME_VERIFIED`。缺少输入时可以继续做契约、影子和单元测试；不得伪造现场 Proof、保留期、云搜开通状态或跨设备产品语义。

### 29.2 文档使用规则

本文件是当前项目重构的设计基线。实施、Code Review、测试和灰度报告必须引用本文件的章节、工作包和能力状态；出现代码与文档冲突时，先按 22.3 停止条件记录差异，再决定更新代码还是提交 ADR，不允许通过临时 fallback 绕过唯一 Writer、Barrier、Outbox 或 Adapter 边界。
