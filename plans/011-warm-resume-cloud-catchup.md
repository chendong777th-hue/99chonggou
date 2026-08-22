# Plan 011: Warm resume must allow CLOUD_NEWER catch-up

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> any STOP condition is hit, stop and report — do not improvise. When done,
> update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt against live files. If symbols or control flow
> changed materially, STOP and report before coding.

## Status

- **Priority**: P0
- **Effort**: S–M
- **Risk**: MED (extra cloud history pulls on resume; keep scoped to
  foreground-recovery reasons)
- **Depends on**: none (plan 012 soft-follow for skip/satisfied false
  positives)
- **Category**: bug / correctness
- **Planned at**: working tree 2026-08-21 (NO_GIT — no SHA)
- **Issue**: omit

## Why this matters

Product report: after background → foreground **without** process kill
(no splash / warm resume), opening chat can **miss messages**. Cold start
(process killed → splash) is fine.

Root cause (verified in code): warm recovery calls
`_pullLatestMessagesFromAnchor(..., allowCloudPull: previewAhead)`. When the
conversation-list **preview is not ahead** of the in-memory last message
(common if the OS suspended the app and SDK did not deliver live updates),
**local-only** newer pull runs and **CLOUD_NEWER is skipped**. Messages that
exist only on the server never appear until a full cold reload.

There is already a **source contract test** that expects
`shouldAllowCloudCatchUp` and `allowCloudPull: shouldAllowCloudCatchUp` in
`lib/src/chat.dart`. Live code does **not** contain that symbol — the test
documents the intended fix that was never landed (or was reverted).

## Current state

### Call site still gates cloud on preview only

`lib/src/chat.dart` (recovery loop inside history activation / refresh):

```dart
if (isRecovery) {
  final changed = await _pullLatestMessagesFromAnchor(
    model: model,
    source: source,
    allowCloudPull: previewAhead,
  );
```

### Pull helper already supports cloud when allowed

Same file, `_pullLatestMessagesFromAnchor`:

```dart
await model.loadChatRecord(
  count: 20,
  lastMsgID: anchorId,
  direction: LoadDirection.latest,
  getType: HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_NEWER_MSG,
);
if (beforeSignature != _visibleHistorySignature()) {
  return true;
}
if (allowCloudPull) {
  await model.loadChatRecord(
    count: 20,
    lastMsgID: anchorId,
    direction: LoadDirection.latest,
    getType: HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_NEWER_MSG,
  );
  // ...
}
```

Anchor is already the latest **visible** real msgID (`_resolveLatestPullAnchorId`)
— that is the correct “since last known message” for CLOUD_NEWER. No need to
invent a new time-based API for this plan; the bug is the **gate**, not the
anchor.

### Foreground recovery reasons (already defined)

```dart
static const Set<String> _foregroundRecoveryReasons = <String>{
  'app_resumed',
  'sync_server_finish',
  'connect_success',
  'im_reconnected',
  ConversationPreviewHistorySync.previewAheadOnOpenReason,
};
```

### Contract test already fails against current tree

`test/chat_foreground_resume_reconcile_contract_test.dart`:

```dart
test('foreground resume permits one cloud newer catch-up', () {
  final chatSource = File('lib/src/chat.dart').readAsStringSync();

  expect(chatSource.contains('shouldAllowCloudCatchUp'), isTrue);
  expect(chatSource.contains("source == 'app_resumed'"), isTrue);
  expect(
      chatSource.contains('allowCloudPull: shouldAllowCloudCatchUp'), isTrue);
});
```

Run once to confirm baseline red:

```bash
flutter test test/chat_foreground_resume_reconcile_contract_test.dart
```

Expected **before** this plan: the second test fails (no `shouldAllowCloudCatchUp`).

### Resume intensity vs catch-up (context only — do not change in 011)

`lib/src/services/resume_foreground_policy.dart` uses background duration only
for light/full side-effects (`shortBackgroundThreshold = 15s`). Chat refresh
still goes through `ImRecoveryService.afterOnline(reason: 'app_resumed')` even
on light intensity. Do **not** gate cloud catch-up on intensity in this plan.

## Desired end state

1. For warm-resume recovery sources that must not trust preview alone, compute:

   `shouldAllowCloudCatchUp = previewAhead || <resume catch-up reason>`

2. Pass `allowCloudPull: shouldAllowCloudCatchUp` into
   `_pullLatestMessagesFromAnchor` in the recovery path.

3. Resume catch-up reasons **must** include at least:
   - `app_resumed`
   - `im_reconnected`
   - `connect_success`

   Optional but recommended (same class of “SDK may have been offline”):
   - `sync_server_finish`

   Do **not** force cloud for `ConversationPreviewHistorySync.previewAheadOnOpenReason`
   beyond `previewAhead` itself (that reason already implies preview ahead).

4. Contract test above is green.

5. Log extras on `history_recovery_pull_done` include
   `allowCloudPull` / `shouldAllowCloudCatchUp` (bool) so field debugging can
   prove cloud was attempted.

## Out of scope

- Changing `_lastEnteredBackgroundAt` into a history `since` timestamp API
- Persisting lastMsgID to disk across process death (cold start already OK)
- Rewriting `ChatHistoryRecoveryCoordinator.shouldSkipForegroundRecovery`
  (that is plan **012**)
- Changing `isRecoveryAlreadySatisfied` (plan **012**)
- Changing `ResumeForegroundPolicy.conversationHoldDuration` or fixing the
  unrelated test that expects `1500ms` while source has `3s`
- Wallet / LiveKit / conversation-list layout / unread semantics
- Broad “always cloud pull on every recovery” for non-foreground reasons

## Implementation steps

### Step 1 — Drift check + baseline red

Compare excerpts above to live `lib/src/chat.dart` and the contract test.

```bash
rg -n "allowCloudPull:|shouldAllowCloudCatchUp|_pullLatestMessagesFromAnchor" lib/src/chat.dart
flutter test test/chat_foreground_resume_reconcile_contract_test.dart
```

Expected: recovery call still uses `allowCloudPull: previewAhead`; contract
test’s second case fails. If live code already has `shouldAllowCloudCatchUp`
and the contract is green, STOP and report — this plan may already be done;
move to plan 012.

### Step 2 — Add a pure helper (prefer small, testable)

Add a small pure function (recommended location:
`lib/src/utils/chat_warm_resume_catchup.dart` **or** next to
`chat_history_recovery_satisfaction.dart`):

```dart
/// Whether warm/foreground recovery may call V2TIM_GET_CLOUD_NEWER_MSG
/// even when conversation preview is not ahead of local history.
bool shouldAllowCloudCatchUp({
  required String? source,
  required bool previewAhead,
}) {
  if (previewAhead) return true;
  switch (source) {
    case 'app_resumed':
    case 'im_reconnected':
    case 'connect_success':
    case 'sync_server_finish':
      return true;
    default:
      return false;
  }
}
```

Match project style: top-level function in `lib/src/utils/`, no new dependency.

Add unit tests in `test/chat_warm_resume_catchup_test.dart` (new file):

| source | previewAhead | expected |
|--------|--------------|----------|
| `app_resumed` | false | true |
| `im_reconnected` | false | true |
| `connect_success` | false | true |
| `sync_server_finish` | false | true |
| `null` / `other` | false | false |
| any | true | true |
| `conversation_open_preview_ahead` (or whatever `previewAheadOnOpenReason` is) | false | false |

Look up the exact string of `ConversationPreviewHistorySync.previewAheadOnOpenReason`
before writing the last row.

```bash
flutter test test/chat_warm_resume_catchup_test.dart
```

Expected: all green.

### Step 3 — Wire into `lib/src/chat.dart` recovery path

Near the recovery pull (same block that currently passes `previewAhead`):

```dart
final shouldAllowCloudCatchUp = shouldAllowCloudCatchUp(
  source: source,
  previewAhead: previewAhead,
);
final changed = await _pullLatestMessagesFromAnchor(
  model: model,
  source: source,
  allowCloudPull: shouldAllowCloudCatchUp,
);
```

**Naming note**: if a local variable would shadow the imported function name,
rename the local to `allowCloudCatchUp` or import with a prefix. Prefer:

```dart
final allowCloudCatchUp = shouldAllowCloudCatchUp(
  source: source,
  previewAhead: previewAhead,
);
// ...
allowCloudPull: allowCloudCatchUp,
```

and keep the **string** `shouldAllowCloudCatchUp` present in the file (function
import + call) so the existing contract test still passes. The contract checks
`chatSource.contains('shouldAllowCloudCatchUp')` and
`allowCloudPull: shouldAllowCloudCatchUp` — if you use a local rename, update
the contract test to match the **actual** wired expression, e.g.
`allowCloudPull: allowCloudCatchUp` **and** still require the helper name
`shouldAllowCloudCatchUp` to appear. Prefer keeping
`allowCloudPull: shouldAllowCloudCatchUp(...)` inline if readable, or keep a
local named `shouldAllowCloudCatchUp` that is the bool result (Dart allows
shadowing; avoid it for clarity).

Recommended form that satisfies the existing contract literally:

```dart
final shouldAllowCloudCatchUp = /* call helper with a different import name */;
```

Simplest approach that keeps the contract test unchanged:

```dart
import 'package:tencent_cloud_chat_demo/src/utils/chat_warm_resume_catchup.dart'
    as warm_resume;

// ...
final shouldAllowCloudCatchUp = warm_resume.shouldAllowCloudCatchUp(
  source: source,
  previewAhead: previewAhead,
);
final changed = await _pullLatestMessagesFromAnchor(
  model: model,
  source: source,
  allowCloudPull: shouldAllowCloudCatchUp,
);
```

That keeps the substrings `shouldAllowCloudCatchUp` and
`allowCloudPull: shouldAllowCloudCatchUp` in source.

Also extend the existing `history_recovery_pull_done` extras map with:

```dart
'shouldAllowCloudCatchUp': shouldAllowCloudCatchUp,
```

Do **not** change non-recovery callers of `_pullLatestMessagesFromAnchor`
unless they already pass `allowCloudPull` explicitly.

### Step 4 — Verify contract + related suites

```bash
flutter test \
  test/chat_foreground_resume_reconcile_contract_test.dart \
  test/chat_warm_resume_catchup_test.dart \
  test/chat_history_recovery_satisfaction_test.dart \
  test/chat_history_recovery_coordinator_test.dart \
  test/resume_foreground_policy_test.dart
```

Expected:

- Contract test **both** cases green.
- New helper tests green.
- Coordinator / satisfaction / policy tests still green (011 must not change
  their APIs).

If `resume_foreground_policy_test` fails on `conversationHoldDuration`
(`1500ms` vs `3s`), that is **pre-existing drift** — do **not** “fix” policy
constants in this plan. Note it in the delivery summary as NOT IN SCOPE;
continue if only that assertion fails for unrelated reasons… Actually: if the
suite fails solely on that assertion, run the other files individually and
treat policy test as known broken baseline — do not change hold duration.

### Step 5 — Manual checklist (operator; mark NOT RUN in delivery if no device)

1. Open a busy C2C or group chat; confirm latest messages visible.
2. Background app **> 30s** (do not force-kill).
3. Have another account send 2–3 messages while backgrounded.
4. Foreground **without** splash; stay on or re-enter the same chat.
5. Expect new messages to appear after recovery (~1–3s), not only after kill+relaunch.

## Done criteria (machine-checkable)

- [ ] `rg -n "allowCloudPull: previewAhead" lib/src/chat.dart` — **no match**
      on the recovery call site (other files OK).
- [ ] `rg -n "shouldAllowCloudCatchUp" lib/src/chat.dart` matches ≥1.
- [ ] `flutter test test/chat_foreground_resume_reconcile_contract_test.dart`
      — PASS.
- [ ] `flutter test test/chat_warm_resume_catchup_test.dart` — PASS.
- [ ] No edits outside the in-scope file list below (except the new util/test).

## In-scope files

- `lib/src/utils/chat_warm_resume_catchup.dart` (**new**)
- `test/chat_warm_resume_catchup_test.dart` (**new**)
- `lib/src/chat.dart` (wire only: recovery `allowCloudPull` + log extras)
- `test/chat_foreground_resume_reconcile_contract_test.dart` (**only** if the
  chosen wiring requires adjusting the string assertions — prefer not)

## Explicitly out of scope files

- `lib/src/services/chat_history_recovery_coordinator.dart` → plan 012
- `lib/src/utils/chat_history_recovery_satisfaction.dart` → plan 012
- `lib/src/pages/app.dart` / `login_coordinator.dart` / cold-start paths
- `third_party/**` UIKit message list (unless a compile error forces a
  signature change — then STOP and report)
- Plans 001–010 code paths

## STOP conditions

- `_pullLatestMessagesFromAnchor` no longer exists or no longer takes
  `allowCloudPull` — STOP.
- Recovery path already always passes `allowCloudPull: true` — STOP; report
  and check whether bug is only plan 012 (false skip/satisfied).
- Tencent SDK docs / project comments forbid CLOUD_NEWER after LOCAL_NEWER
  for the same anchor without an extra precondition — STOP and report (do
  not invent a different getType).
- Fix seems to require rewriting conversation preview sync — STOP; that is
  a different finding.

## Test plan

1. New pure-function tests (Step 2 table).
2. Existing contract test (Step 4).
3. Manual device scenario (Step 5) — may be NOT RUN.

## Maintenance notes

- Any new foreground recovery `source` string that means “app may have missed
  live pushes” must be added to `shouldAllowCloudCatchUp` **and** to
  `_foregroundRecoveryReasons` consistently.
- Do not re-gate cloud solely on `previewAhead` without a product ADR; that
  recreates this bug.
- Plan **012** still needed: even with cloud allowed, false
  `isRecoveryAlreadySatisfied` / `skip_preview_merge_warm` /
  `shouldSkipForegroundRecovery` can mark success without applying results.

## Escape hatches

If cloud pulls spike resume jank: keep allow-list of reasons (do not flip
global default of `_pullLatestMessagesFromAnchor` to always cloud). Optionally
narrow to `app_resumed` + `im_reconnected` only — update helper tests and
contract accordingly, and document in README.
