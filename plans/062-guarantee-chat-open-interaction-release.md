# Plan 062: 保证聊天首屏 gate 有界并可靠释放交互

> **Executor instructions**: 先执行漂移检查。只修改本计划列出的文件；如果需要改其他模块，停止并报告。

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/061-chat-interaction-freeze-observability.md
- **Category**: bug
- **Planned at**: commit `9f7c46e`, 2026-08-23

## Why this matters

`_wrapChatWithOpenHistoryGate` 当前用 `AbsorbPointer` 包住整棵真实聊天树。历史 hydrate、群 tip 合并或布局 ready 任一环节延迟，用户看到的页面就会完全不能点击或滑动；系统键盘仍可能正常，因为它是 iOS 原生层。目标是保留首屏准备逻辑，但任何异常都必须在明确 deadline 后开放交互，并在会话切换、返回、dispose 时清掉旧 gate。

## Current state

- `lib/src/chat.dart:3882-3953` 创建并保存 `_openLifecycle.openHistoryGate`。
- `lib/src/chat.dart:3959-4015` 等待 preparation、tip merge、layout ready。
- `lib/src/chat.dart:4225-4239` 只有 Future `done` 才解除 `AbsorbPointer`。
- `lib/src/chat.dart:6879-6884`、`8726-8732` 有返回/路由清理逻辑。
- `lib/src/chat_page/chat_open_lifecycle.dart:1-80` 保存 gate Future、会话 key 和清理状态。
- 测试模式：`test/chat_page_controllers_test.dart`、`test/chat_history_open_layout_ready_test.dart`、`test/chat_open_non_blocking_history_contract_test.dart`。

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Tests | `flutter test test/chat_page_controllers_test.dart test/chat_history_open_layout_ready_test.dart test/chat_open_non_blocking_history_contract_test.dart` | all pass |
| Analyze | `flutter analyze --no-fatal-warnings --no-fatal-infos lib/src/chat.dart lib/src/chat_page/chat_open_lifecycle.dart` | no errors |
| Diff | `git diff --check` | no output |

## Scope

**In scope:** `lib/src/chat.dart`, `lib/src/chat_page/chat_open_lifecycle.dart`, and focused tests under `test/`.

**Out of scope:** history query semantics, message list ordering, group tip contents, keyboard language, root overlay implementation, and media preview behavior.

## Steps

### Step 1: Make gate state explicit

Extend the open lifecycle with explicit states/reasons (inactive, preparing, ready, timed-out, cancelled) rather than inferring activity only from a nullable Future. Preserve the conversation key and epoch so a late Future from conversation A cannot release or relock conversation B.

**Verify:** `flutter test test/chat_page_controllers_test.dart test/chat_history_open_layout_ready_test.dart` → new state-transition assertions pass.

### Step 2: Enforce one hard interaction deadline

Keep the existing soft timeouts for metrics, but add one outer deadline that always transitions the gate to timed-out in a `finally`-equivalent path. On timeout, expose the already-rendered chat tree and log the timeout; do not discard loaded messages or change history ordering. Ensure all early returns (`mounted == false`, conversation mismatch, errors) clear the matching gate epoch.

**Verify:** `flutter test test/chat_open_non_blocking_history_contract_test.dart` → timeout and error paths prove the interaction gate becomes open.

### Step 3: Make cleanup idempotent

Route change, `deactivate`, `dispose`, and return-from-overlay cleanup must be safe to call multiple times. A stale Future completion must be ignored when its epoch/key no longer matches. Keep existing layout-ready cancellation semantics.

**Verify:** `flutter test test/chat_page_controllers_test.dart test/chat_history_open_layout_ready_test.dart` → repeated cancel/late completion tests pass.

### Step 4: Preserve visual behavior without blocking forever

Do not replace the real chat tree with a new skeleton. If the deadline expires, retain the current visual tree and let the list/input receive gestures; loading indicators may remain non-interactive via `IgnorePointer`. Add a contract test that the title/back control and list are not wrapped by an active `AbsorbPointer` after timeout.

**Verify:** `flutter analyze --no-fatal-warnings --no-fatal-infos lib/src/chat.dart lib/src/chat_page/chat_open_lifecycle.dart` → no errors.

## Done criteria

- [ ] Gate has explicit epoch/key and terminal timeout/cancel states.
- [ ] No matching gate remains active after hard deadline, route change, dispose, or error.
- [ ] Late completion from an old conversation cannot affect the active conversation.
- [ ] Existing history and visual tests remain green.
- [ ] Only in-scope files are modified.

## STOP conditions

- Opening interaction before history preparation would violate a documented product invariant; stop and report the invariant rather than removing the gate.
- A required cleanup path lives outside the scope files; stop and request scope expansion.
- Existing tests prove a different timeout contract than the one described here.

## Maintenance notes

Any future open-history phase must register its epoch and terminal outcome with the lifecycle. Do not reintroduce a nullable Future-only gate or let a layout callback be the sole unlock condition.
