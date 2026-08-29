# Plan 080: 显式化消息提交结果与同步快照契约

## Status

- Execution: completed; synchronous `MessageCommitResult` snapshots and
  generation/token-bound delete rollback are in place and verified.
- Priority: P0
- Effort: M
- Risk: HIGH
- Depends on: 074, 076
- Category: correctness / tech-debt
- Planned at: commit `9f7c46e`, 2026-08-24

## Why this matters

077 不能直接把 `setMessageList` 改成异步按帧排队，因为当前调用者依赖它同步完成后立即读取结果。已确认的依赖包括 alias 暖窗迁移后立即读取数量、批量图片占位后立即读取 raw list、SDK adoption 后继续准备发送，以及删除后按原 index 回滚。若提交时序改变，会出现空占位、错误贴底、未读投影延迟或删除回滚错位。

## Current state

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart` 的 `setMessageList` 同时负责列表提交、revision/notify、in-flight outgoing 保留、memory window、unread projection 和 anchor。
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart:706-724` alias 迁移后立即读取 `rawMessageCount`。
- `:6308-6323` 批量媒体占位提交后立即读取 raw list、返回 optimistic IDs 并请求贴底。
- 删除路径先同步修改正式列表，再异步调用 SDK，失败时按提交前 index 回滚。

## Scope

In scope:

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
- 新增提交结果/快照契约测试

Out of scope: 延迟合并、消息来源、SDK 分页参数、会话列表、媒体编码和通话音频。

## Steps

1. 为同步提交返回不可变 `MessageCommitResult`，至少包含 committed list revision、raw count、首尾身份、memory-window 状态、unread projection 状态和是否发生结构变化。
2. 将 alias 迁移、媒体占位、adoption、删除回滚等调用点改为消费 result，而不是重新读取可能变化的全局 map；保留原有同步时序。
3. 为删除/回滚建立 commit token，回滚只允许匹配同一 generation 和 token，避免异步 SDK 失败覆盖新消息。
4. 为提交结果增加契约测试，覆盖空列表、短会话、内存窗裁剪、发送中消息保留、未读投影和重复提交。
5. 完成后再重新执行 077；077 才允许引入按帧合并，且必须以 result/snapshot 作为同步边界。

## Verification

- 现有消息排序、媒体 identity、历史分页和删除回滚测试全部通过。
- 新增测试断言提交后立即可获得稳定 result，且不需要再次读取全局列表。
- `git diff --check` 通过。
- 在没有执行 077 的情况下，消息首帧、占位 ID、删除回滚和未读投影行为与基线一致。

## STOP conditions

- 必须修改 SDK 来源或分页语义；
- result 无法完整表达 memory-window、unread 或 in-flight 保留状态；
- 需要把同步提交改成异步才能完成；
- 回滚无法绑定 generation/token。

## Maintenance notes

080 完成后，任何新消息 mutation 必须使用提交结果，不得在提交后依赖无版本保护的全局 map 重新采样。077 的按帧协调只能建立在该契约之上。
