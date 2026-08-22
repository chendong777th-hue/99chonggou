# Plan 037: Lossless cut of `msgId.c2cWireIdentity` RegExp on chat open

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt below to the live file. If `_c2cWireIdentity`
> already skips RegExp when `timestamp`/`random` are both `> 0` **and** parses
> `msgID` without `_sdkMsgIdWirePattern` / `_sdkUserMsgIdWirePattern` /
> `_c2cArchiveMsgKeyWirePattern`, mark DONE and stop.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: LOW–MED (identity / dedupe correctness — tests must stay green)
- **Depends on**: none (033/036 DONE; evidence in `docs/pro-scenario.md`)
- **Category**: perf
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Status**: DONE (2026-08-22) — early-out when ts+random set; hand parsers
  replace wire RegExps; `message_ordering_test` + `regexp_probe_test` green.

## Why this matters

After the Frame stack-overflow fix, profile dump in `docs/pro-scenario.md`:

```text
[RegExpProbe] dump reason=list_to_chat_didGetHistoricalMessageList |
  msgId.c2cWireIdentity: calls=21596 us=18572 matches=0 |
  call_bubble.normalize: calls=29 us=1660 |
  msgId.isLikelySdk: calls=1709 us=89 |
  link.LinkText.scan: calls=21 us=61
```

~**18.5ms / 21k calls** on Main during list→chat history land. Link enrich is
already negligible. This plan removes that cost **without changing identity
semantics**.

Two stacked wastes in one function:

1. RegExp runs even when `message.timestamp` and `message.random` are already
   valid — the body only fills when `ts <= 0` / `random <= 0`, so RegExp is a
   pure no-op for the common case.
2. Remaining fills still use 2–3 `RegExp` matches per call.

## Current state

**File**:
`third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`

**Patterns + hot function** (live ~6692–6749):

```dart
static final RegExp _sdkMsgIdWirePattern = RegExp(r'^(\d{6,})-(\d+)-(\d+)$');
static final RegExp _sdkUserMsgIdWirePattern =
    RegExp(r'^([A-Za-z0-9_-]+)-(\d+)-(\d+)$');
static final RegExp _c2cArchiveMsgKeyWirePattern =
    RegExp(r'^(\d+)_(\d+)_(\d+)$');

static ({String sender, int timestampSec, int random})? _c2cWireIdentity(
  V2TimMessage message,
) {
  // ... sender from sender/userID; ts from timestamp; random from random ...
  final msgID = message.msgID?.trim() ?? '';
  if (msgID.isNotEmpty) {
    RegExpProbe.measure('msgId.c2cWireIdentity', () {
      final sdk = _sdkMsgIdWirePattern.firstMatch(msgID) ??
          _sdkUserMsgIdWirePattern.firstMatch(msgID);
      if (sdk != null && !_c2cArchiveMsgKeyWirePattern.hasMatch(msgID)) {
        // apply sdk group(2)=ts, group(3)=random only when <= 0
      } else {
        final archive = _c2cArchiveMsgKeyWirePattern.firstMatch(msgID);
        // apply group(2)=random, group(3)=ts only when <= 0
      }
    });
  }
  // return null if sender empty or ts/random <= 0
}
```

**Public test hooks** (do not rename):

- `parseC2cWireIdentityForTesting`
- `historyIdentitySignature` / `historyIdentitySignatureForTesting`

**Regression net** (must stay green):

- `test/message_ordering_test.dart` — archive↔SDK wire / dedupe (~920–960,
  `parseC2cWireIdentity` userId-ts-random ~1074+)

**Also uses `_c2cArchiveMsgKeyWirePattern`**: `_isLikelyTencentSdkMsgId`
(~6678, probe `msgId.isLikelySdk`). Do not delete that RegExp until both
call sites are migrated or share a non-RegExp helper.

**Conventions**: Match surrounding style in `tui_chat_global_model.dart`
(private `static` helpers, Chinese doc comments OK, `@visibleForTesting`
hooks). Prefer small helpers next to `_c2cWireIdentity`, not a new package.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Wire/dedupe tests | `flutter test test/message_ordering_test.dart` | All pass |
| Probe unit | `flutter test test/regexp_probe_test.dart` | All pass |
| Analyze model | `dart analyze third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart` | No new errors |

## Scope

**In scope**

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
- `test/message_ordering_test.dart` (add cases; do not delete existing)
- `plans/README.md` status row for 037

**Out of scope**

- `call_bubble.normalize` (plan 038)
- Link / DeferredHyperlinkText / Frame / RegExpProbe enable flags
- Changing how often `historyIdentitySignature` is called in
  `tui_chat_separate_view_model.dart`
- Dedupe winner policy / `messagesCorrelateForDedup` logic
- Rewriting `_isLikelyTencentSdkMsgId` beyond sharing a boolean
  “archive underscore id?” helper if needed

## Locked decisions (lossless)

| Decision | Value |
|----------|--------|
| Early-out | If `msgID.isEmpty` **or** (`ts > 0 && random > 0`), **do not** enter `RegExpProbe.measure` / parser for wire fill |
| Parser | Hand-rolled `indexOf` / `substring` / `int.tryParse` matching the three patterns **exactly**; try TIM digits6+ dash → userId dash → else archive underscore |
| Archive groups | `^(\d+)_(\d+)_(\d+)$` → group2=**random**, group3=**ts** (same as today) |
| Probe name | Keep `msgId.c2cWireIdentity`; wrap **only** the remaining parse path |
| Static RegExps | Remove from `_c2cWireIdentity` path; delete `static final` only when `rg` shows zero references left in this file |
| Optional cache | Only if still hot after early-out+parse: map **trimmed msgID → fill pair**, max ~512; never cache full wire by msgID alone |
| Public API | Do not rename test hooks or change record field names |

## Steps

### Step 1: Drift + baseline

Confirm live excerpts match. Run:

```bash
flutter test test/message_ordering_test.dart
```

**Verify**: all pass before any edit.

### Step 2: Early-out

After computing `ts`, `random`, `msgID` in `_c2cWireIdentity`, before measure:

```dart
if (msgID.isEmpty || (ts > 0 && random > 0)) {
  // skip wire fill
} else {
  RegExpProbe.measure('msgId.c2cWireIdentity', () { /* fill */ });
}
```

Do not change the final null-guard on `sender` / `ts` / `random`.

**Verify**: `flutter test test/message_ordering_test.dart` still passes.

### Step 3: Hand parsers replace RegExp fill

Add private helpers in the same file, for example:

- `_tryParseTimDigitDashWire(String msgID)` ↔ `^(\d{6,})-(\d+)-(\d+)$`
- `_tryParseUserIdDashWire(String msgID)` ↔ `^([A-Za-z0-9_-]+)-(\d+)-(\d+)$`
- `_isArchiveUnderscoreMsgId` / `_tryParseArchiveUnderscoreWire` ↔
  `^(\d+)_(\d+)_(\d+)$`

Control flow inside measure must stay:

1. TIM dash else user dash.
2. If dash hit **and** not archive-underscore shaped → fill ts/random when `<= 0`.
3. Else archive underscore → fill random/ts when `<= 0`.

Empty segments rejected; TIM first segment length ≥ 6 and all digits.

If `_isLikelyTencentSdkMsgId` still needs archive detection, share
`_isArchiveUnderscoreMsgId` (string check) instead of deleting the RegExp
while that site still uses it.

**Verify**:

```bash
flutter test test/message_ordering_test.dart
dart analyze third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart
```

### Step 4: Characterization tests

In `test/message_ordering_test.dart`, add/keep:

1. TIM / userId / archive msgID fill when fields missing (existing tests cover
   much of this — keep green).
2. Message with valid `timestamp`+`random` and any msgID → same wire as fields
   (early-out must not change result).
3. Malformed msgID does not invent wire when fields incomplete.

Reuse existing `_msg` / `_c2cTextMsg` factories in that file.

**Verify**: `flutter test test/message_ordering_test.dart` all pass.

### Step 5: Optional msgID fill cache

Only if a new Profile `[RegExpProbe]` dump still shows
`msgId.c2cWireIdentity` calls ≫ distinct msgIDs. Otherwise skip.

**Verify**: tests still pass.

### Step 6: Index

Set 037 to **DONE** in `plans/README.md`.

## Test plan

- Primary: `flutter test test/message_ordering_test.dart`
- Sanity: `flutter test test/regexp_probe_test.dart`
- Manual (operator): Profile → list scroll → open chat → filter
  `[RegExpProbe]`; expect `msgId.c2cWireIdentity` us/calls sharply below
  ~21596 / ~18572. Executor does not invent log lines.

## Done criteria

- [ ] Early-out: no wire parse/RegExp when `ts > 0 && random > 0`
- [ ] `_c2cWireIdentity` does not call `firstMatch`/`hasMatch` on the three
      wire RegExps
- [ ] `flutter test test/message_ordering_test.dart` exits 0
- [ ] `flutter test test/regexp_probe_test.dart` exits 0
- [ ] `dart analyze` on the model file: no new errors
- [ ] No files outside Scope modified
- [ ] `plans/README.md` row 037 = DONE

## STOP conditions

- Live symbol/probe name differs and equivalent cannot be found — STOP.
- Any existing `message_ordering_test` failure — STOP; do not weaken asserts.
- Fix seems to need dedupe-policy changes — STOP (out of scope).
- Uncertainty about archive group order — re-read live else-branch (group2=
  random, group3=ts); do not guess.

## Maintenance notes

- New msgID wire formats require parser + tests updates together.
- Reviewers: read `parseC2cWireIdentityForTesting` cases first; confirm
  early-out cannot skip fills when ts/random are 0.
- Follow-up: plan 038 (`call_bubble.normalize`); optional later reduction of
  repeated `historyIdentitySignature` in separate view model.
