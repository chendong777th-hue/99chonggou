# Plan 012: Stop false “recovery satisfied” on warm resume

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> any STOP condition is hit, stop and report — do not improvise. When done,
> update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt against live files. If symbols or control flow
> changed materially, STOP and report before coding.
>
> **Prerequisite**: Prefer landing **plan 011** first (CLOUD_NEWER allowed on
> `app_resumed`). This plan still helps if 011 is blocked, but the product
> gap closes only when both land.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED (more retries / fewer early exits on resume — watch coalesce
  and skip windows)
- **Depends on**: plan 011 (soft — wire cloud first; then fix early-exit lies)
- **Category**: bug / correctness
- **Planned at**: working tree 2026-08-21 (NO_GIT — no SHA)
- **Issue**: omit

## Why this matters

Even after plan 011 allows cloud pull, warm resume can still **claim success
without catching up**:

1. **`isRecoveryAlreadySatisfied`** returns true when
   `!changed && hasMessages && !previewAhead && !hasDeferredIncoming`.
   After a no-op local pull (or before cloud results apply), this treats
   “preview aligned + we already have some bubbles” as done — which is
   exactly the warm-resume miss case when messages arrived offline.

2. **`history_recovery_skip_preview_merge_warm`** path: if pull did not change
   history but the chat already has visible messages and
   `hasInitialHistoryLoaded`, recovery **records successful recovery** and
   returns. That arms the **30s skip window** in
   `ChatHistoryRecoveryCoordinator.shouldSkipForegroundRecovery`, so a later
   `app_resumed` / `sync_server_finish` is skipped even when the list is stale.

3. **`ResumeForegroundPolicy.chatRecoveryRetryDelays`**: when
   `hasVisibleMessages && !previewAhead`, returns **only** `[Duration.zero]` —
   a single attempt. Combined with (1)/(2), there is no second chance.

User-visible symptom matches: warm resume (no splash) drops messages; kill
process → cold start reloads and messages reappear.

## Current state

### Satisfaction helper

`lib/src/utils/chat_history_recovery_satisfaction.dart`:

```dart
bool isRecoveryAlreadySatisfied({
  required bool changed,
  required bool hasMessages,
  required bool previewAhead,
  bool hasDeferredIncoming = false,
}) {
  return !changed && hasMessages && !previewAhead && !hasDeferredIncoming;
}
```

Tests in `test/chat_history_recovery_satisfaction_test.dart` encode the old
contract (true when messages exist, preview aligned, no change).

### Early exit that records success without cloud proof

`lib/src/chat.dart` (after `_pullLatestMessagesFromAnchor` in recovery):

```dart
if (isRecoveryAlreadySatisfied(
  changed: changed,
  hasMessages: hasMessages,
  previewAhead: previewAhead,
  hasDeferredIncoming: hasDeferredIncoming,
)) {
  // logs history_recovery_skip_satisfied
  _recordRecoverySuccess();
  _publishExternalEntryState();
  return;
}
final convKey = _getConvID()?.trim() ?? '';
final globalModel = serviceLocator<TUIChatGlobalModel>();
if (hasMessages &&
    convKey.isNotEmpty &&
    globalModel.hasInitialHistoryLoaded(convKey)) {
  ExternalChatEntryService.instance.logFlow(
    'history_recovery_skip_preview_merge_warm',
    // ...
  );
  _recordRecoverySuccess();
  _publishExternalEntryState();
  return;
}
```

### Skip window after false success

`lib/src/services/chat_history_recovery_coordinator.dart`:

```dart
static const Duration _skipRecoveryWindow = Duration(seconds: 30);
// ...
if (normalizedReason != 'sync_server_finish' &&
    normalizedReason != 'connect_success' &&
    normalizedReason != 'app_resumed') {
  return false;
}
return true; // skip when recent successful recovery + !previewAhead
```

`im_reconnected` is already never skipped (good). `app_resumed` **is**
skippable after a false success within 30s.

### Single retry when preview not ahead

`lib/src/services/resume_foreground_policy.dart`:

```dart
static List<Duration> chatRecoveryRetryDelays({
  required bool hasVisibleMessages,
  required bool previewAhead,
}) {
  if (hasVisibleMessages && !previewAhead) {
    return const <Duration>[Duration.zero];
  }
  return const <Duration>[
    Duration.zero,
    Duration(milliseconds: 800),
    Duration(milliseconds: 2000),
  ];
}
```

## Desired end state

### A. Satisfaction must know whether cloud catch-up was required / attempted

Extend the pure helper (keep it pure — no Flutter services):

```dart
bool isRecoveryAlreadySatisfied({
  required bool changed,
  required bool hasMessages,
  required bool previewAhead,
  bool hasDeferredIncoming = false,
  bool cloudCatchUpRequired = false,
  bool cloudCatchUpAttempted = false,
}) {
  if (changed) return false;
  if (!hasMessages) return false;
  if (previewAhead) return false;
  if (hasDeferredIncoming) return false;
  // Warm resume: having local bubbles is not proof the server gap is closed.
  if (cloudCatchUpRequired && !cloudCatchUpAttempted) return false;
  return true;
}
```

Semantics:

- `cloudCatchUpRequired`: same meaning as plan 011’s
  `shouldAllowCloudCatchUp` when `previewAhead` is false (i.e. we needed
  cloud because of resume reason).
- `cloudCatchUpAttempted`: true only after `_pullLatestMessagesFromAnchor`
  was invoked with `allowCloudPull: true` for this attempt (011 wires that).

When `cloudCatchUpRequired && cloudCatchUpAttempted && !changed &&
!previewAhead && !hasDeferredIncoming`, returning **true** is OK (server had
nothing newer than the anchor). Returning true without an attempted cloud
pull when required is **forbidden**.

### B. Do not `_recordRecoverySuccess` on `skip_preview_merge_warm` when cloud was required

For the warm skip branch:

- If `cloudCatchUpRequired` is true and this attempt did **not** run with
  cloud allowed, **do not** call `_recordRecoverySuccess()`; continue retry
  delays or fall through to merge/preview paths as today.
- If cloud was required **and** attempted and still `!changed`, then
  recording success is allowed (same as satisfied).
- Prefer renaming the log event only if needed; keep
  `history_recovery_skip_preview_merge_warm` for telemetry continuity when
  behavior is “skip merge but success ok”.

Minimum acceptable change if control flow is messy: **never** call
`_recordRecoverySuccess()` on that warm branch when
`source == 'app_resumed' || source == 'im_reconnected' || source == 'connect_success'`
unless `allowCloudPull` was true for the just-finished pull. Prefer the
explicit bools from A for clarity.

### C. Retry delays for resume when cloud catch-up is required

Update `ResumeForegroundPolicy.chatRecoveryRetryDelays` to accept an optional
flag (or replace `previewAhead` coupling):

```dart
static List<Duration> chatRecoveryRetryDelays({
  required bool hasVisibleMessages,
  required bool previewAhead,
  bool cloudCatchUpRequired = false,
}) {
  if (hasVisibleMessages && !previewAhead && !cloudCatchUpRequired) {
    return const <Duration>[Duration.zero];
  }
  return const <Duration>[
    Duration.zero,
    Duration(milliseconds: 800),
    Duration(milliseconds: 2000),
  ];
}
```

Wire from `_resolveRecoveryRetryDelays` in `chat.dart` using the same
`shouldAllowCloudCatchUp` helper from plan 011 when `!previewAhead`.

Update `test/resume_foreground_policy_test.dart` cases that assert single
delay for `hasVisibleMessages && !previewAhead` — add a case that
`cloudCatchUpRequired: true` returns the three-delay list.

### D. Coordinator: do not skip `app_resumed` after a recovery that never cloud-caught when required

Minimal fix (choose **one**; prefer smallest):

**Option D1 (preferred)**: Add optional
`forceAllow = false` / or reason-specific: if
`normalizedReason == 'app_resumed'` and caller passes
`requireCloudCatchUp: true`… actually coordinator does not know cloud.

Better **Option D2**: Stop recording false successes (B) so the 30s window
is never armed incorrectly. Keep `shouldSkipForegroundRecovery` logic
unchanged if B is solid.

**Option D3** (only if B is insufficient): For `app_resumed`, never skip
when `hasDeferredIncoming` (already) **or** when a new flag
`lastRecoveryCloudCatchUpAttempted == false` is stored on the coordinator
state. This is more invasive — use only if D2 cannot land.

This plan’s default is **D2**: fix success recording + satisfaction; leave
skip predicate as-is unless tests prove a remaining hole.

## Out of scope

- Changing cold-start / splash path
- Persisting background lastMsgID to SharedPreferences
- Using `_lastEnteredBackgroundAt` as a message timestamp filter
- Raising or removing `_loggedInSideEffectMinInterval` (12s) in `app.dart`
  unless proven necessary after 011+012 — note as follow-up if still flaky
- Fixing unrelated `conversationHoldDuration` 1500ms vs 3s test drift
  (document only)

## Implementation steps

### Step 1 — Drift check + confirm 011 status

```bash
rg -n "shouldAllowCloudCatchUp|allowCloudPull: previewAhead|isRecoveryAlreadySatisfied|history_recovery_skip_preview_merge_warm|chatRecoveryRetryDelays" \
  lib/src/chat.dart \
  lib/src/utils/chat_history_recovery_satisfaction.dart \
  lib/src/services/resume_foreground_policy.dart
```

If `shouldAllowCloudCatchUp` is missing, implement plan 011 first (or STOP and
report that 012 alone cannot close the product gap).

### Step 2 — Update satisfaction helper + tests

Edit `lib/src/utils/chat_history_recovery_satisfaction.dart` per Desired A.

Update `test/chat_history_recovery_satisfaction_test.dart`:

- Keep existing cases with defaults (`cloudCatchUpRequired` false) so old
  behavior for non-resume paths stays.
- Add:
  - `cloudCatchUpRequired: true, cloudCatchUpAttempted: false` → **false**
    even when hasMessages && !previewAhead && !changed
  - `cloudCatchUpRequired: true, cloudCatchUpAttempted: true` → **true**
    under the same other flags
  - deferred incoming still forces false

```bash
flutter test test/chat_history_recovery_satisfaction_test.dart
```

Expected: PASS.

### Step 3 — Wire bools in `lib/src/chat.dart` recovery loop

At the pull site (after plan 011):

```dart
final shouldAllowCloudCatchUp = warm_resume.shouldAllowCloudCatchUp(
  source: source,
  previewAhead: previewAhead,
);
final changed = await _pullLatestMessagesFromAnchor(
  model: model,
  source: source,
  allowCloudPull: shouldAllowCloudCatchUp,
);
// ...
if (isRecoveryAlreadySatisfied(
  changed: changed,
  hasMessages: hasMessages,
  previewAhead: previewAhead,
  hasDeferredIncoming: hasDeferredIncoming,
  cloudCatchUpRequired: shouldAllowCloudCatchUp && !previewAhead,
  cloudCatchUpAttempted: shouldAllowCloudCatchUp,
)) {
```

For the warm skip branch: only `_recordRecoverySuccess()` when
`isRecoveryAlreadySatisfied(...)` would be true **or** when
`!shouldAllowCloudCatchUp || shouldAllowCloudCatchUp` already attempted and
nothing changed. Concrete rule:

```dart
if (hasMessages &&
    convKey.isNotEmpty &&
    globalModel.hasInitialHistoryLoaded(convKey)) {
  final mayMarkSuccess = !shouldAllowCloudCatchUp ||
      (shouldAllowCloudCatchUp && !changed && !previewAhead && !hasDeferredIncoming);
  // Actually: if cloud required, only mark success if cloud was allowed on this pull
  // (shouldAllowCloudCatchUp true) AND !hasDeferredIncoming.
  final mayMarkSuccess = shouldAllowCloudCatchUp
      ? (!hasDeferredIncoming && !previewAhead)
      : true;
  ExternalChatEntryService.instance.logFlow(
    'history_recovery_skip_preview_merge_warm',
    // extras: include mayMarkSuccess, shouldAllowCloudCatchUp
  );
  if (mayMarkSuccess) {
    _recordRecoverySuccess();
  }
  _publishExternalEntryState();
  if (mayMarkSuccess) {
    return;
  }
  // else: fall through to continue retry / merge paths — do not return early
}
```

**Careful**: today’s code **always returns** after that branch. Changing to
fall-through must not infinite-loop. Prefer:

- If `!mayMarkSuccess`, **do not return**; let the existing retry loop
  continue to the next delay.
- If the loop would immediately hit the same branch again without cloud,
  that indicates 011 was not applied — STOP.

Re-read the full `for` / retry loop around this block before editing. If
fall-through is unsafe, alternative: `continue` to next retry index instead
of `return`, still without `_recordRecoverySuccess()`.

### Step 4 — Retry delays

Update `ResumeForegroundPolicy.chatRecoveryRetryDelays` per Desired C.
Update `_resolveRecoveryRetryDelays` callers to pass
`cloudCatchUpRequired: shouldAllowCloudCatchUp && !previewAhead` (compute
source/preview the same way as the pull).

Update `test/resume_foreground_policy_test.dart` accordingly.

```bash
flutter test test/resume_foreground_policy_test.dart
```

If the suite fails on `conversationHoldDuration == 1500ms` while source is
`3s`, **only** fix the test expectation to match **current source** `3s` if
you touch that file for the delay cases — do not change the production
constant. Document the expectation fix in the PR/summary.

### Step 5 — Coordinator tests (regression)

Add one test in `test/chat_history_recovery_coordinator_test.dart`:

- After `recordSuccessfulRecovery`, `app_resumed` + visible + !previewAhead
  still skips (existing behavior).
- Document in a comment that false success must not be recorded (012
  responsibility in chat.dart) — optional: do **not** change skip logic
  unless D3 is required.

```bash
flutter test \
  test/chat_history_recovery_satisfaction_test.dart \
  test/chat_history_recovery_coordinator_test.dart \
  test/resume_foreground_policy_test.dart \
  test/chat_foreground_resume_reconcile_contract_test.dart \
  test/chat_warm_resume_catchup_test.dart
```

Expected: all PASS (011 tests must exist).

### Step 6 — Manual checklist (same as 011)

1. Warm background > 30s, peer sends messages, resume without splash.
2. Confirm messages appear.
3. Immediately background/foreground again within 30s; confirm no permanent
   “stuck empty gap” (skip window must not hide a real gap after a real
   cloud attempt that returned empty — OK to skip).

## Done criteria

- [ ] `isRecoveryAlreadySatisfied` rejects
      `cloudCatchUpRequired && !cloudCatchUpAttempted`.
- [ ] Warm `skip_preview_merge_warm` path does not
      `_recordRecoverySuccess()` when cloud catch-up was required but not
      allowed/attempted.
- [ ] `chatRecoveryRetryDelays(..., cloudCatchUpRequired: true)` returns the
      three-delay list even when `hasVisibleMessages && !previewAhead`.
- [ ] Tests listed in Step 5 PASS.
- [ ] No changes to cold-start login / splash.

## In-scope files

- `lib/src/utils/chat_history_recovery_satisfaction.dart`
- `test/chat_history_recovery_satisfaction_test.dart`
- `lib/src/chat.dart` (recovery early-exit / success recording / retry args)
- `lib/src/services/resume_foreground_policy.dart`
- `test/resume_foreground_policy_test.dart`
- Optionally `test/chat_history_recovery_coordinator_test.dart` (comments /
  regression only)

## Explicitly out of scope files

- `lib/src/pages/app.dart` lifecycle timers (follow-up if still flaky)
- `lib/src/services/login_coordinator.dart`
- Conversation list preview builders
- Plans 001–010 / 011 helper file except calling it

## STOP conditions

- Recovery loop structure makes fall-through unsafe (risk of tight spin) —
  STOP and report with the loop excerpt; propose `continue` vs redesign.
- Plan 011 not present and product owner forbids cloud pulls — STOP; 012
  alone cannot fix missing server messages.
- Need to change UIKit `loadChatRecord` semantics — STOP.

## Test plan

1. Extended satisfaction unit tests.
2. Policy delay unit tests.
3. Existing coordinator + contract + 011 helper tests.
4. Manual warm-resume scenario (NOT RUN OK if no device; list steps).

## Maintenance notes

- Any new early-exit that calls `_recordRecoverySuccess()` must prove either
  history `changed` or cloud catch-up attempted when required.
- Keep `im_reconnected` unskippable in the coordinator.
- If logs still show `history_recovery_skip_satisfied` immediately after
  resume with empty cloud, check previewAhead false-negatives separately.

## Escape hatches

If three retries cause visible jank on every short unlock: keep three delays
only when `cloudCatchUpRequired`, leave single attempt for the old
`hasVisible && !previewAhead && !cloudCatchUpRequired` path (as specified).
