# Plan 066: Make SDK messages the only chat-message authority

> **Executor instructions**: This is a read-before-write plan. Run the drift check first. Modify only the files listed in Scope. If any current-state excerpt differs, stop and report.

## Status

- **Priority**: P0
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: 067
- **Category**: tech-debt / bug
- **Planned at**: commit `9f7c46e`, 2026-08-23

## Why this matters

The chat page currently mixes SDK `V2TimMessage` objects with app-created optimistic messages in the same list. Failed media preparation can therefore look like a message that was sent and then silently disappear. The target is SDK-authoritative messaging: history, realtime events, created messages, and send results are the only business-message inputs; memory remains only a rebuildable UI projection.

## Current state

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart:8419` derives the rendered list from an in-memory message map.
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart:6174` creates image `V2TimMessage` placeholders before SDK creation.
- `.../tui_chat_separate_view_model.dart:6393` calls `createImageMessage` only after preparation; `:6413` removes the placeholder if creation fails; `:6460` adopts the SDK object later.
- `third_party/tencent_cloud_chat_uikit/lib/data_services/message/message_service_implement.dart:52` maintains a second message cache (`messageListMap`/`sendingMessage`) that is merged with SDK history.
- SDK history and listener boundaries already exist at `.../message_service_implement.dart:243`, `...:493`, and `.../tui_chat_global_model.dart:1397`.
- Tencent’s documented model is `createXxxMessage -> sendMessage`; history may come from SDK local storage or cloud, while local-insert APIs are not server messages. Preserve this distinction.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Drift | `git diff --stat 9f7c46e..HEAD -- third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart third_party/tencent_cloud_chat_uikit/lib/data_services/message/message_service_implement.dart test` | inspect before editing |
| Tests | `flutter test test/chat_media_optimistic_send_contract_test.dart test/outgoing_image_bubble_dedupe_contract_test.dart test/message_ordering_test.dart` | all pass |
| Static check | `flutter analyze third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart` | no new analyzer errors |

## Scope

**In scope**: the two chat models, message service cache boundary, message projection tests, and the media/text/video send paths that currently fabricate `V2TimMessage` placeholders.

**Out of scope**: Tencent SDK version changes, message wire format, cloud retention settings, search semantics, conversation-list layout, calls, wallet messages, and server-side APIs.

## Steps

### Step 1: Add characterization tests

Add tests proving that history and realtime SDK messages enter the projection, that SDK-created messages can be shown in `SENDING` state, and that no pre-`createXxxMessage` app-created `V2TimMessage` is inserted into the canonical message list. Cover image, text, video, rapid multi-send, SDK echo, failure, and app restart reconstruction.

**Verify**: run the three test commands above; new tests must fail against the old pre-create placeholder behavior and existing ordering/dedupe tests remain green.

### Step 2: Introduce one projection reducer

Create one reducer in the GlobalModel boundary that accepts only SDK history, SDK listener, SDK create result, SDK send result, revoke/modify events, and explicit local UI sidecar updates. Normalize conversation aliases, stable SDK IDs, group sequence ordering, dedupe, and memory-window trimming in this reducer. Keep the authoritative SDK message object separate from progress/path/row-height UI metadata.

**Verify**: unit tests show the same SDK message identity survives create → send result → echo and that a projection can be cleared and rebuilt from SDK history without message loss.

### Step 3: Remove app-created business placeholders

For each send path, do preparation first, call `createXxxMessage`, then insert the returned SDK object into the projection as sending. Remove the placeholder/adopt/stable-ID replacement path only after all callers use the new reducer. A failed create or send must leave a visible failure state or an explicit operation error; it must not silently delete a business row.

**Verify**: `rg -n "_prependOptimistic|beginOptimistic|hydrateOptimistic|_swapOutgoingMessage"` is empty or limited to an explicitly documented UI-sidecar implementation, and media/text/video contract tests pass.

### Step 4: Collapse the duplicate service cache

Make `message_service_implement.dart` return SDK results and callbacks without maintaining a second canonical message list. If a short-lived transport queue is required for serialization, store only operation metadata keyed by SDK client ID, never a second `List<V2TimMessage>`.

**Verify**: source inspection confirms one canonical projection owner; history tests show no duplicate rows when local SDK history and cloud history overlap.

### Step 5: Rebuild on lifecycle recovery

On chat entry, foreground recovery, and uncertain send completion, rebuild the projection from SDK local history and then cloud history when required. Do not restore app-created placeholders from preferences or custom caches.

**Verify**: add a restart/reopen test or deterministic fake SDK test proving that only SDK-persisted messages reappear.

## Test plan

Model tests after `test/message_ordering_test.dart`, `test/outgoing_image_bubble_dedupe_contract_test.dart`, and `test/chat_media_optimistic_send_contract_test.dart`. Cover SDK-only identity, local/cloud history merge, realtime echo, send failure, retry, revoke/modify, group sequence ordering, alias IDs, and restart reconstruction.

## Done criteria

- [ ] No app-created `V2TimMessage` enters the canonical business-message list before SDK creation.
- [ ] SDK history/listener/create/send are the only business-message inputs.
- [ ] Projection rebuild from SDK history preserves order and dedupe.
- [ ] All listed Flutter tests pass; no new analyzer errors.
- [ ] No files outside Scope are modified.

## STOP conditions

- SDK create/send callbacks cannot provide a stable identity for a required path.
- Removing placeholders breaks a documented product requirement for a pre-create message.
- A failure requires changing wire payloads or SDK versions.

## Maintenance notes

Keep UI operation state out of `V2TimMessage`. Any new message type must enter through the reducer and have a restart/rebuild test.
