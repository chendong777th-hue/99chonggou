# Plan 053: Make history commits incremental and bounded

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/052-chat-main-thread-baseline.md
- **Category**: perf
- **Planned at**: commit `bc8e10d`, 2026-08-23

## Why this matters

`loadChatRecord` commits through `mergeHistoricalWithInMemory`, dedupe, chronological sorting, memory-window trimming, and `setMessageList`. Repeating this for the whole window during realtime traffic or recovery creates avoidable main-isolate work and rebuilds all bubbles.

## Current state

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_history_pagination_load.dart:607-661` merges a fetched batch with the in-memory list and calls `setMessageList(... replace: true)`.
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart:6070-6230` performs full dedupe/sort/window logic on each commit.
- `lib/src/chat.dart` can request recovery after open, overlay return, reconnect, and call completion.

## Scope

**In scope:** coalescing identical in-flight history commits, skipping a commit when the deduped window signature is unchanged, and preserving the existing outgoing-message retention and ordering contracts.

**Out of scope:** changing SDK fetch semantics, pagination direction, memory-window limits, or realtime message delivery.

## Steps

1. Add a per-conversation commit signature containing count, newest/oldest msg identity, seq/timestamp, and source direction.
2. Skip only byte-for-byte equivalent commits; retain all existing merge/dedupe behavior for changed windows.
3. Coalesce recovery triggers while one request/commit is active, with a final latest request after the active operation completes.
4. Add tests for unchanged commit, changed newest message, older-page append, in-flight outgoing retention, and realtime arrival during history fetch.

**Verify each step:** `flutter analyze`, targeted `flutter test test` for the new history tests, and `git diff --check`.

## Done criteria

- [ ] Equivalent history batches do not trigger `setMessageList` or a full rebuild.
- [ ] Realtime and sending messages remain visible during history commits.
- [ ] Existing pagination and ordering tests remain green.
- [ ] No change to SDK source selection or message semantics.

## STOP conditions

Stop if signature equality would require comparing message body text or would hide a changed message status/media URL.
