# Plan 044: Continue older-history load while pinned at top

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt below to the live files. If
> `ChatListPaginationUiGate` already exposes
> `releaseTopReachConsumedAfterSuccessfulPage` (or equivalent) **and**
> `_loadPreviousImpl` already clears `previousLoadConsumedThisTopReach` on
> `effectiveLoaded && haveMoreData`, mark DONE / adjust and report — do not
> duplicate the latch.

## Status

- **Priority**: P0
- **Effort**: S–M
- **Risk**: MED (must not reintroduce iOS rubber-band burst loads or empty-batch
  list oscillation)
- **Depends on**: none
- **Category**: bug
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Issue**: omit

## Why this matters

Users who slide to the **oldest** edge of a chat (visual top) often get only
**one** extra page, then nothing happens until they scroll **down ~320px**
and back up. That is not an SDK miss: the UI latch
`previousLoadConsumedThisTopReach` is set when `_loadPrevious` starts and is
**intentionally kept** after the request finishes (`finishPreviousLoadInFlight`
only clears the in-flight anchor). The 320px reset
(`loadPreviousTopReachResetPx`) only runs on finger `ScrollStart`. Staying
pinned at the top therefore blocks the next `LoadDirection.previous`.

Product intent: **keep loading older history while the user stays at / keeps
gesturing at the top**, as long as `haveMoreData` is true. Anti-burst
machinery (debounce 120ms, cooldown 320ms, `ignoreScrollLoadPrevious`,
`historyScrollProtectMs` ~520ms) stays. Empty/failed pages must still latch
so a no-growth batch cannot spin.

## Current state

Chat history list is **reversed**: visual top (older) is `maxScrollExtent`;
visual bottom (newer) is `minScrollExtent`. Do not flip these.

**Gate** — `third_party/tencent_cloud_chat_uikit/lib/ui/controllers/chat_list_pagination_ui_gate.dart`

Constants and latch:

```dart
static const loadPreviousDebounceMs = 120;
static const loadPreviousCooldownMs = 320;
static const historyScrollProtectMs = 520;
static const loadPreviousScrollUnlockMs = 360;
static const loadPreviousTopReachResetPx = 320.0;
static const loadPreviousTopNearPx = 160.0;
```

```dart
/// 本次贴顶是否已消费过上拉分页；须离开顶部 [loadPreviousTopReachResetPx] 后再允许。
bool shouldAllowLoadPreviousAtTopReach({bool bypassTopReachConsumed = false}) {
  if (bypassTopReachConsumed) {
    return true;
  }
  return !previousLoadConsumedThisTopReach;
}

void markTopReachConsumedForPreviousLoad(String anchorKey) { ... }

void resetTopReachConsumedIfScrolledAway({
  required double pixels,
  required double maxScrollExtent,
}) {
  if (maxScrollExtent <= 0) {
    return;
  }
  if (pixels < maxScrollExtent - loadPreviousTopReachResetPx) {
    previousLoadConsumedThisTopReach = false;
    lastTopReachConsumedAnchorKey = null;
  }
}

/// 分页请求结束：只清 in-flight，保留贴顶消费位（防同顶连拉）。
void finishPreviousLoadInFlight() {
  previousLoadInFlightAnchorKey = null;
}
```

**List UI** — `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart`

Near-top (do not change thresholds in this plan):

```dart
bool _isNearTopForHistoryLoad(ScrollMetrics metrics) {
  // ...
  if (metrics.maxScrollExtent <= 0) {
    return false; // short / unscrollable — not this bug
  }
  if (_isOverscrollingPastTop(metrics)) {
    return false;
  }
  return metrics.pixels >= metrics.maxScrollExtent - _loadPreviousTopNearPx;
}
```

Trigger from `NotificationListener` (~9729–9790): `ScrollUpdate` /
`Overscroll` → `_shouldTriggerLoadPreviousFromScroll` →
`_scheduleLoadPrevious`. Latch check is first in
`_shouldTriggerLoadPreviousFromScroll` (`consumed_this_top_reach`).

`ScrollStart` (finger only) is the **only** place that calls
`resetTopReachConsumedIfScrolledAway`.

`_loadPrevious` marks the latch **immediately**:

```dart
_paginationUi.markTopReachConsumedForPreviousLoad(
  _previousLoadAnchorKey(anchor),
);
```

`_loadPreviousImpl` `finally` (~6013–6087):

- sets `lastLoadPreviousCompletedAtMs`, `isLoadingPrevious = false`
- `effectiveLoaded = loaded && listLenAfter > listLenBefore`
- **if `!effectiveLoaded`**: keep latch (comment: 空批 / 防同顶连拉振荡)
- **if `effectiveLoaded`**: compensate scroll; **does not** clear latch
- `_finishPreviousLoadPagination()` → `finishPreviousLoadInFlight()` only
- delayed `ignoreScrollLoadPrevious -= 2` after 360ms

Short-list fill (`_scheduleShortViewportHistoryFill`, ~8808–8847) already
uses `bypassTopReachConsumed: true` when `maxScrollExtent <= 1`. **Do not
reuse that bypass on the normal scrollable path** — it is for unscrollable
first-screen fill only.

**Existing tests (extend, do not delete the empty-batch latch cases)** —
`test/chat_list_pagination_ui_gate_test.dart`:

- `blocks repeat load at same top reach until scrolled away`
- `viewport fill can bypass top reach consumed`
- `does not reset top reach when still near top`

**Conventions**: keep Chinese comments explaining *why* (oscillation vs
continue-at-top). Match gate naming (`previousLoadConsumedThisTopReach`,
`haveMoreData`). Prefer a named gate method over scattering
`previousLoadConsumedThisTopReach = false` in the list file. Do not change
`haveMoreData` computation in
`tui_chat_history_pagination_load.dart`.

## Product decisions (locked)

| Decision | Choice |
|----------|--------|
| Successful page + `haveMoreData` | **Release** same-top latch so the next user scroll/overscroll can load again |
| Empty / no-growth / error | **Keep** latch; user must leave top 320px (existing reset) or wait for a later SDK `haveMoreData` flip via other paths |
| Auto-chain pages with no new scroll event | **No** — do not schedule `_scheduleLoadPrevious` from `finally` just because still near top. Relies on continued gesture / overscroll / next `ScrollUpdate` |
| Cooldown / debounce / ignoreScroll / historyScrollProtect | **Keep** current constants |
| `loadPreviousTopReachResetPx` (320) | **Keep** as the empty-batch / retry-by-leaving-top backup |
| `bypassTopReachConsumed` on the scroll listener | **Do not** set true for ordinary `ScrollUpdate` |
| `haveMoreData` / SDK `isFinished` | **Out of scope** |
| Inverted list / `HistoryPaginationScrollPhysics` | **Out of scope** |

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Gate + contract tests | `flutter test test/chat_list_pagination_ui_gate_test.dart` | all pass (including new cases) |
| Related pagination tests | `flutter test test/history_pagination_scroll_physics_test.dart test/history_pagination_stable_window_contract_test.dart` | all pass |
| Analyze touched | `dart analyze third_party/tencent_cloud_chat_uikit/lib/ui/controllers/chat_list_pagination_ui_gate.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart test/chat_list_pagination_ui_gate_test.dart` | no errors in those files |

## Scope

**In scope**:

- `third_party/tencent_cloud_chat_uikit/lib/ui/controllers/chat_list_pagination_ui_gate.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart`
- `test/chat_list_pagination_ui_gate_test.dart`
- `plans/README.md` status row for 044

**Out of scope**:

- `tui_chat_history_pagination_load.dart` / `haveMoreData` SDK mapping
- `history_pagination_scroll_physics.dart` compensation math
- `_scheduleShortViewportHistoryFill` (keep bypass only for unscrollable)
- Conversation **list** feed paging (`conversation.dart` `_loadMoreFeedConversations`)
- Chat-open warm count / ViewportReady (020/022)
- Search-jump latest pagination (025–026)
- Auto-paging N pages while the finger is idle at top
- Changing debounce / cooldown / protect / 160 / 320 numeric constants
  unless a STOP condition proves they make the new latch-release burst
  (then STOP and report — do not silently retune)

## Git workflow

- This tree may have **no `.git`**. Do not `git init`. If `.git` exists:
  branch `advisor/044-pinned-top-history-continue`
- Commit message style: Conventional, e.g.
  `fix(chat): release top-reach latch after successful older-history page`
- Do **not** push or open a PR unless the operator asked.

## Steps

### Step 1: Add gate release API + unit tests

In `ChatListPaginationUiGate` add:

```dart
/// 成功翻到更早一页且模型仍有更早历史：放开同一次贴顶消费位。
/// 空批 / 无增长仍保持消费位（见 finishPreviousLoadInFlight）。
void releaseTopReachConsumedAfterSuccessfulPage({
  required bool haveMoreData,
}) {
  if (!haveMoreData) {
    return;
  }
  previousLoadConsumedThisTopReach = false;
  lastTopReachConsumedAnchorKey = null;
}
```

Keep `finishPreviousLoadInFlight` **unchanged** (in-flight ≠ success).

Update `test/chat_list_pagination_ui_gate_test.dart`:

1. Keep `blocks repeat load at same top reach until scrolled away` — still
   true when `releaseTopReachConsumedAfterSuccessfulPage` is **not** called.
2. Keep `does not reset top reach when still near top` (320px API).
3. Add `successful page with haveMore releases latch` —
   `markTopReachConsumed` → `releaseTopReachConsumedAfterSuccessfulPage(haveMoreData: true)` →
   `shouldAllowLoadPreviousAtTopReach()` is true.
4. Add `successful page without haveMore keeps latch` —
   `haveMoreData: false` → still blocked.
5. Add `finishPreviousLoadInFlight does not release latch` — still blocked
   after finish-only.

**Verify**: `flutter test test/chat_list_pagination_ui_gate_test.dart` → all
pass. If the first existing test name is now misleading, rename it to
`blocks repeat load at same top reach until scrolled away or successful release`
but keep the same assertions for the scroll-away path.

### Step 2: Release latch only on effective growth + haveMore

In `_loadPreviousImpl` `finally`, after `effectiveLoaded` is computed
(~6024), **only on the `effectiveLoaded` branch**, call:

```dart
_paginationUi.releaseTopReachConsumedAfterSuccessfulPage(
  haveMoreData: widget.model.haveMoreData,
);
```

Do this **before** `_finishPreviousLoadPagination()` so logs can show
`topReachConsumed` after release.

On the `!effectiveLoaded` branch: **do not** call release (keep today's
comment).

On the `catch` that already clears the latch (~6009–6010): leave as-is
(error already unblocks).

Do **not** add a `finally` `_scheduleLoadPrevious(...)` with no new
scroll event.

Optional one-line log extra: `'releasedTopReach': effectiveLoaded && widget.model.haveMoreData`.

**Verify**:

```bash
rg -n "releaseTopReachConsumedAfterSuccessfulPage" \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart
```

→ exactly **one** call site, inside `_loadPreviousImpl`.

```bash
rg -n "bypassTopReachConsumed: true" \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart
```

→ still **only** the short-viewport fill path (~8845). If this count grew,
STOP.

### Step 3: Source contract + analyze

Add to `test/chat_list_pagination_ui_gate_test.dart` a `source contracts`
group (same style as `test/chat_open_viewport_ready_contract_test.dart`):

- Read `tim_uikit_chat_history_message_list.dart` as a string.
- Assert it contains `releaseTopReachConsumedAfterSuccessfulPage`.
- Assert `_loadPreviousImpl` appears **before** that call.
- Assert `!effectiveLoaded` / empty-batch comment path still exists
  (`保留贴顶消费位` or `effectiveLoaded`).

**Verify**:

```bash
flutter test test/chat_list_pagination_ui_gate_test.dart \
  test/history_pagination_scroll_physics_test.dart \
  test/history_pagination_stable_window_contract_test.dart
```

→ all pass.

```bash
dart analyze \
  third_party/tencent_cloud_chat_uikit/lib/ui/controllers/chat_list_pagination_ui_gate.dart \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart \
  test/chat_list_pagination_ui_gate_test.dart
```

→ no **errors** in those files (pre-existing warnings in the huge list file
are OK if they are not new).

### Step 4: Index

Set plan 044 status to **DONE** in `plans/README.md` when the above is green.

## Test plan

| Case | Where | Expect |
|------|--------|--------|
| Latch still blocks without release or 320px leave | existing gate test | `shouldAllow` false after mark + finish |
| 320px leave still resets | existing | pixels 500 / max 1000 → allow |
| Still near top (900/1000) does not reset via scroll-away API | existing | still blocked |
| `haveMoreData: true` after success | **new** | allow |
| `haveMoreData: false` after "success" API | **new** | blocked |
| Source: list calls release once in `_loadPreviousImpl` | **new** | string contract |
| Physics / stable window | existing files | no regressions |

Manual (operator, not a gate): long chat, slide to visual top, keep
nudging/overscrolling up — second page should appear **without** first
scrolling ~320px toward newest. Empty chat / last page must not spin a
spinner loop.

## Done criteria

- [x] `releaseTopReachConsumedAfterSuccessfulPage` exists on the gate
- [x] `_loadPreviousImpl` calls it **only** when `effectiveLoaded` is true
- [x] `finishPreviousLoadInFlight` still does **not** clear the latch
- [x] `bypassTopReachConsumed: true` remains only on short-viewport fill
- [x] Debounce / cooldown / 160 / 320 constants unchanged
- [x] `flutter test test/chat_list_pagination_ui_gate_test.dart` passes
- [x] Related pagination tests in Commands still pass (physics **pass**;
      `history_pagination_stable_window_contract_test` **pre-existing fail**
      on `tui_chat_history_pagination_load.dart` string contract — out of
      044 scope, file untouched)
- [x] No files outside Scope (`git status` or `ls` of diffs)
- [x] `plans/README.md` row 044 → DONE

## STOP conditions

- Live excerpts no longer match (latch already released on every
  `finally`, or latch deleted entirely) — report and do not invent a
  second mechanism.
- Fix appears to need `haveMoreData` / SDK `isFinished` changes — STOP.
  Wrong `haveMoreData` is a different bug.
- After release, a unit/widget test or obvious scroll-notification loop
  would fire `_loadPrevious` **without** cooldown (burst). Do not retune
  constants; STOP and report the stack.
- `bypassTopReachConsumed: true` would be the only way to pass the
  scroll listener — that is the wrong lever; STOP.
- You need to edit files outside Scope.

## Maintenance notes

- Reviewers: confirm empty-batch still latches; confirm no auto-chain
  from `finally`; confirm inverted-list comments stay correct
  (top = `maxScrollExtent`).
- If users still report "must bounce" **and** logs show
  `schedule_previous_no_more` / `haveMoreData: false`, that is pagination
  model / SDK finished — file a follow-up, do not weaken this latch again.
- If iOS rubber-band starts loading 3+ pages per flick, the follow-up is
  to keep latch until `ScrollEnd` then release once — not to restore the
  320px mandatory leave.
- Search-jump (025–026) and short-viewport fill stay independent.
- Chat-open warm window (20) is unrelated; do not raise fetch count here.
