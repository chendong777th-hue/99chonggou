# Plan 043: Stop bottom-nav unread badge flicker from transient zero

> **Executor instructions**: Follow step by step. Run every verification
> command and confirm the expected result before the next step. If anything
> in "STOP conditions" occurs, stop and report — do not improvise. When done,
> update the status row for this plan in `plans/README.md` — unless a reviewer
> told you they maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt below to the live files. If
> `ConversationUnreadAggregate._refreshFromStoreOnce` already refuses
> owner-empty / transient `(0,0)` overwrites (or badge no longer
> `SizedBox.shrink()` on `<=0`), mark DONE / adjust and report — do not
> duplicate logic.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED (must not leave a sticky badge after the user truly clears
  all unread; must not break logout `clearSession`)
- **Depends on**: none
- **Category**: bug
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Status**: DONE

## Why this matters

Bottom-nav 消息 / 群聊红点有时会「闪一下消失再出现」。角标在
`visibleUnread <= 0` 时直接 `SizedBox.shrink()`，因此任何 **短暂写成 0 再
写回非 0** 都会肉眼可见闪烁。根因在
`ConversationUnreadAggregate`：`refreshFromStore` 会把 DB 汇总原样写进内存
并 `notifyListeners`，而 `ConversationLocalStore.sumNotifiableUnreadByScope`
在 **owner 为空** 时返回 `(0,0)`；登出 `clearSession` 也会合法清零。需要把
「真·清零」和「瞬态假零」分开，避免假零打到 UI。

## Current state

**Badge (display gate)** —
`lib/src/widgets/conversation_scope_unread_badge.dart`:

```dart
final visibleUnread = scope == ConversationListScope.group
    ? AppBadgeUnreadUtils.visibleUnreadForGroup()
    : AppBadgeUnreadUtils.visibleUnreadForC2c();
if (visibleUnread <= 0) {
  return const SizedBox.shrink();
}
return UnreadMessage(unreadCount: visibleUnread, ...);
```

**Aggregate** —
`lib/src/services/conversation_local/conversation_unread_aggregate.dart`:

- `applyNotifiableDeltas` — synchronous memory update + `notifyListeners`
- `scheduleRefresh` — 220ms / 800ms debounce → `refreshFromStore`
- `_refreshFromStoreOnce` — always assigns `sums` from store then notifies
  when changed
- `clearSession` — force `(0,0)` + notify (logout / account switch)

**Store empty-owner path** —
`lib/src/services/conversation_local/conversation_local_store.dart`
(`sumNotifiableUnreadByScope`):

```dart
final owner = _resolveOwner(ownerUserId);
if (owner.isEmpty) {
  return const NotifiableUnreadSums(c2c: 0, group: 0);
}
```

Also exposes `currentOwnerUserId()` for the executor to gate on.

**Existing tests to extend** —
`test/conversation_unread_aggregate_test.dart` (uses `setSumsForTest`,
`resetForTest`, `applyNotifiableDeltas`, `debounceForReasonForTest`).

**Conventions**: match existing aggregate naming (`c2cNotifiableUnreadSum`,
`scheduleRefresh`, `clearSession`). Prefer fixing the **data source** over
adding UI opacity/animation. Do not change `UnreadMessage` drawing.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Aggregate + badge utils tests | `flutter test test/conversation_unread_aggregate_test.dart test/app_badge_unread_utils_test.dart` | All pass |
| Analyze aggregate | `dart analyze lib/src/services/conversation_local/conversation_unread_aggregate.dart` | No errors |
| Broader unread suite (optional) | `flutter test test/conversation_unread_guard_test.dart test/conversation_unread_merge_foreground_test.dart` | All pass |

## Scope

**In scope**

- `lib/src/services/conversation_local/conversation_unread_aggregate.dart`
- `test/conversation_unread_aggregate_test.dart`
- `plans/README.md` (status row)

**Out of scope**

- `home_page.dart` BottomNavigationBar layout / icon Stack rebuild
- `UnreadMessage` / UIKit badge widgets
- `ContactUnreadBadge` / friend-request path (unless a one-line shared helper
  is required — prefer not)
- Changing `applyNotifiableDeltas` to sticky-hold zero after real reads
  (would delay legitimate badge clear)
- Desktop launcher badge policy beyond sharing the same aggregate getters

## Locked decisions

| Decision | Value |
|----------|--------|
| Fix layer | **Aggregate** (single source for tab + app badge) |
| Empty owner | If `ConversationLocalStore.instance.currentOwnerUserId()` is empty at refresh time: **do not** overwrite sums, **do not** notify |
| Transient `(0,0)` from refresh | If previous sums were non-zero and reason is **not** in an allow-zero set: **keep previous sums**, schedule one follow-up refresh with reason `zero_confirm` (short debounce, same as default 220ms) |
| Allow-zero reasons | At minimum: `zero_confirm`, and any reason already used for intentional clear via refresh if present. **`clearSession()` stays a direct force-zero** (does not go through this gate) |
| Second confirm | When reason == `zero_confirm`, apply `(0,0)` even if previous non-zero |
| Deltas | Leave `applyNotifiableDeltas` behavior unchanged in this plan |
| Badge widget | Keep `SizedBox.shrink()` on `<=0` — after aggregate fix, false zeros should stop reaching it |

## Steps

### Step 1: Drift inventory

Confirm live symbols match this plan:

- `ConversationUnreadAggregate.refreshFromStore` /
  `_refreshFromStoreOnce`
- `clearSession`
- `ConversationLocalStore.currentOwnerUserId`
- `sumNotifiableUnreadByScope`

**Verify**: `rg -n "refreshFromStore|clearSession|currentOwnerUserId|sumNotifiableUnreadByScope" lib/src/services/conversation_local/conversation_unread_aggregate.dart lib/src/services/conversation_local/conversation_local_store.dart` shows the symbols above.

### Step 2: Empty-owner guard in `_refreshFromStoreOnce`

At the start of `_refreshFromStoreOnce` (before awaiting the SQL sum), if
owner is empty:

```dart
final owner =
    ConversationLocalStore.instance.currentOwnerUserId().trim();
if (owner.isEmpty) {
  if (kDebugMode) {
    debugPrint(
      'ConversationUnreadAggregate: skip refresh reason=$reason '
      '(empty owner; keep c2c=$_c2cNotifiableUnreadSum '
      'group=$_groupNotifiableUnreadSum)',
    );
  }
  return;
}
```

**Verify**: `dart analyze lib/src/services/conversation_local/conversation_unread_aggregate.dart` → no errors.

### Step 3: Transient-zero confirmation

After `sums` returns, **before** assigning fields / notify:

```dart
final goingToAllZero = sums.c2c == 0 && sums.group == 0;
final hadUnread =
    _c2cNotifiableUnreadSum > 0 || _groupNotifiableUnreadSum > 0;
const allowZeroReasons = <String>{
  'zero_confirm',
  // add only if codebase already uses an intentional refresh-to-zero reason
};
if (goingToAllZero &&
    hadUnread &&
    !allowZeroReasons.contains(reason)) {
  if (kDebugMode) {
    debugPrint(
      'ConversationUnreadAggregate: defer zero refresh reason=$reason '
      '(had c2c=$_c2cNotifiableUnreadSum group=$_groupNotifiableUnreadSum)',
    );
  }
  scheduleRefresh(reason: 'zero_confirm');
  return;
}
// else existing assign + notify when changed
```

Ensure `zero_confirm` is **not** classified as a bulk (800ms) reason — it
must use the default 220ms debounce (or an explicit ≤220ms Timer if you
must bypass `scheduleRefresh` coalescing). If another `scheduleRefresh`
with a different reason is already pending, do not lose the confirm:
either let the next non-zero refresh cancel the need, or coalesce so
`zero_confirm` still runs once if sums stay zero.

**Verify**: analyze clean.

### Step 4: Preserve `clearSession`

Do **not** route `clearSession` through the defer gate. It must still:

1. Cancel debounce
2. Set sums to 0
3. `notifyListeners` when previously non-zero

**Verify**: existing tests that call `clearSession` (if any) still pass; add
an explicit unit test if missing.

### Step 5: Unit tests

Extend `test/conversation_unread_aggregate_test.dart`:

1. **`refresh skips empty owner`**: `setSumsForTest(c2c: 5, group: 1)`, force
   empty owner (`debugOwnerUserId = null` / empty — match how store tests
   clear owner), call `await refreshFromStore(reason: 'test_empty_owner')`,
   expect sums still `5/1`.

2. **`refresh defers first zero`**: `setSumsForTest(c2c: 3, group: 0)`,
   arrange store so sum returns 0/0 with a real owner (empty DB for that
   owner is fine), `await refreshFromStore(reason: 'test_zero')`, expect
   sums still `3/0` immediately; then `await refreshFromStore(reason:
   'zero_confirm')` (or pump debounce) and expect `0/0`.

3. **`clearSession still zeros immediately`**: `setSumsForTest(c2c: 2,
   group: 2)`, `clearSession()`, expect `0/0` with no defer.

4. Keep existing delta / debounce tests green.

**Verify**:

```bash
flutter test test/conversation_unread_aggregate_test.dart test/app_badge_unread_utils_test.dart
```

All pass.

### Step 6: Manual checklist (document in plan Status when DONE)

On device / simulator:

1. Have unread on 消息 Tab → background/foreground app → badge must **not**
   blink off.
2. Read all unread conversations → badge clears (may lag ≤ ~220ms once).
3. Logout / switch account → badge clears immediately.

## Done when

- [x] Empty-owner refresh does not wipe sums
- [x] First surprising `(0,0)` refresh defers; `zero_confirm` applies
- [x] `clearSession` still immediate zero
- [x] Unit tests above green
- [x] `plans/README.md` row 043 → DONE

## STOP conditions

- Store has no reliable empty-owner signal and inventing one would touch
  auth/session plumbing → STOP and report
- Making `zero_confirm` work requires rewriting sync pipeline → STOP
- Legitimate “all read” badge now stuck visible >1s in manual check → STOP;
  tighten allow-zero / confirm path instead of adding UI hacks

## Out of scope reminder

Do not animate the badge, do not change bottom-nav icon rebuild, do not
sticky-hold zeros from `applyNotifiableDeltas` in this plan.

## Maintenance

Future `scheduleRefresh(reason: …)` callers that **intentionally** mean
“trust zero now” must use an allowlisted reason (or call `clearSession`).
Reviewers: any new refresh reason that should clear the badge immediately
needs to be added to `allowZeroReasons` or documented why confirm is OK.
