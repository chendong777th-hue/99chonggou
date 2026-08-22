# Plan 003: Attribute Main-thread RegExp to concrete Dart call sites

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt below to the live files. If symbols moved or
> behavior changed, STOP and report.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: LOW
- **Depends on**: none
- **Category**: perf
- **Planned at**: working tree 2026-08-20 (no git SHA available)
- **Execution**: DONE (2026-08-20) — implemented in working tree (no git worktree;
  workspace has no `.git`). Device attribution dump left as NOT RUN.

## Why this matters

Instruments export `docs/pro.md` (~49s Time Profiler) shows Main Thread ~44.5%
of samples, with leaf
`dart::BytecodeRegExpMacroAssembler::Interpret` alone ~5398 samples (~16% of
Main samples have RegExp in the stack). Parent frames are fully collapsed to
`(N other frames)`, so the profile **cannot** name Dart functions.

Without attribution, any "optimize RegExp" change is guesswork. This plan adds
a **Profile-gated counter + Timeline** probe on the highest-suspicion call
sites so a single chat-open / history-load / call-bubble session produces a
ranked list of which wrappers spent how much wall time and how many matches.
A later plan can then fix the winner(s) only.

## Current state

### Evidence from profile (do not re-parse unless verifying)

- File: `docs/pro.md` — Instruments sample TSV:
  `time | CPU | Runner | thread | Running | leaf ← (N other frames)`
- Main RegExp-dense seconds historically clustered around 3s, 5–8s, 23–25s,
  31–32s, 41s, 44s (episodic, not flat).
- Console correlation (same product moment, not symbol proof):
  `docs/控制台输出.md` lines with
  `[CHAT_JITTER] event=call_bubble_normalize`.

### Suspect sites (instrument these first)

1. **Link / mention scanning on text bubbles** (heavy patterns, per visible text):

```37:58:third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/common/utils.dart
  static RegExp urlReg = RegExp(
      r"([hH][tT]{2}[pP]:\/\/|...)");
  static final RegExp chatIdMentionReg = RegExp(
    r'(?<![A-Za-z0-9.])@(?:'
    ...
  );
  static final RegExp groupAtMentionReg = RegExp(
    r'(?<![A-Za-z0-9.])@([^\s@]+)'
    ...
  );
```

Callers: `wrapChatIdMentionsForExtendedText`, `getURLMatches`, and
`link_text.dart` `urlReg.allMatches` / `chatIdMentionReg.allMatches`.

2. **Markdown preprocess creating ephemeral RegExp every call**:

```45:66:third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/link_preview_entry.dart
  static String addSpaceAfterLeftBracket(String inputText) {
    return inputText.splitMapJoin(
      RegExp(r'<\w+[^<>]*>'),
      ...
    );
  }
  static String addSpaceBeforeHttp(String inputText) {
    return inputText.splitMapJoin(
      RegExp(r'http'),
      ...
    );
  }
```

3. **msgID classification during dedupe / cross-source keys** (runs over whole
   history lists; also allocates **new** `RegExp` objects inline):

```6438:6480:third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart
  static bool _isLikelyTencentSdkMsgId(String? msgID) {
    ...
    if (RegExp(r'^\d{6,}-').hasMatch(id)) {
      return true;
    }
    return RegExp(r'^[A-Za-z0-9_-]+-\d+-\d+$').hasMatch(id) &&
        !_c2cArchiveMsgKeyWirePattern.hasMatch(id);
  }
  ...
  static ({String sender, int timestampSec, int random})? _c2cWireIdentity(...) {
    ...
      final sdk = _sdkMsgIdWirePattern.firstMatch(msgID) ??
          _sdkUserMsgIdWirePattern.firstMatch(msgID);
```

`dedupeMessages` (~6998+) calls cross-source helpers that use the above per
message; chat open path also calls
`CallBubbleDedupe.normalizeCallHistoryMessages` then `dedupeMessages` from
`lib/src/chat.dart` `didGetHistoricalMessageList` (~7966–7970).

4. **Call-bubble normalize** — mostly `jsonDecode`, not RegExp. Still add one
   outer timer around `normalizeCallHistoryMessages` so the dump can show
   "normalize ms vs regexp probe ms" and avoid false blame.

### Existing logging convention to match

```1:18:lib/src/services/chat_open_perf_log.dart
/// 发布版可见：进入聊天页耗时追踪。过滤关键字：`[ChatOpenPerf]`
class ChatOpenPerfLog {
  static const bool enabled = false;
  static const bool enabledInProfile = true;
  static bool get isEnabled =>
      enabled || (kProfileMode && enabledInProfile);
```

New probe must follow the same gate style: default off in release unless
`kProfileMode`, filter keyword distinct (`[RegExpProbe]`), no secrets in logs.

### Product boundary

Do **not** change: wallet, LiveKit/CallKit audio semantics, unread counts,
conversation SDK-primary flag, message display semantics, dedupe preference
rules, or link/mention match results. This plan is **observe-only** plus a
tiny shared probe helper.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Unit tests (probe helper) | `flutter test test/regexp_probe_test.dart` | all pass |
| Existing link/dedupe smoke | `flutter test test/call_bubble_dedupe_key_test.dart` | all pass |
| Analyze touched pkgs (optional) | `dart analyze lib/src/services/regexp_probe.dart third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/common/utils.dart` | no new errors |

There is no `.git` in this workspace — do not `git init`.

## Scope

**In scope** (only these):

- `lib/src/services/regexp_probe.dart` (create)
- `test/regexp_probe_test.dart` (create)
- `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/common/utils.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/link_preview_entry.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/widgets/link_text.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
  — only wrap `_isLikelyTencentSdkMsgId` and `_c2cWireIdentity` (or the
  regex calls inside them) with probe counters; do **not** refactor dedupe
  logic
- `lib/src/utils/call_bubble_dedupe.dart` — only wrap
  `normalizeCallHistoryMessages` entry/exit with probe site `call_bubble_normalize`
- Optionally call `RegExpProbe.dumpIfNeeded()` from one existing chat-open
  milestone in `lib/src/services/chat_open_perf_log.dart` **or**
  `lib/src/chat.dart` after history normalize — one place only

**Out of scope**:

- Plan 004 ephemeral-RegExp staticization (separate plan) — do not combine
- Rewriting URL/mention regexes, changing match behavior
- Moving work to isolates
- Editing `docs/pro.md` / deleting Instruments data
- Conversation list Feed changes (plans 001/002 already DONE)

## Git workflow

No git remote/worktree assumed. Do not commit unless the operator asks.

## Steps

### Step 1: Add `RegExpProbe` helper

Create `lib/src/services/regexp_probe.dart` with:

- `static const bool enabled = false;`
- `static const bool enabledInProfile = true;`
- `static bool get isEnabled` mirroring `ChatOpenPerfLog`
- Per-site counters: `calls`, `matchInvocations` (or `us` via
  `Stopwatch` when `isEnabled`)
- API:
  - `static T measure<T>(String site, T Function() body)`
  - `static void recordMatch(String site, {int count = 1})` (optional)
  - `static void reset()`
  - `static void dump({String reason = ''})` → single `print` line or few
    lines starting with `[RegExpProbe]` listing sites sorted by
    `elapsedUs` descending
- When `!isEnabled`, `measure` must call `body()` with **zero** allocation
  beyond the closure itself (no Stopwatch).

**Verify**: `dart analyze lib/src/services/regexp_probe.dart` → no issues

### Step 2: Unit-test the probe

Create `test/regexp_probe_test.dart`:

1. With probe forced on (use a `@visibleForTesting` override or test-only
   setter `RegExpProbe.debugForceEnabled = true`), `measure` increments
   calls and elapsed for a site.
2. With force off, calling `measure` still returns the body result and
   dump prints nothing / counters stay 0.
3. `dump` output contains the site name and is sorted by elapsed.

**Verify**: `flutter test test/regexp_probe_test.dart` → all pass

### Step 3: Instrument link / mention paths

In `utils.dart`:

- Wrap bodies of `wrapChatIdMentionsForExtendedText` and `getURLMatches`
  with `RegExpProbe.measure('link.wrapMentions', ...)` /
  `RegExpProbe.measure('link.getURLMatches', ...)`.

In `link_text.dart` wherever `urlReg.allMatches` / `chatIdMentionReg.allMatches`
run in the build/parse path, wrap that function/method with
`RegExpProbe.measure('link.LinkText.scan', ...)`.

In `link_preview_entry.dart`, wrap `addSpaceAfterLeftBracket` and
`addSpaceBeforeHttp` with sites `link.addSpaceBracket` /
`link.addSpaceHttp`.

UIKit files importing app `lib/` can be awkward. Prefer **one of**:

- **A (preferred)**: put `RegExpProbe` under
  `third_party/tencent_cloud_chat_uikit/lib/ui/utils/regexp_probe.dart`
  (duplicate the tiny helper next to `chat_jitter_diag.dart`) so UIKit does
  not import the app package; **and** keep a thin re-export or identical
  API in `lib/src/services/regexp_probe.dart` for app-side
  `call_bubble_dedupe` — OR only place the helper in UIKit and have
  `call_bubble_dedupe` import that UIKit util (it already imports UIKit).

Choose **single implementation** in UIKit
`third_party/.../ui/utils/regexp_probe.dart` and import it from both UIKit
and `call_bubble_dedupe.dart` (already depends on UIKit). Then Step 1's
path becomes the UIKit util; app `lib/src/services/regexp_probe.dart` is
**not** required. Update Scope accordingly when implementing: only one
helper file.

**Verify**: `flutter test test/regexp_probe_test.dart` still pass (move test
import to the chosen path)

### Step 4: Instrument msgID / wire identity

In `tui_chat_global_model.dart`:

- Wrap `_isLikelyTencentSdkMsgId` body with
  `RegExpProbe.measure('msgId.isLikelySdk', () { ... original ... })`
- Wrap the msgID regex block inside `_c2cWireIdentity` with
  `RegExpProbe.measure('msgId.c2cWireIdentity', ...)`

Do not change return values.

**Verify**: Prefer an existing test that imports
`TUIChatGlobalModel` msgID helpers if present; otherwise:

`flutter test test/call_bubble_dedupe_key_test.dart` → pass

If you find `parseC2cWireIdentityForTesting` tests, run those too.

### Step 5: Instrument call-bubble normalize outer timer

In `call_bubble_dedupe.dart` `normalizeCallHistoryMessages`, wrap the whole
method body with `RegExpProbe.measure('call_bubble.normalize', ...)`.

**Verify**: `flutter test test/call_bubble_dedupe_key_test.dart` → pass

### Step 6: Dump once per chat-open session

Hook dump after history path settles — recommended:

In `lib/src/chat.dart` inside `didGetHistoricalMessageList`, after
normalize + dedupe (near existing `[CHAT_JITTER] event=call_bubble_normalize`
print), call:

```dart
RegExpProbe.dump(reason: 'didGetHistoricalMessageList');
RegExpProbe.reset();
```

Only when probe enabled. Do not dump every inbound message.

**Verify**: code compiles; `flutter test test/regexp_probe_test.dart` pass

### Step 7: Manual attribution procedure (document in plan status notes)

Executor writes a short note at the bottom of this file under
`## Attribution runbook (executor filled)`:

1. Build profile: `flutter run --profile` (iOS device preferred).
2. Enable probe (`enabledInProfile` already true when `kProfileMode`).
3. Open a busy C2C chat with many text messages; trigger one history load
   (and optionally one call so `call_bubble_normalize` fires).
4. Capture log lines `[RegExpProbe]`.
5. Paste top 5 sites by `elapsedUs` into the runbook section.

**Verify**: runbook section exists with either real numbers **or**
`NOT RUN — no device` plus the exact commands the human must run.

## Test plan

- New: `test/regexp_probe_test.dart` (force on/off, dump ordering).
- Regression: `test/call_bubble_dedupe_key_test.dart`.
- Do **not** add golden tests for mention/URL matching in this plan.

## Done criteria

- [ ] Single `RegExpProbe` helper exists, gated like `ChatOpenPerfLog`
- [ ] Sites listed in Steps 3–5 are wrapped; match behavior unchanged
- [ ] `flutter test test/regexp_probe_test.dart` exits 0
- [ ] `flutter test test/call_bubble_dedupe_key_test.dart` exits 0
- [ ] No files outside Scope modified
- [ ] `plans/README.md` status row for 003 updated
- [ ] Attribution runbook section filled (`NOT RUN` allowed)

## STOP conditions

- UIKit cannot import the chosen probe path without creating a circular
  dependency — stop and report; do not invent a code-gen bridge.
- Any test shows mention/URL/dedupe behavioral drift — revert the wrap that
  caused it (wrapping must be transparent).
- Operator asks to "just delete RegExp" without dump data — that belongs to
  a follow-up plan after attribution, not this file.

## Maintenance notes

- After attribution, write a **new** plan (005+) that only optimizes the top
  site(s). Do not expand this plan into rewrites.
- Turn `enabledInProfile` false or delete dump hook once the follow-up fix
  lands, to avoid log noise.
- Reviewer: confirm wrappers do not allocate when disabled.

## Attribution runbook (executor filled)

**NOT RUN — no device** in this execution session.

Commands for a human on device:

1. `flutter run --profile` (prefer physical iOS).
2. Probe is on when `kProfileMode && RegExpProbe.enabledInProfile` (default true).
3. Open a busy C2C chat (many text messages); optionally place a call so
   `call_bubble.normalize` fires.
4. Filter logs for `[RegExpProbe]`.
5. Paste top sites by `us=` here after capture.

Verification already run in-tree:

- `flutter test test/regexp_probe_test.dart` → pass (3)
- `flutter test test/call_bubble_dedupe_key_test.dart` → pass
