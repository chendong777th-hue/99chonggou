# Plan 036: Fix Frame.onReportTimings stack overflow (profile)

> **Executor**: Follow steps. STOP on drift. Update `plans/README.md` when done.
>
> **Drift check**: `third_party/tencent_cloud_chat_uikit/lib/ui/utils/frame.dart`
> still does `orginalCallback = window.onReportTimings` then assigns
> `window.onReportTimings = onReportTimings` with no install guard; `destroy`
> sets the callback to `null`.

## Status

- **Priority**: P0
- **Effort**: S
- **Risk**: LOW
- **Depends on**: none
- **Category**: perf / crash
- **Planned at**: 2026-08-22 (NO_GIT)
- **Status**: DONE (2026-08-22) — idempotent refcounted install; restore on
  destroy; per-frame fps log off; `frame_timings_test` green.

## Why

`docs/pro-scenario.md` device log shows repeated **Stack Overflow** in
`Frame.onReportTimings` (~13k frames). Profile chat open calls `Frame.init()`;
a second install chains `orginalCallback` to itself. Every vsync then
recurses via `List.addAll` — swamps hitch measurement and can crash.

## Locked decisions

| Decision | Value |
|----------|--------|
| Install | idempotent + refcount (nested chat ok) |
| Chain | never call self; skip if `identical(prev, onReportTimings)` |
| destroy | restore previous callback; clear only when refcount hits 0 |
| Per-frame `outputLogger.i("fps:…")` | **remove** (or sample ≥60 frames, default off) |
| Release path | still gated by `kProfileMode` at call sites |

## Scope

- `third_party/tencent_cloud_chat_uikit/lib/ui/utils/frame.dart`
- unit/widget test for double-init no recursion
- `plans/README.md`

## Done

- [x] Double `init` does not recurse
- [x] `destroy` restores prior callback
- [x] No per-frame fps log (default `fpsLogEveryNFrames = 0`)
- [x] Tests green (`third_party/.../test/frame_timings_test.dart`)
