# Plan 026: Contiguous latest merge after around-window + harden search miss fallback

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
> **Depends on Plan 025**: if 025 is not DONE, either execute 025 first or
> confirm live code already allows `loadLatest` while `notShowLatest` +
> `haveMoreLatestData` — otherwise this plan’s merge path never runs in the
> failing product scenario.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED–HIGH (message-list splice; wrong continuity = silent holes or
  fake timelines)
- **Depends on**: plans/025-search-jump-latest-after-land.md (soft: gates must
  allow latest pages to arrive)
- **Category**: bug
- **Planned at**: working tree 2026-08-22 (no git SHA — `NO_GIT` at plan time)
- **Execution**: DONE (2026-08-22) — `HistoryPaginationContinuity` wired on
  latest merge; `MessageAnchor.isPresentIn` for miss/fallback; tests green.
- **Issue**: omit

## Why this matters

Even after Plan 025 makes `LoadDirection.latest` reachable from a search
around-window, pagination still **splices** with:

```dart
List<V2TimMessage> _combineMessageList(
    List<V2TimMessage> first, List<V2TimMessage> second) {
  return TUIChatGlobalModel.sortMessagesNewestFirst(
    model._dedupeMessages([...first, ...second]),
  );
}
```

(`tui_chat_history_pagination_load.dart` ≈893–897.) For
`LoadDirection.latest`, the SDK batch is reversed then combined with the
in-memory around window (≈336–338). Dedup+sort can produce a list that
**looks** continuous in time/seq while skipping an unfetched gap (or can
attach a tip page that does not abut the window’s newest edge). Users then
see “jumped then weird neighbors” or scroll holes when paging toward tip.

Separately, when `loadListForSpecificMessage` returns false / no anchor
match, `tim_uikit_chat.dart` calls `_fallbackToRecentHistory`, sets position
to `bottom`, marks `SearchJumpStatus.failed`, and toasts
「无法定位到该消息，已显示最近聊天记录」. That is intentional UX, but a
**false miss** (transient empty, race with `windowGen`, overly strict match)
still wipes the around attempt and dumps the user on the tip — feels like a
failed jump / wrong scroll. This plan hardens miss detection and keeps
fallback only for true unlocatable targets.

## Current state

### A. Combine without abutment check

`tui_chat_history_pagination_load.dart` paginated branch ≈335–341:

```dart
if (direction == LoadDirection.latest) {
  messageList = messageList.reversed.toList();
  newList = _combineMessageList(messageList, mergeBase);
} else {
  newList = _combineMessageList(mergeBase, messageList);
}
```

`_combineMessageList` ≈893–897 — concat, dedupe, `sortMessagesNewestFirst`.
No check that the newest seq/timestamp of `mergeBase` abuts the oldest of
the incoming newer batch (or vice versa for previous).

Related existing gap tooling (reuse ideas / seq helpers, do **not** rewrite
archive HTTP):

- `ArchiveWindowReconciler.detectGaps` in
  `lib/ui/utils/archive_window_reconciler.dart`
- `RoamingContiguousWindow` in `lib/ui/utils/roaming_contiguous_window.dart`
  (spine / contiguous helpers — exemplar for pure tests:
  `test/roaming_contiguous_window_test.dart`)

### B. Search miss → recent fallback

`tim_uikit_chat.dart` ≈1868–1906:

```dart
final loaded = await model!.loadListForSpecificMessage(
  anchor: searchJumpAnchor,
  targetMessage: target,
);
final messages = globalModel.getMessageList(conversationID);
if (loaded &&
    messages != null &&
    messages.any(searchJumpAnchor.matches)) {
  // success
  return;
}
final recovered = await _fallbackToRecentHistory(fallbackCount);
globalModel.setMessageListPosition(..., HistoryMessagePosition.bottom, ...);
globalModel.setSearchJumpStatus(..., SearchJumpStatus.failed, ...);
// toast: 无法定位…已显示最近聊天记录 / 无法定位到该消息
```

`loadListForSpecificMessage` already returns `false` when window empty or
target seq missing beyond ±20 (≈1141–1213 in
`tui_chat_separate_view_model.dart`). False fallback risk is mainly:

- `loaded == true` but `messages.any(matches)` false while seq-near window
  is present (match too strict vs around-load’s seqInt equality path).
- Or list cleared then fallback races with a late around commit
  (`windowGen`) — prefer keeping failed empty + toast over tip dump only
  when around truly failed; if generation invalidated mid-flight, do not
  treat as “message gone.”

### C. Conventions

- Prefer a **pure** abutment helper + unit tests (Plan 009 style).
- When abutment fails: **do not** silently sort-merge. Either keep
  `mergeBase` unchanged and set/keep `haveMoreLatestData` appropriately, or
  mark a “gap / missing newer” flag so Plan 025’s missing-newer path can
  retry — pick one policy and test it (Step 2).
- Do not change search result UI copy except clarifying the miss toast if
  fallback is skipped (optional; default keep existing strings).

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| New + roaming tests | `cd third_party/tencent_cloud_chat_uikit && flutter test test/history_pagination_continuity_test.dart test/roaming_contiguous_window_test.dart` | exit 0 |
| Analyze | `cd third_party/tencent_cloud_chat_uikit && dart analyze lib/business_logic/separate_models/tui_chat_history_pagination_load.dart lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart` | no new errors |
| Grep combine | `rg -n "_combineMessageList|abut|contiguous|LoadDirection.latest" third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_history_pagination_load.dart` | latest path uses continuity gate |

## Scope

**In scope**:

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_history_pagination_load.dart`
  — continuity check before accepting a latest (and optionally previous)
  combine into an around / mid-history window.
- Pure helper file under
  `third_party/tencent_cloud_chat_uikit/lib/ui/utils/` (recommended name:
  `history_pagination_continuity.dart`) +
  `third_party/tencent_cloud_chat_uikit/test/history_pagination_continuity_test.dart`.
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart`
  — search-jump success/miss criteria only (match / fallback gating).
- Optionally thin read-only use of seq helpers already on messages; do not
  fork `MessageAnchor.matches`.

**Out of scope**:

- Plan 025 gate / suppress release (must already be done or equivalent live).
- Rewriting `loadListForSpecificMessage` fetch counts / cloud vs local order.
- Archive API, conversation list, wallet, LiveKit, search UI chrome.
- Changing global `sortMessagesNewestFirst` semantics for non-paginated
  paths.
- Forcing full-chat download to “fill the gap” in one shot.

## Git workflow

- Branch if git exists: `advisor/026-search-jump-contiguous-merge`.
- Commits: `fix: reject non-abutting latest merge into around window`,
  `fix: harden search jump miss vs recent fallback`.
- Do NOT push unless asked.

## Target behavior

1. **Latest page abuts window**: If the newest message in the current
   in-memory window and the oldest message of the incoming newer batch are
   contiguous by **group seq** when both sides have positive seq (recommended
   primary key), merge as today. If seq missing (C2C), fall back to
   timestamp tolerance documented in the helper (e.g. allow merge when
   timestamps are non-decreasing across the join edge with no other messages
   claimed missing — keep the rule simple and tested).
2. **Non-abutting latest batch**: Do **not** concat+sort into a fake spine.
   Keep prior list; leave `haveMoreLatestData` true (or set
   `memoryWindowMissingNewer` if that is the existing signal Plan 025
   honors); log a `ChatHistoryTrace` event
   `load_latest_rejected_non_contiguous` with edge seqs.
3. **Search miss**: Fallback to recent only when around load returned false
   **or** the in-memory list has no seq/msgID match under the same rules
   `loadListForSpecificMessage` uses for success (including seqInt equality).
   If `loaded == true` and seq matches but `MessageAnchor.matches` fails,
   treat as **success** for status purposes (align UI check with model), do
   not dump to tip.
4. If around load was invalidated by `windowGen` (returns false with empty
   list after clear), prefer failed toast **without** pretending the tip is
   the search target; existing failed status stays.

## Steps

### Step 1: Pure continuity helper + tests

Create `lib/ui/utils/history_pagination_continuity.dart` with something like:

```dart
class HistoryPaginationContinuity {
  /// Returns true if [incomingNewer] (already newest-first or document order)
  /// can be prepended to [existingNewestFirst] without inventing a gap.
  static bool canPrependNewerBatch({
    required List<({int? seq, int? timestamp})> existingNewestFirst,
    required List<({int? seq, int? timestamp})> incomingNewerNewestFirst,
  });
}
```

Adapt field names to whatever is natural; map from `V2TimMessage` at the
call site.

Tests in `test/history_pagination_continuity_test.dart`:

1. Contiguous group seqs (e.g. existing newest seq 100, incoming older edge
   101… or whatever order you document — **be explicit in comments** about
   newest-first list orientation).
2. Gap (existing 100, incoming starts at 150) → false.
3. Empty incoming → true (no-op merge) or false — pick one; document.
4. C2C / seq-null path: timestamps abut within rule → true; large time hole
   → false.
5. Dedup overlap (incoming shares id/seq with existing edge) → true
   (overlap is OK; gap is not).

**Verify**:

```bash
cd third_party/tencent_cloud_chat_uikit && flutter test test/history_pagination_continuity_test.dart
```

→ exit 0.

### Step 2: Wire continuity into latest pagination combine

In `tui_chat_history_pagination_load.dart`, for `direction == LoadDirection.latest`
paginated combine:

1. Before `_combineMessageList`, evaluate continuity between `mergeBase` and
   the reversed newer `messageList`.
2. If false: do not replace the committed list with a gapped merge; restore /
   keep baseline; keep `haveMoreLatestData` meaningful; emit trace log.
3. If true: existing combine + commit path unchanged.
4. **Optional but recommended**: apply the same abutment idea for
   `LoadDirection.previous` (older batch must abut oldest edge). If previous
   already feels solid in production, you may limit this plan to **latest
   only** — state which in the commit message. Prefer latest-first.

Do **not** change `_combineMessageList` global sort behavior for unrelated
callers without the gate.

**Verify**:

```bash
rg -n "HistoryPaginationContinuity|load_latest_rejected_non_contiguous" \
  third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_history_pagination_load.dart
```

→ wired. Then `dart analyze` on that file → clean.

### Step 3: Align search-jump success match with around-load

In `tim_uikit_chat.dart` search branch after `loadListForSpecificMessage`:

1. Treat success if `loaded` and list contains either
   `searchJumpAnchor.matches(m)` **or** same seqInt equality used in
   `loadListForSpecificMessage` (extract a shared `MessageAnchor` /
   small helper if one already exists — search for `seqInt` on
   `MessageAnchor` before duplicating).
2. Only then call `_fallbackToRecentHistory`.
3. If `loaded == false` because generation invalidated and list is empty,
   still fallback or show failed empty — **prefer** current fallback if that
   avoids a blank chat; document choice in code comment (one sentence).

**Verify**:

```bash
rg -n "searchJumpAnchor.matches|loadListForSpecificMessage|_fallbackToRecentHistory" \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart
```

→ success condition broader than raw `matches` alone when seq present.

```bash
cd third_party/tencent_cloud_chat_uikit && dart analyze \
  lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart
```

### Step 4: Regression suite

```bash
cd third_party/tencent_cloud_chat_uikit && flutter test \
  test/history_pagination_continuity_test.dart \
  test/roaming_contiguous_window_test.dart \
  test/search_jump_latest_gate_test.dart \
  test/at_me_jump_window_test.dart
```

→ exit 0 (`search_jump_latest_gate_test` from Plan 025 must exist).

**Manual (NOT RUN in CI)**:

1. Search-jump to old hit → scroll down many pages → no sudden tip splice;
   seqs increase without multi-hundred jumps.
2. Force a miss (deleted msg) → toast + recent or empty failed; no silent
   wrong “success.”
3. @me / unread entry still OK (smoke).

## Test plan

- New continuity unit tests (Step 1).
- Keep Plan 025 gate tests green.
- No full SDK integration test required.

## Done criteria

- [ ] Latest paginated merge refuses non-abutting batches (tested + wired).
- [ ] Trace log on reject exists.
- [ ] Search-jump success uses seq-aware match aligned with around-load.
- [ ] Fallback only on true miss / load false (per Step 3 policy).
- [ ] Listed `flutter test` commands exit 0; analyze clean on touched files.
- [ ] No out-of-scope files modified.
- [ ] `plans/README.md` row for 026 updated.

## STOP conditions

- Plan 025 not landed and live gates still block all latest under
  `notShowLatest` — STOP; finish 025 first.
- Continuity rule would reject **all** C2C latest pages (seq always null) —
  STOP and redesign C2C timestamp rule before shipping.
- Fix seems to need downloading the entire gap in one request — out of
  scope; report.
- Excerpts drifted; verification fails twice.

## Maintenance notes

- Reviewers: ensure reject path cannot leave `haveMoreLatestData == false`
  forever when a gap remains (stuck edge).
- Future archive fill can consume the same continuity helper.
- Do not weaken dedupe; continuity is about **edges**, not id uniqueness.
