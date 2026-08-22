# Plan 006: Cut link/mention RegExp invocations on chat text hot path

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm expected results before moving on. If any
> STOP condition is hit, stop and report — do not improvise.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> all "Current state" excerpts against live files. If symbols or call paths
> changed materially, report drift first.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MEDIUM (text parsing behavior surface)
- **Depends on**: 003 (attribution baseline), 004 (ephemeral constructor waste already removed)
- **Category**: perf
- **Planned at**: working tree 2026-08-20 (no git SHA available)
- **Execution**: DONE (2026-08-20) — candidate gates landed; characterization +
  regression tests green. Probe wrappers from 003 kept.

## Why this matters

`docs/pro.md` shows Main-thread `dart::BytecodeRegExpMacroAssembler::Interpret`
as the dominant named leaf. Plans 003/004 solved attribution + constructor
waste, but match-time cost can still be high when `allMatches` runs for every
visible text bubble.

The next cut should **reduce how often heavy regex runs at all**, not change
regex syntax blindly. For link/mention text, many messages are obviously
non-candidates (no `http`, no `@`, no `.` / no URL-like separators). Those
should return early via cheap string scans.

## Current state

Primary files:

- `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/common/utils.dart`
  - `wrapChatIdMentionsForExtendedText`
  - `getURLMatches`
- `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/widgets/link_text.dart`
  - text parse path calling `urlReg.allMatches` / mention scans

Known patterns:

- `urlReg`, `chatIdMentionReg`, `groupAtMentionReg` are already static fields.
- Hot cost is **match execution volume** (`allMatches`/`firstMatch` on many
  non-candidate strings), not pattern construction.

## Product boundary

Do **not** change:

- final rendered text semantics,
- mention highlight semantics,
- URL detection acceptance rules,
- wallet / LiveKit / conversation list behavior.

This plan is a performance refactor with behavior-preserving fast paths.

## Commands you will need

Run from repo root unless noted.

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Mention regex behavior | `flutter test test/chat_id_mention_full_group_id_test.dart` | pass |
| Group mention behavior | `flutter test test/group_at_mention_test.dart` | pass |
| Hyperlink cache path | `flutter test third_party/tencent_cloud_chat_uikit/test/message_hyperlink_text_cache_test.dart` | pass |
| Chat dedupe regression | `flutter test test/call_bubble_dedupe_key_test.dart` | pass |
| UIKit analyze | `dart analyze third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/common/utils.dart third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/widgets/link_text.dart` | no new errors |

Fallback when the third-party test path fails from root (package resolution):

1. `cd third_party/tencent_cloud_chat_uikit`
2. `flutter test test/message_hyperlink_text_cache_test.dart`
3. return to repo root and continue.

## Scope

**In scope**:

- `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/common/utils.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/widgets/link_text.dart`
- Optional: small helper colocated in same directory for shared candidate checks
- Optional: one focused characterization test file for URL/mention edge cases

**Out of scope**:

- Editing regex pattern strings themselves (unless explicitly required to keep behavior identical)
- Isolate/off-main-thread rewrite
- Any files for plans 001/002/005
- `docs/pro.md` or instrumentation log documents

## Steps

### Step 1: Add zero-allocation candidate gates before regex

In the link/mention parse entry points, add cheap guards using `String` checks:

- For URL scan path:
  - if text length below minimal URL threshold, return quickly
  - if `text.contains('http') == false` and no `www.`-like marker, skip regex
- For mention path:
  - if no `'@'` in text, skip mention regex entirely

Implementation constraint for this step (must follow):

- Add private helpers with explicit names so reviewers can audit quickly:
  - `_mayContainUrlCandidate(String text)`
  - `_mayContainMentionCandidate(String text)`
- Keep them in the same file as the call site first; do not introduce shared
  utils unless duplication is proven.

Rules:

- Keep guard logic deterministic and side-effect free.
- Avoid new allocations in hot path (`split`, `toLowerCase`, `replaceAll`
  should be avoided in the early gate).

**Verify**:

- `dart analyze` on touched files is clean.
- `flutter test test/chat_id_mention_full_group_id_test.dart` passes.

### Step 2: Convert all-matches usage to conditional execution

Where `urlReg.allMatches(...)` and mention `allMatches(...)` are called
unconditionally, wrap them behind the Step-1 candidate gates.

If both URL and mention are needed in the same method:

- evaluate cheap URL gate and mention gate first,
- execute only the needed regex path,
- preserve original ordering of produced spans/entities.

**Verify**:

- `flutter test test/chat_id_mention_full_group_id_test.dart`
- `flutter test test/group_at_mention_test.dart`

Both pass with no assertion changes.

### Step 3: Add characterization tests for high-risk text shapes

Create or extend one small test file that locks behavior for:

1. Plain Chinese/English text with no URL/mention (should remain unchanged).
2. `@name` mention text (mention still detected).
3. URL text (`http://...`, `https://...`, mixed-case schema variants currently accepted).
4. Mixed text with both URL and mention.
5. Edge case: lone `@` or malformed URL should match exactly as before.

Use existing test style in repo; do not add broad golden suites.

Preferred location:

- extend `test/chat_id_mention_full_group_id_test.dart` first,
- add a new file only if extension becomes unclear.

**Verify**: new + existing tests pass.

### Step 4: Keep profile observability

If Plan 003 probe wrappers are present in current tree:

- keep wrapper sites intact while adding gates,
- ensure counters still report reduced invocation/cost for link sites.

If probe code is absent (already cleaned), skip this step and mark `NOT RUN`.

**Verify**: record whether probe path was available.

### Step 5: Regression + static checks

Run:

1. target link/mention tests,
2. `test/call_bubble_dedupe_key_test.dart`,
3. `dart analyze` for touched files.

Record exact command lines and pass/fail summary.

Add grep gates (must capture output in delivery note):

```bash
rg -n "urlReg\\.allMatches\\(|chatIdMentionReg\\.allMatches\\(" \
  third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/common/utils.dart \
  third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/widgets/link_text.dart
rg -n "_mayContainUrlCandidate\\(|_mayContainMentionCandidate\\(" \
  third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/common/utils.dart \
  third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/widgets/link_text.dart
```

Expected:

- first command may still match, but matches must appear only in branches gated
  by `_mayContain*Candidate` checks;
- second command must match at least one location for each gate helper used.

## Test plan

- Behavior tests for URL/mention detection before and after fast-path gates.
- Existing chat regression tests to catch unintended parser side effects.
- Optional profile-mode manual smoke: open busy C2C chat and verify no missing
  link/mention rendering.

## Done criteria

- [x] URL and mention paths have cheap candidate gates before regex
- [x] No unconditional `allMatches` remains on clearly non-candidate text path
- [x] `flutter test test/chat_id_mention_full_group_id_test.dart` passes
- [x] `flutter test test/group_at_mention_test.dart` passes
- [x] Hyperlink cache test passes (root or fallback subdir command recorded)
- [x] URL/mention behavior tests pass (existing + any added characterization)
- [x] `test/call_bubble_dedupe_key_test.dart` passes
- [x] `dart analyze` on touched files passes
- [x] grep gate output is attached in delivery note
- [x] No files outside Scope modified
- [x] `plans/README.md` updated to reflect execution result

## Delivery note (executor)

### Commands run

```bash
flutter test test/chat_id_mention_full_group_id_test.dart   # 11 pass
flutter test test/group_at_mention_test.dart                # pass (earlier batch)
flutter test test/call_bubble_dedupe_key_test.dart          # pass (earlier batch)
flutter test third_party/tencent_cloud_chat_uikit/test/message_hyperlink_text_cache_test.dart  # 2 pass
dart analyze .../utils.dart .../link_text.dart              # 1 pre-existing unused_import warning in link_text.dart (gestures.dart); no new errors
```

### Grep gate

`allMatches` only after `_mayContain*Candidate` checks in:
- `utils.dart` wrapMentions / getURLMatches
- `link_text.dart` `_collectSegments`

Helpers present in both files.

### Step 4 observability

Plan 003 `RegExpProbe` wrappers retained around wrap / getURLMatches / LinkText.scan.

## STOP conditions

- Any behavior drift in mention/URL rendering that cannot be fixed without
  changing product semantics.
- Candidate gate would require locale-dependent normalization or expensive
  transformations in hot path.
- Existing parser contracts are unclear and no tests cover them — in that case
  add characterization tests first, then continue.
- `third_party/tencent_cloud_chat_uikit/test/message_hyperlink_text_cache_test.dart`
  cannot run from root or package dir due environment issues — stop and report
  exact error; do not silently skip.

## Maintenance notes

- If this plan lands and Main-thread RegExp remains dominant, the follow-up
  should target **algorithmic URL extraction** (single-pass scanner) behind
  strict behavior lock tests.
- Keep fast-path predicates simple; complex heuristics can become slower than
  the regex they replace.
