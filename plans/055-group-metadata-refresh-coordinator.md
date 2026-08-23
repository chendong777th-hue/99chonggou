# Plan 055: Serialize group metadata refreshes

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/052-chat-main-thread-baseline.md
- **Category**: correctness/perf
- **Planned at**: commit `6333e34`, 2026-08-23

## Why this matters

Opening a group can read local SQLite data, resolve SDK group data, refresh member details, load announcements, and update the conversation list independently. Multiple completions can rebuild the header and list during history and keyboard work.

## Current state

- `lib/src/chat.dart:4994` reads local group display data; `:5130` loads member count; both are called during init, recovery, and conversation changes.
- `lib/src/services/group_local/group_membership_sync_service.dart` persists group detail/member updates.
- `lib/src/services/conversation_local/conversation_sync_service.dart` updates conversation rows and notifies list consumers.
- A 60-second count throttle and request-generation guard already exist; preserve them.

## Scope

**In scope:** one per-group refresh coordinator returning a single snapshot `{name,count,notice,avatar}`, source precedence, request generation, and one UI commit.

**Out of scope:** changing group membership semantics, announcement content, group permissions, or conversation list layout.

## Steps

1. Define source precedence: explicit SDK group-change/self-hosted authoritative data, then remote group detail, then local cache as first-paint fallback.
2. Deduplicate concurrent refreshes by canonical group ID and cancel/ignore stale generations after conversation changes.
3. Apply name/count/notice/avatar together only when the snapshot differs; do not notify the message list for metadata-only changes.
4. Add tests for concurrent open/reconnect, stale response, local fallback followed by remote snapshot, and group leave/dissolve.

**Verify:** `flutter analyze`, targeted group metadata tests, `flutter test test`, and `git diff --check`.

## STOP conditions

Stop if the remote API does not provide a coherent snapshot or if applying one field at a time is required for an existing product flow; document the exception instead.

## Completed

- [x] Canonical group ID single-flight with 60-second throttle.
- [x] Coherent name/count/notice/avatar snapshot and atomic chat-header apply.
- [x] Local SQLite is first-paint placeholder only; remote detail replaces it.
- [x] Explicit membership events bypass throttle; stale generations are ignored.
- [x] Metadata apply does not notify the message list.
