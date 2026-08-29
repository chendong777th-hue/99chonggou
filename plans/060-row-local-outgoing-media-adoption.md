# Plan 060: Make outgoing media adoption and receipts row-local

> **Executor instructions**: Add characterization tests before touching list
> mutation. Preserve ordering, dedupe, historical retention, stable IDs, and SDK
> semantics. STOP on any message loss or duplicate-row result.
>
> **Drift check (run first)**:
> `git diff --stat 9f7c46e..HEAD -- third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/chat_ui_state_store.dart test/message_ordering_test.dart test/outgoing_image_bubble_dedupe_contract_test.dart`
> Reconcile with Plans 056/057 if they changed global message revisions or list
> viewport policy. STOP rather than reverting their behavior.

## Status

- **Execution**: Implemented 2026-08-23; automated ordering, dedupe, history and
  media suites pass. Awaiting the planned on-device Profile receipt-storm run.
- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: plans/058-stream-gallery-placeholders-before-photokit.md; preserve plans/018, 045, 049, 053, 056 and 057
- **Category**: perf
- **Planned at**: commit `9f7c46e`, 2026-08-23

### Implementation notes

- Same-index optimistic adoption now replaces authoritative storage and emits a
  row revision only when there is exactly one match and newest-first order stays
  valid.
- Missing rows, duplicate collapse and reordered rows retain the existing full
  list replacement and pin path.
- Final SDK success/failure receipts use the same structural distinction. A
  same-index receipt does not issue a list revision or pull a scrolled-up user
  back to the bottom.
- Stable/client/msgID aliases are migrated before the row revision, so the
  mounted row resolves the latest authoritative SDK object.

## Why this matters

Each selected image currently creates a stable optimistic row, but SDK adoption
still copies/scans the full list and calls `setMessageList(replace: true)`. Final
send receipt then updates storage and unconditionally bumps the full-list
revision, even when the row stayed at the same index. For N images this produces
roughly 2N whole-list invalidations after the initial batch. Keep the authority
list correct while publishing row-local revisions whenever order and membership
did not change.

## Current state

- `tui_chat_separate_view_model.dart::_swapOutgoingMessage` scans the complete
  list, collapses matching aliases/stable IDs, then calls
  `setMessageList(convID, next, replace: true)` and a soft pin.
- `tui_chat_global_model.dart::updateMessage` replaces the sent row in storage,
  preserves paths/order metadata, marks the row changed, then always calls
  `_bumpMessageListRevisionFor`, including `send_done_inplace_invalidate`.
- Upload progress 1–99 already uses row-local `ChatUiStateStore` revisions; use
  that as the behavioral pattern, not as permission to mutate SDK objects in
  place without updating authoritative storage.
- Plans 018/045/049/053 protect duplicate collapse, visible self-sent rows,
  retention across history commits, and identical-history skip. These invariants
  are higher priority than this optimization.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Ordering/dedupe | `flutter test test/message_ordering_test.dart test/outgoing_image_bubble_dedupe_contract_test.dart` | all pass |
| History safety | `flutter test test/chat_history_commit_signature_test.dart test/chat_history_recovery_coordinator_test.dart` | all pass |
| Media safety | `flutter test test/chat_media_optimistic_send_contract_test.dart test/chat_image_send_performance_contract_test.dart` | all pass |
| Hygiene | `git diff --check` | exit 0 |

## Scope

**In scope**:
- outgoing optimistic-to-SDK row adoption
- final send success/failure receipt for an already-present row
- row/list revision policy and focused tests

**Out of scope**:
- inbound messages, pagination, history source policy, SDK send protocol,
  compression, retry UI, list ordering rules, memory-window constants, or pin UI
- replacing authoritative message storage with UI-only state

## Git workflow

- Branch: `codex/060-row-local-media-adoption`
- Use at least two commits: characterization tests, then implementation.
- Commit example: `perf: keep media adoption row-local`.
- Do not push unless instructed.

## Steps

### Step 1: Build an acceptance ledger in tests

Add tests covering optimistic image and video adoption when:

- the optimistic row is present at its expected index;
- an SDK echo with the new ID already exists;
- the placeholder is missing;
- two same-second sends have identical content but different stable IDs;
- a history commit races with adoption;
- success, failure, retry, remote URL, local path, layout size, progress and
  `msgID` change;
- ordering keys change versus remain identical.

Assert both the authoritative list and revision effects: same-index replacement
must issue a row revision only; insertion, removal of an orphan duplicate, or
ordering change must issue one full-list revision.

**Verify**: new revision assertions fail on the old implementation while all
existing ordering/dedupe tests pass.

### Step 2: Introduce a typed adoption result

Extract the pure correlation/replacement decision into a helper returning a
typed result such as: `notFound`, `inPlace(index, aliases)`, or
`structural(nextList, reason)`. It must use the existing stable-ID, id, msgID,
path and correlation rules rather than inventing a new identity algorithm.

For `inPlace`, replace the authoritative storage entry, migrate aliases, path,
height and progress metadata, and publish only the row revision. For
`structural`, retain the existing `setMessageList(replace: true)` path exactly.

**Verify**: pure helper tests cover every result type and all dedupe tests pass.

### Step 3: Apply the same distinction to final SDK receipts

In `updateMessage`, compute whether membership or newest-first order actually
changed. If the target row exists at the same index and its ordering keys remain
valid, update authoritative storage plus row aliases/revision without bumping
the full-list revision. If the row is missing, a duplicate must collapse, or
ordering changed, keep the existing sort and full-list revision.

Status, URL, local path, progress, revoke and failure changes must still be
observable through the row revision and must remain part of history signatures.

**Verify**: acceptance ledger, history signature, ordering and media tests pass.

### Step 4: Remove completion-time soft pins only when redundant

For a same-index row-local adoption, do not request a bottom pin: row height and
stable identity are already preserved. Keep pin/list-settle behavior for a true
structural insert or reorder. Add a test covering a user intentionally scrolled
up so a send receipt cannot pull the viewport down.

**Verify**: media scroll contracts pass and source tests show no pin on the
in-place branch.

### Step 5: Profile receipt storms

Send 1, 5, 10, and maximum images in a 360-message conversation. Count
`set_message_list_ms`, full-list revision bumps, row revisions, duplicates and
ordering changes. Expected: the common successful path has one initial batch
commit and row-local adoptions/receipts; full-list revisions occur only for
documented structural cases.

## Test plan

- Image/video, success/failure/retry/cancel, rapid same-second sends.
- SDK echo before and after local adoption; reconnect and history refresh race.
- Remote URL and media availability changes update the bubble.
- User at bottom versus intentionally scrolled up.
- C2C and group conversations; canonical aliases; 360-message window.

## Done criteria

- [ ] Common same-index adoption and receipt do not bump full-list revision.
- [ ] Structural insert/dedupe/reorder still uses one authoritative list commit.
- [ ] No duplicate, missing, reordered, or stale-status messages in all tests.
- [ ] Plans 018/045/049/053/056/057 regression tests remain green.
- [ ] Profile demonstrates full-list commits no longer scale as approximately 2N.
- [ ] `git diff --check` passes and no out-of-scope files changed.

## STOP conditions

- Authoritative list and visible row can disagree after a row-local update.
- Stable identity is unavailable or ambiguous for two legitimate sends.
- A history race loses a sent row, state, URL, or local path.
- Avoiding a list revision changes ordering, pagination, retention, or viewport.
- Implementation requires weakening existing dedupe or retention contracts.

## Maintenance notes

Row-local does not mean UI-only: authoritative storage must receive the new
message object before publishing the row revision. Review every future media
field addition against both row signatures and history commit signatures.
