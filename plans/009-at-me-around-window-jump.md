# Plan 009: Jump @me via around-seq window with contiguous scroll and smooth return-to-bottom

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

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (chat history window + scroll; high user visibility)
- **Depends on**: none (independent of 001–008)
- **Category**: bug
- **Planned at**: working tree 2026-08-20 (no git SHA available)
- **Execution**: DONE (2026-08-20) — `_onScrollToIndexBySeq` uses
  `loadListForSpecificMessage`; tongue clears tip only on success;
  `findingSeq` rebuild chase removed; tests green.

## Why this matters

In group chats, the “有人@我” tongue uses `groupAtInfoList[].seq` and
`_onScrollToIndexBySeq`. That path **chases history upward** from the current
window’s oldest seq with
`requestCount = lastSeqInt - targetSeqInt` (unbounded). For an @ from long
ago this is slow, races with cold-open hydrate, fights the memory window, and
often ends in `showCantFindMsg()` — “sometimes can’t jump.”

Search jump already uses the correct product pattern:
`loadListForSpecificMessage` → OLDER + NEWER around the target →
`HistoryMessagePosition.notShowLatest`. Tencent Cloud IM docs prescribe the
same for @ jump (`lastMsgSeq = atSequence`, ~20 older + ~20 newer).

After a successful @ jump the user must also get:

1. **Contiguous** messages when scrolling **up** (older) and **down** (newer)
   from the @ anchor — no silent holes, no “jump then stuck with a dead edge.”
2. **Smooth return to bottom** via the existing bottom capsule →
   `reloadNewestMessageWindow()` (not animate-to-fake-bottom inside a mid
   history window).

This plan rewires @me to the around-window path and locks the post-jump
pagination / memory-window / return-to-bottom contracts.

## Current state

### Entry: tongue → seq

`third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/tim_uikit_chat_history_message_list_tongue_container.dart`

- Builds tongue type from `groupAtInfoList` (`atMe` / `atAll`).
- On click (approx. lines 948–960): calls
  `widget.scrollToIndexBySeq(groupAtInfoList![0]!.seq)` then **clears**
  `groupAtInfoList` / sets `isFinishJumpToAt = true` **before** knowing
  whether jump succeeded.

### Broken jump: linear chase

`third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart`
→ `_onScrollToIndexBySeq` (approx. lines 8857–8941):

```dart
// If target older than current oldest:
findingSeq = targetSeq;
int requestCount = lastSeqInt - targetSeqInt; // NO clamp
maybeHaveMoreMessageForFind = await widget.onLoadMore(
    _getMessageId(widget.messageList.length - 1),
    LoadDirection.previous,
    requestCount,
    lastSeqInt);
```

Rebuild side-effect (approx. lines 9164–9168) re-enters while `findingSeq != ""`:

```dart
} else if (findingSeq != "") {
  _onScrollToIndexBySeq(findingSeq);
}
```

Contrast: unread-anchor load clamps `requestCount` to `1..80` (~6795).
Unread sequence miss already calls `loadListForSpecificMessage(seq:)` (~7137–7139).

### Correct around-window (reuse this)

`third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
→ `loadListForSpecificMessage` (approx. lines 921–1046):

- Fetches CLOUD_OLDER then LOCAL_OLDER, CLOUD_NEWER then LOCAL_NEWER around
  `lastMsgID` / `lastMsgSeq`.
- Merges newer + target + older, dedupes, requires anchor match.
- Sets `HistoryMessagePosition.notShowLatest`.
- Sets `haveMoreData` / `haveMoreLatestData` from SDK `isFinished`; if newer
  page empty, forces `haveMoreLatestData = true` so downward paging stays
  allowed.

### Bidirectional load after notShowLatest

`tim_uikit_history_message_list_container.dart` → `requestForData`:

- `LoadDirection.previous` always allowed when caller asks.
- `LoadDirection.latest` allowed when `haveMoreLatestData` **or** position is
  `notShowLatest` / `inTwoScreen` / `awayTwoScreen`.

Pagination implementation:
`tui_chat_history_pagination_load.dart` (older may fall back to archive when
SDK roaming ends; newer uses SDK latest direction).

### Memory window + return to bottom (must stay wired)

- After a locate scroll succeeds, list code calls
  `_releaseSearchJumpMemoryWindowSuppress(anchorMsgID:, anchorSeq:)` so
  `ChatMessageWindow.trimToWindow` keeps the **anchor** in the soft window
  instead of prefer-latest-only (see `tui_chat_global_model.dart`
  `applyMessageMemoryWindowNow` / trim with `anchorSeq`).
- Bottom capsule
  `_scrollToLatestAndDismissUnreadCapsule` (~166+ in tongue container):
  when `ChatMessageWindowPolicy.enabled`, **awaits**
  `model.reloadNewestMessageWindow()` then flushes deferred inbound and
  settles to true bottom. `@` jump must leave the chat in `notShowLatest`
  (or otherwise “missing newer”) so this path runs — **do not** invent a
  second return-to-bottom.

### Product / docs alignment (inline)

- Tencent IM Flutter history docs: jump @ with `lastMsgSeq = atSequence`,
  `V2TIM_GET_CLOUD_OLDER_MSG` + `V2TIM_GET_CLOUD_NEWER_MSG`, count ≈ 20.
  Official URL:
  https://cloud.tencent.com/document/product/269/75323
- In-repo roaming coverage constant:
  `RoamingContiguousWindow.roamingCoverageDays = 90`
  (`ui/utils/roaming_contiguous_window.dart`). Beyond that, older continuity
  depends on local DB + existing archive-older pagination — **do not** add a
  new archive API in this plan.

### Conventions to match

- Prefer reusing `loadListForSpecificMessage` / `MessageAnchor` /
  `_centerOnGlobalIndex` / `_releaseSearchJumpMemoryWindowSuppress` — same
  as search jump and unread-seq fallback.
- Toast / callback style: existing `showCantFindMsg()` →
  `TIM_t("无法定位到原消息")` / infoCode `6660401`.
- Tests: pure/unit style like
  `third_party/tencent_cloud_chat_uikit/test/chat_message_window_test.dart`
  and `roaming_contiguous_window_test.dart` (no full chat widget pump unless
  already trivial).

## Commands you will need

Run from repo root unless noted.

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Memory window | `cd third_party/tencent_cloud_chat_uikit && flutter test test/chat_message_window_test.dart` | all pass |
| Roaming helpers | `cd third_party/tencent_cloud_chat_uikit && flutter test test/roaming_contiguous_window_test.dart` | all pass |
| New @-jump tests (this plan) | `cd third_party/tencent_cloud_chat_uikit && flutter test test/at_me_jump_window_test.dart` | all pass |
| Analyze touched Dart | `dart analyze third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/tim_uikit_chat_history_message_list_tongue_container.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart` | no **new** errors |
| Optional app-level smoke | manual — see Done criteria checklist | human |

If `flutter test` from UIKit package fails on package config, run
`flutter pub get` **inside** `third_party/tencent_cloud_chat_uikit` once
(read-only advisor note: executor may run pub get; it mutates lock only in
that package — acceptable for execution). Do **not** `git init` the workspace.

## Suggested executor toolkit

- Re-read Tencent snippet in “Current state” before changing fetch direction
  semantics.
- Use existing search-jump scroll helpers; do not introduce a new scroll
  controller stack.

## Scope

**In scope** (only these, plus the new test file):

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart`
  — rewrite `_onScrollToIndexBySeq`; stop rebuild re-entrancy loops; after
  success center + memory-window release with anchor.
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/tim_uikit_chat_history_message_list_tongue_container.dart`
  — clear `groupAtInfoList` / `isFinishJumpToAt` **only after** jump success
  (or expose a success callback); keep tip on failure.
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
  — **only if needed**: thin wrapper e.g. `jumpToMessageBySeq(int seq)` that
  calls `loadListForSpecificMessage(seq: seq)` and documents @me/search
  shared contract; fix any clear bug that prevents seq-only around windows
  from marking `haveMoreLatestData` / `notShowLatest` correctly. Prefer
  **zero** model changes if list-layer reuse is enough.
- `third_party/tencent_cloud_chat_uikit/test/at_me_jump_window_test.dart`
  (create) — characterization / contract tests listed in Test plan.
- `third_party/tencent_cloud_chat_uikit/test/chat_message_window_test.dart`
  — **add** 1–2 cases for trim-around-`anchorSeq` while position is
  historical (preferLatest false), if not already covered.
- `plans/README.md` — status row only.

**Out of scope** (do NOT touch):

- Search UI / `initFindingMsg` / `searchJumpAnchor` entry from conversation
  search (already around-window) — unless a one-line shared helper extraction
  is required; do not change search UX copy.
- Conversation list, wallet, LiveKit, contacts, moments.
- Changing `RoamingContiguousWindow.roamingCoverageDays` or inventing new
  cloud retention.
- New archive HTTP endpoints / `message_archive_api.dart` rewrite.
- Redesigning tongue visuals / unread tongue policy.
- Changing `ChatMessageWindowPolicy` softMax/targetSize defaults globally
  (may set **anchor** only).
- App shell `lib/src/chat.dart` unless a compile break forces a one-line
  passthrough — prefer STOP over expanding scope.

## Git workflow

- No `.git` in this workspace historically; if git appears, branch
  `advisor/009-at-me-around-window-jump`, conventional-style commits like
  prior plans (`fix: …` / `test: …`).
- Do NOT push or open a PR unless the operator asks.

## Target behavior (acceptance narrative)

After clicking @me for a message whose seq is far below the current window:

1. Client replaces (or loads into) the message list with a **small window
   around that seq** via `loadListForSpecificMessage` (not N = seq-delta
   previous loads).
2. List position is `notShowLatest`; `haveMoreData` / `haveMoreLatestData`
   reflect whether older/newer pages remain.
3. Viewport centers on the @ message (`_centerOnGlobalIndex` +
   `jumpMsgID`); memory window suppress releases with **that** msgID/seq as
   trim anchor.
4. User scrolls **up**: `LoadDirection.previous` appends older contiguous
   pages (SDK then existing archive-older fallback). No requirement to keep
   the entire chat in RAM.
5. User scrolls **down**: `LoadDirection.latest` appends newer contiguous
   pages toward the live tip until `haveMoreLatestData == false`.
6. User taps return-to-bottom: existing
   `reloadNewestMessageWindow` path runs; list returns to global latest
   without stopping on the mid-history “fake bottom.”
7. If cloud+local+archive cannot resolve the seq: toast
   `无法定位到原消息`; **keep** the @ tip so the user can retry; do not leave
   `findingSeq` stuck causing rebuild storms.

## Steps

### Step 1: Characterization tests first (red or document baseline)

Create `third_party/tencent_cloud_chat_uikit/test/at_me_jump_window_test.dart`.

Cover **pure** contracts the implementation must honor (implement helpers
under `@visibleForTesting` only if needed; prefer testing
`ChatMessageWindow.trimToWindow` + a tiny extracted pure function rather than
mocking IM SDK):

1. **Seq parse**: empty / non-int seq → treated as unlocatable (mirrors early
   `int.tryParse` failure in `_onScrollToIndexBySeq`).
2. **Memory trim around anchor**: with `preferLatest: false` and
   `anchorSeq` set to a mid-list seq, after trim the window still contains
   that seq and keeps neighbors on both sides (extend
   `chat_message_window_test.dart` if cleaner there).
3. **Post-jump flag table** (document as comments + assert a small pure
   mapper if you extract one): successful around-load ⇒ position
   `notShowLatest`; `haveMoreLatestData` true when newer edge not finished;
   failure ⇒ do not clear tongue.

**Verify**:

```bash
cd third_party/tencent_cloud_chat_uikit && flutter test test/chat_message_window_test.dart test/at_me_jump_window_test.dart
```

→ exit 0. If Step 1 only adds failing stubs for not-yet-extracted helpers,
either extract the pure helper in the same step or keep tests green by
testing only `ChatMessageWindow` behavior first — **do not** leave the suite
red overnight.

### Step 2: Rewrite `_onScrollToIndexBySeq` to around-window + center

In `tim_uikit_chat_history_message_list.dart`:

1. Parse `targetSeq`; on failure → `showCantFindMsg()` (unchanged UX).
2. **Fast path**: if `_globalIndexForSeq(targetSeq)` is non-null, keep
   existing center-on-index + `jumpMsgID` +
   `_releaseSearchJumpMemoryWindowSuppress(anchorMsgID:, anchorSeq:)` —
   no network.
3. **Slow path** (target not in memory):
   - Set loading indicator (`loadingPlace = LoadingPlace.top` or existing
     pattern).
   - `_lockSearchJumpStabilization` as today.
   - `await widget.model.loadListForSpecificMessage(seq: targetSeqInt)`
     (or thin wrapper from Step 3).
   - On `false` → `showCantFindMsg()`; clear `findingSeq`; return.
   - On `true` → await end-of-frame; resolve index via
     `_globalIndexForSeq`; `_centerOnGlobalIndex` with
     `_SearchJumpTarget(resolveIndex: () => _globalIndexForSeq(targetSeq))`;
     set `widget.model.jumpMsgID` when msgID known; call
     `_releaseSearchJumpMemoryWindowSuppress` with that msgID/seq;
     clear `findingSeq` / `maybeHaveMoreMessageForFind` chase state;
     `loadingPlace = none`.
4. **Delete** the `requestCount = lastSeqInt - targetSeqInt` previous-load
   branch and any dependency on multi-round `findingSeq` chase for @me.
5. Remove or guard the build()-time `else if (findingSeq != "") {
   _onScrollToIndexBySeq(findingSeq); }` so a successful/failed jump cannot
   re-enter every rebuild. If search/other features still need `findingSeq`,
   restrict re-entry to an explicit “in-flight around jump” flag with a
   single-flight lock (`_scrollToFindInFlight` already exists — reuse it).

**Verify**:

```bash
cd third_party/tencent_cloud_chat_uikit && dart analyze lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart
```

→ no new errors. Grep must show **no** `lastSeqInt - targetSeqInt` in that
file:

```bash
rg -n "lastSeqInt - targetSeqInt" third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart
```

→ no matches.

### Step 3: Tongue tip lifecycle (success-only dismiss)

In `tim_uikit_chat_history_message_list_tongue_container.dart`:

- Change `scrollToIndexBySeq` usage so the tip is **not** cleared
  synchronously before the async jump finishes.
- Practical options (pick the smallest):
  - Make `scrollToIndexBySeq` return `Future<bool>` and `await` it in
    `onClick`; clear list / set `isFinishJumpToAt` only when `true`; **or**
  - Pass a callback / ValueChanged from the list after successful center.

For multiple @ items: on success of one, remove **that** seq entry only
(existing `removeAt(0)` behavior), not the whole list unless length was 1.

**Verify**: `dart analyze` on the tongue file → no new errors. Manual note
in Done criteria: failure keeps tip visible.

### Step 4: Contiguity & return-to-bottom contract (assert in code paths)

Confirm after Step 2 (read + minimal glue only):

| Concern | Required post-success state |
|---------|-----------------------------|
| Up scroll | `model.haveMoreData` true if older remains; previous loads use list edge msgID/seq via existing `onLoadMore` |
| Down scroll | position `notShowLatest` **or** `haveMoreLatestData` true so `requestForData` allows `LoadDirection.latest` |
| Memory trim | `_releaseSearchJumpMemoryWindowSuppress` called with @ msgID/seq so trim does not prefer-latest-away the anchor mid-scroll |
| Return bottom | Do **not** bypass tongue `_scrollToLatestAndDismissUnreadCapsule`; ensure `ChatMessageWindowPolicy.enabled` path still calls `reloadNewestMessageWindow`. After reload, `haveMoreLatestData == false` and position `bottom` (existing `reloadNewestMessageWindow` behavior) |

If `loadListForSpecificMessage` returns success but leaves `haveMoreLatestData == false` **and** newer messages clearly exist beyond the window, fix **only** the existing force-true branch already present when `newerList.isEmpty` — do not invent heuristics. If you discover the SDK marks `isFinished` incorrectly for mid-history, STOP and report (needs product decision).

**Verify**:

```bash
cd third_party/tencent_cloud_chat_uikit && flutter test test/chat_message_window_test.dart test/at_me_jump_window_test.dart test/roaming_contiguous_window_test.dart
```

→ all pass.

### Step 5: Trace / diagnostics (optional but recommended)

Add a single `ChatHistoryTrace.log` (or existing jitter diag) on @ around-jump
begin/success/fail with `targetSeq`, `loaded`, `listLen`, `haveMoreData`,
`haveMoreLatestData`, `position` — match existing `request_for_data` log
style. Do not spam per-frame.

**Verify**: analyze clean; no PII in logs (seq/ids only).

### Step 6: Update plans index

Set plan 009 status to DONE in `plans/README.md` when Done criteria pass
(or IN PROGRESS while executing).

## Test plan

| Case | Where | Notes |
|------|-------|-------|
| Trim keeps `anchorSeq` mid-window when preferLatest false | `chat_message_window_test.dart` or new file | Contiguity under memory window |
| Unlocatable seq parse | `at_me_jump_window_test.dart` | Pure |
| Grep gate: no seq-delta chase | shell in Done criteria | Prevents regression |
| Roaming helpers unchanged | `roaming_contiguous_window_test.dart` | Safety |

Do **not** require full `TIMUIKitChat` widget tests with fake SDK unless the
repo already has a harness — it does not. Manual smoke covers E2E.

**Manual smoke** (executor or human; mark NOT RUN in delivery if skipped):

1. Group with recent @me → tip → lands on message; scroll up/down a page;
   messages remain ordered contiguous; no blank hole.
2. Group with **old** @me (beyond current first screen, ideally near roaming
   edge) → tip → lands without multi-second “loading forever”; scroll both
   directions.
3. After @ jump, tap return-to-bottom → lands on live latest; new inbound
   sticks to bottom as before.
4. Force failure (bogus seq via debug if available) → toast; tip remains.

## Done criteria

Machine-checkable — ALL must hold:

- [ ] `rg -n "lastSeqInt - targetSeqInt" third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart` → **no matches**
- [ ] `_onScrollToIndexBySeq` slow path calls `loadListForSpecificMessage` (or thin wrapper that does)
- [ ] Tongue clears @ tip only after successful jump (code review of
      `onClick` / Future)
- [ ] `cd third_party/tencent_cloud_chat_uikit && flutter test test/chat_message_window_test.dart test/at_me_jump_window_test.dart test/roaming_contiguous_window_test.dart` → exit 0
- [ ] `dart analyze` on in-scope lib files → no new errors
- [ ] No files outside Scope modified (`git status` if git exists; else list
      touched paths in the handoff note)
- [ ] `plans/README.md` row for 009 updated

Manual (may remain NOT RUN with reason):

- [ ] Smoke items 1–3 in Test plan

## STOP conditions

Stop and report (do not improvise) if:

- Live `_onScrollToIndexBySeq` / `loadListForSpecificMessage` / tongue
  `onClick` no longer match the excerpts (drift).
- Fix appears to require changing archive HTTP contracts or
  `lib/src/chat.dart` open-hydrate ownership.
- `loadListForSpecificMessage(seq:)` systematically returns false for valid
  in-roaming seqs (SDK / permission) — report with Trace logs; do not fall
  back to unbounded seq-delta chase.
- Making `scrollToIndexBySeq` async forces a wide API break across
  out-of-scope packages — prefer a success callback local to tongue+list.
- Contiguity “fix” seems to need disabling `ChatMessageWindowPolicy`
  entirely — STOP; that is a product/perf tradeoff outside this plan.
- A step’s verification fails twice after a reasonable fix attempt.

## Maintenance notes

- Search jump and @me must stay on the **same** around-window primitive; if
  one gains archive-around-seq later, update both.
- Any future change to `ChatMessageWindow.trimToWindow` must keep
  `anchorSeq` behavior — @ jump depends on it for mid-history scrolling.
- Reviewers should watch for: rebuild re-entrancy on `findingSeq`, tip
  cleared on failure, return-to-bottom skipping `reloadNewestMessageWindow`,
  and accidental reintroduction of `lastSeq - targetSeq` loads.
- Deferred (explicitly not this plan): jump-to-@ from push notification
  deep link; multi-@ playlist UI; changing 90-day roaming product config.
