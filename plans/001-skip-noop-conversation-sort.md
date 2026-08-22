# Plan 001: Skip no-op sort on lastMessage local patch

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: Open
> `lib/src/services/conversation_local/conversation_list_notifier.dart`
> around `applyLastMessageLocally` and confirm it still **unconditionally**
> calls `next.sort(ConversationLocalStore.compareConversationsForUi)` and
> `_bumpRevisionsForChange(orderOrMembershipChanged: true)` after a successful
> lastMessage patch. If that is already conditional, STOP — this plan is stale.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: perf
- **Planned at**: working tree 2026-08-20 (no git SHA available)
- **Execution**: DONE (2026-08-20)

## Why this matters

Inbound preview updates call `ConversationListNotifier.applyLastMessageLocally`. After patching one row it **always** sorts the whole UI window and **always** increments `structureRevision`. Feed treats structure changes as “list identity changed”: it cannot use `patchConversationFeedRowsById`, and DevTools shows Build + CPU `sort` on every new message — even when that conversation was already at the correct pin/time slot (already at the top, or a status-only upgrade).

After this plan: if the patched row is already in UI order relative to its neighbors, skip `sort`, keep `structureRevision` unchanged, and still refresh preview/unread via `contentRevision` + `notifyListeners`. Conversations that become hotter still move (full sort + structure bump).

## Current state

### Files

- `lib/src/services/conversation_local/conversation_list_notifier.dart` — UI window; `applyLastMessageLocally` (~4048–4164)
- `lib/src/services/conversation_local/conversation_local_store.dart` — `compareConversationsForUi` / `_sortConversations` (~3344–3587)
- `test/conversation_list_notifier_incremental_test.dart` — existing lastMessage / bumpUnread tests; extend here
- `test/conversation_send_status_arrow_test.dart` — same-msgID status upgrade; must still pass (no reorder expected)

### Sort order (do not invent a new comparator)

From `_sortConversations` in `conversation_local_store.dart`:

```dart
// pin DESC, then activeTimeMs DESC, then orderkey DESC, then conversationID
```

`applyLastMessageLocally` already sets `orderkey` from `preferred.timestamp` when `ts > 0`. That can change `activeTimeMs` and therefore position.

### Unconditional sort + structure bump (the bug for perf)

After a successful patch the method does:

```dart
    next.sort(ConversationLocalStore.compareConversationsForUi);
    _conversations = next;
    // ... hydrate patch with reorder: true ...
    _bumpRevisionsForChange(orderOrMembershipChanged: true);
    _notifyIfAllowed(reason: 'last_message_local');
```

`_bumpRevisionsForChange`:

```dart
  void _bumpRevisionsForChange({required bool orderOrMembershipChanged}) {
    _contentRevision++;
    if (orderOrMembershipChanged) {
      _structureRevision++;
    }
  }
```

### Optimistic unread (must keep)

`bumpUnread: true` still +1 `unreadCount` and `ConversationUnreadAggregate.applyNotifiableDeltas`. Do not remove or gate unread on sort.

### Conventions

- Match existing notifier tests: `setConversationsForTest`, `clearSession` in `tearDown`, `ConversationLocalStore.instance.debugOwnerUserId = 'test_user'`.
- Prefer a small `@visibleForTesting` helper on the notifier or a top-level function in the same file rather than a new service.
- Do not change `compareConversationsForUi`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Tests (this change) | `flutter test test/conversation_list_notifier_incremental_test.dart test/conversation_send_status_arrow_test.dart test/conversation_revoked_preview_cache_test.dart` | all pass |
| Nearby regression | `flutter test test/conversation_list_notifier_test.dart test/conversation_unread_guard_test.dart` | all pass |

There is no reliable full-repo `flutter analyze` gate (README: historical warnings). Do not use analyze-as-done.

## Suggested executor toolkit

- None required. Stay in Dart unit tests; do not profile on device.

## Scope

**In scope** (the only files you should modify):

- `lib/src/services/conversation_local/conversation_list_notifier.dart`
- `test/conversation_list_notifier_incremental_test.dart`

**Out of scope** (do NOT touch):

- `lib/src/conversation.dart` — Feed page; 002 owns listenable splitting
- `lib/src/widgets/conversation_feed/**` — Feed UI
- `lib/src/services/conversation_local/conversation_sync_service.dart` — persist path; `applyConversationsFromStore` already has its own sort
- `lib/src/services/conversation_local/conversation_tab_store.dart` — SDK-primary store
- `ConversationPerfFlags` values, especially `conversationListSdkPrimary`
- Unread guard rules, pin reorder delay, hydrate budget
- Any UIKit / `third_party/` file

## Git workflow

- No git repo was present when this plan was written. If the operator has git: branch `advisor/001-skip-noop-conversation-sort`, one commit, message like `perf: skip conversation window sort when lastMessage patch does not move`. Do not push unless asked.

## Steps

### Step 1: Add a neighbor-order helper

In `conversation_list_notifier.dart`, add a private (or `@visibleForTesting` static) helper:

```dart
/// True if [index] must move under [ConversationLocalStore.compareConversationsForUi].
/// Assumes [list] was sorted before the in-place field update at [index].
static bool conversationNeedsUiReorderAfterPatch(
  List<V2TimConversation> list,
  int index,
) {
  if (index < 0 || index >= list.length) {
    return false;
  }
  final current = list[index];
  if (index > 0) {
    final prev = list[index - 1];
    // current belongs before prev → move toward head
    if (ConversationLocalStore.compareConversationsForUi(current, prev) < 0) {
      return true;
    }
  }
  if (index + 1 < list.length) {
    final next = list[index + 1];
    // current belongs after next → move toward tail
    if (ConversationLocalStore.compareConversationsForUi(current, next) > 0) {
      return true;
    }
  }
  return false;
}
```

If a sorted list is patched at `index`, checking only neighbors is sufficient (standard insertion-sort invariant). Do **not** reimplement pin/time rules.

**Verify**: helper compiles; no tests yet is OK if Step 2 lands in the same edit.

### Step 2: Use the helper in `applyLastMessageLocally`

Keep the existing loop that mutates `next[i]` (lastMessage, orderkey, optional unread). After `changed == true`, **before** assigning `_conversations`:

1. `final needsReorder = conversationNeedsUiReorderAfterPatch(next, i);`
   - You must capture `i` (the patched index) before breaking the loop. If the current code `break`s without storing index, store `patchedIndex`.
2. If `needsReorder`: `next.sort(ConversationLocalStore.compareConversationsForUi);`
3. `_conversations = next;`
4. `_patchTypeHydrateConversation(..., reorder: needsReorder, ...)`
   - Today `reorder: true` is hardcoded. Passing `false` when the row did not move avoids hydrate-window reshuffle.
5. `_bumpRevisionsForChange(orderOrMembershipChanged: needsReorder);`
6. Keep TabStore `applyPatches` and unread aggregate as they are.

When `needsReorder` is false, `_conversations` order (ID sequence) must be identical to before the patch.

**Verify**: `dart analyze lib/src/services/conversation_local/conversation_list_notifier.dart` if available; otherwise rely on tests in Step 3.

### Step 3: Tests

In `test/conversation_list_notifier_incremental_test.dart`, add:

1. **Already-hot row does not bump structure / order**
   - Seed `c2c_hot` orderkey `200` and `c2c_old` orderkey `100` (hot already first).
   - `applyLastMessageLocally` on `c2c_hot` with a newer timestamp (e.g. `250`) and `bumpUnread: true`.
   - Expect: ID order still `[c2c_hot, c2c_old]`.
   - Expect: `structureRevision` **unchanged**.
   - Expect: `contentRevision` **increased**.
   - Expect: `unreadCount` +1 and `lastMessage.msgID` updated.
   - Wait `60ms` if this file’s other tests wait for coalesced notify; match local style.

2. **Colder row becomes hottest → reorder + structure bump**
   - Same seed.
   - Patch `c2c_old` with timestamp `300`.
   - Expect: first ID is `c2c_old`.
   - Expect: `structureRevision` **increased**.

3. Keep existing tests: `virtual hydrate reflects lastMessage immediately`, `inbound lastMessage bumpUnread updates unread with preview`, `lastMessage local does not shrink conversation window`.

**Verify**:

```bash
flutter test test/conversation_list_notifier_incremental_test.dart test/conversation_send_status_arrow_test.dart test/conversation_revoked_preview_cache_test.dart
```

→ all pass.

## Test plan

- New cases listed in Step 3 (no-op order vs must-move).
- Pattern: `test/conversation_list_notifier_incremental_test.dart` existing `applyLastMessageLocally` tests.
- Edge already covered elsewhere: same msgID status upgrade (`conversation_send_status_arrow_test.dart`) — if preferLastMessage keeps orderkey equal, `needsReorder` is false; structure must not bump.

## Done criteria

- [ ] `applyLastMessageLocally` does not call `sort` when neighbor order is already valid
- [ ] `structureRevision` unchanged in the already-hot test; incremented in the colder-becomes-hot test
- [ ] Optimistic unread +1 still happens in the already-hot test
- [ ] `flutter test` commands in Commands table all pass
- [ ] `git status` (if git exists) shows only in-scope files
- [ ] `plans/README.md` row 001 updated

## STOP conditions

Stop and report (do not improvise) if:

- `applyLastMessageLocally` no longer exists or lastMessage is applied only via `applyConversationsFromStore`.
- Hydrate patch **requires** `reorder: true` even when ID order is unchanged (e.g. tests fail with skeleton/wrong typeIndex). Revert hydrate `reorder` to `true` and report; still skip window `sort` + structure bump if that part is green.
- You think you need to change `compareConversationsForUi` or pin delay.
- Any test in the Commands table fails twice after a reasonable fix.

## Maintenance notes

- Reviewer: confirm pinned rows still stay above unpinned after a lastMessage patch (pin flag unchanged in this method; neighbor check uses the real comparator).
- `applyConversationsFromStore` still full-sorts; do not “optimize” it in this plan.
- Follow-up (plan 002): Feed can trust `structureRevision` as “ID order / membership changed”.
