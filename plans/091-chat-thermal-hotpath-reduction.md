# Plan 091: 聊天页五类热负载根治

> 目标是降低长时间停留在聊天页、消息量大和媒体密集场景下的持续 CPU/GPU/I/O 压力。先建立证据，再逐条收敛热路径；不通过延时堆叠、提高并发或关闭 SDK 同步来掩盖问题。

## Status

- **Priority**: P0
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: 052、079、089、090
- **Category**: performance / thermal / architecture / tests
- **Planned at**: commit `9f7c46e`, 2026-08-24

## Product invariants

- 腾讯 IM SDK 仍是实时消息和历史消息唯一业务来源；不改变分页方向、排序、内存窗口和历史恢复语义。
- 新消息、发送中/失败消息、撤回/删除、未读、草稿、媒体 stable identity 不得丢失或重复。
- 图片/视频压缩质量、上传字节、消息 payload、失败重试和预览行为不变。
- 通话 CallKit、LiveKit、麦克风、扬声器/听筒路由不受热负载调度影响。
- 群资料仍由统一快照提供；暂停低优先级刷新不能用旧缓存覆盖已确认值。

## Phase 0 — 建立五类热负载基线

真机 Profile 覆盖：首次进入、暖启动、长历史群、图片密集群、连续收发、长时间静置 30 分钟、键盘打开、相册覆盖、后台恢复和通话进出。

至少记录：

- `message_merge_ms/count`、`set_message_list_count_per_minute`、`list_revision_count`；
- `image_decode_ms/count`、视频首帧耗时、纹理/图片缓存峰值；
- `active_timer_count`、网络刷新次数、取消/超时任务数；
- `read_receipt_count`、SQLite 写入次数、SDK 同步次数；
- `custom_parse_count/cache_hit_rate`；
- CPU、GPU hitch、内存、温度、电量和页面 FPS。

发布版默认关闭，日志不得包含正文、账号、群 ID、token 或本地路径。没有真机数据不得进入后续算法调整。

## Phase 1 — 消息列表整表处理

### 根因

消息、回执、发送状态和历史恢复通过不同入口反复触发合并、去重、排序、窗口裁剪、签名和列表通知；即使可见内容未改变，也可能产生新的 revision 和气泡重建。

### 方案

以 089 MessageStore 和 080 `MessageCommitResult` 为唯一提交边界：

1. 同一会话同一 microtask/短窗口内合并 mutation；
2. 内容、状态、媒体 URL、窗口边界和排序均未变化时跳过整表 revision；
3. 上传进度、已读进度和行内状态走 row-local 更新；
4. 历史分页保持连续窗口合并，不使用 latest-wins；
5. dedupe/sort/window/signature 使用 Store 快照缓存，避免每个入口重复计算；
6. 仅结构变化才触发列表 partition 和全量通知。

### 必须舍弃

相同快照的重复提交、同一状态的重复回执、无法改变可见结果的重复通知。

### 必须保留

实时消息、发送中消息、撤回/删除、未读/草稿投影和前后分页边界。

## Phase 2 — 图片/视频解码与纹理缓存

### 根因

长列表同时创建多个图片解码任务，offscreen 预取和视频首帧会与滚动、布局和上传共用 CPU/内存带宽；缓存过大又会造成内存压力和反复回收。

### 方案

1. 只为 viewport 附近的媒体申请解码预算；
2. 解码并发按 activity state 和 frame budget 限制，ACTIVE 可有界执行，INTERACTING 降低预算，COVERED/BACKGROUND 停止 offscreen 解码；
3. 复用现有 `cacheWidth/cacheHeight`、ResizeImage 和 stable identity；
4. 视频首帧采用可取消、有界队列；只取消尚未开始的低优先级任务；
5. 建立纹理/图片缓存上限和淘汰指标，不改变媒体文件和上传 payload；
6. 发送占位和 SDK 消息不因解码失败被删除。

### 禁止

不直接把 iOS PhotoKit、FlutterImageCompress、腾讯 SDK 对象送进 isolate；不直接提高 iOS 上传 worker 数量。

## Phase 3 — 页面后台任务

### 根因

群直播、群资料、游戏状态、在线状态、钱包重试、头像/媒体预取和历史 tail recovery 存在多个 Timer、post-frame 和 delayed 回调；页面被覆盖或长期静置时仍产生网络、解析和 UI 通知。

### 方案

统一使用 090 scheduler 和 `ChatActivityState`：

- ACTIVE：允许必要资料刷新、可见媒体工作和消息提交；
- INTERACTING：只保留消息、发送状态、必要回执和用户当前操作；
- COVERED：停止轮询、头像/媒体预取、游戏和钱包 enrichment；
- BACKGROUND：只保留 SDK/系统要求的同步；
- DISPOSED：取消全部页面任务并拒绝旧 generation 回写。

每个任务必须有唯一 `taskKey`、owner、generation、超时和取消指标。删除重复 Timer 和页面旁路调用，不能用多个 coordinator 互相补偿。

## Phase 4 — 已读回执与本地持久化

### 根因

消息到达、打开页面、滚动和后台恢复可能分别触发已读、SQLite、SDK 同步和会话列表刷新，造成 I/O 与通知风暴。

### 方案

1. 以 conversation + message boundary 合并已读请求；
2. 相同或更旧的 read boundary 直接丢弃；
3. SDK 回执、SQLite 持久化和 UI 投影由对应 Store 串行提交；
4. 允许用户可见的未读清零及时更新，但将非关键镜像写入短窗口批处理；
5. 页面切换/退出后旧回执只能写入后台 Store，不能写当前页面。

### 必须保留

未读数、已读状态、退出后恢复和跨端 SDK 语义，不能为了降温停掉必要同步。

## Phase 5 — 自定义消息解析

### 根因

通话、钱包、群提示等 JSON 在消息列表重建、摘要解析和回执更新时重复解析，消息越多累计越明显。

### 方案

1. 使用 `conversation + stable identity + payload hash + parser version` 作为缓存键；
2. 命中时返回防御性副本，null 结果也缓存；
3. payload 或 parser version 改变才重新解析；
4. 纯 JSON 解析可进入受控缓存/后台 isolate，SDK、PhotoKit 和 Flutter 对象不得跨 isolate；
5. 通话实时状态、钱包远端状态和打开状态不缓存，只缓存纯解析结果。

## Phase 6 — 统一验证与删除旁路

完成前删除已被 Store/scheduler 接管的旧 Timer、重复通知和 legacy fallback，并完成：

- 五类单元/契约测试；
- 长历史消息风暴、连续收发、图片/视频密集、键盘/相册覆盖、后台恢复；
- 30–60 分钟真机长驻和通话进出；
- 与 Phase 0 对比 CPU、GPU hitch、温度、内存、解码、整表提交、回执和 SQLite 写入。

## Conflict policy

优先级固定为：当前用户操作与可见消息 > SDK 明确事件/回执 > Store 已确认快照 > 低优先级网络结果 > 本地旧缓存。低优先级工作可以暂停或舍弃；历史窗口、撤回/删除、未读/草稿不能按简单 latest-wins 覆盖。

## STOP conditions

- 没有真机基线却开始调并发或缓存；
- 消息丢失、重复、顺序变化、草稿/未读回灌；
- 媒体 payload、压缩结果、预览行为变化；
- 通话音频路由、CallKit 或 LiveKit 状态异常；
- 任务 owner 不唯一、旧 generation 仍能回写；
- 需要改变 SDK 历史来源、分页参数或关闭必要同步。

## Done criteria

五类热负载均有前后对比数据；长驻聊天页 CPU、媒体解码、整表 revision、后台刷新、SQLite 写入和峰值内存下降；所有消息、媒体、未读、草稿、群资料和通话回归通过；每个持续任务都能追溯到唯一 Store 或 scheduler owner。
