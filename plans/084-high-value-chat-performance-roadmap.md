# Plan 084: 按收益收敛聊天与会话高频性能链路

## Status

- Priority: P0
- Effort: L
- Risk: HIGH
- Depends on: 080, 083
- Category: perf / correctness / tech-debt
- Planned at: commit `9f7c46e`, 2026-08-24

## Why this matters

当前最大性能成本来自四类高频路径：聊天消息整表提交、多图媒体发送、聊天页初始化并发、会话列表滚动生命周期。它们分别对应不同代码区域，但会共同竞争 Flutter 主 isolate、布局/绘制和原生 I/O。084 不新增第五套优化逻辑，而是规定唯一执行顺序和硬门禁，确保每一步都能证明消息、媒体、未读和滚动语义没有回归。

## Prioritized outcomes

| 顺序 | 目标 | 主要收益 | 依赖 |
|---|---|---|---|
| 1 | 080→077 消息提交快照与单写入协调 | 降低整表 revision、减少持续掉帧和重复气泡 | 080 |
| 2 | 078 多媒体唯一管线 | 消除多图发送前等待、重复 staging 和首帧解码峰值 | 077 |
| 3 | 079 聊天页阶段预算 | 缩短冷启动/首次进群可交互时间 | 080、076 |
| 4 | 083 会话列表滚动生命周期 | 修复列表完全不能滑、Tab 返回仍失效 | 061、063、072 |

## Current evidence

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart` 仍存在历史、媒体、撤回和通话路径的 `setMessageList`。
- `lib/src/chat.dart:5282-5301` 同时启动多个群资料/权限/业务网络任务。
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart:6488-6504` 同时创建 SDK 图片消息并探测本地尺寸。
- `lib/src/widgets/conversation_feed/conversation_feed_sync_gate.dart` 在 cached/active Feed 之间切换，而两套 ListView 共享页面 ScrollController。

## Scope and ownership

本计划只负责编排，不直接改业务源码。执行时必须分别使用既有计划：

- 080/077：消息提交结果和单写入协调；
- 078：媒体唯一发送管线；
- 079：聊天页阶段预算；
- 083：会话列表滚动生命周期。

不要在 084 中创建新的全局 debounce、reload、fallback、第二历史源或第二媒体发送入口。

## Execution gates

### Gate 1: 消息语义

执行 080 后再执行 077。必须通过实时+历史并发、发送中状态、撤回、删除回滚、媒体 adoption、未读和排序测试。任何消息丢失、顺序改变或发送中状态被历史覆盖，停止后续阶段。

### Gate 2: 媒体内容

执行 078 前确认 077 的提交 snapshot 可被媒体 pipeline 消费。图片 1/4/9 张、HEIC、iCloud 未下载、视频混选、取消、失败重试都必须保持字节、压缩质量、payload、顺序和单 worker 语义。

### Gate 3: 首帧交互

执行 079 时，首帧只依赖历史和输入框；Profile 验证首次安装、暖启动、长历史群和键盘打开。post-frame 不得包含同步大 JSON、整表扫描、文件头读取或图片解码。

### Gate 4: 滚动可用性

083 必须验证 cached/active 切换时 ScrollController 恰好一个 position，Tab 连续切换后仍可拖动；不得用关闭虚拟列表、整页重建或无条件 `jumpTo` 通过验收。

## Verification commands

- `flutter test test/chat_row_local_message_commit_test.dart test/outgoing_image_bubble_dedupe_contract_test.dart test/message_ordering_test.dart` → 全部通过。
- `flutter test test/conversation_feed_scroll_lifecycle_test.dart` → 全部通过。
- 运行既有 chat-open、媒体、历史分页、Slidable、生命周期定向测试 → 全部通过。
- `git diff --check` → 通过。
- 真机 Profile 对比 `history_merge_ms`, `set_message_list_ms`, `image_decode_ms`, `keyboard_layout_ms`, `scroll_hitch`；任何指标恶化超过基线阈值停止。

## STOP conditions

- 需要改变腾讯 SDK 历史来源、分页参数、消息 payload 或未读规则；
- 需要提高 iOS PhotoKit/上传并发；
- 需要新增旁路 reload、防抖或 fallback 才能通过测试；
- 无法区分同步提交和异步提交的状态边界；
- Flutter 测试或真机 Profile 无法取得可比较结果。

## Maintenance notes

完成后应删除已经不可达的旧媒体路径和直接整表提交入口。后续新增消息、媒体或 Feed 功能必须接入既有协调器和阶段预算，不得在页面组件中启动无代次、无取消的 Future。
