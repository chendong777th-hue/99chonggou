# Plan 028: Instant contacts Tab switch — do not await sync before setState

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt against live files. If symbols, call paths, or
> control flow changed materially, treat it as a STOP and report before coding.

## Status

- **Priority**: P0
- **Effort**: S–M
- **Risk**: MED (tab UX + friend list freshness; must not drop sync work)
- **Depends on**: none
- **Category**: perf
- **Planned at**: working tree 2026-08-22 (no git SHA — `NO_GIT` at plan time)
- **Execution**: DONE (2026-08-22) — `_switchHomeTab` unawaits enter before
  `setState`; `ContactDataSourceEnterSingleFlight` + debounce helper; tests green.
- **Issue**: omit

## Why this matters

Switching from another bottom-nav Tab to **通讯录** sometimes feels slow:
the UI stays on the previous Tab until friend-data work finishes. Root cause
is structural — `_switchHomeTab` **awaits** `enterContactDataSource` *before*
`setState(currentIndex = 2)`. That path always waits on local SQLite hydrate,
and when the 2s enter-debounce has expired also waits on network Difference
sync + `refreshUIKitLists` (including optional `loadUserStatus`).

The product intent of `enterContactDataSource` (“show local first, then
Difference”) is correct; **blocking the Tab switch on it is not**. Group Tab
already fires `enterGroupDataSource` via `unawaited` through
`onHomeTabChanged`. Contacts should match: paint the Tab immediately, sync
in the background; the Contact page already has a loading skeleton when the
friend list is empty and still loading.

## Current state

### A. Tab switch blocks on contacts enter (bug / perf)

`lib/src/pages/home_page.dart` ≈1252–1285:

```dart
Future<void> _switchHomeTab(int index) async {
  OrphanOverlayGuard.scheduleCleanup(...);
  if (index == _contactTabIndex) {
    await FriendRequestNoticeService.instance.enterContactDataSource(
      reason: 'contact_tab',
    );
    FriendRequestNoticeService.instance.onHomeTabChanged(
      index,
      skipDataSourceEnter: true,
    );
  } else {
    FriendRequestNoticeService.instance.onHomeTabChanged(index);
  }
  DeviceSyncService.instance.setHomeTabIndex(index);
  _activeTabIndex.value = index;
  if (!mounted) return;
  setState(() {
    currentIndex = index;
    _visitedTabs.add(index);
    // ...
  });
}
```

`_contactTabIndex == 2`. Conversation / wallet / profile Tabs do **not**
await a data-source enter before `setState`.

### B. Enter path: hydrate always; network after 2s debounce

`lib/src/services/friend_request_notice_service.dart` ≈57, 136–151:

```dart
static const Duration _dataSourceEnterDebounce = Duration(seconds: 2);

Future<void> enterContactDataSource({required String reason}) async {
  if (!_started) return;
  await FriendSyncService.instance.hydrateContactListFromLocal();
  final now = DateTime.now();
  final last = _lastContactDataSourceEnterAt;
  if (last != null && now.difference(last) < _dataSourceEnterDebounce) {
    return;
  }
  _lastContactDataSourceEnterAt = now;
  await _syncFriendContactDifference(reason: '${reason}_enter');
  await FriendSyncService.instance.refreshUIKitLists(force: false);
}
```

`hydrateContactListFromLocal` → SQLite → `applyLocalFriendSnapshot`
(`friend_sync_service.dart` ≈153–170).
`refreshUIKitLists` → `loadContactListData` + maybe `loadUserStatus` +
remark reseed (≈1043–1058).

### C. Second enter from the list widget

`lib/src/widgets/contact_list_with_presence.dart` ≈115–126 — first frame
`unawaited(enterContactDataSource(reason: 'contact_list_widget'))`.
Today the Tab path usually finishes first and stamps debounce; after this
plan both may race — **must** coalesce (single-flight) so Difference is not
doubled.

### D. Lazy mount (keep)

`_getContactPage()` ≈512–514 caches `const Contact()`; first visit still
pays first-build cost. Out of scope to prewarm unless a tiny optional step
is explicitly listed below.

### E. Conventions / exemplars

- Prefer `unawaited(...)` for non-UI-blocking sync (same file already uses
  it for `_changePage` → `_switchHomeTab` and for profile `getLoginUserInfo`).
- Pure helpers + tests: follow `test/friend_request_poll_gate_test.dart`
  (tiny pure gate). If extracting enter policy, put pure timing/coalesce
  logic under `lib/src/utils/` or keep private with `@visibleForTesting`
  on the service — match existing friend_* test style under `test/`.
- Do **not** remove Difference sync or local-first semantics — only remove
  the **await-before-paint** coupling.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Focused tests | `cd /Users/qiu/Downloads/9925banben && flutter test test/friend_request_poll_gate_test.dart test/contact_tab_enter_gate_test.dart` | exit 0 (create the new file in Step 1) |
| Friend sync suite (smoke) | `cd /Users/qiu/Downloads/9925banben && flutter test test/friend_contact_incremental_sync_test.dart test/friend_sync_service_test.dart` | exit 0 |
| Grep await coupling | `rg -n "await.*enterContactDataSource|enterContactDataSource" lib/src/pages/home_page.dart lib/src/services/friend_request_notice_service.dart lib/src/widgets/contact_list_with_presence.dart` | home_page must **not** `await enterContactDataSource` before setState |

## Scope

**In scope**:

- `lib/src/pages/home_page.dart` — `_switchHomeTab` contacts branch: paint Tab
  first; fire enter without blocking `setState`.
- `lib/src/services/friend_request_notice_service.dart` — single-flight /
  coalesce for `enterContactDataSource` so Tab + list widget concurrent
  calls share one in-flight Future; optionally split “hydrate only” vs
  “hydrate + network” **only if** needed for clarity (not required if
  unawait + single-flight is enough).
- `test/contact_tab_enter_gate_test.dart` (**create**) — pure coalesce /
  ordering policy tests if you extract a tiny helper; otherwise document
  behavioral assertions via a thin `@visibleForTesting` API on the service
  (e.g. expose whether an enter is in flight / last enter reason) — prefer
  pure helper to avoid serviceLocator in tests.
- Optionally one-line comment in `contact_list_with_presence.dart` that
  list-side enter remains `unawaited` and relies on service coalesce — do
  **not** remove the list enter unless you prove Tab always enters first
  even on cold first visit (IndexedStack may build Contact in the same
  frame as setState).

**Out of scope**:

- Rewriting `FriendContactIncrementalSyncService` / SQLite schema.
- Changing AZListView layout, presence prefetch counts, or skeleton UI.
- Preloading Contact Tab on cold start (can be a follow-up plan).
- Group Tab `enterGroupDataSource` behavior (already unawaited) — do not
  “fix” it unless a one-line symmetry comment.
- Wallet / profile Tab work, conversation Feed, IM login.
- Changing `_dataSourceEnterDebounce` duration unless tests prove 2s is
  wrong — default **keep 2s**.

## Git workflow

- No `.git` historically; if present, branch
  `advisor/028-contact-tab-instant-switch`, commits like
  `perf: do not await contact enter before home tab setState`.
- Do NOT push unless asked.

## Target behavior

1. Tapping 通讯录 updates `currentIndex` / shows Contact **without waiting**
   for Difference or `refreshUIKitLists`.
2. `enterContactDataSource` still runs (local hydrate + debounced network +
   refresh) after or overlapping the paint.
3. Concurrent Tab + list enters → **one** in-flight enter (or second joins
   the same Future); no duplicate Difference storms.
4. Empty / first-load still shows Contact skeleton until
   `TUIFriendShipViewModel` has data (`contact.dart` existing path).
5. Friend list still becomes network-fresh within the same debounce/sync
   budget as today — only the **perceived Tab latency** changes.

## Steps

### Step 1: Characterization — enter coalesce policy (pure)

Create `lib/src/utils/contact_data_source_enter_gate.dart` (name flexible)
**or** put a small static helper next to the service if you prefer fewer
files. Behavior to test in `test/contact_tab_enter_gate_test.dart`:

1. While an enter is in flight, a second `begin()` returns the **same**
   Future (join), does not start a second runner.
2. After the Future completes, the next `begin()` starts a new run.
3. Debounce decision (optional pure fn): given `lastEnterAt` + `now` +
   `Duration(seconds: 2)`, decide whether network phase should run — mirror
   existing service logic so the service can call the helper.

Keep the helper free of Flutter widgets / GetIt if possible.

**Verify**:

```bash
cd /Users/qiu/Downloads/9925banben && flutter test test/contact_tab_enter_gate_test.dart
```

→ exit 0.

### Step 2: Wire single-flight into `enterContactDataSource`

In `friend_request_notice_service.dart`:

1. Hold `Future<void>? _contactDataSourceEnterInFlight`.
2. At the start of `enterContactDataSource`, if in-flight != null, `return`
   that Future.
3. Otherwise assign `inFlight = _enterContactDataSourceBody(reason)` (extract
   current body), clear in-flight in `whenComplete`.
4. Preserve hydrate → debounce → Difference → `refreshUIKitLists` order
   inside the body.

**Verify**:

```bash
rg -n "_contactDataSourceEnterInFlight|enterContactDataSource" \
  lib/src/services/friend_request_notice_service.dart
```

→ single-flight visible. Then:

```bash
cd /Users/qiu/Downloads/9925banben && dart analyze lib/src/services/friend_request_notice_service.dart
```

→ no new errors (ignore pre-existing project-wide issues).

### Step 3: Unblock `_switchHomeTab` paint

In `home_page.dart` `_switchHomeTab`:

**Required shape** (adapt to style):

```dart
Future<void> _switchHomeTab(int index) async {
  OrphanOverlayGuard.scheduleCleanup(...);
  // Update tab chrome / services first so IndexedStack can paint.
  DeviceSyncService.instance.setHomeTabIndex(index);
  _activeTabIndex.value = index;
  if (index == _contactTabIndex) {
    FriendRequestNoticeService.instance.onHomeTabChanged(
      index,
      skipDataSourceEnter: true,
    );
    unawaited(
      FriendRequestNoticeService.instance.enterContactDataSource(
        reason: 'contact_tab',
      ),
    );
  } else {
    FriendRequestNoticeService.instance.onHomeTabChanged(index);
  }
  if (!mounted) return;
  setState(() {
    currentIndex = index;
    _visitedTabs.add(index);
    // pageName branches unchanged
  });
}
```

Hard rules for this step:

- **Must not** `await enterContactDataSource` before `setState`.
- Still call `onHomeTabChanged` for contacts (polling interval / tab index)
  with `skipDataSourceEnter: true` so it does not start a *second* unawaited
  enter via the non-skip path — keep exactly one enter kickoff from Home
  (`unawaited(enter...)`) plus the list widget’s own enter (joined by
  single-flight).
- Keep `OrphanOverlayGuard.scheduleCleanup` as today.

**Verify**:

```bash
rg -n "await FriendRequestNoticeService.instance.enterContactDataSource|await.*enterContactDataSource" \
  lib/src/pages/home_page.dart
```

→ **no matches**.

```bash
rg -n "unawaited\(\s*FriendRequestNoticeService.instance.enterContactDataSource" \
  lib/src/pages/home_page.dart
```

→ at least one match in `_switchHomeTab`.

### Step 4: Regression tests + manual checklist

```bash
cd /Users/qiu/Downloads/9925banben && flutter test \
  test/contact_tab_enter_gate_test.dart \
  test/friend_request_poll_gate_test.dart \
  test/friend_contact_incremental_sync_test.dart
```

→ exit 0.

Update `plans/README.md` row 028 → DONE when finished.

**Manual (operator, NOT RUN in CI)**:

1. Cold-ish: open app on 消息 → tap 通讯录 — Tab should switch **immediately**;
   list may fill from cache or show skeleton briefly, then refresh.
2. Wait >2s on another Tab → tap 通讯录 again — still instant switch; list
   may refresh quietly after Difference.
3. Rapidly toggle 消息 ↔ 通讯录 — no hang; no duplicate toast/errors; friend
   count stays coherent.
4. Accept/decline a friend request elsewhere → enter 通讯录 within a minute —
   new friend still appears (sync not dropped).

## Test plan

- New: `contact_tab_enter_gate_test.dart` (Step 1).
- Keep green: `friend_request_poll_gate_test.dart`,
  `friend_contact_incremental_sync_test.dart`.
- No full widget golden for HomePage required.

## Done criteria

- [ ] `home_page.dart` does not `await enterContactDataSource` before
      updating `currentIndex`.
- [ ] `enterContactDataSource` has single-flight coalesce for concurrent
      callers.
- [ ] Hydrate + debounced Difference + `refreshUIKitLists` still run (not
      deleted).
- [ ] `flutter test test/contact_tab_enter_gate_test.dart` (+ listed
      regressions) exit 0.
- [ ] No files outside Scope modified.
- [ ] `plans/README.md` status for 028 updated.

## STOP conditions

- Live `_switchHomeTab` no longer awaits enter (already fixed) — STOP and
  report; only add single-flight if missing.
- Making enter fully sync-free would require deleting Difference on tab
  enter — **forbidden**; report instead of inventing a new sync product.
- Single-flight causes enters to never run after a failed Future that never
  clears in-flight — fix clear-in-`whenComplete` or STOP.
- Verification fails twice after a reasonable fix attempt.
- Fix seems to need prebuilding Contact on app start — out of scope; file a
  follow-up note in README “Considered” instead of expanding this plan.

## Maintenance notes

- Reviewers: ensure `onHomeTabChanged(..., skipDataSourceEnter: true)` +
  explicit `unawaited(enter...)` does not double-kick without coalesce.
- Any new “must be fresh before showing contacts” feature must **not**
  reintroduce await-before-`setState` on the home Tab path; use in-page
  loading/skeleton instead.
- Follow-up (not this plan): optional idle prewarm of `_getContactPage()`
  after first frame on 消息 Tab to cut first-visit build cost.
