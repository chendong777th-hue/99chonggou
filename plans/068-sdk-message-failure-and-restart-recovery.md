# Plan 068: Preserve SDK-created failures and recover sends after restart

> **Executor instructions**: This plan assumes 067 is complete and 066’s SDK-authoritative projection API exists. Do not restore app-created optimistic messages.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: 066, 067
- **Category**: bug / tests
- **Planned at**: commit `9f7c46e`, 2026-08-23

## Why this matters

After SDK message creation, the app must never erase the only visible evidence of a send attempt. The current adoption/failure path can remove the row, while restart recovery depends on whether the SDK local database contains the message. This plan makes SDK-created send failure observable and defines the recovery behavior for uncertain completion.

## Current state

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart:6393-6485` creates, adopts, and sends image messages.
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart:6551-6677` applies final SDK updates to the in-memory row.
- SDK history entry points are `.../tui_chat_separate_view_model.dart:1021-1030` and `.../message_service_implement.dart:243-305`.
- Tencent documents that non-online messages are stored by SDK/server and that local inserted messages are not server messages; use that distinction in restart tests.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Media/order tests | `flutter test test/chat_media_optimistic_send_contract_test.dart test/outgoing_image_bubble_dedupe_contract_test.dart test/message_ordering_test.dart` | all pass |
| Static check | `flutter analyze third_party/tencent_cloud_chat_uikit/lib/business_logic` | no new analyzer errors |

## Scope

**In scope**: SDK-created send state, retry/error UI metadata, lifecycle recovery, and tests.

**Out of scope**: pre-SDK gallery export (067), SDK wire protocol, cloud retention policy, or new persistence database.

## Steps

### Step 1: Characterize SDK-created failure states

Add deterministic tests for create success/send success, create success/send failure, SDK echo before send completion, callback omission, retry, revoke/modify, and restart. Assert the SDK-created row remains visible with a retryable state until a documented terminal cleanup action.

**Verify**: tests fail against any path that removes the SDK-created row on send failure.

### Step 2: Model send operation metadata separately

Store progress, retry count, error category, and last-attempt time in a sidecar keyed by SDK client ID/msgID. Keep `V2TimMessage` as the message entity; do not encode transient retry state into fake message elements or local-only message IDs.

**Verify**: projection tests show the same SDK entity across progress, failure, retry, and success; no duplicate row is created.

### Step 3: Reconcile uncertain completion on lifecycle events

On foreground, chat reopen, and send timeout, query SDK local history first, then cloud history if the message is missing and the conversation permits it. Reconcile by SDK client ID/msgID/sequence using the single reducer from Plan 066. Mark an operation unknown/retryable when the SDK cannot prove delivery; never silently drop it.

**Verify**: fake SDK tests cover callback lost, app restart, cloud message present, cloud message absent, and duplicate echo.

### Step 4: Add manual Profile acceptance matrix

Run on iOS and Android with local JPEG, HEIC, iCloud/cloud asset, offline network, limited permission, group mute/permission denial, background/foreground, and app restart. Capture trace IDs and assert visible state, server presence, and exactly one row.

**Verify**: record a pass/fail matrix; any platform-specific inability to recover a failed SDK-created message is a STOP/report item.

## Done criteria

- [ ] SDK-created sends remain visible on failure and support retry.
- [ ] Restart recovery is SDK-local/cloud based and deduplicated.
- [ ] Lost callback/timeout is not silently treated as success or deletion.
- [ ] Focused tests and static checks pass.

## STOP conditions

- Current SDK version does not expose enough identity/state to reconcile a lost callback; stop and propose a bounded app-side outbox as a separate design, not an ad hoc message row.
- Recovery requires changing cloud retention or wire semantics.

## Maintenance notes

Any new media type must specify create identity, send failure state, retry key, and restart reconciliation before implementation.
