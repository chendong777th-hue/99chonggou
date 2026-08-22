# Plan 029: Cut LiveKit call-page stutter — paint-gate rebuilds + stagger heavy bg

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
- **Effort**: M
- **Risk**: MED (call UI timing; must not blank video or break hangup exit)
- **Depends on**: none
- **Category**: perf
- **Planned at**: working tree 2026-08-22 (no git SHA — `NO_GIT` at plan time)
- **Execution**: DONE (2026-08-22) — paint snapshot gates `_onSession`;
  heavy bg delayed (audio 430ms / video 630ms) + capped memCache; tests green.
- **Issue**: omit

## Why this matters

Users feel **顿挫** on the fullscreen LiveKit C2C call page (enter, answer,
layout swap, hangup). Plan 005 already cut call-bubble history alloc; this
plan targets the **fullscreen page** only.

Two high-confidence mechanisms stack on the same window:

1. `LiveKitCallPage._onSession` always `setState(() {})` on every
   `LiveKitCallSession.notifyListeners` — phase, tracks, mute, room attach,
   etc. all rebuild the full Stack (background + `VideoTrackRenderer` + chrome).
2. `_scheduleHeavyBg` enables full-bleed `CachedNetworkImage` exactly when
   the 180ms enter fade ends — often the same moment local/remote video
   textures are mounting (`shouldShowLiveKitVideoLayer` already true in
   `connecting` / caller `ringingOut`).

Goal: rebuild only when **paint-relevant** session fields change, and
**stagger** heavy avatar decode away from video texture mount — without
changing call audio/signaling semantics or the intentional early video
preview policy.

## Current state

### A. Unconditional rebuild on session notify

`lib/src/pages/livekit_call_page.dart` ≈208–228:

```dart
void _onSession() {
  if (!mounted || _closing) return;
  // ... callee _localIsBig = false once ...
  if (_session.phase == LiveKitCallPhase.idle ||
      _session.phase == LiveKitCallPhase.ended) {
    _exitCallPage();
    return;
  }
  setState(() {});
}
```

Session notifies frequently (`livekit_call_session.dart` — many
`notifyListeners()` sites for phase / tracks / mute).

Duration already uses `ValueNotifier` + `ValueListenableBuilder` (≈505+) —
good pattern to extend: chrome/video should not rebuild for non-visual churn.

### B. Heavy bg timed to enter fade only

≈147–153 + ≈456–491:

```dart
_heavyBgTimer = Timer(LiveKitCallNavigator.enterTransitionDuration, () {
  setState(() => _allowHeavyBg = true);
});
// ...
CachedNetworkImage(
  ...
  memCacheWidth: cacheSize, // shortestSide — still large full-bleed decode
  fadeInDuration: Duration.zero,
);
```

`enterTransitionDuration` is 180ms (`livekit_call_navigator.dart` ≈19).

### C. Video layer policy (keep product behavior)

`lib/src/services/livekit_call_video_layer.dart` —
`shouldShowLiveKitVideoLayer`: video shows in `connected`, `connecting`+room,
caller `ringingOut`+room. Covered by `test/livekit_call_video_layer_test.dart`.
**Do not** revert to “connected-only” (that caused blank preview before).

### D. Exit path (do not break)

≈231–263: `_exiting` blanks video/bg then next-frame pop. Keep this contract.

### E. Conventions / exemplars

- Pure helpers + tests: match `test/livekit_call_video_layer_test.dart` and
  `lib/src/services/livekit_call_video_layer.dart` (`@visibleForTesting`).
- Logging: keep `liveKitCallUiLog` on real phase/exit transitions; do **not**
  log every skipped rebuild (noise).
- Prefer extracting a small immutable **paint snapshot** over rewriting
  `LiveKitCallSession` into multiple ChangeNotifiers (higher risk).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| New + video-layer tests | `cd /Users/qiu/Downloads/9925banben && flutter test test/livekit_call_page_paint_gate_test.dart test/livekit_call_video_layer_test.dart test/livekit_call_transition_test.dart` | exit 0 |
| Grep rebuild gate | `rg -n "_onSession|LiveKitCallPagePaintSnapshot|shouldRebuild|setState" lib/src/pages/livekit_call_page.dart` | `_onSession` gated |
| Grep heavy bg | `rg -n "_scheduleHeavyBg|_allowHeavyBg|enterTransitionDuration" lib/src/pages/livekit_call_page.dart` | stagger logic present |

## Scope

**In scope**:

- `lib/src/pages/livekit_call_page.dart` — `_onSession` paint gate; heavy-bg
  scheduling; optional bound decode size for backdrop only.
- New pure helper file, e.g.
  `lib/src/services/livekit_call_page_paint_gate.dart` (or under
  `lib/src/utils/`) + `test/livekit_call_page_paint_gate_test.dart`.
- Touch `livekit_call_video_layer.dart` **only** if you add a documented
  helper used by the page (e.g. “video layer just became showable”) — do not
  change default show/hide matrix without updating
  `livekit_call_video_layer_test.dart` and an explicit product note in the
  PR/plan status.

**Out of scope**:

- Call signaling, token, ringtone, CallKit audio gate, VoIP push.
- Rewriting `LiveKitCallSession` notify frequency / splitting the session
  singleton into many notifiers (unless a one-line bugfix is forced — prefer
  STOP).
- Chat call bubbles / Plan 005 paths.
- `RecentCallsPage` list jank (separate follow-up).
- Changing enter fade to non-zero exit animation.
- Removing early video preview for connecting / ringingOut caller.

## Git workflow

- Branch if git exists: `advisor/029-livekit-call-page-stutter`.
- Commits: `perf: gate LiveKitCallPage setState on paint snapshot`,
  `perf: stagger call-page heavy avatar behind video settle`.
- Do NOT push unless asked.

## Target behavior

1. Session notifies that do **not** change paint-relevant fields → **no**
   `setState` on the call page.
2. Paint-relevant changes (phase, room presence for video gate, local/remote
   track identity, mute/camera UI flags the chrome reads, peer ids if shown)
   still update UI promptly.
3. Idle/ended still calls `_exitCallPage` immediately (must not be gated away).
4. Full-bleed peer face decode starts **after** enter fade **and** either
   (a) an extra delay (≥150–300ms beyond enter), or (b) when video layer is
   not mounting in the same window — pick one policy and test it; for
   **audio-only** calls, heavy bg may still follow enter+extra delay (no video
   race).
5. `shouldShowLiveKitVideoLayer` matrix stays product-equivalent unless tests
   are intentionally updated.
6. Hangup still blanks layers then pops (`_exiting` contract).

## Steps

### Step 1: Pure paint snapshot + shouldRebuild tests

Create `lib/src/services/livekit_call_page_paint_gate.dart`:

```dart
@immutable
class LiveKitCallPagePaintSnapshot {
  const LiveKitCallPagePaintSnapshot({
    required this.phase,
    required this.isVideo,
    required this.hasRoom,
    required this.showVideoLayer,
    required this.localTrackSid,   // or identity string; null if none
    required this.remoteTrackSid,
    required this.micMuted,        // whatever chrome actually reads
    required this.cameraOff,
    required this.speakerOn,
    // add only fields the page build() genuinely depends on
  });

  // equality / hashCode — or use Equatable if already in deps (prefer manual)

  static LiveKitCallPagePaintSnapshot capture(LiveKitCallSession session) { ... }

  static bool shouldRebuild({
    required LiveKitCallPagePaintSnapshot? previous,
    required LiveKitCallPagePaintSnapshot next,
  }) => previous == null || previous != next;
}
```

Wire `showVideoLayer` via existing `shouldShowLiveKitVideoLayer`.

Tests in `test/livekit_call_page_paint_gate_test.dart`:

1. Identical snapshots → `shouldRebuild` false.
2. Phase change → true.
3. Track sid null→non-null → true.
4. Unrelated field omitted from snapshot must **not** force rebuild (document
   which session churn is intentionally ignored).

**Do not** instantiate a real LiveKit `Room` in tests — pass fabricated
snapshot fields.

**Verify**:

```bash
cd /Users/qiu/Downloads/9925banben && flutter test test/livekit_call_page_paint_gate_test.dart
```

→ exit 0.

### Step 2: Gate `_onSession` with the snapshot

In `livekit_call_page.dart`:

1. Keep `LiveKitCallPagePaintSnapshot? _lastPaint`.
2. On `_onSession`: always handle idle/ended → `_exitCallPage` first.
3. Apply callee `_localIsBig` once as today.
4. `final next = LiveKitCallPagePaintSnapshot.capture(_session);`
5. If `!shouldRebuild(previous: _lastPaint, next: next)` → return.
6. Else `_lastPaint = next; setState(() {});`

Optional: when `showVideoLayer` flips false→true, call into Step 3’s
“video mounted” hint for heavy-bg scheduling.

**Verify**:

```bash
rg -n "shouldRebuild|LiveKitCallPagePaintSnapshot|_lastPaint" \
  lib/src/pages/livekit_call_page.dart
```

→ gate present. Manually sanity: mute toggle still updates icon if chrome
reads mute from snapshot — if mute was forgotten in snapshot, STOP and add it.

```bash
cd /Users/qiu/Downloads/9925banben && flutter test \
  test/livekit_call_page_paint_gate_test.dart \
  test/livekit_call_video_layer_test.dart
```

### Step 3: Stagger heavy background decode

Change `_scheduleHeavyBg` policy:

**Recommended (simple, testable)**:

- Base delay = `enterTransitionDuration + const Duration(milliseconds: 250)`
  (total ~430ms from init).
- If `session.isVideo`, add another `+ 200ms` **or** postpone enabling
  `_allowHeavyBg` until `showVideoLayer` has been true for one frame + 200ms
  (whichever is later). Audio-only: base delay only.
- Cap backdrop `memCacheWidth/Height` to something smaller than full
  `shortestSide` when used as **blurred/scrimmed** bg (e.g. half shortestSide
  or a fixed 720) — keep `BoxFit.cover` + scrim; visual softness under scrim
  is OK. Do **not** change avatar widget sizes in the user-info row.

Keep solid `ColoredBox` until `_allowHeavyBg`. Cancel timer on dispose/exit
as today.

Extract delay math to a pure function in the paint-gate file for unit tests:

```dart
Duration liveKitCallHeavyBgDelay({
  required bool isVideo,
  required Duration enterTransition,
});
```

**Verify**:

```bash
cd /Users/qiu/Downloads/9925banben && flutter test test/livekit_call_page_paint_gate_test.dart
```

→ includes delay cases. Grep `_allowHeavyBg` still gated behind the new delay.

### Step 4: Regression suite + manual checklist

```bash
cd /Users/qiu/Downloads/9925banben && flutter test \
  test/livekit_call_page_paint_gate_test.dart \
  test/livekit_call_video_layer_test.dart \
  test/livekit_call_transition_test.dart \
  test/livekit_call_small_video_pip_test.dart \
  test/livekit_voip_accept_order_test.dart
```

→ exit 0.

Update `plans/README.md` row 029 → DONE.

**Manual (NOT RUN in CI)**:

1. Outgoing video: local preview still appears before answer; enter feels
   smoother (less hitch at ~180ms).
2. Incoming video accept: no long blank; chrome buttons remain tappable.
3. Mute / speaker / camera toggles still update UI.
4. Hangup: page still pops cleanly without stuck black frame.
5. Audio-only call: avatar/backdrop still appears; no permanent solid-only.

## Test plan

- New: `livekit_call_page_paint_gate_test.dart` (snapshot equality + delay).
- Keep green: video layer, transition, small PiP, voip accept order tests.
- No golden screenshot required.

## Done criteria

- [ ] `_onSession` does not `setState` when paint snapshot unchanged.
- [ ] Idle/ended still exits via `_exitCallPage`.
- [ ] Heavy bg delay > enter fade alone when video; pure delay helper tested.
- [ ] `shouldShowLiveKitVideoLayer` product matrix unchanged **or** tests +
      plan note explicitly updated.
- [ ] Listed `flutter test` commands exit 0.
- [ ] No out-of-scope files modified.
- [ ] `plans/README.md` 029 status updated.

## STOP conditions

- Paint snapshot omits a field the chrome reads → mute/camera UI stuck —
  add field, do not ship.
- Fix seems to require silencing `notifyListeners` inside
  `LiveKitCallSession` — STOP; keep UI-side gate only.
- Early video preview regresses to blank during connecting — STOP; do not
  “fix” by connected-only layer.
- Hangup leaves a zombie route — restore `_exiting` order; STOP if unclear.
- Verification fails twice after a reasonable fix attempt.

## Maintenance notes

- Any new chrome control bound to session state must be added to
  `LiveKitCallPagePaintSnapshot` or it will not refresh.
- Reviewers: compare rebuild count mentally — connecting→connected should
  still rebuild; rapid identical notifies must not.
- Follow-ups (not this plan): split session into chrome vs media listenables;
  `RecentCallsPage` load jank; Instruments Display Hitch on device.
