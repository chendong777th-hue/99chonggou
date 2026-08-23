# Plan 054: Move media preparation out of the chat UI critical frame

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/052-chat-main-thread-baseline.md
- **Category**: perf
- **Planned at**: commit `bc8e10d`, 2026-08-23

## Why this matters

Image/video sending currently chains file read, compression, thumbnail generation, dimension probing, upload, optimistic insertion, and scroll-to-bottom. Any synchronous preparation overlaps the chat frame and keyboard animation.

## Current state

- Media entry points are in `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_more_panel.dart` and related image/video helpers.
- The chat page consumes the resulting message and requests bottom pinning from `lib/src/chat.dart`/`tui_chat_global_model.dart`.
- Existing media tests and upload error paths must remain authoritative.

## Scope

**In scope:** isolate/background preparation where the existing APIs permit it, staged optimistic UI, and one final list/scroll commit after upload state changes.

**Out of scope:** changing compression quality, upload protocol, message payloads, or media preview product behavior.

## Steps

1. Use plan 052 timings to identify synchronous preparation exceeding one frame.
2. Move pure byte/thumbnail work to an isolate or platform background API; keep plugin calls on their required platform thread.
3. Insert a lightweight sending placeholder immediately, then update the same stable message identity through upload and send completion.
4. Coalesce the final message-list update and bottom-scroll request.
5. Test cancel, permission denial, large image, video, slow upload, retry, and failed upload.

**Verify:** `flutter analyze`, targeted media tests, `flutter test test`, and `git diff --check`.

## STOP conditions

Stop if an SDK/plugin object must cross isolates, if stable identity cannot be preserved, or if moving work changes the uploaded bytes.
