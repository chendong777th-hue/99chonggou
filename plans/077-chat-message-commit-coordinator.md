# Plan 077: 建立聊天消息单写入提交协调器

> Executor: 先做 drift check；只修改 Scope 文件。任何消息丢失、顺序变化、未读变化或媒体状态变化立即 STOP。

## Status

- Execution: completed; synchronous authoritative writes are preserved behind
  the 080 snapshot boundary, while presentation revisions are coalesced by the
  per-conversation coordinator.
- Priority: P0
- Effort: L
- Risk: HIGH
- Depends on: 074, 076
- Category: perf / tech-debt / correctness
- Planned at: commit `9f7c46e`, 2026-08-24

## Why this matters

聊天消息仍由历史分页、实时回调、发送回执、撤回删除、媒体 adoption 和通话记录多个入口直接调用 `setMessageList`。例如 `tui_chat_separate_view_model.dart:1301`, `3434`, `3609`, `6308` 都能触发整表提交；这会让一条消息产生多次全列表 revision，并放大滑动和解码压力。目标是建立唯一提交协调器，所有入口先提交 mutation，再由协调器按帧合并为一次可验证的列表变更。

## Current state

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart` 持有正式消息列表和 revision。
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart` 同时负责历史、发送、媒体、撤回和通话消息。
- 现有 074 行级更新必须保留；无法行级安全替换时才允许整表 fallback。
- `setMessageList` 仍被多个业务入口直接调用；不要改变 SDK 历史来源、分页方向、内存窗口或消息排序。

## Scope

In scope:

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
- 新增消息提交协调器及其单元/契约测试

Out of scope: SDK API、消息 payload、历史来源策略、未读规则、会话列表、媒体压缩质量、通话音频。

## Steps

1. 定义按 conversation ID 隔离的 mutation 类型：insert, replace-row, remove, history-window, reorder；每个 mutation 携带 stable identity、generation、来源和预期排序边界。
2. 将实时、发送、撤回、删除、通话和历史入口改为提交 mutation，不直接通知 UI。
3. 在一个 frame/microtask 窗口内合并 mutation：同一 stable identity 只保留最后状态；历史窗口和顺序变化优先级高于 row patch；无变化则跳过提交。
4. 将 074 的安全行级替换接入协调器，失败时执行现有整表 fallback，并记录 fallback reason。
5. 删除 Scope 内不再使用的直接 `setMessageList` 调用。

### 必须固定的 mutation 优先级

协调器不得按“最后到达者覆盖一切”合并。固定优先级为：历史窗口/排序变化 > 删除或撤回 > 消息内容或媒体 URL 更新 > 发送状态/进度。SDK 返回的本地/云端合并结果直接作为历史窗口输入，不得在协调器中再次选择历史来源、改变分页方向或重写 `lastMsgID`/`lastMsgSeq` 语义。

## Verification

- `flutter test test/chat_row_local_message_commit_test.dart test/outgoing_image_bubble_dedupe_contract_test.dart test/message_ordering_test.dart` → 全部通过。
- 新增测试覆盖实时+历史并发、发送回执+撤回、媒体 adoption、批量多 mutation 合并、排序变化 fallback。
- `rg -n "globalModel\.setMessageList"` 在 Scope 调用入口只剩协调器和明确的历史窗口 fallback。
- `rg -n "getC2CHistoryMessageList|getGroupHistoryMessageList|getHistoryMessageList"` 的调用参数和分页方向与改造前一致；协调器不新增第二历史源。
- `git diff --check` → 通过。

## STOP conditions

- 需要改变 SDK 消息来源或分页语义；
- 无法证明未读、草稿、发送中状态保持不变；
- stable identity 不唯一或 mutation 顺序无法确定；
- 需要修改会话列表或媒体编码协议。

## Maintenance notes

后续新增消息类型必须声明 mutation 类型和 identity 策略，不得直接调用 `setMessageList`。审查重点是合并顺序、generation 校验和 fallback 可观测性。
