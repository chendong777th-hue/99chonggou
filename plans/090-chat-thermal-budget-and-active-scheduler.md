# Plan 090: 长驻聊天页与大消息量热负载治理

> 这是性能根治计划，不是继续叠加延时或防抖补丁。先建立真机 Profile 基线，再以页面活跃度统一裁决轮询、历史恢复、媒体解码、解析和持久化预算。任何消息语义、排序、未读、草稿、媒体或通话回归立即 STOP。

## Status

- **Priority**: P0
- **Effort**: L / 多阶段
- **Risk**: HIGH
- **Depends on**: 052、079、089 Phase 0；不得绕过 066–070 的 SDK 消息权威边界
- **Category**: performance / architecture / thermal / tests
- **Planned at**: commit `9f7c46e`, 2026-08-24

## Why this matters

长时间停留在聊天页时，页面仍可能同时运行群直播/游戏/资料轮询、历史恢复与补页、回执写入、头像和媒体预取、图片解码、SQLite/SDK 同步以及自定义消息解析。消息较多时，每次事件还可能触发整表合并、排序、签名、通知和大量气泡重建。这些工作分别不一定超时，但叠加后会持续占用 CPU、I/O、内存带宽和 GPU 纹理解码，表现为发热、掉帧、滑动迟滞和电量快速下降。

当前高风险入口包括：`lib/src/chat.dart` 的周期任务与 post-open enrichment；`third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart` 的周期/回执/通知任务；`third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart` 的历史恢复、`setMessageList`、自定义消息解析和媒体相关重建；以及聊天气泡的图片/视频解码和缓存。计划不改变腾讯 IM SDK 的历史来源、分页方向、消息 payload 或媒体质量。

## Non-negotiable invariants

- SDK 仍是聊天实时消息和历史消息的业务事实源；不新增本地历史 fallback。
- 实时消息、发送中消息、失败消息、撤回/删除、未读和草稿不能丢失、重复或改变顺序。
- 群名/人数/公告/头像继续由统一群资料快照提供；暂停低优先级刷新不能覆盖已确认值。
- 图片/视频压缩质量、上传字节、SDK payload、失败重试、自动贴底和稳定 identity 不变。
- 通话 CallKit、麦克风、扬声器/听筒、LiveKit 音频状态不受调度降级影响。
- 页面不可见时只能暂停低优先级工作，不能暂停 SDK 必需的入站消息接收或持久化。

## Thermal budget model

为每个聊天页建立 `ChatActivityState`：

```text
ACTIVE       当前可见且用户交互
INTERACTING  键盘、滚动、发送或选择媒体中
COVERED      路由仍挂载但被弹层/底部页/相册覆盖
BACKGROUND   App 不在前台
DISPOSED     页面已退出
```

状态由 route visibility、AppLifecycle、键盘/媒体面板、滚动活动和当前 conversation generation 共同决定。所有周期任务必须带 `taskKey + generation + owner`，由一个 scheduler 注册；切换会话、覆盖、后台和 dispose 时统一取消或降级，禁止页面、ViewModel、RefreshBus 各自再开同类 Timer。

预算原则：ACTIVE 每帧只允许有限的可见区域工作；INTERACTING 只保留消息提交、发送状态和必要回执；COVERED 停止图片预取、群资料轮询和低优先级解析；BACKGROUND 仅保留 SDK/系统要求的同步；DISPOSED 不允许任何回写。

## Execution phases

### Phase 0 — 真机基线与热负载证据

在首次安装、暖启动、长历史群、图片密集群、连续收发、键盘打开、相册覆盖、后台恢复和长驻 30 分钟场景采集 Profile/Instruments：CPU、GPU、hitch、内存/纹理、温度、电量、网络请求、SQLite 写入和定时器数量。

固定指标：`chat_cpu_active_percent`、`message_merge_per_minute`、`set_message_list_per_minute`、`custom_parse_per_minute`、`image_decode_per_minute`、`active_timer_count`、`network_refresh_per_minute`、`sqlite_write_per_minute`、`memory_cache_mb`。发布版默认关闭且不得记录正文、账号、群 ID 或 token。

**Gate**：没有真机 Profile 结果，不进入算法调整；先确认 052 基线和当前 089 写入者清单可复现。

### Phase 1 — 单一活跃度调度器

在页面 host 建立唯一 scheduler，复用 079 的 generation/lifecycle，不创建第二套生命周期。将群直播/游戏/群资料、在线 URL、头像预热、钱包/通话 enrichment、历史 recovery tail、贴纸和图片预取全部登记为有 key 的任务。

- 同一 key 单飞，重复触发只保留一次 latest 请求；
- 每个 generation 限制并发数和单任务超时，切换/退出立即取消；
- ACTIVE/INTERACTING/COVERED/BACKGROUND 使用不同预算；
- 只允许当前会话和当前 generation 提交结果；
- 记录取消、超时、跳过原因，便于验证没有隐性循环。

### Phase 2 — 消息提交降温

在 089 MessageStore/080 `MessageCommitResult` 边界上增加提交准入：内容、状态、媒体 URL、排序或窗口边界未变时不产生新的整表 revision；row-local 进度继续局部更新。历史合并必须保持连续窗口、分页方向和 live/outgoing 保留规则，不能用 latest-wins 代替合并。

将重复的 dedupe/sort/signature/partition 计算缓存到 Store 级快照；批量入站在一个提交中完成，避免每条消息都复制全历史列表。仅在结构确实变化时通知列表，且保留 unread/draft projection 的同步采样时刻。

### Phase 3 — 解码、缓存与媒体预算

以可见 viewport 和 frame budget 为准限制图片/视频解码并发；offscreen 预取在 COVERED/BACKGROUND 禁止，ACTIVE 只允许有界队列。继续使用现有 ResizeImage/cacheWidth/cacheHeight 和 stable identity，不改变压缩、上传和预览语义。

对 HEIC/iCloud、大图、视频首帧设置 admission 与取消策略；取消只丢弃尚未开始的低优先级解码，不删除已经创建的 SDK 消息或发送占位。验证纹理缓存上限、内存回收和长列表滑动，不以提高 iOS 上传并发换取表面速度。

### Phase 4 — 解析、回执和持久化批处理

自定义消息 JSON 只在 payload hash/parser version 未命中时解析；纯 JSON 解析可进入受控缓存或后台 isolate，SDK/PhotoKit 对象不得跨 isolate。回执、已读、SQLite 写入按会话和短窗口合并，但发送状态和用户可见结果必须及时提交。

### Phase 5 — 清理重复来源与回归

删除已被 scheduler/Store 接管的旧 Timer、重复 post-frame 回调和无效 legacy fallback。通过真机 30–60 分钟长驻、消息风暴、图片密集群、切后台/恢复、相册覆盖、通话进出和内存压力测试。对比 Phase 0，目标是降低持续 CPU、解码次数、整表提交次数、活跃 Timer 数和峰值内存，同时保持消息语义不变。

## Keep / drop conflict policy

**保留**当前可见会话、用户主动操作、SDK 明确事件、发送中/失败状态、撤回/删除和可唯一匹配的 stable identity。

**舍弃**页面已退出或 generation 过期的回调、覆盖/后台期间的低优先级轮询、offscreen 尚未开始的解码、相同快照的重复整表提交、无法改变可见结果的重复解析和重复持久化。

历史分页、撤回/删除、未读/草稿不能按简单 latest-wins 舍弃；必须由 MessageStore/ConversationStore 按 revision、窗口边界和身份合并。

## STOP conditions

- 无法取得真机 CPU/温度/内存/帧率基线；
- 需要改变 SDK 历史来源、分页参数、消息排序或内存窗口；
- 出现消息丢失/重复、顺序变化、未读/草稿回灌、媒体 payload 变化或通话音频异常；
- 不能证明每个 Timer/网络任务只有一个 owner；
- 取消任务后仍有旧 generation 写入当前页面；
- 以提高媒体并发、关闭必要 SDK 同步或无限增大缓存来掩盖热负载。

## Verification

- 单元/契约：状态转换、任务单飞、generation 取消、预算并发、无变化提交跳过、历史连续窗口、row-local 进度、解码 admission、解析缓存。
- 定向回归：现有 052、053、058–060、073–080、089 测试；并记录当前已知 IME 契约测试失败，不把失败伪装成通过。
- 真机：首次安装/暖启动、长历史、图片密集、连续收发、键盘/相册覆盖、后台恢复、通话进出、30–60 分钟长驻。

## Done criteria

1. 每个页面后台/覆盖/退出状态没有重复 Timer 或旧回调写入。
2. 长驻和大消息场景的持续 CPU、解码、整表提交、SQLite 写入和内存峰值均有基线对比并下降。
3. 消息、历史、未读、草稿、群资料、媒体和通话回归全部通过。
4. 计划范围内的 legacy 旁路已删除或有明确保留理由，且每个 Store 的写入 owner 可追踪。
