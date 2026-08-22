# Plan 046: Settle-jump conversation feed hydrate so fling blanks recover

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt below to the live files. If
> `_requestVirtualHydrateForFeedScroll` already passes `allowWindowJump` on
> `force: true`, or `_ensureTypeIndexHydratedImpl` already notifies on a
> settle covered-skip, mark those steps DONE / adjust and report — do not
> duplicate.

## Status

- **Priority**: P0
- **Effort**: S–M
- **Risk**: MED (settle jump must not run mid-fling; must not turn every
  scroll-end into a SQLite full-window reload)
- **Depends on**: none
- **Category**: bug
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Issue**: omit
- **Status**: DONE (2026-08-22) — settle jump + covered-skip notify; mid-scroll clamp unchanged

## Why this matters

The message-tab conversation list is a true virtual list: `itemCount` is the
on-disk type total, but only a hydrate window of ~72–88 rows holds real
`V2TimConversation` objects. Rows outside that window paint gray skeletons
(or an empty `vidx_gap` box). Users describe this as “滑动空白，重启才好”.

Restart works because offset resets to 0 and the window rehydrates from the
head. The data is still in SQLite. Two gates make a far fling permanent:

1. **No teleport on settle.** Mid-scroll hydrate clamps `center` to the
   current window ± `virtualHydrateRadius` (~20–28). Chat-return already
   passes `allowWindowJump: true`. Ordinary `scroll_end` does **not**, so a
   viewport left outside that neighborhood never loads.
2. **Cache-only + no notify.** While `isFeedScrolling` is true, a hydrate
   writes `_typeHydrate` then returns without `notifyListeners`. The virtual
   `itemBuilder` reads `_typeHydrate` directly, so it would paint real rows
   **if** the list rebuilt. Covered-skip on settle often returns without
   notify when `_slidingWindowUserExpanded` is already true, so skeletons
   stay even after memory has the page.

Product intent: after the finger/fling **stops**, the visible rows must
become real conversations (or the window must jump to the viewport). Do
**not** start SQLite hydrate on every Android scroll frame.

## Current state

**Virtual list paints skeletons for missing indexes** —
`lib/src/widgets/conversation_feed/conversation_feed_body.dart`
`_buildVirtualFeedListView` (~785–910):

```dart
final conversation =
    notifier.conversationAtTypeIndex(convType, typeIndex);
if (conversation == null) {
  _scheduleVirtualSkeletonHydrate(
    convType: convType,
    centerIndex: typeIndex,
    nearEnd: typeIndex >= total - 8,
  );
  return KeyedSubtree(
    key: ValueKey<String>('vidx:$typeIndex'),
    child: buildConversationFeedRowSkeleton(...),
  );
}
```

Android skeleton requests are blocked while scrolling
(`conversationVirtualSkeletonMayRequestHydrate` +
`ConversationPerfFlags.virtualHydrateOnlyOnScrollSettle`). Keep that.

**Settle hydrate does not jump** —
`lib/src/conversation.dart` `_onFeedScrollEndSettled` (~1609–1622) calls
`_requestVirtualHydrateForFeedScroll(..., force: true)`. That method
(~1634–1682) ends with:

```dart
    _lastVirtualHydrateCenter = center;
    unawaited(
      ConversationListNotifier.instance.ensureTypeIndexHydrated(
        convType: type,
        centerIndex: center,
      ),
    );
```

No `allowWindowJump`, no `forceReload`, no settle-notify flag.
`_scheduleVirtualFeedHydrateAfterChatReturn` (~1685–1752) already passes
`forceReload: true, allowWindowJump: true` — copy that idea **only when
the viewport center is outside the live window ± radius**.

Public window readers already exist on the notifier (~183–197):

```dart
int hydratedStartOffsetForType(int convType);
int hydratedLengthForType(int convType);
```

**Clamp + teleport reject + cache-only** —
`lib/src/services/conversation_local/conversation_list_notifier.dart`
`_ensureTypeIndexHydratedImpl` (~985–1067):

```dart
    if (cur.isNotEmpty && !allowWindowJump) {
      final minC = (curStart - radius).clamp(0, totalNow);
      final maxC = (curEnd + radius).clamp(0, totalNow);
      if (center < minC) {
        center = minC;
      } else if (center > maxC) {
        center = maxC;
      }
    }
    ...
    if (!forceReload &&
        conversationVirtualHydrateCovered(...)) {
      if (!_slidingWindowUserExpanded && curStart > 0 && cur.isNotEmpty) {
        await _rebuildConversationsFromTypeHydrates();
      }
      return;
    }
    if (cur.isNotEmpty && !allowWindowJump) {
      ...
      if (!touchesOrOverlaps) {
        // logs hydrate_page_skip_teleport and return
        return;
      }
    }
    ...
    final cacheOnlyWhileScrolling =
        _isFeedScrollingNow && !forceReload && !allowWindowJump;
    if (cacheOnlyWhileScrolling) {
      // writes _typeHydrate, no notify
      return;
    }
```

`_rebuildConversationsFromTypeHydrates` (~1084–1107) also returns **without
notify** when the merged `_conversations` list is unchanged. Virtual rows
do not need `_conversations` to change — they need `notifyListeners` so
`itemBuilder` re-reads `_typeHydrate`.

**Policy file to extend** (pure functions, already unit-tested):
`lib/src/services/conversation_local/conversation_virtual_hydrate_policy.dart`

Existing tests to match:
`test/conversation_virtual_hydrate_policy_test.dart`
`test/conversation_virtual_skeleton_hydrate_policy_test.dart`

**Repo conventions**: keep policy math in the policy file; keep SQLite /
`notifyListeners` in the notifier; keep scroll wiring in `conversation.dart`.
Do not add comments that restate the function name. Chinese comments for
Why only.

`ConversationPerfFlags.conversationListSdkPrimary` defaults **false**. The
sdkPrimary early-return in `ensureTypeIndexHydrated` (~918–927) must stay
unchanged (TabStore path). New `forceNotify` is ignored there.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Policy tests | `flutter test test/conversation_virtual_hydrate_policy_test.dart test/conversation_virtual_skeleton_hydrate_policy_test.dart` | all pass |
| New settle-jump tests | `flutter test test/conversation_virtual_hydrate_policy_test.dart` | includes new jump / notify cases, all pass |
| Wire contract | `flutter test test/conversation_feed_settle_jump_contract_test.dart` | all pass (new file) |
| Related virtual tests | `flutter test test/conversation_virtual_index_cache_test.dart test/conversation_virtual_skeleton_hydrate_policy_test.dart` | all pass |

This repo uses `flutter test` (not `dart test`). There may be no `.git`.
Do not `git init`. Do not commit unless the operator asks.

## Scope

**In scope** (the only files you should modify):

- `lib/src/services/conversation_local/conversation_virtual_hydrate_policy.dart`
- `lib/src/services/conversation_local/conversation_list_notifier.dart`
- `lib/src/conversation.dart`
- `test/conversation_virtual_hydrate_policy_test.dart`
- `test/conversation_feed_settle_jump_contract_test.dart` (create)
- `plans/README.md` (status row only, when done)

**Out of scope** (do NOT touch, even though they look related):

- `ConversationPerfFlags.virtualHydrateOnlyOnScrollSettle` / Android “no
  hydrate while scrolling” — keep. Mid-fling SQLite is the hitch they
  already paid to avoid.
- `virtualHydrateRadius` / `virtualHydrateMaxPerType` / cacheExtent
  numbers — do not “fix” blanks by enlarging the window.
- `conversationVirtualListEnabled` / `conversationListSdkPrimary`
- `tim_uikit_chat_history_message_list.dart` (chat history, not this list)
- Folder-filter non-virtual `ListView` (`_selectedFolderId != null`)
- `_scheduleVirtualFeedHydrateAfterChatReturn` logic (already jumps)
- Sync / persist / unread badge / pin reorder

## Git workflow

- This workspace may have **no `.git`**. Do not `git init`.
- If `.git` exists: do **not** commit unless the operator asks.
- Do not push or open a PR unless asked.

## Steps

### Step 1: Add settle-jump + covered-notify policy functions

In `conversation_virtual_hydrate_policy.dart` add two pure functions.

**Jump** — viewport center is outside the live window’s clamp neighborhood
(same math as `_ensureTypeIndexHydratedImpl` when `!allowWindowJump`):

```dart
/// 停滑时：视口中心已离开旧窗 ± [radius]，才允许跳窗。
/// 滑动中仍禁止瞬移；空窗且中心不在 0 也要跳，否则远端 offset 永为骨架。
bool conversationVirtualHydrateShouldJumpWindow({
  required int viewportCenter,
  required int curStart,
  required int curLength,
  required int radius,
}) {
  if (radius < 0) {
    return true;
  }
  if (curLength <= 0) {
    return viewportCenter > 0;
  }
  final curEnd = curStart + curLength;
  return viewportCenter < curStart - radius ||
      viewportCenter > curEnd + radius;
}
```

Cases the tests must lock:

| viewportCenter | curStart | curLength | radius | result |
|----------------|----------|-----------|--------|--------|
| 100 | 80 | 40 | 20 | false (100 is inside [60, 140]) |
| 141 | 80 | 40 | 20 | true (`curEnd+radius` is 140; `>` jumps) |
| 59 | 80 | 40 | 20 | true |
| 140 | 80 | 40 | 20 | false (equal to maxC, clamp does not move) |
| 80 | 0 | 0 | 20 | true (empty window, not at head) |
| 0 | 0 | 0 | 20 | false (head empty is first-load, not a jump) |

**Covered-skip notify** — settle must notify even when the window already
covers the (possibly clamped) center:

```dart
bool conversationVirtualHydrateShouldNotifyOnCoveredSkip({
  required bool forceNotify,
  required bool slidingWindowUserExpanded,
  required int curStart,
  required bool curIsNotEmpty,
}) {
  if (forceNotify && curIsNotEmpty) {
    return true;
  }
  return !slidingWindowUserExpanded && curStart > 0 && curIsNotEmpty;
}
```

Today’s rebuild-on-skip is the second branch. Settle (`forceNotify: true`)
is the first. Empty window → false (nothing to paint).

Add tests in `test/conversation_virtual_hydrate_policy_test.dart` next to
the existing `conversationVirtualHydrateCovered` group. Model after that
file (plain `expect(...)`, no SQLite).

**Verify**:
`flutter test test/conversation_virtual_hydrate_policy_test.dart` → all
pass, including the new cases.

### Step 2: Thread `forceNotify` through hydrate and honor it on covered-skip

In `conversation_list_notifier.dart`:

1. Add `bool forceNotify = false` to `ensureTypeIndexHydrated` **and**
   `_ensureTypeIndexHydratedImpl`. Pass it through the existing serial
   gate. Do **not** add it to the sdkPrimary early-return body.

2. Replace the covered-skip inner `if` with the policy:

```dart
    if (!forceReload &&
        conversationVirtualHydrateCovered(
          center: center,
          curStart: curStart,
          curLength: cur.length,
          margin: skipMargin,
        )) {
      if (conversationVirtualHydrateShouldNotifyOnCoveredSkip(
        forceNotify: forceNotify,
        slidingWindowUserExpanded: _slidingWindowUserExpanded,
        curStart: curStart,
        curIsNotEmpty: cur.isNotEmpty,
      )) {
        _bumpRevisionsForChange(orderOrMembershipChanged: false);
        _notifyIfAllowed(reason: 'hydrate_settle_covered');
      }
      return;
    }
```

Do **not** call `_rebuildConversationsFromTypeHydrates` here just to get a
notify — that helper early-returns without notify when `_conversations`
already matches. `contentRevision++` via `_bumpRevisionsForChange` is
required so inactive-tab feed cache (`shouldReuseInactiveConversationFeed`)
does not keep the skeleton subtree.

3. Leave clamp / teleport-reject / cache-only conditions as they are.
   `allowWindowJump: true` already disables clamp, teleport reject, and
   cache-only. That is enough for the jump path.

Import the new policy symbols if this file does not already import
`conversation_virtual_hydrate_policy.dart` (it already uses
`conversationVirtualHydrateCovered` — same import).

**Verify**:
`flutter test test/conversation_virtual_hydrate_policy_test.dart test/conversation_virtual_index_cache_test.dart`
→ all pass.

### Step 3: Wire scroll_end to jump + forceNotify

In `lib/src/conversation.dart` `_requestVirtualHydrateForFeedScroll`, after
`center` is finalized and **before** the `unawaited(ensureTypeIndexHydrated)`
call, compute jump only on settle (`force == true`):

```dart
    final notifier = ConversationListNotifier.instance;
    final jump = force &&
        conversationVirtualHydrateShouldJumpWindow(
          viewportCenter: center,
          curStart: notifier.hydratedStartOffsetForType(type),
          curLength: notifier.hydratedLengthForType(type),
          radius: ConversationPerfFlags.virtualHydrateRadius,
        );
    _lastVirtualHydrateCenter = center;
    unawaited(
      notifier.ensureTypeIndexHydrated(
        convType: type,
        centerIndex: center,
        allowWindowJump: jump,
        forceReload: jump,
        forceNotify: force,
      ),
    );
```

Rules:

- `force == false` (mid-scroll): **unchanged** — still no jump, still
  Android early-return when `virtualHydrateOnlyOnScrollSettle`.
- `force == true` and viewport still in the neighborhood: `jump == false`,
  but `forceNotify: true` so covered-skip still notifies.
- `force == true` and viewport outside neighborhood: `jump == true` →
  `allowWindowJump` + `forceReload` (re-query around the real center).
- Keep `unawaited`. Do not `await` hydrate on the scroll/settle stack.
- Do not change `_scheduleVirtualFeedHydrateAfterChatReturn`.
- Folder filter early-return (`_selectedFolderId != null`) stays.

`conversation.dart` already imports the hydrate policy (it calls
`conversationVirtualHydrateCenterStepAllows`). Confirm the import; add
only if missing.

**Verify**: create and run the contract test in Step 4.

### Step 4: Source-lock contract test

Create `test/conversation_feed_settle_jump_contract_test.dart` modeled on
`test/conversation_virtual_skeleton_hydrate_policy_test.dart` / other
file-read contracts (`test/chat_cvp_measure_attempts_contract_test.dart`):

Assert `lib/src/conversation.dart` contains all of:

- `conversationVirtualHydrateShouldJumpWindow(`
- `allowWindowJump: jump`
- `forceReload: jump`
- `forceNotify: force`

Assert `conversation_list_notifier.dart` contains:

- `bool forceNotify = false`
- `hydrate_settle_covered`
- `conversationVirtualHydrateShouldNotifyOnCoveredSkip(`

Assert it does **not** contain a mid-scroll jump such as
`allowWindowJump: true` inside `_requestVirtualHydrateForFeedScroll`
unconditionally (the chat-return site may still have
`allowWindowJump: true` — that is fine; lock the settle site to the
`jump` variable).

**Verify**:
`flutter test test/conversation_feed_settle_jump_contract_test.dart test/conversation_virtual_hydrate_policy_test.dart test/conversation_virtual_skeleton_hydrate_policy_test.dart`
→ all pass.

## Test plan

- **New policy cases** in
  `test/conversation_virtual_hydrate_policy_test.dart`:
  jump true/false table above; covered-notify true when `forceNotify` and
  window non-empty; false when window empty; legacy
  `!expanded && start>0` still true when `forceNotify` is false.
- **New contract file**
  `test/conversation_feed_settle_jump_contract_test.dart` (source lock).
- Do **not** add a full `ConversationListNotifier` SQLite integration test
  unless Step 2 cannot be reasoned about from the policy + contract.
  `conversation_ui_window_test.dart` is heavy (ffi); do not expand it.
- Device / fling blank is **NOT RUN** in CI. After landing, a human should
  fling a long C2C or group list on Android past ~50 rows and confirm
  skeletons become real rows within one settle (~one frame after
  `scroll_end`). Restart must no longer be required.

Verification:
`flutter test test/conversation_virtual_hydrate_policy_test.dart test/conversation_virtual_skeleton_hydrate_policy_test.dart test/conversation_feed_settle_jump_contract_test.dart`
→ all pass.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `conversationVirtualHydrateShouldJumpWindow` and
      `conversationVirtualHydrateShouldNotifyOnCoveredSkip` exist in
      `conversation_virtual_hydrate_policy.dart`
- [ ] `ensureTypeIndexHydrated` accepts `forceNotify` and the covered-skip
      path uses the notify policy (reason `hydrate_settle_covered`)
- [ ] `_requestVirtualHydrateForFeedScroll` passes `allowWindowJump: jump`
      / `forceReload: jump` / `forceNotify: force` and computes `jump`
      only when `force` is true
- [ ] `flutter test test/conversation_virtual_hydrate_policy_test.dart test/conversation_virtual_skeleton_hydrate_policy_test.dart test/conversation_feed_settle_jump_contract_test.dart`
      exits 0
- [ ] `ConversationPerfFlags.virtualHydrateOnlyOnScrollSettle` getter body
      unchanged
- [ ] No files outside the in-scope list are modified
- [ ] `plans/README.md` status row for 046 updated

## STOP conditions

Stop and report back (do not improvise) if:

- The excerpts in "Current state" no longer match (especially the
  `ensureTypeIndexHydrated` call with only `convType` + `centerIndex`).
- Fixing notify appears to require changing
  `deferUiNotifyWhileFeedScrolling` globally (too broad — settle should
  pass `forceNotify` into hydrate only).
- `conversationListSdkPrimary` is **true** in this tree’s default flags
  (today it is `false`). If production flipped it, stop — TabStore jump
  is a different path.
- You feel you must enlarge `virtualHydrateRadius` or disable the virtual
  list to “make blanks go away”.
- A verification command fails twice after a reasonable fix.

## Maintenance notes

- Reviewers: mid-scroll path must still clamp and reject teleport. A
  settle jump is **one** `loadConvTypePage` around the viewport center,
  not a walk from the old window to the new one.
- `isFeedScrolling` stuck `true` is only partially helped: jump sets
  `allowWindowJump` which also disables cache-only. If settle never
  fires, blanks remain — do not “fix” that by polling in this plan.
- `PageStorageKey` restoring a far offset after a head-seed
  (`_typeHydrateStart == 0`) is the same jump predicate (empty-or-head
  window vs far center). Chat-return already jumps; this plan covers
  ordinary fling + tab-stay.
- Follow-up explicitly deferred: folder virtual list, sdkPrimary TabStore
  holes, `vidx_gap` notice-index math, stuck `isScrollingNotifier`.
