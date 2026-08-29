# Plan 061: 建立聊天交互冻结的状态与性能回归基线

> **Executor instructions**: 本计划只建立可验证的诊断与回归基线，不直接改变聊天交互语义。先运行漂移检查；如果引用代码已变化，停止并报告。完成后更新 `plans/README.md` 状态。

## Status

- **Priority**: P0
- **Effort**: S–M
- **Risk**: LOW
- **Depends on**: none
- **Category**: tests
- **Planned at**: commit `9f7c46e`, 2026-08-23

## Why this matters

当前“正文点击/滑动无响应、键盘仍可用”可能来自三种不同机制：整树 `AbsorbPointer`、root Overlay 截获命中、或消息列表滚动锁；键盘动画还可能造成短时 UI 线程拥塞。没有统一的现场证据时，修一个路径容易掩盖另一个路径。本计划先把这些状态和关键耗时变成稳定日志，并补状态机测试，后续修复可以按真实触发源验证。

## Current state

- `lib/src/chat.dart:3882-4015` 启动 `_startOpenHistoryGate`，等待历史 hydrate、群 tip 合并和 `ChatHistoryOpenLayoutReady`。
- `lib/src/chat.dart:4225-4239` 使用 `FutureBuilder` 将整棵 `TIMUIKitChat` 包在 `AbsorbPointer(absorbing: !ready)` 中。
- `lib/src/navigation/orphan_overlay_guard.dart:1-80` 负责路由切换后的孤儿 overlay 清理。
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart:8461` 暴露 `shouldLockChatScrollForMediaPreview`。
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart:2441-2458` 在该锁为真时返回 `NeverScrollableScrollPhysics`。
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart:398-427` 和 `TIMUIKitTextField/tim_uikit_text_field_layout/narrow.dart:272-319` 响应键盘 metrics；`tim_uikit_text_field.dart:614-670` 触发 flush、贴底和多次 `jumpTo`。

现有测试可作为模式：`test/chat_history_open_layout_ready_test.dart`、`test/chat_page_controllers_test.dart`、`test/media_preview_chat_scroll_lock_contract_test.dart`、`test/chat_main_thread_perf_test.dart`。

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Drift | `git diff --stat 9f7c46e..HEAD -- lib/src/chat.dart lib/src/navigation/orphan_overlay_guard.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart` | no unexpected plan-scope drift |
| Tests | `flutter test test/chat_history_open_layout_ready_test.dart test/chat_page_controllers_test.dart test/media_preview_chat_scroll_lock_contract_test.dart test/chat_main_thread_perf_test.dart` | all pass |
| Analyze | `flutter analyze --no-fatal-warnings --no-fatal-infos lib/src/chat.dart lib/src/navigation/orphan_overlay_guard.dart` | no errors |

## Scope

**In scope:** the four source areas above, their existing diagnostic utilities, and new focused tests under `test/`.

**Out of scope:** message ordering, message rendering, keyboard language selection, media product behavior, server/API changes, and any unrelated existing worktree modifications.

## Steps

### Step 1: Define one diagnostic snapshot

Add a small immutable diagnostic record or equivalent structured event containing conversation ID, gate active/conversation key, gate elapsed time, layout-ready epoch, overlay cleanup state/depth, media preview lock flags, scroll physics lock, keyboard inset, and the triggering action. Reuse existing `ChatOpenPerfLog`, `ChatJitterDiag`, and `ChatMainThreadPerf` conventions instead of introducing a second logging format. Do not log message content or secrets.

**Verify:** `flutter analyze --no-fatal-warnings --no-fatal-infos <changed source files>` → no errors.

### Step 2: Emit bounded transition events

Emit events at gate begin/ready/timeout/cancel, route cleanup, overlay cleanup, media-lock begin/finish/fallback, and keyboard `goDownBottom` start/end. Include elapsed milliseconds and a reason enum; rate-limit repeated keyboard metrics so one animation does not produce unbounded logs.

**Verify:** `rg -n "gate_(begin|ready|timeout|cancel)|media_lock|go_down_bottom|overlay_cleanup" <changed files>` → every transition has a matching event; no message payloads are logged.

### Step 3: Add characterization tests

Add pure/contract tests for: gate timeout releases interaction eligibility; stale conversation keys cannot keep a new conversation locked; overlay cleanup is idempotent; media lock finish and fallback both release; keyboard transition coalescing emits one logical action per focus/metric burst. Model tests after the existing four test files listed above.

**Verify:** `flutter test <new test files> test/chat_history_open_layout_ready_test.dart test/chat_page_controllers_test.dart test/media_preview_chat_scroll_lock_contract_test.dart` → all pass.

## Done criteria

- [ ] Every lock source has a begin/end/timeout diagnostic.
- [ ] Diagnostics are bounded and contain no message text or secret values.
- [ ] New regression tests cover gate, overlay, media lock, and keyboard burst state transitions.
- [ ] Targeted analyze and tests pass.
- [ ] No files outside the declared scope are modified.

## STOP conditions

- Existing logging utilities cannot carry the required fields without changing unrelated logging contracts.
- A test requires a live IM SDK or real iOS keyboard; stop and report instead of adding network/device dependence.
- Any cited source location has drifted materially from the current-state description.

## Maintenance notes

Keep event names stable so future freeze reports can be correlated across iOS versions. Remove or downgrade verbose events only after a production reproduction confirms the source; do not remove the state fields used to distinguish overlay, gate, media lock, and UI-thread congestion.
