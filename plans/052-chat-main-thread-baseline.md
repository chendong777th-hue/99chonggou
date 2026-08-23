# Plan 052: Establish a chat-page performance baseline before further changes

> **Executor instructions**: This is a read-first instrumentation plan. Do not change message semantics, pagination, media behavior, or group data precedence.

## Status

- **Priority**: P0
- **Effort**: S–M
- **Risk**: LOW
- **Depends on**: none
- **Category**: perf
- **Planned at**: commit `6333e34`, 2026-08-23

## Why this matters

The chat page combines history merge, group metadata, conversation refresh, image decode, and keyboard layout in the same opening window. Without timings, fixes risk moving work rather than removing it. Establish one repeatable profile scenario and disabled-by-default timings first.

## Current state

- `lib/src/chat.dart` owns entry/recovery, group metadata, media callbacks, and conversation refresh triggers.
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart:6070` performs list merge, dedupe, sort, memory-window trimming, and notification.
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_history_pagination_load.dart:607` commits history batches.
- Existing diagnostics such as `ChatHistoryTrace` are disabled by default; match that convention and never log message text or identifiers in release.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Static check | `flutter analyze` | No new analyzer errors in touched files |
| Tests | `flutter test test` | Existing tests pass, or document environment failure |
| Diff check | `git diff --check` | No whitespace errors |

## Scope

**In scope:** a disabled-by-default timing utility and instrumentation at history commit, group metadata apply, conversation reload, image decode/prefetch entry, and keyboard settle.

**Out of scope:** changing fetch counts, message ordering, group-data precedence, media compression, or UI layout.

## Steps

### Step 1: Add disabled timing probes

Follow the existing `ChatHistoryTrace`/`ChatOpenPerfLog` style. Emit only duration, count, source, and conversation type; gate all output from release/profile unless explicitly enabled for local profiling.

**Verify:** `git diff --check` → exit 0.

### Step 2: Instrument the six boundaries

Measure `history_merge_ms`, `set_message_list_ms`, `group_metadata_apply_ms`, `conversation_reload_ms`, `image_decode_ms`, and `keyboard_layout_ms`. Ensure timers use `Stopwatch` and close in `finally`.

**Verify:** `flutter analyze` → no new errors.

### Step 3: Add a repeatable scenario note

Document cold install, warm open, long-history group, image-heavy group, keyboard open, and media send in `docs/perf-hitch-capture.md` or the existing performance document. Include expected log fields and the profile/Instruments capture steps.

**Verify:** `flutter test test` → pass or record the known environment blocker.

## Done criteria

- [x] All six timing fields exist and are disabled in release.
- [x] No message text, token, or full user/group identifier is logged.
- [x] Targeted analysis/tests show no new instrumentation errors.
- [x] `git diff --check` passes.

## STOP conditions

Stop if instrumentation requires changing a message list algorithm, adding synchronous file/database work, or enabling verbose release logging.

## Maintenance notes

Use this baseline before plans 053–055. Keep the probe names stable so future profile captures remain comparable.
