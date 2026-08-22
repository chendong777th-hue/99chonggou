# Plan 004: Staticize ephemeral RegExp on msgID and markdown preprocess hot paths

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt below to the live files. If the inline
> `RegExp(...)` calls are already gone, mark this plan DONE and stop.

## Status

- **Priority**: P1
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none (can run parallel with `plans/003-attribute-main-thread-regexp.md`; 003 measures impact, this removes known waste)
- **Category**: perf
- **Planned at**: working tree 2026-08-20 (no git SHA available)
- **Execution**: DONE (2026-08-20) — static finals landed; tests green.

## Why this matters

`docs/pro.md` shows Main-thread Dart RegExp Interpret as the top leaf symbol.
Independent of full attribution, several **hot-path call sites construct a new
`RegExp` object on every invocation** instead of reusing `static final`
patterns already used elsewhere in the same file. That adds allocation +
compile work on every `dedupeMessages` / preference / wire-identity check and
on every markdown hyperlink preprocess.

This plan only converts those ephemeral constructors to `static final` (or
reuses existing statics). Match semantics must stay identical.

## Current state

### A — `_isLikelyTencentSdkMsgId` allocates twice per call

File:
`third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`

Existing statics nearby (~6451–6457):

```dart
static final RegExp _sdkMsgIdWirePattern = RegExp(r'^(\d{6,})-(\d+)-(\d+)$');
static final RegExp _sdkUserMsgIdWirePattern =
    RegExp(r'^([A-Za-z0-9_-]+)-(\d+)-(\d+)$');
static final RegExp _c2cArchiveMsgKeyWirePattern =
    RegExp(r'^(\d+)_(\d+)_(\d+)$');
```

But `_isLikelyTencentSdkMsgId` (~6438–6448) still does:

```dart
if (RegExp(r'^\d{6,}-').hasMatch(id)) {
  return true;
}
return RegExp(r'^[A-Za-z0-9_-]+-\d+-\d+$').hasMatch(id) &&
    !_c2cArchiveMsgKeyWirePattern.hasMatch(id);
```

Callers include preference / correlate / `_groupCrossSourceDedupKey` paths
used from `dedupeMessages` (~6998+), which chat open runs after
`CallBubbleDedupe.normalizeCallHistoryMessages` in `lib/src/chat.dart`.

### B — Duplicate community-token helpers recreate RegExp

Same file ~2165–2168 (and contrast with cached statics ~1988–1999):

```dart
if (!RegExp(r'^[A-Za-z0-9_]+$').hasMatch(token)) {
  return false;
}
return RegExp(r'[A-Z]').hasMatch(token);
```

while `_looksLikeCommunityShortToken` already uses
`_communityShortAlnumReg` / `_hasUpperCaseReg`.

### C — Digit-suffix check

Same file ~6274:

```dart
if (!RegExp(r'^\d+$').hasMatch(suffix)) {
```

### D — LinkPreviewEntry markdown preprocess

File:
`third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/link_preview_entry.dart`

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

Called when building markdown hyperlink text (cache miss path in
`MessageHyperlinkTextCache`).

### Conventions

- Prefer `static final RegExp _foo = RegExp(...);` next to sibling statics.
- Do not change pattern strings.
- Do not change public API.
- UIKit lives under `third_party/`; edits here are expected for this app
  (path dependency / vendored tree).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| MsgID / dedupe related | `flutter test test/call_bubble_dedupe_key_test.dart` | pass |
| Broader chat tests if present | `flutter test test/group_local_tips_dedupe_test.dart` | pass |
| Grep gate | see Done criteria | zero ephemeral hits at listed sites |

## Scope

**In scope**:

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/link_preview_entry.dart`
- Optional characterization test only if an existing msgID test file already
  covers `_isLikelyTencentSdkMsgId` / `parseC2cWireIdentityForTesting` —
  extend that file; do **not** create a large new suite

**Out of scope**:

- Changing `urlReg` / `chatIdMentionReg` / `groupAtMentionReg` pattern text
- Isolate offload, caching of match results beyond existing
  `MessageHyperlinkTextCache`
- `plans/003` probe hooks (leave them alone; if both land, probes still work)
- Conversation list / wallet / LiveKit

## Steps

### Step 1: Staticize `_isLikelyTencentSdkMsgId` patterns

Add near the other msgID statics:

```dart
static final RegExp _sdkMsgIdPrefixDigitDashReg = RegExp(r'^\d{6,}-');
static final RegExp _sdkUserMsgIdShapeReg =
    RegExp(r'^[A-Za-z0-9_-]+-\d+-\d+$');
```

Rewrite `_isLikelyTencentSdkMsgId` to use them (and keep
`_c2cArchiveMsgKeyWirePattern`).

Optional stronger reuse (only if behavior stays identical): if
`_sdkUserMsgIdWirePattern.hasMatch(id)` is exactly equivalent to the shape
regex **and** archive exclusion, you may use `_sdkUserMsgIdWirePattern`
instead of a new shape regex — but **STOP** if you are unsure about
capture-group differences affecting `hasMatch` (hasMatch should be fine;
prefer dedicated shape static if any doubt).

**Verify**: `flutter test test/call_bubble_dedupe_key_test.dart` → pass

### Step 2: Reuse community statics / digit suffix static

- Change the ~2165–2168 helper to call `_communityShortAlnumReg` /
  `_hasUpperCaseReg` (same as `_looksLikeCommunityShortToken`), or delete
  the duplicate helper if it is dead — only delete if `dart analyze` /
  references show zero callers.
- Add `static final RegExp _digitsOnlyReg = RegExp(r'^\d+$');` and use it at
  ~6274.

**Verify**: `flutter test test/call_bubble_dedupe_key_test.dart` → pass

### Step 3: Staticize LinkPreviewEntry preprocess regexes

In `link_preview_entry.dart`:

```dart
static final RegExp _htmlTagReg = RegExp(r'<\w+[^<>]*>');
static final RegExp _httpTokenReg = RegExp(r'http');
```

Use them in `addSpaceAfterLeftBracket` / `addSpaceBeforeHttp`.

**Verify**: If there is an existing link-preview test, run it; else rely on
analyze + call_bubble tests. `dart analyze` on the file → no issues.

### Step 4: Grep gate

Run from repo root:

```bash
rg -n "RegExp\(r'\^\\\\d\{6,\}-" third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart
rg -n "RegExp\(r'<\\\\w\+" third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/link_preview_entry.dart
rg -n "RegExp\(r'http'\)" third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/link_preview_entry.dart
```

Expected: **no matches** for ephemeral constructors at those call sites
(static field definitions may still contain the pattern strings).

**Verify**: grep exits 1 (no matches) for the three ephemeral call-site
patterns above.

## Test plan

- No behavior change expected; existing dedupe tests are the safety net.
- If `parseC2cWireIdentityForTesting` has tests elsewhere, run
  `flutter test` with a filter `c2c` / `wire` / `msgId` and ensure pass.

## Done criteria

- [ ] `_isLikelyTencentSdkMsgId` no longer constructs `RegExp(` inline
- [ ] Community-token duplicate uses shared statics
- [ ] Digit-suffix check uses `static final`
- [ ] `LinkPreviewEntry` preprocess uses `static final`
- [ ] Grep gate in Step 4 clean
- [ ] `flutter test test/call_bubble_dedupe_key_test.dart` exits 0
- [ ] `plans/README.md` row for 004 updated
- [ ] No files outside Scope modified

## STOP conditions

- Pattern string would need to change to reuse another static — stop; keep a
  dedicated static with the **exact** old pattern.
- Dedup tests fail after Step 1 — revert and report; do not weaken tests.
- You discover these methods are no longer on the chat-open path — still
  finish staticization (cheap, correct); note it in Maintenance.

## Maintenance notes

- Reviewer: confirm only `static final` moves, no logic edits.
- After `plans/003` dump, if `msgId.*` or `link.addSpace*` dominate, follow
  up with algorithmic plans (prefix scans, narrower patterns) — not in 004.
- Do not "optimize" `urlReg` in this plan; it is already a static field; its
  cost is match work, not construction.
