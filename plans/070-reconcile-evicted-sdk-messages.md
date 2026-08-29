# Plan 070: Reconcile memory-window eviction with SDK history

> **Executor instructions**: This plan addresses the production symptom where a sent message exists in memory, memory cleanup removes its bubble, and the chat page does not restore it. Do not disable the memory window globally and do not delete SDK history to hide the symptom.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: 066, 068
- **Category**: bug
- **Planned at**: commit `9f7c46e`, 2026-08-23

## Why this matters

The chat page renders a memory projection, while Tencent IM is the durable source for non-online messages. A memory-window trim is valid only if an evicted message can be fetched back from SDK local/cloud history when the user returns to that range. Today the code can trim `_messageListMap`, then treat a partial local window as sufficient and skip cloud recovery, leaving a sent message absent from the rendered list.

## Current state

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart:6060-6175` trims the in-memory list and explicitly states it does not delete SDK/DB storage.
- `.../tui_chat_global_model.dart:6200-6355` merges incoming history into the current memory list, then applies the memory window; eviction is therefore a projection loss, not durable deletion.
- `.../tui_chat_global_model.dart:8419-8447` renders from the in-memory projection.
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart:1974-2020` loads local history first and may return when the local window is non-empty/large enough, without proving that the requested visible range or newest self-sent message is present.
- SDK history boundaries are `.../tui_chat_separate_view_model.dart:1021-1030` and `.../message_service_implement.dart:243-305`.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Drift | `git diff --stat 9f7c46e..HEAD -- third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart test` | inspect before editing |
| Tests | `flutter test test/message_ordering_test.dart test/chat_media_optimistic_send_contract_test.dart test/outgoing_image_bubble_dedupe_contract_test.dart` | all pass |
| Static check | `flutter analyze third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart` | no new analyzer errors |

## Scope

**In scope**: memory-window missing-range markers, SDK local/cloud recovery decisions, chat reopen/foreground reconciliation, and tests.

**Out of scope**: disabling memory-window trimming, changing window sizes as the primary fix, changing ordering, deleting SDK history, changing SDK versions, or changing conversation-list semantics.

## Steps

### Step 1: Characterize eviction and recovery

Create tests with an SDK fake containing more messages than `ChatMessageWindowPolicy.softMax`. Trim a message out of memory, then simulate local history that does not contain it and cloud history that does. Cover older-range eviction, newest-range eviction, self-sent media, group sequence ordering, alias conversation IDs, scroll-away/scroll-back, foreground recovery, and app reopen.

**Verify**: tests fail if a non-empty local window suppresses required cloud recovery or an evicted message cannot be reinserted by SDK identity.

### Step 2: Record exact missing-range state

When `_applyMessageMemoryWindow` evicts older or newer rows, record direction, anchor message/sequence, oldest/newest in-memory identities, and whether the evicted range is known complete. Do not infer completeness from list length alone. Clear the marker only after an SDK response covers the requested range.

**Verify**: tests assert trim sets the correct direction/anchor and SDK coverage clears it; ordinary refresh does not clear it accidentally.

### Step 3: Make recovery prove coverage

Update history loading so it continues from SDK local to cloud when the requested missing range, newest self-send, or anchor is not covered. A local response with enough rows is insufficient if it does not contain the target identity/sequence or required boundary. Merge recovered SDK messages through Plan 066’s reducer and preserve scroll anchors.

**Verify**: cover local hit, cloud fallback, both sources missing, duplicate local/cloud copies, and unrelated local responses. Only coverage-proven paths may clear the missing marker.

### Step 4: Reconcile after send and lifecycle events

After SDK send success, callback loss, foreground resume, chat reopen, and memory-window trim, schedule one bounded reconciliation for the open conversation. Query SDK local first, cloud only when local cannot prove coverage. Coalesce by conversation and anchor; do not reload every frame.

**Verify**: instrumentation/fake tests show one reconciliation per coalesced event, no infinite retry, and no viewport jump when intentionally scrolled away.

### Step 5: Add production diagnostics

Log projection trim, missing-range marker, local coverage result, cloud fallback, recovered count, and final coverage status using existing `ChatHistoryTrace`/`ChatJitterDiag` conventions. Use privacy-safe hashes for conversation/message identifiers; never log image paths or content.

**Verify**: synthetic traces distinguish trimmed/recovered, cloud fallback, SDK record absent, and lifecycle/hidden filtering.

## Test plan

Follow `test/message_ordering_test.dart`, `test/chat_media_optimistic_send_contract_test.dart`, and existing history recovery tests. Required cases: sent message survives trim/reopen; local miss → cloud hit; local wrong range → cloud fallback; duplicate local/cloud identity; group seq and C2C alias keys; scroll-away does not force bottom; no SDK record remains absent with a visible diagnostic rather than a fake bubble.

## Done criteria

- [ ] Memory trim never implies durable deletion.
- [ ] Every evicted range has explicit recoverability/coverage state.
- [ ] SDK local/cloud recovery restores messages by SDK identity and sequence.
- [ ] Non-empty local history cannot suppress required cloud fallback.
- [ ] Recovery is bounded/coalesced and preserves scroll semantics.
- [ ] Focused tests and analyzer pass; no out-of-scope files change.

## STOP conditions

- SDK APIs cannot prove range coverage with available cursor/sequence fields; stop and report before changing window policy.
- A fix requires treating app-created placeholders as durable messages; return to Plan 066’s SDK-authoritative boundary.

## Maintenance notes

Every future memory-window change must include an eviction → SDK recovery test. Never use `list.length >= count` as proof that the requested message range is present.
