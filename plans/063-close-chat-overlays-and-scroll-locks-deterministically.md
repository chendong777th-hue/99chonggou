# Plan 063: 统一清理聊天全屏 Overlay 与媒体滚动锁

> **Executor instructions**: 先运行漂移检查；本计划只处理交互层生命周期，不改变菜单项、媒体预览产品行为或消息数据。

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/061-chat-interaction-freeze-observability.md
- **Category**: bug
- **Planned at**: commit `9f7c46e`, 2026-08-23

## Why this matters

长按消息菜单和图片/视频预览都在聊天树之外或之上持有交互状态。一个没有移除的 root `OverlayEntry` 会吃掉全屏点击和滑动；一个没有完成的媒体恢复状态会把列表永久切成 `NeverScrollableScrollPhysics`。两者都能表现为“页面卡住”，重新进入页面后又恢复。

## Current state

- 长按菜单创建与移除位于 `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart:1203-1360,3508`。
- Telegram 菜单全屏手势层位于 `.../tim_uikit_telegram_message_context_controller.dart:215-290`，使用 opaque `GestureDetector`。
- 路由级孤儿清理位于 `lib/src/navigation/orphan_overlay_guard.dart:1-80`。
- 媒体锁计算位于 `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart:8461`；列表 physics 位于 `.../tim_uikit_chat_history_message_list.dart:2441-2458`。
- 媒体恢复与 1.6 秒 fallback 位于 `tui_chat_global_model.dart:8714,8923,9026`；现有契约测试为 `test/media_preview_chat_scroll_lock_contract_test.dart`、`test/media_preview_return_transition_test.dart`。

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Tests | `flutter test test/media_preview_chat_scroll_lock_contract_test.dart test/media_preview_return_transition_test.dart test/chat_video_long_press_preview_contract_test.dart` | all pass |
| Analyze | `flutter analyze --no-fatal-warnings --no-fatal-infos lib/src/navigation/orphan_overlay_guard.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart` | no errors |

## Scope

**In scope:** the overlay controller/item files, `OrphanOverlayGuard`, global media lock/recovery methods, list physics, and focused tests.

**Out of scope:** menu options, deletion/reply semantics, media download/quality, message list data, and keyboard layout.

## Steps

### Step 1: Make overlay removal idempotent and observable

Centralize removal of the mobile Telegram menu, tooltip blur, and related entries behind one idempotent cleanup path. Every insertion receives an owner token; cleanup checks ownership before removing and records the remaining overlay count. Call this path from normal dismiss, route cleanup, `deactivate`, and `dispose`.

**Verify:** `flutter test test/chat_video_long_press_preview_contract_test.dart` → repeated dismiss/dispose cases pass.

### Step 2: Add a route-level forced cleanup boundary

When the chat route is no longer active, force cleanup of chat-owned entries before the next route receives gestures. Do not remove overlays owned by unrelated features. Keep `OrphanOverlayGuard` as the single route scheduling point.

**Verify:** `flutter test test/chat_page_controllers_test.dart` → route cleanup does not affect unrelated controller state.

### Step 3: Make media lock release tokenized

Associate `restoreScrollAfterMediaPreview` and `finishScrollAfterMediaPreview` with a preview epoch/token. A late callback from an older preview must not keep or clear the active preview lock. Ensure every exit path (`finally`, route pop, presenter error, fallback) reaches exactly one terminal release and emits the diagnostic event from Plan 061.

**Verify:** `flutter test test/media_preview_chat_scroll_lock_contract_test.dart test/media_preview_return_transition_test.dart` → open/close, error, fallback, and stale callback cases pass.

### Step 4: Preserve scroll semantics

Continue using `NeverScrollableScrollPhysics` only while an active media preview epoch owns the lock. Do not change user scrolling, unread, pagination, or preview presentation behavior outside the lock lifetime.

**Verify:** `rg -n "NeverScrollableScrollPhysics|shouldLockChatScrollForMediaPreview" <changed files>` → all uses are guarded by the tokenized state.

## Done criteria

- [ ] No chat-owned full-screen overlay survives route exit, dispose, or repeated dismiss.
- [ ] Stale media callbacks cannot leave the active list locked.
- [ ] Media lock always has a normal and fallback terminal release.
- [ ] Targeted tests/analyze pass; no unrelated overlay is removed.

## STOP conditions

- Overlay ownership cannot be distinguished from another feature's overlay; stop rather than broadening cleanup.
- A presenter contract requires a lock beyond the stated route lifetime; document it and stop.
- Existing completed plans 021/023/027 would be contradicted; preserve their behavior and report the conflict.

## Maintenance notes

Future overlays must register ownership and terminal cleanup with the same route boundary. Future media presenters must carry the preview epoch through every asynchronous callback.
