# 021 — Unlock chat scroll after media gallery dismiss

## Goal

After swipe-down dismiss of in-chat image/gallery preview, the message list
must become scrollable again even if the opening bubble `State` was disposed
(common in busy group chats).

## Root cause

`saveScrollBeforeMediaPreview` sets `_isMediaPreviewOverlayOpen`, which forces
`NeverScrollableScrollPhysics`. Unlock lived in image/video elem
`whenComplete` / `finally` behind `if (!mounted) return`, so recycled bubbles
left the lock on forever. `endMediaPreviewOverlay` was unused.

## Fix

1. `pushMediaPreview(restoreChatScrollConversationID:)` always calls
   `restoreScrollAfterMediaPreview` in `finally` (post-frame).
2. Image/video elems only dispose session / hero; video early-exit still
   unlocks when push never happened.
3. 1.6s failsafe `finishScrollAfterMediaPreview` if list never finishes restore.

## Verify

`test/media_preview_chat_scroll_lock_contract_test.dart`
