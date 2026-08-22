# Plan 025: After search jump, release memory suppress and allow contiguous loadLatest

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
> If `.git` exists: `git rev-parse --short HEAD` and diff the in-scope paths
> against the planned-at note below.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED (history pagination + memory window; user-visible scroll)
- **Depends on**: none (builds on DONE 009/010 around-window contracts; do not
  re-open those plans)
- **Category**: bug
- **Planned at**: working tree 2026-08-22 (no git SHA — `NO_GIT` at plan time)
- **Execution**: DONE (2026-08-22) — `_onScrollToAnchor` releases suppress;
  UI/model latest gates share `SearchJumpLatestGate`; tests green.
- **Issue**: omit

## Why this matters

Chat history search / quote jump uses `loadListForSpecificMessage` to replace
the list with a mid-history around-window and
`HistoryMessagePosition.notShowLatest`. After the viewport centers on the
target, the user must be able to scroll **down** toward newer messages
(`LoadDirection.latest`) and eventually return to the live tip via the
existing bottom capsule.

Today that post-land contract is broken in three cooperating places:

1. **Anchor success path never releases memory-window suppress** — search
   jump via `MessageAnchor` calls `_onScrollToAnchor`, which on success sets
   `SearchJumpStatus.success` but does **not** call
   `_releaseSearchJumpMemoryWindowSuppress`. Compare `_onScrollToIndex`
   (message-based finding) and `_centerOnAtMeSeq` / first-unread, which do
   release. Suppress stays `true` after a successful search land.
2. **UI gate blocks latest while in `notShowLatest`** —
   `_shouldAttemptLatestHistoryLoad` returns `false` for
   `notShowLatest` unless `memoryWindowMissingNewer`, **before**
   `_allowsLatestHistoryPagination` (which already returns `true` in search
   jump mode). So the allow-list is dead code for the common search land.
3. **Model gate also skips latest while reading history** —
   `tui_chat_history_pagination_load.dart` early-returns on
   `LoadDirection.latest` when `isReadingHistory` (defined as
   `awayTwoScreen || notShowLatest`) and not `memoryWindowMissingNewer`.
   Even if the UI scheduled a load, the model no-ops it.

Net user effect: after jumping to an old hit, downward pagination stalls;
list feels “stuck” mid-history or only older pages work. Plan 026 separately
hardens **splice continuity** when latest batches do land; this plan only
makes contiguous latest **reachable** and cleans suppress/anchor state.

## Current state

### A. Search entry → around window (keep; do not redesign)

`third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart`
≈1856–1906:

```dart
if (isSearchJump && searchJumpAnchor != null) {
  globalModel.setSearchJumpStatus(..., SearchJumpStatus.loading, ...);
  globalModel.removeMessageList(conversationID);
  globalModel.setMessageListPosition(
    conversationID,
    HistoryMessagePosition.notShowLatest,
    notify: false,
  );
  final loaded = await model!.loadListForSpecificMessage(
    anchor: searchJumpAnchor,
    targetMessage: target,
  );
  // on success → SearchJumpStatus.success; on miss →
  // _fallbackToRecentHistory + failed toast
}
```

Around load itself (`tui_chat_separate_view_model.dart`
`loadListForSpecificMessage`) already sets `notShowLatest` and forces
`haveMoreLatestData = true` after a non-empty window (≈1156–1161). Keep that.

### B. Anchor scroll success — missing release (bug)

`tim_uikit_chat_history_message_list.dart` `_onScrollToAnchor` ≈9213–9231:

```dart
if (centered) {
  _findingRetryCount = 0;
  final matched = _messageForAnchor(targetAnchor);
  findingAnchor = null;
  findingMsg = null;
  // ... jumpMsgID ...
  loadingPlace = LoadingPlace.none;
  _chatGlobalModel?.setSearchJumpStatus(
    _conversationId(),
    SearchJumpStatus.success,
    notify: true,
  );
  if (mounted) setState(() {});
  return; // ← NO _releaseSearchJumpMemoryWindowSuppress
}
```

Contrast `_onScrollToIndex` ≈9283–9294 (same file):

```dart
if (centered) {
  // ...
  _releaseSearchJumpMemoryWindowSuppress(
    anchorMsgID: targetMsg.msgID,
    anchorSeq: targetMsg.seq,
  );
  // ...
  return;
}
```

And `_centerOnAtMeSeq` ≈9468–9472 **does** release. Helper already exists at
≈9146–9160:

```dart
void _releaseSearchJumpMemoryWindowSuppress({
  String? anchorMsgID,
  String? anchorSeq,
}) {
  final gm = _chatGlobalModel;
  final conv = _conversationId();
  if (gm == null) return;
  gm.setMemoryWindowSuppressed(conv, false);
  gm.applyMessageMemoryWindowNow(
    conv,
    memoryWindowAnchorMsgID: anchorMsgID,
    memoryWindowAnchorSeq: anchorSeq,
  );
}
```

`initFinding` / post-frame path uses `findingAnchor` → `_onScrollToAnchor`
(≈6413–6416). That is the **primary** search-jump scroll path.

### C. Conflicting latest gates (bug)

`_isSearchJumpHistoryMode` ≈5388–5393 — true when
`searchJumpAnchor` / `initFindingMsg` still on widget **or** position is
`notShowLatest`.

`_allowsLatestHistoryPagination` ≈5632–5639 — **allows** search-jump mode.

`_shouldAttemptLatestHistoryLoad` ≈5642–5674 — **blocks** first:

```dart
if ((listPosition == HistoryMessagePosition.notShowLatest ||
        listPosition == HistoryMessagePosition.awayTwoScreen) &&
    !globalModel.memoryWindowMissingNewer(_conversationId())) {
  return false;
}
// ... later:
if (!_allowsLatestHistoryPagination(globalModel)) {
  return false;
}
```

### D. Model skip while `isReadingHistory` (bug)

`tui_chat_global_model.dart` ≈1960–1963:

```dart
bool isReadingHistory(String conversationID) {
  final position = getMessageListPosition(conversationID);
  return position == HistoryMessagePosition.awayTwoScreen ||
      position == HistoryMessagePosition.notShowLatest;
}
```

`tui_chat_history_pagination_load.dart` ≈66–81:

```dart
if (direction == LoadDirection.latest &&
    !forceReloadNewest &&
    model.globalModel.isReadingHistory(model.conversationID) &&
    !model.globalModel.memoryWindowMissingNewer(model.conversationID)) {
  // logs load_chat_record_skip_latest_reading_history
  return pagination.haveMoreLatestData;
}
```

### E. Conventions / exemplars

- Match Plan 009/010: after around land, release suppress with **anchor**
  msgID/seq; keep return-to-bottom via `reloadNewestMessageWindow` (do not
  invent a new bottom path).
- Pure helpers + tests: follow
  `third_party/tencent_cloud_chat_uikit/test/at_me_jump_window_test.dart`
  and `test/unread_entry_jump_test.dart` (small pure contracts, no full SDK
  mock).
- Logging: use existing `ChatHistoryTrace.log` keys; add one new key only if
  needed for gate decisions (prefer reusing skip/allow logs).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| UIKit focused tests | `cd third_party/tencent_cloud_chat_uikit && flutter test test/at_me_jump_window_test.dart test/unread_entry_jump_test.dart test/search_jump_latest_gate_test.dart` | exit 0 |
| Analyze touched files | `cd third_party/tencent_cloud_chat_uikit && dart analyze lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart lib/business_logic/separate_models/tui_chat_history_pagination_load.dart` | no new errors |
| Grep release parity | `rg -n "_onScrollToAnchor|_releaseSearchJumpMemoryWindowSuppress" third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart` | success branch of `_onScrollToAnchor` calls release |
| Grep gate | `rg -n "notShowLatest|isReadingHistory|skip_latest_reading_history|_shouldAttemptLatestHistoryLoad|_allowsLatestHistoryPagination" third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_history_pagination_load.dart` | see Done criteria |

If `flutter test` fails on package config from UIKit folder, run from repo
root with the path package override already used by this app (same as Plan
009 notes). Do **not** `flutter pub get` that mutates lockfiles unless
tests cannot resolve packages — then STOP and report.

## Scope

**In scope** (only these may change):

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart`
  — `_onScrollToAnchor` success release; unify
  `_shouldAttemptLatestHistoryLoad` / related helpers so mid-history search
  land can schedule `loadLatest` when `haveMoreLatestData` (or equivalent
  search-jump mode) without requiring `memoryWindowMissingNewer`.
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_history_pagination_load.dart`
  — exception to `isReadingHistory` latest-skip when the conversation is in
  around-window / `notShowLatest` **with** `haveMoreLatestData` (user paging
  toward tip), **or** when a narrow documented flag says “allow latest while
  reading history for contiguous fill.” Prefer: skip only when
  `isReadingHistory && !haveMoreLatestData && !memoryWindowMissingNewer`
  is wrong — see Step 3 for the exact policy.
- `third_party/tencent_cloud_chat_uikit/test/search_jump_latest_gate_test.dart`
  (**create**) — pure gate policy tests.
- Optional tiny pure helper file under
  `third_party/tencent_cloud_chat_uikit/lib/ui/utils/` (e.g.
  `search_jump_latest_gate.dart`) **if** extracting the boolean keeps the
  list file smaller and tests pure — allowed; do not invent a second policy
  engine.

**Out of scope** (do NOT touch):

- `_combineMessageList` continuity / gap detection — that is **Plan 026**.
- `_fallbackToRecentHistory` miss hardening — Plan 026.
- Search UI, date picker, keyword search APIs, conversation list.
- Wallet, LiveKit, contacts, moments, archive HTTP.
- Changing `ChatMessageWindowPolicy` softMax/targetSize defaults.
- Rewriting `loadListForSpecificMessage` around-seq fetch strategy.
- App shell `lib/src/chat.dart` unless a one-line compile break — prefer STOP.
- Plan 009/010 @me / unread entry behavior beyond shared helpers you already
  call; do not regress their release-on-success paths.

## Git workflow

- No `.git` historically; if present, branch
  `advisor/025-search-jump-latest-after-land`, commits like
  `fix: allow loadLatest after search around-window land`.
- Do NOT push or open a PR unless the operator asks.

## Target behavior (acceptance narrative)

After a successful chat-history search jump to an old message:

1. Viewport centers on the hit; `SearchJumpStatus.success`.
2. Memory-window suppress is **false**; trim anchor is the hit’s msgID/seq
   (same as @me / message-finding paths).
3. Scrolling toward the newer edge schedules `LoadDirection.latest` while
   position remains `notShowLatest` and `haveMoreLatestData == true`.
4. Model layer does **not** no-op that request solely because
   `isReadingHistory` is true.
5. Ordinary “user is reading history and we must not auto-replace with tip”
   protection remains for cases where `haveMoreLatestData == false` and
   `memoryWindowMissingNewer == false` (no spurious tip replace).
6. Return-to-bottom capsule still uses existing
   `reloadNewestMessageWindow` (unchanged).

## Steps

### Step 1: Characterization tests for the gate policy (pure)

Create
`third_party/tencent_cloud_chat_uikit/test/search_jump_latest_gate_test.dart`.

Extract (or define first as a pure function the implementation will call) a
small policy, e.g. `SearchJumpLatestGate.shouldAllowLatestPagination` with
inputs:

| Input | Meaning |
|-------|---------|
| `position` | `HistoryMessagePosition` (or string enum mirror in pure file) |
| `haveMoreLatestData` | from separate view model |
| `memoryWindowMissingNewer` | from global model |
| `isSearchJumpMode` | widget still in jump **or** `notShowLatest` mid-window (same idea as `_isSearchJumpHistoryMode`) |
| `forceReloadNewest` | force path always allowed at model layer |

Assert at least:

1. `notShowLatest` + `haveMoreLatestData: true` + `memoryWindowMissingNewer: false`
   + search-jump mode → **allow** (this is the bug regression).
2. `notShowLatest` + `haveMoreLatestData: false` + `memoryWindowMissingNewer: false`
   → **deny** model auto-latest (keep tip-replace protection).
3. `notShowLatest` + `memoryWindowMissingNewer: true` → **allow**.
4. `bottom` + normal flags → **allow** (existing).
5. `awayTwoScreen` + no missing-newer + no more latest → **deny**.

Keep the pure API free of Flutter widgets / IM SDK types if possible (use
bools + a tiny enum duplicate or import the existing position enum if the
test package already depends on UIKit).

**Verify**:

```bash
cd third_party/tencent_cloud_chat_uikit && flutter test test/search_jump_latest_gate_test.dart
```

→ exit 0. If you only stub failing expectations, extract the helper in the
same step so the suite stays green.

### Step 2: Release suppress on `_onScrollToAnchor` success

In `tim_uikit_chat_history_message_list.dart`, inside `_onScrollToAnchor`
when `centered` is true (before `return`):

1. Resolve `matched = _messageForAnchor(targetAnchor)` (already there).
2. Call `_releaseSearchJumpMemoryWindowSuppress(`
   `anchorMsgID: matched?.msgID ?? targetAnchor.msgID,`
   `anchorSeq: matched?.seq ?? targetAnchor.seq,`
   `)`.
3. Keep `setSearchJumpStatus(...success...)`.
4. Do **not** release on the retry / `showCantFindMsg` paths beyond what
   `showCantFindMsg` already does.

**Verify**:

```bash
rg -n -A25 "_onScrollToAnchor\(MessageAnchor" \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart \
  | rg "_releaseSearchJumpMemoryWindowSuppress|setSearchJumpStatus"
```

→ both appear in the success branch. Also:

```bash
cd third_party/tencent_cloud_chat_uikit && dart analyze \
  lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart
```

→ no new errors.

### Step 3: Unify `_shouldAttemptLatestHistoryLoad` with the pure gate

Replace the hard `notShowLatest → false` early return with the Step 1 policy
so that:

- Mid-history search land (`notShowLatest` + `haveMoreLatestData`) can reach
  `_isNearLatestScrollEdge` / `fromItemBuilder` paths.
- Keep other guards: media-preview restore, loading flags,
  `ignoreScrollLoadPrevious` (existing missing-newer exception),
  `_allowsLatestHistoryPagination` (may simplify to “always use pure gate”
  — if you inline, delete dead contradiction comments).

Recommended shape:

```dart
bool _shouldAttemptLatestHistoryLoad({...}) {
  if (!_canProbeLatestHistory(globalModel) || /* existing busy/restore guards */) {
    return false;
  }
  final listPosition = globalModel.getMessageListPosition(_conversationId());
  final allowed = SearchJumpLatestGate.shouldAllowLatestPagination(
    position: listPosition,
    haveMoreLatestData: widget.model.haveMoreLatestData,
    memoryWindowMissingNewer:
        globalModel.memoryWindowMissingNewer(_conversationId()),
    isSearchJumpMode: _isSearchJumpHistoryMode(globalModel),
  );
  if (!allowed) return false;
  // keep ignoreScrollLoadPrevious exception as today
  // then fromItemBuilder / near-edge checks unchanged
}
```

Do **not** remove near-edge / debounce behavior — only the position block.

**Verify**:

```bash
cd third_party/tencent_cloud_chat_uikit && flutter test test/search_jump_latest_gate_test.dart
cd third_party/tencent_cloud_chat_uikit && dart analyze \
  lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart
```

### Step 4: Align model `load_chat_record` latest skip

In `tui_chat_history_pagination_load.dart`, change the early skip so it uses
the **same** policy (import the pure helper). Concrete rule for this step:

- Keep skipping tip-chasing replaces while reading history when there is
  **no** newer page to fill (`!haveMoreLatestData && !memoryWindowMissingNewer`).
- **Do not** skip when `haveMoreLatestData == true` (around-window expects
  downward pages) or `memoryWindowMissingNewer == true` or
  `forceReloadNewest`.

After change, a search land with `haveMoreLatestData: true` must reach the
SDK fetch path (not return at the skip log).

Optionally rename the log event to
`load_chat_record_skip_latest_reading_history` only when still skipping;
when allowing, no new noisy log required.

**Verify**:

```bash
rg -n "skip_latest_reading_history|isReadingHistory" \
  third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_history_pagination_load.dart
```

→ skip condition references `haveMoreLatestData` and/or the shared gate.
Then:

```bash
cd third_party/tencent_cloud_chat_uikit && dart analyze \
  lib/business_logic/separate_models/tui_chat_history_pagination_load.dart
```

### Step 5: Regression suite + manual checklist note

Run:

```bash
cd third_party/tencent_cloud_chat_uikit && flutter test \
  test/search_jump_latest_gate_test.dart \
  test/at_me_jump_window_test.dart \
  test/unread_entry_jump_test.dart \
  test/chat_message_window_test.dart
```

→ exit 0.

Update this plan’s status in `plans/README.md` to DONE (or leave TODO if a
reviewer owns the index).

**Manual (operator, NOT RUN in CI)** — document in the PR/delivery note only:

1. Open a long group chat → search an old keyword/date hit → jump.
2. Confirm hit centered; scroll **down** loads newer pages (network/logs show
   `LoadDirection.latest`, not only previous).
3. Tongue/bottom capsule still returns to live tip smoothly.
4. @me jump and entry unread jump still center and page (smoke).

## Test plan

- **New**: `search_jump_latest_gate_test.dart` — cases in Step 1.
- **Keep green**: `at_me_jump_window_test.dart`, `unread_entry_jump_test.dart`,
  `chat_message_window_test.dart`.
- Do **not** require full-widget Flutter scroll tests for this plan.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `_onScrollToAnchor` success path calls
      `_releaseSearchJumpMemoryWindowSuppress` with msgID/seq.
- [ ] `_shouldAttemptLatestHistoryLoad` no longer unconditionally returns
      false solely for `notShowLatest` when `haveMoreLatestData` is true.
- [ ] Pagination load latest-skip no longer treats all `isReadingHistory` as
      skip when `haveMoreLatestData` is true.
- [ ] `flutter test test/search_jump_latest_gate_test.dart` (+ listed
      regressions) exit 0.
- [ ] `dart analyze` on touched Dart files: no new errors.
- [ ] No files outside Scope modified.
- [ ] `plans/README.md` row for 025 updated.

## STOP conditions

Stop and report (do not improvise) if:

- Live excerpts no longer match “Current state” (symbols renamed / gates
  already unified differently).
- Fix seems to require changing `_combineMessageList` to “make scroll work”
  — that belongs in Plan 026; do not merge plans.
- Making latest allowed causes tip **replace** (list jumps to newest without
  user tapping return-to-bottom) in manual smoke — revert gate; report with
  logs (`forceReloadNewest` vs paginated latest confusion).
- `haveMoreLatestData` is false immediately after successful around load in
  live code (contradicts `loadListForSpecificMessage` ≈1156–1157) — STOP;
  fix around-load flags first, do not paper over with `memoryWindowMissingNewer`
  hacks.
- A step’s verification fails twice after a reasonable fix attempt.

## Maintenance notes

- Any new mid-history jump path (`loadListForSpecificMessage` +
  `notShowLatest`) must release suppress on **scroll success**, not only on
  load success — load success alone leaves suppress true until center.
- Reviewers: watch that `awayTwoScreen` browsing still does **not** auto
  loadLatest without missing-newer / haveMoreLatest.
- Deferred to Plan 026: contiguous merge when latest batch does not abut the
  around window; miss → recent fallback UX.
- Interaction: Plan 011/012 warm-resume cloud catch-up must remain gated;
  this plan only opens **paginated** latest while `haveMoreLatestData`.
