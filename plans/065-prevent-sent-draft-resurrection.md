# Plan 065: Prevent sent-message draft resurrection

> **Executor instructions**: Follow this plan step by step. Run every
> verification command before moving on. If a STOP condition occurs, stop and
> report instead of broadening the change. Update the `plans/README.md` status
> row when complete.
>
> **Drift check (run first)**: `git diff --stat 9f7c46e..HEAD -- lib/src/chat.dart lib/src/chat_page/chat_draft_controller.dart lib/src/services/conversation_local/conversation_draft_service.dart lib/src/services/conversation_local/conversation_local_store.dart test/chat_input_composition_guard_test.dart test/conversation_local_store_draft_test.dart`

## Status

- **Execution**: Implemented 2026-08-23; core draft/controller and local-store
  tests pass. One existing composition contract has a pre-existing path/assert
  failure unrelated to this plan; real-device send/lifecycle verification is
  still required.
- **Priority**: P0
- **Effort**: M
- **Risk**: MED
- **Depends on**: none; preserve plans 053, 056, 060
- **Category**: bug
- **Planned at**: commit `9f7c46e`, 2026-08-23

## Why this matters

After a successful send, the chat callback asynchronously clears the local
draft, but `deactivate` and `dispose` can immediately persist the text still
held by the text controller. The old text then appears again in the
conversation list. A second risk is that drafts are cleared by exact
conversation ID while group IDs can be represented as bare, `group_`-prefixed,
or equivalent canonical IDs. The fix must make send completion authoritative
for that conversation and must not alter normal draft persistence while a user
is genuinely editing.

## Current state

Relevant files:

- `lib/src/chat.dart` — host lifecycle, input change callback, send callback,
  draft load/save/clear.
- `lib/src/chat_page/chat_draft_controller.dart` — 250 ms debounce and write
  generation invalidation.
- `lib/src/services/conversation_local/conversation_draft_service.dart` —
  local-only draft API and notifier patch.
- `lib/src/services/conversation_local/conversation_local_store.dart` —
  SQLite draft columns and conversation upsert merge.
- `test/chat_input_composition_guard_test.dart` — existing source contract for
  stale queued draft writes.
- `test/conversation_local_store_draft_test.dart` — existing draft merge and
  clear behavior tests.

The send callback currently starts cleanup without awaiting it:

```dart
// lib/src/chat.dart:8484
if (conversationId.isNotEmpty) {
  unawaited(_clearChatLocalDraftAfterSend(conversationId));
}
```

Both lifecycle callbacks can save the controller contents independently:

```dart
// lib/src/chat.dart:8691 and 8733
unawaited(_persistChatLocalDraft());
```

The save path reads the current controller text and queues it using the
controller generation:

```dart
// lib/src/chat.dart:1186-1191
final text = _chatController.textFieldController
        ?.textEditingController?.text ?? '';
await _persistChatLocalDraftText(text, _draft.writeGeneration);
```

The clear path increments the generation and queues a database clear, but does
not prevent a later lifecycle save from reading stale controller text:

```dart
// lib/src/chat.dart:1193-1210
_draft.clear();
_draftWriteTail = _draftWriteTail.then((_) async {
  await ConversationDraftService.instance.clearDraft(conversationID: id);
});
```

The local store intentionally preserves the existing draft during SDK
conversation upsert (`conversation_local_store.dart:3778-3779`). This is
correct for ordinary SDK refreshes, but means an incorrectly targeted or
out-of-order clear can make the old text visible again.

The draft service currently passes one exact ID to SQLite
(`conversation_draft_service.dart:12-37`); it does not resolve equivalent
conversation IDs.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Draft/controller tests | `flutter test test/chat_input_composition_guard_test.dart test/conversation_local_store_draft_test.dart test/chat_page_controllers_test.dart` | all pass |
| Conversation regression | `flutter test test/conversation_preview_after_clear_send_test.dart test/conversation_list_notifier_test.dart test/conversation_sync_reload_coalesce_test.dart` | all pass |
| Static hygiene | `git diff --check` | exit 0 |
| Focused analysis | `flutter analyze lib/src/chat.dart lib/src/chat_page/chat_draft_controller.dart lib/src/services/conversation_local/conversation_draft_service.dart lib/src/services/conversation_local/conversation_local_store.dart` | no new errors attributable to this plan |

## Scope

**In scope**:

- send-completion suppression/ordering for host draft saves;
- equivalent group/conversation ID handling for clear and load where needed;
- lifecycle and local-store regression tests;
- diagnostic events that identify save suppression, generation, canonical ID,
  and operation ordering without logging message text or user IDs.

**Out of scope**:

- changing Tencent IM SDK draft behavior or enabling SDK draft persistence;
- changing conversation list sorting or message history sources;
- changing text composition, emoji, @mention, or input controller behavior;
- changing the intentional rule that SDK upsert preserves an existing draft;
- broad changes to group ID canonicalization outside draft operations.

## Git workflow

- Branch: `codex/065-prevent-sent-draft-resurrection`
- Follow the repository's existing commit convention; use one logical commit
  for implementation and tests.
- Do not push unless explicitly instructed.

## Steps

### Step 1: Add characterization tests for the race

Add tests in `test/chat_input_composition_guard_test.dart` or a new focused
`test/chat_send_draft_race_test.dart` covering:

1. A debounced old text queued before send is invalidated by send completion.
2. A lifecycle save invoked after send completion is suppressed even when the
   text controller still contains the old text.
3. A legitimate edit after send completion is allowed to create a new draft.
4. Clear and save operations are serialized; an old save cannot complete after
   the clear and resurrect text.
5. Group IDs in bare and `group_` forms clear the same stored draft, while two
   genuinely different conversation IDs remain independent.

Model the tests on the existing `ChatDraftController` tests and local-store
draft tests. Prefer deterministic fake callbacks/futures over sleeps.

**Verify**: the new race tests must fail against the current implementation for
the stale lifecycle save case, while all existing draft tests continue to pass.

### Step 2: Introduce an explicit send-clear barrier

Extend `ChatDraftController` or add a narrowly scoped host-side coordinator in
`lib/src/chat_page/chat_draft_controller.dart` so it owns:

- the current write generation;
- a per-conversation `sendClearGeneration`/suppression marker;
- the serialized write tail;
- a predicate used by `_persistChatLocalDraft` to skip lifecycle saves that
  belong to the just-completed send.

The barrier must be conversation-scoped and must be cleared when a new user
edit is observed. Do not use a global boolean: the chat route can be reused
for another conversation. Keep the existing 250 ms debounce behavior.

**Verify**: controller/race tests pass, including “new edit after send is
persisted”; no test relies on wall-clock timing.

### Step 3: Make chat lifecycle ordering authoritative

Update `lib/src/chat.dart` so `messageDidSend` records the successful send
before any lifecycle save can run. For successful sends, clear the controller
state or mark the send-clear barrier before scheduling the database clear. For
failed sends, preserve the draft unless the product's existing contract/tests
explicitly require clearing it; do not silently change failure retry behavior.

Make `_persistChatLocalDraft` check the barrier immediately before reading and
again inside the serialized write continuation. `deactivate` and `dispose`
must be safe to call repeatedly and must not enqueue an old non-empty value
after a successful send. Keep the existing route/overlay distinction: covering
the chat with a profile page is not a new conversation.

**Verify**: run the race tests and inspect logs/source to confirm the sequence
is `send_clear_mark → lifecycle_save_suppressed → clear_done`, with no text
content or identifiers emitted in production logs.

### Step 4: Canonicalize draft clear/load IDs at the draft boundary

In `ConversationDraftService` and, if required, the local store, resolve the
small set of equivalent IDs for the active conversation using existing
`MessageConversationId`/`ChatIdFormat` helpers. Do not rewrite unrelated
conversation identity storage. Clear all matching draft rows atomically or
through the existing serialized store queue; load should prefer the canonical
row and fall back only to an equivalent row when the canonical row is empty.

Add tests for bare group ID, `group_` prefix, and the actual `@TGS#...` ID. A
failed lookup/empty ID must not clear another conversation.

**Verify**: local-store draft tests pass and a clear followed by an SDK-style
upsert leaves `draftText == null` for every equivalent row.

### Step 5: Preserve SDK upsert semantics and add regression coverage

Do not remove the existing `existing.draftText` preservation in
`conversation_local_store.dart`. Instead, test the complete intended behavior:

- ordinary SDK refresh preserves a draft while the user is editing;
- successful send barrier plus clear leaves no draft;
- a later SDK refresh cannot restore the sent draft;
- a new post-send edit is preserved by the next SDK refresh.

Add a source contract if needed to prevent future changes from removing the
barrier check from both lifecycle save paths.

**Verify**: run the full command set in “Commands you will need”; all tests
pass and `git diff --check` is clean.

## Test plan

- `test/chat_send_draft_race_test.dart` (new): deterministic send/lifecycle
  ordering, stale-write suppression, legitimate post-send edit, ID aliases.
- `test/chat_input_composition_guard_test.dart`: retain existing generation
  invalidation contract.
- `test/conversation_local_store_draft_test.dart`: equivalent-ID clear and
  SDK-upsert-after-clear behavior.
- `test/conversation_preview_after_clear_send_test.dart`: conversation preview
  no longer shows `[草稿]` after a successful send and subsequent refresh.

Use existing test helpers and avoid integration tests that require a logged-in
IM SDK. Do not assert log text containing message bodies, user IDs, or group
IDs.

## Done criteria

- [ ] No lifecycle save can write a non-empty pre-send value after successful
      send completion.
- [ ] A successful send followed by SDK conversation refresh shows no draft.
- [ ] A new edit after send still persists normally.
- [ ] Equivalent group ID representations clear/load one logical draft.
- [ ] All focused and conversation regression tests pass.
- [ ] `flutter analyze` reports no new errors in the in-scope files.
- [ ] `git diff --check` exits 0.
- [ ] Only the in-scope source/test files and this plan/index are modified.
- [ ] `plans/README.md` status row is updated.

## STOP conditions

Stop and report if:

- the live code no longer contains the cited lifecycle saves or send callback;
- canonical ID equivalence cannot be resolved without changing global message
  or conversation identity rules;
- the barrier would suppress a legitimate edit, mention, emoji, or retry draft;
- a test shows an ordinary SDK refresh loses an actively edited draft;
- fixing the race requires changing the SDK history/message source or files
  outside the Scope section.

## Maintenance notes

- Any new route lifecycle callback that saves drafts must use the same barrier;
  do not call the local store directly.
- Any future send path (media, custom cards, wallet messages) must declare
  whether it is a successful send-clear or a retry-preserving failure.
- Reviewers should inspect operation ordering, canonical ID coverage, and the
  absence of message/user/group values in diagnostics.
- Tombstones for deleted conversations and RefreshBus event coalescing are
  separate concerns and are intentionally not included here.
