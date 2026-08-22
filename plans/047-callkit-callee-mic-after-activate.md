# Plan 047: Gate CallKit callee mic publish on didActivate (no silent timeout)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt against live files. If
> `_waitForCallKitAudioReadyIfPending` already refuses to publish on timeout,
> or `CXAnswerCallAction` already `fulfill()`s without `holdCallAction`, mark
> those steps DONE / adjust and report — do not duplicate.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED (iOS CallKit + LiveKit audio; must not hang up a recoverable
  call, must not gate App-in accept / caller join)
- **Depends on**: none
- **Category**: bug
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Execution**: DONE (2026-08-22) — latch + bool waiter; defer mic on
  timeout (no throw); republish on `didActivate`; native Answer
  `configure` + `fulfill` (no 8s hold). Two-device CallKit repro NOT RUN.
- **Issue**: omit

## Why this matters

Repro (device A = no offline push; device B = production build with VoIP /
CallKit):

| Direction | How B/A answers | Result |
|-----------|-----------------|--------|
| B → A | A answers in App (no CallKit) | both OK |
| A → B (voice) | B answers system incoming | **A silent, B hears A** |

B hearing A means A's mic, room, and B's playback work. A not hearing B
means B published a **silent / unbound** local mic — classic CallKit
`didActivate` race. Local same-build calls and App-in answers skip this
path, so signaling/token is not the root.

Today the callee still `setMicrophoneEnabled(true)` after a **swallowed
3s timeout**, or after a waiter that **no-ops** when `didActivate` arrived
before the completer existed. Native `CXAnswerCallAction` is also
`fail()`ed after **8s** if Flutter is still waking / logging in /
requesting permission. This plan makes **confirmed `didActivate`** the
only license to publish the callee mic, latches early activate, fulfills
Answer on the native side so the session is alive before Flutter joins,
and **republishes** if activate arrives late. Timeout must **defer**, not
silently publish and not hang up.

## Current state

### A. Waiter no-ops or swallows timeout — then publish anyway

`lib/src/services/livekit_voip_bridge.dart` ≈22–25, 82–135, 342–361:

```dart
static const Duration _audioActivateTimeout = Duration(seconds: 3);
Completer<void>? _audioActivatedCompleter;

void _onAudioSessionActivated() {
  final c = _audioActivatedCompleter;
  if (c != null && !c.isCompleted) {
    c.complete();
  }
  // no latch if completer is still null
  unawaited(LiveKitCallSession.instance.ensureCallAudioRoute());
}

Future<void> _waitForCallKitAudioReadyIfPending({...}) async {
  if (!_isIos) return;
  final existing = _audioActivatedCompleter;
  if (existing == null || existing.isCompleted) return; // no-op
  try {
    await existing.future.timeout(timeout);
  } on TimeoutException {
    debugPrint('LiveKitVoipBridge: audioActivateTimeout (media gate)');
    // swallow — caller proceeds to connect + publish
  }
}

// _onAccept after permission:
_audioActivatedCompleter = Completer<void>();
await _completeAction(uuid, true); // Flutter fulfill Answer
unawaited(_restoreAudioRouteWhenReady(session));
await session.acceptIncoming();    // does not await didActivate
```

Comment at `_onAccept` ≈342–344 **intentionally** refuses to await
activation so UI is not delayed. `prepareIosCallKitMediaJoin` / 
`publishLocalCallTracks` are supposed to wait, but the waiter above
treats timeout and “completer missing” as success.

### B. Media helpers wait 3s then publish regardless

`lib/src/services/livekit_call_media_helpers.dart` ≈35–70, 94–112:

```dart
Future<void> Function({Duration timeout})? iosCallKitAudioReadyWaiter;

Future<void> waitForIosCallKitAudioReady({
  Duration timeout = const Duration(seconds: 3),
}) async {
  final waiter = iosCallKitAudioReadyWaiter;
  if (waiter == null) return;
  await waiter(timeout: timeout);
}

Future<void> prepareIosCallKitMediaJoin({
  required bool video,
  required bool isCallee,
}) async {
  if (!isCallee) return;          // caller path — keep this
  await waitForIosCallKitAudioReady();
}

// publishLocalCallTracks:
await waitForIosCallKitAudioReady();
final micPub = await local.setMicrophoneEnabled(true);
```

`prepareIosCallKitMediaJoin` is **callee-only**. That matches the repro
(A answering B in-app is fine; B answering via CallKit is broken). Do
**not** add a CallKit wait on the caller `_connectAndPublish` path.

### C. Publish failure hangs up the call

`lib/src/services/livekit_call_session.dart` `acceptIncoming` ≈342–353
and `_connectAndPublish` ≈801–812: `LiveKitPublishException` toasts and
`_finalizePublishFailure()`. Therefore a timeout **must not throw**
`LiveKitPublishException` — that would drop a call that can recover
when `didActivate` arrives 1s later. Defer publish instead.

`recoverCallAudio` ≈544–561 only re-subscribes **remote** audio and
re-applies route. It does **not** republish local mic. Late activate
currently cannot repair a silent local track.

### D. Native Answer is held 8s then failed

`ios/Runner/SelfHostedVoipCallKit.swift` ≈287–305, 378–389:

```swift
func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    holdCallAction(action)
    onAccept?(uuidToInviteId[action.callUUID], action.callUUID.uuidString)
}

func provider(_ provider: CXProvider, didActivate audioSession: AVAudioSession) {
    configureAudioSession()
    onAudioSessionActivated?(uuid)
}

private func holdCallAction(_ action: CXCallAction) {
    pendingActions[action.callUUID] = action
    DispatchQueue.main.asyncAfter(deadline: .now() + 8) { ...
        action.fail()
    }
}
```

`didActivate` typically fires **after** `CXAnswerCallAction.fulfill()`.
If Flutter is still in `PermissionGuard` / login at T+8s, Answer is
already `fail()`ed; Dart `completeAction` no-ops (`completeAction`
removes from `pendingActions` or returns). Flutter still joins and
publishes into a dead / never-activated session.

`CXEndCallAction` / `CXSetMutedCallAction` may keep `holdCallAction`.
Only **Answer** must stop waiting on Flutter.

### E. Existing policy + source-string tests

- `lib/src/services/livekit_call_kit_policy.dart` today only has
  `calleeMayStartOutgoingCallKitOnConnected() => false`. **Extend this
  file** with the wait/publish decision helpers (same pattern as
  `conversation_virtual_hydrate_policy.dart`).
- `test/livekit_call_kit_policy_test.dart` — one test; add the new cases.
- `test/livekit_ios_callkit_audio_gate_test.dart` — **source-string**
  contracts. It currently requires:

```dart
expect(bridge, contains('if (existing == null || existing.isCompleted) return'));
```

  That line **must change**. Update this test in the same change as the
  waiter (Step 3/5). Keep: callee-only `prepareIosCallKitMediaJoin`,
  `keepAudioSession`, `hasLiveCallAudioTracks` before `setSpeakerphoneOn`.

### F. App-in accept must stay ungated

`LiveKitVoipBridge.acceptFromUi` ≈210–285 does **not** create
`_audioActivatedCompleter`. After this plan, that remains skip
(`callKitAnswerInFlight == false`) so App-in mic publish is immediate.
Do **not** await CallKit on `acceptFromUi`.

## Conventions to match

- Policy helpers are **pure functions** in
  `lib/src/services/livekit_call_kit_policy.dart`, `@visibleForTesting`
  if needed. Mirror `conversationVirtualHydrateShouldJumpWindow` style:
  named required args, no Flutter/LiveKit types.
- Always-on diagnosis via `liveKitCallUiLog(...)` (not `kDebugMode`-only)
  when deferring or republishing mic — same style as
  `recoverCallAudio` / `describeCallAudioState`.
- Tests: `flutter test` from repo root (not `dart test`). Policy tests
  import the policy file; wiring tests may stay source-string like
  `test/livekit_ios_callkit_audio_gate_test.dart`.
- Do **not** `git init` / commit / push unless the operator asks.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Policy tests | `cd /Users/qiu/Downloads/9925banben && flutter test test/livekit_call_kit_policy_test.dart` | all pass (incl. new cases) |
| Gate contract | `cd /Users/qiu/Downloads/9925banben && flutter test test/livekit_ios_callkit_audio_gate_test.dart` | all pass (updated strings) |
| Existing CallKit policy smoke | same policy file still exports `calleeMayStartOutgoingCallKitOnConnected` | `isFalse` |
| Analyze touched Dart | `cd /Users/qiu/Downloads/9925banben && dart analyze lib/src/services/livekit_call_kit_policy.dart lib/src/services/livekit_voip_bridge.dart lib/src/services/livekit_call_media_helpers.dart lib/src/services/livekit_call_session.dart` | no errors |

This repo uses `flutter test`. There may be no `.git`. Device / two-phone
CallKit repro is **NOT RUN** in CI — list it under Done as operator
verification, do not claim it passed.

## Scope

**In scope** (the only files you should modify):

- `lib/src/services/livekit_call_kit_policy.dart` — add wait / publish
  decision helpers; keep `calleeMayStartOutgoingCallKitOnConnected`
- `lib/src/services/livekit_voip_bridge.dart` — latch, waiter returns
  ready/not-ready, reset on hangup, republish on activate
- `lib/src/services/livekit_call_media_helpers.dart` — waiter returns
  `bool`; `publishLocalCallTracks` defers when not ready (no throw)
- `lib/src/services/livekit_call_session.dart` — honor deferred publish;
  republish local mic on CallKit activate; do **not** treat defer as
  `LiveKitPublishException`
- `ios/Runner/SelfHostedVoipCallKit.swift` — Answer: configure +
  fulfill immediately; do not `holdCallAction` Answer
- `test/livekit_call_kit_policy_test.dart` — decision table
- `test/livekit_ios_callkit_audio_gate_test.dart` — update / add
  source-string contracts
- `plans/README.md` — status row for 047

**Out of scope** (do NOT touch, even though they look related):

- `LiveKitVoipBridge.acceptFromUi` control flow (permission →
  `acceptIncoming` → `dismissSystemCallKitForSession(keepAudioSession: true)`)
- Caller `_connectAndPublish` CallKit wait (`prepareIosCallKitMediaJoin`
  must stay `if (!isCallee) return`)
- `setSpeakerphoneOn` / `hasLiveCallAudioTracks` skip (that bug is
  **callee cannot hear remote** — opposite of this repro)
- Android FCM / no-CallKit incoming
- `keepAudioAcrossCallKitEnd` / `didDeactivate ignored` path (already
  correct for dismiss-after-accept)
- Plan 029 call-page paint gate, chat/history/wallet, 018/044/045/046
- Raising native End/Mute 8s hold; changing `CXStartCallAction`
- Vendored `livekit_client` / `flutter_webrtc`

## Git workflow

- No `.git` in this workspace historically — do not `git init`.
- If a git repo exists: branch `advisor/047-callkit-callee-mic-after-activate`.
- Do NOT push or open a PR unless the operator instructed it.

## Steps

### Step 1: Add pure wait / publish decisions

In `lib/src/services/livekit_call_kit_policy.dart` add (names may vary
slightly but tests must import these symbols):

```dart
enum IosCallKitAudioWaitDecision {
  /// App-in accept, caller, or Android — do not wait.
  skip,
  /// `didActivate` already latched (possibly before the completer existed).
  alreadyReady,
  /// Completer is in flight — await it; timeout is NOT ready.
  waitPending,
}

IosCallKitAudioWaitDecision iosCallKitAudioWaitDecision({
  required bool callKitAnswerInFlight,
  required bool activatedLatch,
}) {
  if (!callKitAnswerInFlight) return IosCallKitAudioWaitDecision.skip;
  if (activatedLatch) return IosCallKitAudioWaitDecision.alreadyReady;
  return IosCallKitAudioWaitDecision.waitPending;
}

/// Only CallKit-answer callees need the latch. Everyone else may publish.
bool iosCallKitAllowMicPublish({
  required bool isIosCalleeCallKitAnswer,
  required bool activatedLatch,
}) {
  if (!isIosCalleeCallKitAnswer) return true;
  return activatedLatch;
}
```

Keep `calleeMayStartOutgoingCallKitOnConnected() => false`.

In `test/livekit_call_kit_policy_test.dart` add cases:

| callKitAnswerInFlight | activatedLatch | wait decision | allow mic (CallKit callee) |
|-----------------------|----------------|---------------|----------------------------|
| false | false | skip | n/a — `isIosCalleeCallKitAnswer: false` → allow |
| false | true | skip | leftover latch must **not** apply; allow because not CallKit answer |
| true | true | alreadyReady | allow |
| true | false | waitPending | **deny** |

Also: `iosCallKitAllowMicPublish(isIosCalleeCallKitAnswer: false, activatedLatch: false)` is `true` (App-in / caller).

**Verify**: `flutter test test/livekit_call_kit_policy_test.dart` → all pass.

### Step 2: Latch activate; waiter returns bool; never swallow as ready

In `livekit_voip_bridge.dart`:

1. Add `bool _audioSessionActivatedLatch = false`.
2. `_onAudioSessionActivated`:
   - set latch `true`
   - complete pending completer if any
   - `ensureCallAudioRoute()` (keep)
   - **also** `unawaited(session.ensureLocalMicPublishedAfterCallKitActivate())`
     (added in Step 4)
3. `_onAccept`: after permission, set `_audioActivatedCompleter = Completer()`.
   If latch is **already** true, `complete()` immediately. Then
   `_completeAction(uuid, true)` as today.
4. Replace `_waitForCallKitAudioReadyIfPending` so it uses
   `iosCallKitAudioWaitDecision(callKitAnswerInFlight: completer != null, activatedLatch: latch)`:
   - `skip` / `alreadyReady` → return `true`
   - `waitPending` → `await completer.timeout(const Duration(seconds: 8))`;
     on timeout **return `false`** (log `audioActivateTimeout` via
     `liveKitCallUiLog`). Do **not** complete the completer on timeout.
5. Change `iosCallKitAudioReadyWaiter` typedef to
   `Future<bool> Function({Duration timeout})`.
6. `_cancelAudioWait` / hangup / reject / end-CallKit failure paths:
   clear **both** completer and latch. Leftover latch must not leak into
   the next App-in accept.
7. Keep `_onAccept` **not** awaiting activate before `acceptIncoming`
   (UI stays snappy). The gate is inside prepare/publish.

Default waiter timeout: **8 seconds** (was 3). Aligns with the old native
hold; after Step 5 Answer is fulfilled immediately so activate should
already be latched and this wait is usually a no-op.

**Verify**: `dart analyze lib/src/services/livekit_voip_bridge.dart` —
will fail until Step 3 updates the typedef call sites. Proceed to Step 3
in the same coding burst if the analyzer only reports the typedef.

### Step 3: Helpers — bool waiter; defer mic, do not throw

In `livekit_call_media_helpers.dart`:

```dart
Future<bool> Function({Duration timeout})? iosCallKitAudioReadyWaiter;

Future<bool> waitForIosCallKitAudioReady({
  Duration timeout = const Duration(seconds: 8),
}) async {
  final waiter = iosCallKitAudioReadyWaiter;
  if (waiter == null) return true;
  return waiter(timeout: timeout);
}
```

`prepareIosCallKitMediaJoin`: still callee-only + iOS. Await the waiter
(connect prefers an active session) but **do not throw** if `false` —
connect still runs so B can hear A.

`publishLocalCallTracks`:

```dart
if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
  final ready = await waitForIosCallKitAudioReady();
  if (!ready) {
    liveKitCallUiLog(
      'publishLocalCallTracks defer mic — CallKit audio not ready',
    );
    return; // or return a small result type; MUST NOT throw
  }
}
final micPub = await local.setMicrophoneEnabled(true);
```

If you change the return type, update `_connectAndPublish` so a defer is
**not** treated as success-with-mic (`_micEnabled` stays false until a
real publication exists). Suggested: return `bool published` (`true`
when mic track exists).

Camera wait stays after mic; if mic was deferred, **do not** enable
camera either (video CallKit same race). Retry both in Step 4.

**Verify**: `dart analyze` on the three Dart service files → no errors
from the typedef. `flutter test test/livekit_ios_callkit_audio_gate_test.dart`
will fail until Step 5 updates strings — expected mid-plan.

### Step 4: Session — deferred publish + republish on activate

In `livekit_call_session.dart`:

1. After `publishLocalCallTracks`, set `_micEnabled` only if
   `countLocalAudioTracks(_room) > 0` (helper already in media_helpers).
2. Add `ensureLocalMicPublishedAfterCallKitActivate()`:
   - no-op if `!isInCall` / `_finalizing` / `_room == null`
   - if a live unmuted local audio track already exists, still call
     `recoverCallAudio(tag: 'callKitDidActivate')` (remote + route)
   - else `setMicrophoneEnabled(true)` on the local participant (do
     **not** go through `LiveKitCallSession.setMicrophoneEnabled` if that
     path `_finalizePublishFailure`s on a transient miss — prefer a
     dedicated retry that logs and returns; one retry after 200ms is OK)
   - then `recoverCallAudio`
3. Wire this from `_onAudioSessionActivated` (Step 2).
4. `acceptIncoming` / `_connectAndPublish`: deferred mic is **not**
   `LiveKitPublishException`. Phase may become `connected` so the callee
   still sees the call UI and can hear the caller; A hears B only after
   republish.

**Verify**: `dart analyze lib/src/services/livekit_call_session.dart` →
no errors. Do not run a full-app call here.

### Step 5: Native — fulfill Answer immediately after configure

In `ios/Runner/SelfHostedVoipCallKit.swift`, change **only**
`perform CXAnswerCallAction`:

```swift
func provider(_ provider: CXProvider, perform action: CXAnswerCallAction) {
    configureAudioSession()
    action.fulfill()
    onAccept?(uuidToInviteId[action.callUUID], action.callUUID.uuidString)
}
```

Do **not** pass Answer into `holdCallAction`. Keep `holdCallAction` for
`CXEndCallAction` and `CXSetMutedCallAction`.

Flutter `_completeAction(uuid, true)` after this is a no-op (`completeAction`
already `guard let action = pendingActions.remove... else { return }`).
Keep the Dart call — harmless and still needed if an older native binary
holds Answer.

`didActivate` still `configureAudioSession()` + `onAudioSessionActivated`.
Do not remove that.

**Verify**: `rg -n "CXAnswerCallAction" ios/Runner/SelfHostedVoipCallKit.swift`
shows `configureAudioSession()` and `action.fulfill()` in that method, and
that method does **not** call `holdCallAction`.

### Step 6: Update source-string + policy tests

Update `test/livekit_ios_callkit_audio_gate_test.dart`:

- **Remove** the assertion that the waiter contains
  `if (existing == null || existing.isCompleted) return`.
- **Add** (source-string) that the bridge has an activate **latch**
  (`_audioSessionActivatedLatch` or the policy call
  `iosCallKitAudioWaitDecision`).
- **Add** that timeout logging still exists but
  `publishLocalCallTracks` contains a **defer** path
  (`CallKit audio not ready` or `defer mic`) **before**
  `setMicrophoneEnabled(true)`, and does not throw
  `LiveKitPublishException` on that path.
- **Add** Swift: `CXAnswerCallAction` body contains `action.fulfill()`
  and does not contain `holdCallAction(action)` (search the method
  slice, not the whole file — End/Mute still hold).
- **Keep**: `prepareIosCallKitMediaJoin` + `if (!isCallee)`;
  `hasLiveCallAudioTracks` before speaker; `keepAudioSession`.

**Verify**:

```bash
cd /Users/qiu/Downloads/9925banben && flutter test \
  test/livekit_call_kit_policy_test.dart \
  test/livekit_ios_callkit_audio_gate_test.dart
```

→ all pass.

## Test plan

- New / extended **policy** tests in
  `test/livekit_call_kit_policy_test.dart` (table in Step 1). Pattern:
  existing file + `conversation_virtual_hydrate_policy_test.dart`
  (pure functions, no `Room` mocks).
- Updated **wiring** tests in
  `test/livekit_ios_callkit_audio_gate_test.dart` (source-string, same
  file style as today).
- Do **not** add a LiveKit `Room` widget test.
- Device matrix (operator, **NOT RUN** in this plan):
  1. A (no push) answers B — both audio (regression).
  2. A calls B voice, B answers **system CallKit** from lock/background —
     both audio (the fix).
  3. B App-in accept while CallKit also showing — still both audio;
     dismiss keeps session (`keepAudioSession`).
  4. Voice stays earpiece default (`_speakerOn = creds.isVideo`).

## Done criteria

Machine-checkable. ALL must hold:

- [x] `iosCallKitAudioWaitDecision` / `iosCallKitAllowMicPublish` exist
      and the Step 1 table is covered by tests
- [x] `_onAudioSessionActivated` sets a latch even when the completer is
      null; hangup clears the latch
- [x] `publishLocalCallTracks` does not call `setMicrophoneEnabled(true)`
      when the CallKit waiter returns not-ready; it does not throw
      `LiveKitPublishException` for that case
- [x] `ensureLocalMicPublishedAfterCallKitActivate` (or equivalent) is
      invoked from the activate handler
- [x] `prepareIosCallKitMediaJoin` remains callee-only
      (`if (!isCallee) return`)
- [x] `CXAnswerCallAction` fulfills after `configureAudioSession` and is
      not held for 8s
- [x] `flutter test test/livekit_call_kit_policy_test.dart test/livekit_ios_callkit_audio_gate_test.dart` exits 0
- [x] `dart analyze` on in-scope Dart files reports no errors
      (pre-existing warnings in `acceptFromUi` only)
- [x] No files outside the in-scope list are modified
- [x] `plans/README.md` status row for 047 updated
- [ ] Two-device CallKit repro listed as **NOT RUN** unless the operator
      actually ran it

## STOP conditions

Stop and report back (do not improvise) if:

- Live files no longer have `_waitForCallKitAudioReadyIfPending` /
  `prepareIosCallKitMediaJoin` / `holdCallAction` as described (drift).
- Fixing the waiter appears to require awaiting CallKit inside
  `acceptFromUi` or gating the **caller** connect path.
- `publishLocalCallTracks` defer seems to require changing Android
  join/publish (it must stay a no-op on Android — waiter unused /
  returns true).
- You believe the only fix is to delete CallKit or switch back to
  TUICallKit — out of scope.
- A step's verification fails twice after a reasonable fix attempt.

## Maintenance notes

- Reviewers: confirm timeout **never** publishes; confirm Answer
  fulfill is native and End/Mute still hold; confirm App-in + caller
  paths have no new awaits.
- If `didActivate` is still lost (engine not ready), the latch +
  native fulfill should still activate the session; Flutter then
  sees latch on first `_onAccept`. If logs show
  `voipAudioSessionActivated` never arriving, the next lever is
  AppDelegate channel readiness — do not silently re-add swallowed
  timeout.
- Follow-up explicitly deferred: Android FCM one-way audio (different
  stack); splitting `LiveKitCallSession` notifiers (029 V3).
