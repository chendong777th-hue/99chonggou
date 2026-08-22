# Plan 034: Stagger DeferredHyperlinkText enrich after chat open

> **Executor instructions**: Follow step by step. Verify each gate. STOP on
> drift. Update `plans/README.md` when done.
>
> **Drift check**: Read
> `third_party/tencent_cloud_chat_uikit/lib/ui/utils/deferred_hyperlink_text.dart`
> — today every instance schedules its own `addPostFrameCallback` that
> `setState`s enrich on the **same** next frame.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED (links/mentions appear over a few frames instead of all at once)
- **Depends on**: none (pairs with 033 for measurement)
- **Category**: perf
- **Status**: DONE (2026-08-22) — `HyperlinkEnrichScheduler` max 2/frame;
  `DeferredHyperlinkText` queued; tests green.

Plan 008 defers enrich off the **first** frame, but N visible text bubbles all
upgrade on frame 2 → RegExp storm (matches `docs/pro.md` Main RegExp + open
chat scenario). Cap how many enrichments run per frame.

## Locked decisions

| Decision | Value |
|----------|--------|
| First frame | stays plain (no `buildEnriched`) |
| Budget | default **2** enrichments per frame (named const, testable) |
| Fairness | FIFO queue across bubbles |
| Cancel | disposed / identity change must not enrich |
| Visual | links may pop in over ~N/2 frames — acceptable |

## Scope

- New scheduler helper under `ui/utils/` (e.g. `hyperlink_enrich_scheduler.dart`)
- `deferred_hyperlink_text.dart` — use scheduler instead of raw post-frame
- Tests: existing defer test + new stagger test
- `plans/README.md`

**Out of scope**: urlReg rewrite, conversation list preview, menu toImage.

## Steps

1. Add singleton scheduler: `schedule(void Function() job)`, processes ≤
   `maxPerFrame` per frame via chained post-frame callbacks.
2. Wire `DeferredHyperlinkText` to enqueue enrich `setState`.
3. Tests: two widgets → after one `pump`, at most `maxPerFrame` ready;
   after enough pumps, all ready.
4. `flutter test` on defer + new tests; `dart analyze` on touched files.

## Done

- [ ] No same-frame stampede of all enriches
- [ ] First frame still zero LinkText parse misses for new text
- [ ] Tests green
