# Plan 069: Remove pseudo-message rows and duplicate message caches

> **Executor instructions**: Execute only after 066–068 are verified on device. This is a cleanup/refactor plan; preserve all chat semantics.

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: 066, 068
- **Category**: tech-debt
- **Planned at**: commit `9f7c46e`, 2026-08-23

## Why this matters

The same `V2TimMessage` list currently carries real SDK messages, local group tips, time-divider pseudo rows, loading rows, and send placeholders. A second cache exists in the message service. This makes alias normalization, dedupe, pagination, and restart behavior difficult to reason about and is a direct contributor to disappearing or duplicate bubbles.

## Current state

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart:8419-8503` builds the rendered list and injects time-divider pseudo messages.
- `.../tui_chat_global_model.dart:4302-4450` batches incoming SDK messages and deduplicates them.
- `.../tui_chat_global_model.dart:6094-6164` trims only the memory window and intentionally leaves SDK storage untouched.
- `third_party/tencent_cloud_chat_uikit/lib/data_services/message/message_service_implement.dart:52-55` has another message cache.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Full relevant tests | `flutter test test/message_ordering_test.dart test/outgoing_image_bubble_dedupe_contract_test.dart test/chat_media_optimistic_send_contract_test.dart` | all pass |
| Static check | `flutter analyze third_party/tencent_cloud_chat_uikit/lib/business_logic third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat` | no new analyzer errors |

## Scope

**In scope**: GlobalModel projection rows, service cache boundary, time-divider/loading row types, and related tests.

**Out of scope**: message content, sorting semantics, search result ordering, conversation list, archive retention, calls, wallet, and UI styling.

## Steps

### Step 1: Introduce typed UI row projection

Represent real SDK messages, time dividers, loading rows, local notices, and operation rows as distinct projection types. Keep `V2TimMessage` only for SDK business messages. Preserve existing chronological ordering and visible-row keys.

**Verify**: rendering tests show the same visible rows and assert time dividers are not `V2TimMessage` instances.

### Step 2: Make GlobalModel the sole projection owner

Remove service-level message-list merging and expose SDK history/transport results to GlobalModel. Keep any serialization queue keyed by conversation/client ID but remove duplicate message collections. Preserve alias-aware keys and memory-window trimming.

**Verify**: source search finds no second canonical `List<V2TimMessage>` cache; history and alias tests pass.

### Step 3: Migrate local tips deliberately

Classify each `local_*`/`local_gt_*` row. If it must survive restart or be visible to all members, send a real SDK custom/group-tip message. If it is device-only UI, keep it as a typed UI notice with explicit lifecycle and no claim of server history.

**Verify**: group-tip tests cover restart, remote member visibility, and device-only notices.

### Step 4: Audit consumers and remove casts

Update list virtualization, message items, scroll anchors, snapshots, and row revision code to consume typed projection rows. Remove `elemType` checks that exist only for pseudo rows; retain real SDK element handling.

**Verify**: full relevant tests, analyzer, and a manual scroll/pagination/restart matrix pass.

## Done criteria

- [ ] One projection owner; no duplicate canonical message cache.
- [ ] Pseudo rows are typed UI rows, not `V2TimMessage`.
- [ ] SDK messages remain order/dedupe/restart compatible.
- [ ] Relevant tests and analyzer pass; no out-of-scope files changed.

## STOP conditions

- A consumer requires pseudo rows to satisfy a public SDK API contract; stop and isolate an adapter instead of reintroducing fake messages.
- Removing the service cache changes server/history semantics; stop and preserve a read-only transport cache with explicit ownership.

## Maintenance notes

New UI-only rows must use projection types. New SDK message sources must enter through the reducer and be covered by restart and duplicate-echo tests.
