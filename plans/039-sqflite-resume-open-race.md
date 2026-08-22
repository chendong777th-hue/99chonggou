# Plan 039: Serialize SQLite close/resume so foreground open is lossless

> **Executor instructions**: Follow step by step. Verify each gate. STOP on
> drift. Update `plans/README.md` when done.
>
> **Drift check**: Confirm
> `lib/src/services/sqflite_lifecycle_host.dart` still uses
> `unawaited(SqfliteLifecycleHost.handle(state))` via
> `scheduleSqfliteLifecycle`, and `AppLifecycleState.resumed` only calls
> `SqfliteLifecycleGuard.instance.resume()` without awaiting an in-flight
> `_closeDatabases()`. Confirm `docs/pro-scenario.md` (or a fresh device log)
> still shows `SqfliteClosedForBackground` around Foreground / list reload.
> Scenario evidence file: `docs/pro-scenario.md`.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED (iOS `0xdead10cc` if open is allowed while truly backgrounded;
  must not weaken pause close)
- **Depends on**: none (037/038 DONE; this is post-RegExp open-path)
- **Category**: correctness + perf (foreground hitch / wasted work)
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Status**: DONE (2026-08-22) — host serializes close/resume with epoch +
  event chain; `waitUntilOpenAllowed` + list `loadUiWindow` soft-retry;
  `test/sqflite_lifecycle_guard_test.dart` green.

## Why this matters

Latest list→chat scenario log (`docs/pro-scenario.md`) shows, on the same
session as the post-037 Probe dump:

1. iOS reports Foreground.
2. Conversation list tries `loadUiWindow` / `reloadFromLocal`.
3. `SqfliteLifecycleGuard.beforeOpen` throws `SqfliteClosedForBackground`
   because `canOpenDatabase` is still false (close still running, or Flutter
   `resumed` has not run yet while native Foreground already hydrates).
4. Shortly after, LiteAV / DB `RunTask took(ms): ~1569` while DBs reopen.

This is **not** a RegExp issue. It is a lifecycle race: pause path
`forbidOpen()` + async close can still be in flight when list hydrate runs.
Failures spam stacks, drop a reload, and force a cold reopen that contends
with list→chat.

Lossless goal: same pause safety (no SQLite open while the app is
background-closed), but **no spurious Closed throws after the user is
visibly foreground**, and reopen work is ordered / single-flight.

## Current state

**Guard** — `lib/src/services/sqflite_lifecycle_guard.dart`:

```dart
class SqfliteLifecycleGuard {
  bool get writesAllowed => _writesAllowed;
  bool get canOpenDatabase => _canOpenDatabase;

  void pauseWrites() { _writesAllowed = false; }

  void forbidOpen() {
    _writesAllowed = false;
    _canOpenDatabase = false;
  }

  void resume() {
    _writesAllowed = true;
    _canOpenDatabase = true;
  }

  static Database? beforeOpen(Database? existing) {
    if (existing != null) return existing;
    if (!instance.canOpenDatabase) {
      throw const SqfliteClosedForBackground();
    }
    return null;
  }
}
```

**Host** — `lib/src/services/sqflite_lifecycle_host.dart`:

```dart
static Future<void> handle(AppLifecycleState state) async {
  switch (state) {
    case AppLifecycleState.inactive:
      _pauseWrites();
      break;
    case AppLifecycleState.paused:
    case AppLifecycleState.hidden:
    case AppLifecycleState.detached:
      _pauseWrites();
      if (_closeDatabasesOnPause) {
        await _closeDatabases(); // forbidOpen() then closeIfOpen on stores
      }
      break;
    case AppLifecycleState.resumed:
      SqfliteLifecycleGuard.instance.resume();
      ConversationLocalStore.instance.resumeCoalesceAfterForeground();
      break;
  }
}

void scheduleSqfliteLifecycle(AppLifecycleState state) {
  unawaited(SqfliteLifecycleHost.handle(state));
}
```

**Caller** — `lib/src/pages/app.dart` `didChangeAppLifecycleState` →
`scheduleSqfliteLifecycle(state)`.

**Hot consumer** — `ConversationListNotifier._reloadFromLocalOnce` →
`ConversationLocalStore.instance.loadUiWindow()` (stack in
`docs/pro-scenario.md`).

**Existing tests** — `test/sqflite_lifecycle_guard_test.dart`. Extend; do not
delete.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Lifecycle tests | `flutter test test/sqflite_lifecycle_guard_test.dart` | All pass |
| Analyze touched files | `dart analyze lib/src/services/sqflite_lifecycle_guard.dart lib/src/services/sqflite_lifecycle_host.dart lib/src/services/conversation_local/conversation_local_store.dart lib/src/services/conversation_local/conversation_list_notifier.dart` | No new errors |

## Scope

**In scope**

- `lib/src/services/sqflite_lifecycle_guard.dart` (only if a small wait/epoch
  helper belongs here — prefer host)
- `lib/src/services/sqflite_lifecycle_host.dart`
- Soft-retry **only** at `ConversationListNotifier.reloadFromLocal` /
  `_reloadFromLocalOnce` (or `loadUiWindow` single-flight) — minimal catch
- `test/sqflite_lifecycle_guard_test.dart` (+ new test file if cleaner)
- `plans/README.md`

**Out of scope**

- Removing iOS DB close-on-pause
- Android/web behavior beyond keeping existing `_closeDatabasesOnPause` gate
- Red-packet / call-bubble / RegExp work (040–042)
- Rewriting every store’s `_openDb`

## Locked decisions

| Decision | Value |
|----------|--------|
| Epoch | Host keeps a generation / `Completer?` for in-flight close; `resumed` **awaits** that close before `resume()` |
| Stale close | Close finishing after a newer resume must not leave `canOpenDatabase == false` and must not clear a handle reopen already created (ignore stale `finally` via epoch) |
| Soft-retry | One retry of list reload after Closed when foregrounding; no busy-spin |
| Logging | Avoid full stack on soft-retry; keep throw for true background |
| Platform | Keep `_closeDatabasesOnPause` iOS-only |

## Steps

### Step 1: Serialize close vs resume in the host

Implement invariants:

1. `resume()` never runs while the matching pause `_closeDatabases()` is still
   awaiting.
2. A close that finishes **after** a later `resume()` must not flip
   `canOpenDatabase` back to false and must not null a DB that resume already
   reopened.

Suggested shape (adapt to file style):

```dart
Completer<void>? _closeInFlight;
int _epoch = 0;

// on paused/hidden/detached when closing:
final myEpoch = ++_epoch;
final c = Completer<void>();
_closeInFlight = c;
try {
  await _closeDatabases();
} finally {
  if (_epoch == myEpoch) {
    if (!c.isCompleted) c.complete();
    if (identical(_closeInFlight, c)) _closeInFlight = null;
  }
}

// on resumed:
final pending = _closeInFlight;
if (pending != null) await pending.future;
SqfliteLifecycleGuard.instance.resume();
ConversationLocalStore.instance.resumeCoalesceAfterForeground();
```

Optional: expose `SqfliteLifecycleHost.waitUntilOpenAllowed()` for callers.

**Verify**: `dart analyze lib/src/services/sqflite_lifecycle_host.dart` → clean.

### Step 2: Soft-retry list reload on Closed

In `ConversationListNotifier._reloadFromLocalOnce` (around the
`loadUiWindow()` call ~line 1230), catch `SqfliteClosedForBackground`:

- Await host open-allowed / resume path once, then retry `loadUiWindow` once.
- If still closed → return without rethrowing a user-visible crash; do not
  spam stacks.

**Verify**: unit/widget-free test: forbidOpen → load throws → resume → load
succeeds (extend `test/sqflite_lifecycle_guard_test.dart`).

### Step 3: Preserve background safety

Assert open during `forbidOpen` still throws. Do not call `resume()` from
`inactive` or from native Foreground without Flutter `resumed` unless you
also prove pause close cannot race — prefer Flutter `resumed` + await close.

**Verify**: existing pause/resume upsert tests still pass.

### Step 4: Evidence

On device: background → foreground → open list → enter chat. Expect no
repeated `SqfliteClosedForBackground` stacks on every foreground. Note result
in plan Status when DONE.

## Done when

- [ ] Close/resume serialized with epoch (or equivalent) in host
- [ ] Soft-retry prevents list reload hard-fail on the race
- [ ] Background `forbidOpen` still throws when truly backgrounded
- [ ] `flutter test test/sqflite_lifecycle_guard_test.dart` green
- [ ] `plans/README.md` row 039 → DONE

## STOP conditions

- Fix would keep DB open across iOS `paused` → reject (`0xdead10cc`)
- Requires rewriting all stores’ open paths → stop; split a follow-up plan
- Device log no longer shows Closed **and** tests cannot reproduce → mark
  REJECTED with evidence instead of inventing work

## Out of scope reminder

Do not touch RegExpProbe, call_bubble, or wallet fetch here.
