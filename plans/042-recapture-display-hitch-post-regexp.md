# Plan 042: Recapture Display hitch after RegExp cut (measurement gate)

> **Executor instructions**: This is a **measurement / evidence** plan, not a
> feature change. Do not edit product Dart except optional logging already
> allowed by plan 032/033. Update `plans/README.md` when the capture package
> is checked in under `docs/`.
>
> **Drift check**: Confirm 037/038 are DONE in `plans/README.md`. Confirm
> `docs/pro-scenario.md` still holds the post-037 Probe (`msgId.c2cWireIdentity`
> gone). Confirm Instruments / Time Profiler workflow from
> `plans/032-recapture-hitch-with-stacks.md` still applies.

## Status

- **Priority**: P0 (gates whether more code plans are worth it)
- **Effort**: S–M (operator + device time)
- **Risk**: LOW (docs only)
- **Depends on**: 037 DONE; **prefer** 039–041 landed first if the operator
  will implement them in the same week — otherwise capture **now** as a
  baseline “RegExp-done, IO/DB not yet deferred”
- **Category**: perf / measurement
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Status**: TODO

## Why this matters

037 removed ~18ms `msgId.c2cWireIdentity` from list→chat. Subjective hitch
may remain from:

- Sqflite foreground race / DB reopen (~1.5s `RunTask` in log — often off
  Dart isolate but still user-visible)
- Wallet order-card GETs on open
- Remaining `call_bubble.normalize` ~1ms
- Layout / image decode / Impeller (unknown without stacks)

Without a **fresh Display + Time Profiler** capture, further code plans are
guesswork. This plan produces the evidence package that either:

- Points at a new concrete Dart/native hotspot → new plan 043+, or
- Shows hitch gone / below threshold → stop lossless open-path work.

## Current state

- Scenario log: `docs/pro-scenario.md` (Probe + SqfliteClosed + red-packet GET)
- Older Display-only notes: `docs/pro-display-2026-08-22.md` / `docs/pro.md`
  — treat as stale for **post-037** conclusions
- Capture playbook: `plans/032-recapture-hitch-with-stacks.md`

## Commands / operator steps

Mostly device + Instruments. Repo commands:

| Purpose | Command | Expected |
|---------|---------|----------|
| Optional Probe unit sanity | `flutter test test/regexp_probe_test.dart` | Pass if file exists |

## Scope

**In scope**

- New evidence file(s) under `docs/` e.g.
  `docs/pro-scenario-post-037.md` or a clearly dated section in
  `docs/pro-scenario.md`
- Time Profiler / Display hitch screenshot or exported sample names
- `plans/README.md` status + “next plan” note

**Out of scope**

- Implementing 039–041 inside this plan
- Blaming message-menu `toImage` / blur (wrong scenario)
- Reverting 027–038

## Locked decisions

| Decision | Value |
|----------|--------|
| Scenario | **Scroll conversation list → enter chat** (same as 032/033) — not message long-press menu |
| Build | Profile (or release-equivalent with Probe if that is how 033 ships) |
| Required artifacts | (1) RegExpProbe dumps on open (2) console slice including Sqflite/red-packet if present (3) Time Profiler top stacks during the hitch window |
| Success threshold | Document hitch duration; if Display hitch &lt; 100ms and no Dart Main &gt; 4ms in window, recommend **stop** further lossless open-path plans |

## Steps

### Step 1: Choose baseline label

In the evidence doc header write:

- Build id / date
- Whether 039/040/041 were already merged (`yes/no` each)

### Step 2: Capture

Follow `plans/032-recapture-hitch-with-stacks.md` for list→chat.
Paste Probe dumps + profiler stack summary into `docs/…`.

### Step 3: Verdict

End the doc with one of:

1. **Hitch gone / acceptable** → no new code plan; mark 042 DONE.
2. **Dart hotspot named** → draft finding for plan 043 (do not implement here).
3. **Native/DB only** → keep 039 as primary; avoid more RegExp plans.

## Done when

- [ ] Dated evidence doc under `docs/`
- [ ] Verdict section filled
- [ ] `plans/README.md` row 042 → DONE (+ pointer to next plan or STOP)

## STOP conditions

- Operator cannot run Instruments this session → leave 042 TODO; do not fake
  stacks
- Capture is menu-open scenario by mistake → discard; re-capture

## Out of scope reminder

No product code changes in this plan.
