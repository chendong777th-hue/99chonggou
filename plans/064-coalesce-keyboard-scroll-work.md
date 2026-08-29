# Plan 064: 合并键盘动画期间的贴底与消息刷新工作

> **Executor instructions**: 先运行漂移检查；本计划只优化键盘 metrics 到列表滚动的调度，不改变输入法语言、发送语义或未读语义。

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/061-chat-interaction-freeze-observability.md
- **Category**: perf
- **Planned at**: commit `9f7c46e`, 2026-08-23

## Why this matters

iOS 键盘动画会连续触发聊天页和输入栏的 metrics 回调。当前一次聚焦可能同时触发 inset rebuild、延迟消息 flush、未读清理、强制贴底和同帧/后两帧多次 `jumpTo`。高频消息或媒体较多时，Flutter UI 线程会出现明显 build/layout 峰值，表现为短时间点击和滑动无响应。

## Current state

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart:398-427` 更新键盘 inset 并 `setState`。
- `.../TIMUIKitTextField/tim_uikit_text_field_layout/narrow.dart:272-319` 同时响应 Focus/metrics。
- `.../TIMUIKitTextField/tim_uikit_text_field.dart:614-670` `goDownBottom` 会 flush、request pin、清未读并多次 `jumpTo`。
- 历史列表 selector 在 `.../tim_uikit_chat_history_message_list.dart:10336-10381` 对 revision/lock 改变重建列表。
- 性能测试模式：`test/chat_main_thread_perf_test.dart`、`test/chat_keyboard_viewport_message_visibility_test.dart`、`test/chat_input_composition_guard_test.dart`。

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Tests | `flutter test test/chat_main_thread_perf_test.dart test/chat_keyboard_viewport_message_visibility_test.dart test/chat_input_composition_guard_test.dart` | all pass |
| Analyze | `flutter analyze --no-fatal-warnings --no-fatal-infos third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_text_field.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_text_field_layout/narrow.dart` | no errors |

## Scope

**In scope:** the three keyboard/input files above, the narrowest scheduler/helper needed for coalescing, and focused tests.

**Out of scope:** keyboard type/locale, IME composition behavior, message ordering, unread product semantics, and general list virtualization.

## Steps

### Step 1: Add a single keyboard-transition coordinator

Coalesce repeated `didChangeMetrics` and focus callbacks into one transition per keyboard animation. Capture the latest inset and schedule one post-frame reconciliation; cancel or replace a pending reconciliation when a newer metric arrives.

**Verify:** `flutter test test/chat_keyboard_viewport_message_visibility_test.dart` → repeated metrics produce one logical reconciliation.

### Step 2: Make `goDownBottom` idempotent per transition

Ensure `flushDeferredIncomingMessages`, `requestPinToBottom`, unread clearing, and scroll correction run at most once for one focus/keyboard transition. Preserve explicit user “send” and “tap back to bottom” actions as independent triggers. Do not remove the existing composition guard.

**Verify:** `flutter test test/chat_input_composition_guard_test.dart test/chat_keyboard_viewport_message_visibility_test.dart` → composition and explicit user actions remain unchanged.

### Step 3: Replace three unconditional jumps with one measured correction

After layout settles, use the latest scroll position and one guarded correction. If the list is no longer attached, the user left bottom, or a newer transition superseded the correction, skip it. Keep existing reverse-list min/max semantics.

**Verify:** `flutter test test/chat_main_thread_perf_test.dart` → no regression in bottom visibility; no unbounded jump scheduling is present in the changed path.

### Step 4: Add performance assertions and diagnostics

Record transition duration, flush count, jump count, and whether the list rebuilt during the keyboard animation using the existing performance utilities. Add a contract test that a burst of metrics does not exceed one flush and one correction.

**Verify:** `flutter analyze --no-fatal-warnings --no-fatal-infos <changed files>` → no errors; targeted tests pass.

## Done criteria

- [ ] One keyboard animation produces at most one logical flush and one scroll correction.
- [ ] User-initiated send/back-to-bottom behavior remains immediate.
- [ ] Text composition and iOS keyboard language behavior are untouched.
- [ ] Targeted performance/visibility tests and analyze pass.
- [ ] No files outside scope are modified.

## STOP conditions

- The existing composition guard requires multiple jumps for correctness; stop and document the evidence.
- Coalescing changes unread or send behavior in an existing test; stop rather than weakening the test.
- A fix requires changing the message list data/revision contract; request a separate plan.

## Maintenance notes

Any future keyboard layout callback must submit work to the coordinator instead of calling `goDownBottom` directly. Keep metrics diagnostics bounded so logging cannot itself create the freeze.
