# Plan 056: Make inbound pending-batch deduplication use the canonical message identity

> **Executor instructions**: Follow this plan step by step. This plan targets
> duplicate chat rows caused by two inbound copies of one group message being
> coalesced together. Do not change message ordering, pagination semantics,
> outgoing-message correlation, or C2C preview behavior. Stop at any STOP
> condition instead of improvising.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `363b315`, 2026-08-23

## Why this matters

The chat UI can show the same group-message sequence twice when two inbound
copies arrive in one coalesced batch with different `msgID`/`id` values. The
current batch path compares only those two fields while the canonical dedupe
implementation already knows how to collapse group SDK/archive copies by
conversation `seq`. The result is a real duplicate in the authoritative list,
not merely a Flutter element-recycling artifact.

## Current state

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
  owns inbound coalescing, authoritative message storage, canonical dedupe,
  and list revisions.
- `_flushInboundMessageBatch` at approximately line 4360 routes a coalesced
  list to `_applyInboundMessageBatch`.
- `_applyInboundMessageBatch` at approximately lines 4420–4585 separates
  deferred messages from messages that may be upserted, then calls
  `_upsertIncomingMessageBatch`.
- `_upsertIncomingMessageBatch` at approximately line 4232 has a local
  `pending` list. Its `matchesPendingIdentity` helper at approximately line
  4269 checks only `message.msgID` and `message.id`.
- Its `flushPending` helper at approximately line 4247 writes
  `pending + existing` after sorting, but does not call `dedupeMessages`.
- `messageDedupKey` at approximately line 7537 uses group conversation identity
  plus `seq` when group ordering is available. `dedupeMessages` at
  approximately line 7561 is the canonical implementation and is already
  covered by extensive tests in `test/message_ordering_test.dart`.
- `_messageCorrelatesWithStored` at approximately line 3979 already delegates
  to `messagesCorrelateForDedup`; preserve that behavior for stored-vs-incoming
  matching.

The existing test pattern is `test/message_ordering_test.dart`, especially the
tests covering group archive/SDK copies with equal `seq` and tests proving that
distinct group sequences remain distinct. Add regression coverage next to
those tests rather than creating a new test framework.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Targeted regression tests | `flutter test test/message_ordering_test.dart` | All tests pass |
| Targeted static check | `flutter analyze --no-fatal-warnings --no-fatal-infos third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart test/message_ordering_test.dart` | No analyzer errors |
| Formatting/diff check | `dart format --output=none --set-exit-if-changed third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart test/message_ordering_test.dart` | Exit 0 |
| Whitespace check | `git diff --check` | Exit 0 |

## Scope

**In scope (only these files):**

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
- `test/message_ordering_test.dart`

**Out of scope:**

- `setMessageList` history pagination behavior;
- `_messageCorrelatesWithStored`, outgoing stable-id correlation, or C2C
  direction normalization;
- `tim_uikit_chat_history_message_list.dart` rendering keys;
- server-side message deletion or SDK configuration;
- merging messages solely by text/timestamp. Distinct user sends must remain
  distinct when their group `seq`/identity differs.

## Steps

### Step 1: Add a failing characterization test for duplicate pending rows

Extend `test/message_ordering_test.dart` with a test fixture representing two
copies of the same group text message: same group identity, same positive
`seq`, same element type, but different SDK `msgID` and client `id`. Also add a
control fixture with the same sender/content and different positive `seq`.

The test must exercise the batch path (not only the already-tested public
`dedupeMessagesForTesting` helper). If the private batch method is not
callable, expose the smallest `@visibleForTesting` adapter that accepts a
conversation key and a message batch and returns the resulting identities;
do not expose mutable internal maps. The duplicate case must produce one
message after the fix; the different-seq case must produce two.

**Verify:** `flutter test test/message_ordering_test.dart` → the new duplicate
case fails before the implementation change and the existing suite remains
green.

### Step 2: Apply canonical dedupe at the pending flush boundary

Change only the `flushPending`/pending comparison logic in
`tui_chat_global_model.dart` so every pending-to-storage merge uses the same
canonical `dedupeMessages` identity rules as `setMessageList`. Preserve newest
first sorting and preserve the existing merge preference behavior. Do not use
message text or timestamp alone as an identity.

The implementation must dedupe both:

1. duplicate messages accumulated inside the current `pending` batch; and
2. a pending message that duplicates an already stored SDK/archive copy.

Avoid an O(n²) full-list dedupe on every message; one dedupe per pending flush
is acceptable. Keep the existing fast `msgID`/`id` checks as an early path only
if they cannot bypass the canonical fallback.

**Verify:** `flutter test test/message_ordering_test.dart` → all tests pass,
including equal-seq collapse and distinct-seq preservation.

### Step 3: Add diagnostic evidence for future reports

At the existing inbound batch diagnostic boundary, record only counts and
identity metadata (`count`, `upserted`, duplicate count, group-vs-C2C source,
and `seq` presence). Do not log message text, full user identifiers, tokens,
or unrestricted message payloads. The diagnostic must be disabled by the
existing project logging gate in normal builds.

**Verify:** `flutter analyze --no-fatal-warnings --no-fatal-infos ...` → no new
errors; `git diff --check` → exit 0.

## Test plan

- Equal group `seq`, different `msgID/id` in one pending batch → one row.
- Equal group `seq`, SDK/archive-shaped copies → one row and canonical
  preference retained.
- Same sender/content but different group `seq` → two rows.
- Existing outgoing/self-message and C2C dedupe tests remain green.
- Run the targeted test command, then the full test suite if the targeted
  tests pass: `flutter test test`.

## Done criteria

- [ ] The batch path cannot commit two messages with the same canonical group
  `seq` identity and element type.
- [ ] Distinct group sequences and distinct legitimate sends remain separate.
- [ ] New regression tests pass and existing `message_ordering_test.dart`
  coverage remains green.
- [ ] Targeted analyze and formatting checks pass.
- [ ] Only the two in-scope source/test files are modified.

## STOP conditions

- The live code no longer contains the `pending`/`flushPending` structure
  described above.
- The proposed change would merge messages based only on text, timestamp, or
  sender without a canonical sequence/identity proof.
- The fix requires changing C2C direction, outgoing stable IDs, pagination,
  or server/SDK behavior.
- The new test cannot distinguish same-seq copies from legitimate different
  seq sends.

## Maintenance notes

Any future inbound batching, chunked reveal, or archive/SDK normalization must
reuse the canonical dedupe function. Reviewers should inspect the “same seq is
one message / different seq is two messages” invariant whenever message
identity code changes. Keep the diagnostic fields stable so production reports
can prove whether duplicate rows originate before or after the batch flush.
