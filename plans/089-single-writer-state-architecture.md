# Plan 089: 移动端单一状态写入架构根治竞态

> **Executor instructions**: 这是架构迁移计划，不是新增防抖或 token 补丁。目标是减少写入者：SDK、网络、本地操作和页面回调只能产生事件；唯一 Store 负责归并、裁决和发布快照。每个阶段必须可回滚、可验证。任何消息丢失、顺序变化、未读/草稿变化、群资料错配、媒体重复、通话音频异常都必须 STOP。

## Status

- **Priority**: P0
- **Effort**: L / 多阶段
- **Risk**: HIGH
- **Depends on**: 080、086、087、088；保持 018、045、049、053、055、060、072、078、079、083、085 语义
- **Category**: architecture / bug / tech-debt / tests
- **Planned at**: commit `9f7c46e`, 2026-08-24

## Why this matters

当前状态由 SDK listener、网络请求、SQLite、UIKit ViewModel、页面 State、RefreshBus、Timer 和多个 coordinator 共同写入。086–088 的 guard 能阻止部分旧结果回写，但仍保留多写入者，因此只能降低风险，不能从根上消除冲突。根治目标是让每类业务状态只有一个写入者，UI 只订阅不可变快照，迁移完成后删除旧旁路和重复 fallback。

## Non-negotiable product invariants

- 腾讯 IM SDK 仍是聊天历史和实时消息的业务来源；不改变历史 API、分页方向、消息排序和内存窗口。
- 用户明确操作优先于旧缓存；SDK 明确回执优先于 preview；本地 SQLite 只作离线/首屏占位。
- 发送中的消息、自己刚发送的消息、撤回/删除状态和媒体 stable identity 不能丢失或重复。
- 草稿、未读、置顶、归档、免打扰的现有产品语义不改变。
- 群名、人数、公告、头像由一个统一群资料快照提供；旧缓存不能覆盖已确认的新值。
- 音视频默认路由、CallKit、麦克风发布、LiveKit 音频恢复语义不改变。
- 迁移期间允许 guard 记录和拒绝旧结果，但不允许用新的 fallback 再增加写入路径。

## Target architecture

```text
SDK listener / network / local user action / lifecycle
                         ↓ events only
                 Domain Store (single writer)
             validate generation + authority + identity
                         ↓ immutable snapshot
              UI / UIKit / page selectors (read only)
```

四个 Store 的唯一写入责任：

1. `MessageStore`：实时消息、历史分页、发送状态、媒体接管、撤回/删除、未读投影。
2. `ConversationStore`：会话排序、置顶、归档、免打扰、摘要、草稿投影和删除墓碑。
3. `GroupMetadataStore`：群名、人数、公告、头像、成员资格和 generation 快照。
4. `CallStore`：来电/去电、CallKit、LiveKit、音频路由、通话结果和气泡身份。

SQLite 仍可作为持久化介质，但不能继续被 UI、SDK listener 或网络回调直接写入；必须由对应 Store 串行提交。

## Authority and conflict policy

### 保留

- 同一账号、页面、会话和 operation generation 的当前事件；
- 用户明确完成的本地操作；
- SDK 明确事件或已确认回执；
- 可以唯一匹配 stable identity 的更新；
- 历史前后页能够证明相邻关系的窗口合并。

### 舍弃

- 账号退出、页面退出、会话切换后的旧事件；
- 同一 operation 的旧请求结果；
- 低权威缓存覆盖高权威值；
- 无法唯一匹配 stable identity 的猜测性替换；
- 不相邻、无法确认归属的历史窗口；
- 重复 callId、重复媒体 identity、重复 SDK 回执。

### 不适用 latest-wins 的场景

历史分页、消息撤回/删除和批量入站不能简单 latest-wins，必须由 Store 按 revision、窗口边界和 stable identity 合并。否则会丢消息或改变顺序。

## Migration phases

### Phase 0: 记录当前写入者并建立 characterization tests

为四个领域列出所有 UI、SDK、网络、SQLite、RefreshBus 和 Timer 写入点。为每个写入点记录 `source/event/authority/generation/target store`。在迁移前固定以下回归：历史分页、连续收发、离线恢复、草稿、未读、置顶/归档/免打扰/删除、群资料、媒体、通话。

**Verify**: 定向测试能在当前代码通过；若工具链无法运行，先修复测试环境，不能以静态检查替代行为门禁。

### Phase 1: 建立事件模型和 Store 接口

新增纯 Dart 领域事件与不可变快照，不接 UI。每个事件必须包含：账号、会话、generation、authority、stable identity、source、revision 和 payload hash。Store 暴露 `dispatch(event)`、`snapshot` 和可测试的 reducer；禁止 reducer 发网络请求。

**Verify**: reducer 单测覆盖旧事件拒绝、权威覆盖、重复幂等、分页窗口合并、撤回优先、会话切换隔离。

### Phase 2: MessageStore 单写入迁移

把 `TUIChatGlobalModel`/`TUIChatSeparateViewModel` 的历史、实时、发送、撤回、媒体回执写入统一 MessageStore；原模型只做适配器。所有 `setMessageList` 必须由 Store 提交结果调用。旧 direct write 入口加计数断言，迁移期间不得新增。

**Verify**: 消息顺序、发送中保留、stable identity、媒体双气泡、撤回、前后分页和未读测试全部通过；Instruments/日志确认同一事件只产生一次正式提交。

### Phase 3: ConversationStore 单写入迁移

把 SDK 分页、SDK changed/deleted、RefreshBus、本地置顶/归档/免打扰、草稿和删除墓碑统一改为 ConversationStore 事件。SQLite 由 Store 持久化；Notifier 只读 Store snapshot。删除墓碑必须在 SDK 晚到分页和重启恢复期间过滤。

**Verify**: 多来源乱序、快速操作、重启、前后台、删除后分页回灌、置顶/归档/免打扰和草稿恢复测试全部通过。

### Phase 4: GroupMetadataStore 单写入迁移

SDK 群资料事件、自建 REST 群列表、本地 SQLite、会话 showName、群成员分页和明确用户修改统一转为快照事件。UI、会话行和聊天 header 禁止旁路读 GroupLocalStore；只读 GroupMetadataStore snapshot。

**Verify**: 群名/人数/公告/头像一次性稳定更新；旧缓存不能覆盖远端；切群、退出、解散、被踢后旧 generation 不得回写。

### Phase 5: CallStore 单写入迁移

把 CallKit、LiveKit、CallResultRepository、通话历史刷新和 call bubble 插入统一转为 CallStore 事件。音频路由仍由现有 route service 执行，但其目标状态只能由 CallStore 发布。相同 callId 只能产生一个最终结果和一条气泡。

**Verify**: 多设备接听、拒接、超时、取消、前后台、CallKit didActivate、重连、蓝牙切换、通话结束后快速新拨号全部通过。

### Phase 6: 删除旧写入旁路

只有在 Phase 2–5 的测试和真机回归通过后，删除或禁用：页面直接写全局模型、SDK listener 直接写 SQLite、RefreshBus 直接触发全量刷新、群资料旁路读取、旧 preview fallback、重复 call bubble insert。086–088 的 guard 保留为边界校验和诊断，不再作为业务状态源。

**Verify**: 静态搜索旧入口为 0 或只剩明确的适配器；四个 Store 的写入计数与事件数一致；全链路回归通过。

## Scope boundaries

**In scope**: `lib/src/services/`、`lib/src/chat.dart`、会话/群资料/通话 Store、UIKit 消息适配器、对应测试和计划文档。

**Out of scope**: 服务端协议、腾讯 SDK 源码、消息 payload、媒体压缩参数、UI 布局、搜索查询和产品规则。

## STOP conditions

- 任何阶段需要让 UIKit vendor 反向依赖 App；
- 无法确定某字段的权威来源；
- Store reducer 需要发网络请求或依赖 Flutter BuildContext；
- 出现消息丢失、顺序变化、未读/草稿变化、群资料错配、媒体重复或通话无声；
- 测试工具链不可运行且没有真机/集成替代证据；
- 迁移需要同时保留两个会写正式状态的 Store。

## Done criteria

- [ ] 四个领域各只有一个正式写入者；
- [ ] UI 不直接写 SQLite/GlobalModel/SDK 状态；
- [ ] 所有异步事件都带 generation、authority 和 stable identity；
- [ ] 旧旁路和重复 fallback 已删除或变成只读适配器；
- [ ] 全部定向测试、真机回归和性能基线通过；
- [ ] 086–088 过渡代码不再承担业务写入职责；
- [ ] plans/README 状态更新，所有变更可独立回滚。

## Maintenance notes

未来新增消息类型、群资料字段或通话状态时，必须先增加领域事件和 reducer 测试，再接入 UI。代码审查重点是“是否出现第二个写入者”，而不是是否增加了更多防抖、Timer 或 fallback。
