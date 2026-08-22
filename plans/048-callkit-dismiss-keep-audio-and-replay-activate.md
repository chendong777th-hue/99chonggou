# Plan 048: After CallKit join, dismiss with keepAudio; skip LiveKit speaker until then; query/replay native activate

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt against live files. Plan **047 must already
> be landed** (`_audioSessionActivatedLatch`, `publishLocalCallTracks` defer,
> native `CXAnswerCallAction` `fulfill` without `holdCallAction`). If 047 is
> missing, STOP. If `_onAccept` already dismisses with `keepAudioSession: true`
> after `acceptIncoming`, and `_ensureCallAudioRoute` already skips when
> CallKit owns the session, mark those steps DONE — do not duplicate.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED (iOS CallKit + LiveKit session ownership; must not
  `setActive(false)` on a live room; must not hang up on activate timeout)
- **Depends on**: plans/047-callkit-callee-mic-after-activate.md (DONE)
- **Category**: bug
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Execution**: DONE (2026-08-22) — `_onAccept` dismiss+keepAudio;
  speaker skip while CallKit owns session; native `audioSessionActivated`
  query on timeout / install / accept. Two-device CallKit repro NOT RUN.
- **Issue**: omit

## Why this matters

047 stopped publishing the callee mic before CallKit `didActivate`. The
repro **A calls B, B answers system incoming → A silent, B hears A** can
still happen after 047 for two independent reasons:

1. **Session fight.** App-in accept (`acceptFromUi`) joins, then
   `dismissSystemCallKitForSession(keepAudioSession: true)`, then
   `recoverCallAudio`. CallKit `_onAccept` joins and **leaves CallKit up**.
   `_connectAndPublish` then calls `_ensureCallAudioRoute` →
   `Hardware.setSpeakerphoneOn`, which reconfigures `AVAudioSession` from
   LiveKit track counters while CallKit still owns `playAndRecord` +
   `voiceChat`. Capture often dies; remote playback often survives → A
   silent, B hears A. This only happens on the system-answer path.
2. **Lost `voipAudioSessionActivated`.** AppDelegate already documents that
   `invokeMethod` before the Dart handler is installed is **silently
   dropped** (`pendingNotificationTap`). `voipAudioSessionActivated` has
   **no** such queue. 047’s Flutter latch never sets. Waiter times out,
   mic is deferred, republish is wired only to the dropped callback → A
   silent, B already in the room.

This plan aligns CallKit `_onAccept` with the working App-in dismiss
pattern, refuses LiveKit speaker reconfig while CallKit owns audio, and
lets Dart **ask native** whether `didActivate` already happened.

## Current state

### A. App-in accept dismisses CallKit with keepAudio; CallKit accept does not

`lib/src/services/livekit_voip_bridge.dart` `acceptFromUi` ≈279–307:

```dart
    // Keep CallKit audio session active through join; end system UI after media.
    await session.acceptIncoming();
    // ...
    await dismissSystemCallKitForSession(
      callId: session.callId,
      keepAudioSession: true,
    );
    if (session.isInCall) {
      await session.recoverCallAudio(tag: 'acceptFromUi/afterDismissCallKit');
```

Same file `_onAccept` success path ≈384–408 — **no dismiss**:

```dart
      unawaited(_restoreAudioRouteWhenReady(session));
      await session.acceptIncoming();
      if (LiveKitCallSession.instance.isInCall) {
        await session.recoverCallAudio(tag: 'callKit/afterAccept');
        await LiveKitCallNavigator.ensureCallPageVisible(
          reason: 'callKit/afterAccept',
        );
```

`dismissSystemCallKitForSession` already exists on the same class
(≈206–225) and forwards `keepAudioSession` to
`IosApnsPushService.endVoipCallKit`. Native
`SelfHostedVoipCallKit.endActiveCall` / `endCall` already honor
`keepAudioAcrossCallKitEnd` so `didDeactivate` does not
`setActive(false)` on LiveKit. **Reuse this. Do not invent a second end
API.**

### B. LiveKit speaker route always applies once any track is live

`lib/src/services/livekit_call_session.dart` `_ensureCallAudioRoute` ≈636–659:

```dart
    // On iOS, setSpeakerphoneOn reconfigures AVAudioSession from LiveKit's
    // track counters. Before any track is live that becomes soloAmbient ...
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        !hasLiveCallAudioTracks(_room)) {
      return;
    }
    await Hardware.instance.setSpeakerphoneOn(
      _speakerOn,
      forceSpeakerOutput: _speakerOn,
    );
```

This runs **inside** `acceptIncoming` → `_connectAndPublish` (after
publish, and again for callee) **before** `_onAccept` could dismiss
CallKit. Skipping only “no tracks” is not enough: after 047 the mic
track exists, so the skip does not fire.

Voice calls use `_speakerOn = creds.isVideo` (false). Product default
(earpiece) must stay. This plan only **delays** applying that route until
CallKit no longer owns the session.

### C. Native activate is fire-and-forget

`ios/Runner/AppDelegate.swift` `configureSelfHostedCallKit` ≈790–794:

```swift
        callKit.onAudioSessionActivated = { [weak self] uuid in
            self?.tuicallChannel?.invokeMethod(
                "voipAudioSessionActivated",
                arguments: ["uuid": uuid ?? ""]
            )
        }
```

Contrast the documented tap queue ≈986–991 (`pendingNotificationTap`).
There is **no** `isVoipAudioSessionActivated` query on `ios_apns_push`
(see `endVoipCallKit` / `connectVoipCallKit` around AppDelegate ≈347–384
and `lib/src/services/ios_apns_push_service.dart` ≈304–335).

047 Flutter latch: `_audioSessionActivatedLatch` only flips in
`_onAudioSessionActivated`. Timeout returns `false`;
`ensureLocalMicPublishedAfterCallKitActivate` only runs from that
callback.

### D. 047 contracts that must stay green

- `test/livekit_call_kit_policy_test.dart` — wait / allow-mic table
- `test/livekit_ios_callkit_audio_gate_test.dart` — latch, defer mic,
  callee-only `prepareIosCallKitMediaJoin`, `CXAnswerCallAction` fulfill,
  `keepAudioSession`, `hasLiveCallAudioTracks` skip
- Do **not** revert native Answer `fulfill` or 047 defer-on-timeout
- Do **not** await CallKit on `acceptFromUi` or caller `_connectAndPublish`

## Conventions to match

- Pure decisions go in `lib/src/services/livekit_call_kit_policy.dart`
  (same file as 047). Named required args, no `Room` types.
- Always-on logs via `liveKitCallUiLog(...)` for skip / dismiss / native
  query (same style as `recoverCallAudio`).
- Native CallKit end: keep using `keepAudioSession: true` after a live
  join — never `endVoipCallKit()` with default `false` on the success
  path.
- Tests: `flutter test` from repo root. Policy tests + source-string
  gate tests (existing style).
- Do **not** `git init` / commit / push unless the operator asks.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| 047 + 048 policy | `cd /Users/qiu/Downloads/9925banben && flutter test test/livekit_call_kit_policy_test.dart` | all pass |
| Gate contracts | `cd /Users/qiu/Downloads/9925banben && flutter test test/livekit_ios_callkit_audio_gate_test.dart` | all pass (updated strings) |
| Analyze | `cd /Users/qiu/Downloads/9925banben && dart analyze lib/src/services/livekit_call_kit_policy.dart lib/src/services/livekit_voip_bridge.dart lib/src/services/livekit_call_session.dart lib/src/services/ios_apns_push_service.dart` | no errors |

Device two-phone CallKit repro is **NOT RUN** in CI.

## Scope

**In scope**:

- `lib/src/services/livekit_call_kit_policy.dart` — add
  `iosCallKitShouldApplyLiveKitSpeakerRoute`
- `lib/src/services/livekit_voip_bridge.dart` — CallKit-owns flag;
  dismiss+recover after `_onAccept` success; query native activate;
  skip speaker while owned
- `lib/src/services/livekit_call_session.dart` — `_ensureCallAudioRoute`
  honors the policy (read a small getter / callback; do not import
  VoIP bridge cycles if avoidable — prefer a `@visibleForTesting` /
  top-level flag setter on the policy file or a `bool Function()?`
  like `iosCallKitAudioReadyWaiter`)
- `lib/src/services/ios_apns_push_service.dart` —
  `isVoipAudioSessionActivated()` invoking native
- `ios/Runner/SelfHostedVoipCallKit.swift` — `audioSessionActivated`
  bool; `didActivate` / `didDeactivate` update it
- `ios/Runner/AppDelegate.swift` — handle `isVoipAudioSessionActivated`
  (and optionally flush a pending activate invoke when Dart is ready)
- `test/livekit_call_kit_policy_test.dart`
- `test/livekit_ios_callkit_audio_gate_test.dart`
- `plans/README.md` — 048 status row

**Out of scope**:

- Reverting 047 waiter / defer / native Answer fulfill
- Awaiting CallKit inside `acceptFromUi` or caller connect
- Removing the `hasLiveCallAudioTracks` skip (keep it; **add** the
  CallKit-owns skip in front)
- Android FCM / no-CallKit incoming
- Changing voice earpiece default (`_speakerOn = creds.isVideo`)
- `LiveKitCallSystemUi._endSystemUi` hangup path (already ends CallKit
  when the Flutter session ends — do not add keepAudio there)
- Chat / wallet / 018 / 044–046
- Vendored `livekit_client`

## Git workflow

- No `.git` historically — do not `git init`.
- If a repo exists: branch `advisor/048-callkit-dismiss-keep-audio`.
- Do NOT push or open a PR unless asked.

## Steps

### Step 1: Policy — when LiveKit may call setSpeakerphoneOn

In `livekit_call_kit_policy.dart` add:

```dart
/// LiveKit Hardware.setSpeakerphoneOn fights CallKit's session.
/// Skip while the system incoming UI still owns audio.
bool iosCallKitShouldApplyLiveKitSpeakerRoute({
  required bool callKitOwnsAudioSession,
}) {
  return !callKitOwnsAudioSession;
}
```

Tests in `livekit_call_kit_policy_test.dart`:

| callKitOwnsAudioSession | apply speaker route |
|-------------------------|---------------------|
| false | true (App-in / after dismiss / caller) |
| true | false (system CallKit answer, join in progress) |

Keep all 047 cases.

**Verify**: `flutter test test/livekit_call_kit_policy_test.dart` → pass.

### Step 2: Session skip — do not reconfigure while CallKit owns audio

Add a hook next to `iosCallKitAudioReadyWaiter` in
`livekit_call_media_helpers.dart` **or** a top-level on the policy file:

```dart
bool Function()? iosCallKitOwnsAudioSession;
```

Bridge sets it `true` at the start of CallKit `_onAccept` (after
permission, when creating the completer) and `false` after successful
`dismissSystemCallKitForSession(keepAudioSession: true)` and on
`_resetAudioGate`.

`_ensureCallAudioRoute`:

```dart
    if (!kIsWeb &&
        defaultTargetPlatform == TargetPlatform.iOS &&
        !iosCallKitShouldApplyLiveKitSpeakerRoute(
          callKitOwnsAudioSession: iosCallKitOwnsAudioSession?.call() ?? false,
        )) {
      liveKitCallUiLog(
        '_ensureCallAudioRoute skip — CallKit owns audio session '
        'role=$_role ${describeCallAudioState(_room)}',
      );
      return;
    }
    // existing hasLiveCallAudioTracks skip stays
```

`acceptFromUi` must **not** set the owns-flag (or must leave it false)
so App-in still applies speaker after join / after its own dismiss.

**Verify**: `dart analyze` on session + helpers. Gate test later.

### Step 3: `_onAccept` success — same dismiss+recover as App-in

After `await session.acceptIncoming()` when `isInCall`:

```dart
      await dismissSystemCallKitForSession(
        callId: session.callId,
        keepAudioSession: true,
      );
      // clear owns-flag HERE (dismiss done)
      await session.recoverCallAudio(tag: 'callKit/afterDismissCallKit');
      await session.ensureLocalMicPublishedAfterCallKitActivate();
      await LiveKitCallNavigator.ensureCallPageVisible(
        reason: 'callKit/afterDismissCallKit',
      );
```

Failure / hangup / permission-deny paths that already
`endVoipCallKit()` without keepAudio stay as they are (call is dead).

Do **not** dismiss before `acceptIncoming` (CallKit must stay up through
join).

Keep `_restoreAudioRouteWhenReady` — it will no-op speaker while owns
is true, then recover after dismiss applies the route.

**Verify**: source-string: `_onAccept` contains
`keepAudioSession: true` after `acceptIncoming` (search that method
slice, not `acceptFromUi`).

### Step 4: Native activate latch + Dart query

`SelfHostedVoipCallKit.swift`:

- Add `private(set) var audioSessionActivated = false`
- `didActivate`: set `true` (already `configureAudioSession` + callback)
- `didDeactivate`: set `false` **unless** `keepAudioAcrossCallKitEnd`
  (same branch that already ignores deactivate for LiveKit)

`AppDelegate.swift` on `ios_apns_push` (same switch as
`endVoipCallKit`):

```swift
case "isVoipAudioSessionActivated":
    result(SelfHostedVoipCallKit.shared.audioSessionActivated)
```

`IosApnsPushService`:

```dart
Future<bool> isVoipAudioSessionActivated() async {
  if (!Platform.isIOS) return false;
  try {
    final v = await _channel.invokeMethod<bool>('isVoipAudioSessionActivated');
    return v == true;
  } catch (_) {
    return false;
  }
}
```

`LiveKitVoipBridge`:

1. In `_waitForCallKitAudioReadyIfPending`, on timeout (before
   `return false`): `await _syncLatchFromNative()`. If latch becomes
   true, return true.
2. `_syncLatchFromNative()`: if already latched, return; else query
   `IosApnsPushService.instance.isVoipAudioSessionActivated()`; if true,
   call `_onAudioSessionActivated()` (sets latch, completes completer,
   republish).
3. `ensureInstalled`: after setting the method handler, `unawaited`
   `_syncLatchFromNative()`.
4. `_onAccept` after creating the completer: `await _syncLatchFromNative()`
   before `acceptIncoming`.

Do **not** replay `voipChangeAccept` (double `acceptIncoming` risk).
Only sync **activate**.

Optional (if you already touch AppDelegate callbacks): if
`tuicallChannel` has no Dart handler yet, stash the last activate
uuid and send it when a new `voipBridgeReady` method arrives. Query
alone is enough if `audioSessionActivated` stays true until
deactivate — prefer query; only add pending invoke if the bool can
be false while the session is actually live (should not happen).

**Verify**: `rg -n "isVoipAudioSessionActivated" ios/Runner lib/src/services` finds Swift + Dart.

### Step 5: Update source-string tests

`test/livekit_ios_callkit_audio_gate_test.dart` add/keep:

- `_onAccept` slice contains `keepAudioSession: true` and
  `callKit/afterDismissCallKit` (or the recover tag you used)
- `_ensureCallAudioRoute` contains `CallKit owns audio session` skip
  **and** still contains `!hasLiveCallAudioTracks(_room)`
- `isVoipAudioSessionActivated` in `ios_apns_push_service.dart` and
  `AppDelegate.swift`
- 047 assertions still hold (latch, defer mic, Answer fulfill, callee-only prepare)

**Verify**:

```bash
cd /Users/qiu/Downloads/9925banben && flutter test \
  test/livekit_call_kit_policy_test.dart \
  test/livekit_ios_callkit_audio_gate_test.dart
```

→ all pass.

## Test plan

- Policy: `iosCallKitShouldApplyLiveKitSpeakerRoute` true/false (Step 1).
- Wiring: source-string tests in `livekit_ios_callkit_audio_gate_test.dart`.
- Pattern: existing 047 tests in that file +
  `test/livekit_call_kit_policy_test.dart`.
- No `Room` widget tests.
- Operator **NOT RUN**: A calls B voice, B lock-screen CallKit answer —
  both audio; A answers B in-app — both audio; voice stays earpiece.

## Done criteria

- [x] `iosCallKitShouldApplyLiveKitSpeakerRoute` tested
- [x] CallKit `_onAccept` success dismisses with `keepAudioSession: true`
      then recover / republish mic
- [x] `_ensureCallAudioRoute` skips `setSpeakerphoneOn` while CallKit owns
      audio; `hasLiveCallAudioTracks` skip remains
- [x] Native `audioSessionActivated` + Dart `isVoipAudioSessionActivated`;
      waiter timeout / ensureInstalled / `_onAccept` sync from native
- [x] 047 tests still pass; new strings covered
- [x] `flutter test test/livekit_call_kit_policy_test.dart test/livekit_ios_callkit_audio_gate_test.dart` exits 0
- [x] `dart analyze` on in-scope Dart files: no errors
      (pre-existing warnings in `acceptFromUi` / push service only)
- [x] No files outside scope
- [x] `plans/README.md` 048 row updated
- [ ] Two-device repro **NOT RUN** unless operator ran it

## STOP conditions

- 047 symbols missing (`_audioSessionActivatedLatch`, defer mic,
  Answer `fulfill` without hold).
- Success-path dismiss would require `keepAudioSession: false`.
- Fix appears to need awaiting CallKit on `acceptFromUi` / caller.
- You would remove the no-tracks speaker skip instead of adding the
  owns-session skip.
- Verification fails twice after a reasonable fix.

## Maintenance notes

- Reviewers: `_onAccept` success must match `acceptFromUi` dismiss
  contract; permission/hangup failures must still end CallKit without
  keepAudio; speaker apply after dismiss must still use
  `_speakerOn = isVideo` (earpiece for voice).
- 047 latch stays; 048 adds a **native source of truth** so a dropped
  MethodChannel activate is not fatal.
- Deferred: Android FCM one-way; pending replay of `voipChangeAccept`
  (dangerous). If logs show `isVoipAudioSessionActivated == false`
  while CallKit is clearly in-call, then add a pending activate
  invoke — do not silently treat timeout as publish-OK.
