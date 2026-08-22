# Plan 032: Recapture Display hitches with Time Profiler + scenario log

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> any STOP condition is hit, stop and report — do not improvise. When done,
> update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Confirm
> `docs/pro.md` still exists and still lacks Dart/CPU stacks (see Current
> state). If a newer capture **already** contains `dart::` / `Interpret` /
> Time Profiler stacks, STOP and report — this plan may already be satisfied;
> do not overwrite without operator confirmation.

## Status

- **Priority**: P0
- **Effort**: S–M (operator capture time dominates; writing playbook is S)
- **Risk**: LOW (docs / process only; no product code)
- **Depends on**: none (blocks future code plans that would target
  `docs/pro.md` Display-only hitches)
- **Category**: perf / dx / docs
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Issue**: omit
- **Status**: DONE (2026-08-22) — new `docs/pro.md` (~68k lines) includes
  CPU samples with `dart::` / `flutter::`; scenario notes in
  `docs/pro-scenario.md`. Gesture script still operator-unknown; stacks are
  mostly VM RegExp + unsymbolicated frames.
hitches to `Runner` with reason **「Potentially expensive app update(s)」**.
Parsed facts from that file:

- ~50 hitch rows; sum ≈ **925 ms**; **≥33 ms = 5**; **≥50 ms = 4**; max
  **150.03 ms** at `00:30.885.595`
- Heavy cluster ~**1.6s–11s** (sum ≈475 ms, peaks 75/83 ms)
- Late peak ~**30.9s** (150 ms) aligned with a ~158 ms surface gap
- Surface rows can show **100–500+ ms** gaps; Runner-tagged rows often show a
  second duration ≈**28–34 ms** (frame commit) — long gaps are **not** proof of
  continuous Main work
- The file contains **zero** of: `dart::`, `Interpret`, `RegExp`, `toImage`,
  `Time Profiler`, `Main Thread` heaviest stacks

Without stacks, any code change “to fix this pro.md” is a guess and can undo
plans **017–031**. This plan produces a **stack-bearing** capture + a
**scenario log** so a later `/improve` can write real code plans.

## Product / process decisions (locked)

| Decision | Value |
|----------|--------|
| Touch Flutter / UIKit / `lib/src` product code | **No** — this plan is docs + capture artifacts only |
| Overwrite `docs/pro.md` | **Yes, only after** the new export includes CPU/Dart stacks (or keep Display export as `docs/pro-display-YYYYMMDD.md` and write stacks to `docs/pro.md`) |
| Minimum stack signal | New primary artifact must contain at least one of: `dart::`, `Interpret`, `#[0x` Flutter frame names, or an exported **Time Profiler** heaviest-stack text with Runner symbols |
| Scenario log | Required; must label what the operator did in windows matching hitch clusters A (~0–11s) and D (~27–31s) |
| Profile build | Use a **profile** (or release-equivalent) build — not debug — for Instruments |
| Existing app logs | Capture `[ChatOpenPerf]` lines from `lib/src/services/chat_open_perf_log.dart` in the same session if opening chat |

## Current state

### Display-only hitch file

`docs/pro.md` begins with hitch rows like:

```text
00:01.605.664	25.00 ms	Runner (36958)	Display 1	0x104d488	Potentially expensive app update(s)
…
00:30.885.595	150.03 ms	Runner (36958)	Display 1	0x104de2a	Potentially expensive app update(s)
```

Then continues with `Display 1	…	Surface …` rows. No CPU call trees.

### Existing remesure note (too thin)

`plans/README.md` 「Remeasure gate」(~209–214) only mentions RegExpProbe +
Display Hitch + Time Profiler in three bullets — no scenario template, no
acceptance checks for stack presence, no cluster windows from this capture.

### In-app open timing log (use during capture)

`lib/src/services/chat_open_perf_log.dart` — filter keyword `[ChatOpenPerf]`.
Do **not** modify this file; only collect logs while reproducing.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Prove current pro.md has no stacks | `rg -n "dart::|Interpret|Time Profiler|RegExpProbe" docs/pro.md \|\| true` | No matches (or only false positives you document) |
| Prove playbook exists | `test -f docs/perf-hitch-capture.md && rg -n "^## " docs/perf-hitch-capture.md` | File exists; headings listed |
| Prove scenario log exists | `test -f docs/pro-scenario.md && rg -n "Cluster A|Cluster D|ChatOpenPerf" docs/pro-scenario.md` | File exists; required sections present |
| Prove new capture has stacks | `rg -n "dart::|Interpret|Heaviest Stack|Time Profiler" docs/pro.md docs/pro-time-profiler.md 2>/dev/null \| head` | ≥1 real stack/symbol hit in the **new** artifact |
| Optional: contract test | `flutter test test/perf_hitch_capture_docs_contract_test.dart` | Pass (if Step 4 adds it) |

## Scope

**In scope**:

- `docs/perf-hitch-capture.md` (create) — capture playbook
- `docs/pro-scenario.md` (create) — filled scenario + cluster labels for the
  session that produced the new profile
- `docs/pro.md` and/or `docs/pro-time-profiler.md` / `docs/pro-display-*.md`
  — archive old Display-only export; install stack-bearing export
- `plans/README.md` — expand Remeasure gate; status row **032**
- Optional: `test/perf_hitch_capture_docs_contract_test.dart` — string checks
  that playbook + scenario templates contain required headings (not that
  Instruments was run on CI)

**Out of scope**:

- Any change under `lib/`, `third_party/tencent_cloud_chat_uikit/`, iOS/Android
  native product code
- New feature work, menu/chat open “optimizations” without stacks
- Re-opening plans 017–031 as regressions without stack proof
- `git init`

## Git workflow

- No `.git` historically — do not `git init`.
- If git exists: branch `advisor/032-perf-hitch-recapture`, commit
  `docs(perf): hitch capture playbook + stack-bearing pro artifacts`.

## Steps

### Step 1: Archive the Display-only export

Copy current `docs/pro.md` to a dated archive, e.g.

```bash
cp docs/pro.md docs/pro-display-2026-08-22.md
```

Do not delete the archive. Leave `docs/pro.md` in place until Step 3 replaces
or supplements it.

**Verify**: `test -f docs/pro-display-2026-08-22.md` → exit 0.

### Step 2: Write the capture playbook

Create `docs/perf-hitch-capture.md` with at least these sections (Chinese or
English OK; keep headings stable for the contract test):

1. `## Goal` — stack-bearing capture for Display hitch clusters
2. `## Build` — profile/release Runner; how to attach Instruments
3. `## Instruments template` — must include **both**:
   - Display / Hitch (or Animation Hitches)
   - **Time Profiler** (sample Main / Runner; record call stacks)
4. `## Optional Flutter Timeline` — `flutter run --profile` + DevTools CPU/Timeline
   for the same gesture window
5. `## Scenario scripts` — at least two scripts the operator can pick:
   - **Script OpenChat**: cold-ish home → tap one heavy conversation (prefer
     image-heavy if available) → wait settle → scroll a bit → back
   - **Script MenuOrMedia**: in an open chat, long-press a message **or** open
     fullscreen image (pick one; record which)
6. `## Cluster windows to annotate` — paste these from the 2026-08-22 Display
   capture so operators align narrative to time:
   - Cluster A ≈ `00:01.6`–`00:11` (heavy)
   - Cluster D ≈ `00:27`–`00:31` (includes 150 ms hitch)
7. `## Export checklist` — before replacing `docs/pro.md`:
   - [ ] Time Profiler heaviest stacks exported as text
   - [ ] At least one Dart/Flutter symbol visible (`dart::` or `Interpret` or
     named Dart frames)
   - [ ] Display hitch table still exported (can be second file)
   - [ ] `docs/pro-scenario.md` filled same session
   - [ ] `[ChatOpenPerf]` log excerpt attached if Script OpenChat was used
8. `## Do not` — do not file code plans from Display-only exports; do not
   restore live `BackdropFilter` σ=22 “to fix hitches”

**Verify**:

```bash
rg -n "^## (Goal|Build|Instruments template|Scenario scripts|Export checklist)" \
  docs/perf-hitch-capture.md
```

→ all headings present.

### Step 3: Operator capture + scenario log

**This step is performed by a human with a device + Instruments** (or an
executor who has that environment). If the executor cannot run Instruments,
they must:

1. Still complete Steps 1–2 and Step 4 template for `docs/pro-scenario.md`
2. Mark plan status **BLOCKED (awaiting device Time Profiler capture)** in
   `plans/README.md`
3. STOP — do not invent stacks

When capture is possible:

1. Run one scenario script from the playbook (prefer **OpenChat** first to
   explain Cluster A).
2. Export Time Profiler heaviest stacks to `docs/pro-time-profiler.md` (or
   merge into `docs/pro.md` with a clear `## Time Profiler` heading).
3. Export Display hitch table to `docs/pro-display-latest.md` or replace the
   hitch section in `docs/pro.md`.
4. Fill `docs/pro-scenario.md` using this skeleton:

```markdown
# pro.md scenario log

- Date:
- Build: profile / release (circle one)
- Device / iOS:
- Script used: OpenChat / MenuOrMedia / other:
- Conversation type: C2C / group; image-heavy?: yes/no

## Cluster A (~1.6s–11s)
What I did:
ChatOpenPerf excerpt (paste):

## Cluster D (~27s–31s)
What I did:

## Top Time Profiler symbols (copy 5–15 lines)
```

**Verify** (when not BLOCKED):

```bash
rg -n "dart::|Interpret|Heaviest|Time Profiler" docs/pro.md docs/pro-time-profiler.md | head -20
```

→ at least one hit. And `docs/pro-scenario.md` has non-empty Cluster A/D notes.

### Step 4 (optional): Docs contract test

Add `test/perf_hitch_capture_docs_contract_test.dart` that reads
`docs/perf-hitch-capture.md` as text and asserts required `##` headings from
Step 2 exist. Do **not** require Instruments output on CI.

**Verify**: `flutter test test/perf_hitch_capture_docs_contract_test.dart` → pass.

### Step 5: Update index + mark status

Update `plans/README.md`:

- Row **032** → `DONE` if stacks + scenario landed; else `BLOCKED (…)`
- Expand 「Remeasure gate」to point at `docs/perf-hitch-capture.md` and require
  stack presence before new hitch code plans

**Verify**: README row matches reality; no `lib/` / UIKit diffs.

## Test plan

- Optional contract test in Step 4 (docs headings only).
- No widget/unit tests of chat behavior — out of scope.
- Human acceptance: a second engineer can follow
  `docs/perf-hitch-capture.md` and produce a stack-bearing export without
  reading this plan.

## Done criteria

- [ ] `docs/pro-display-2026-08-22.md` (or equivalent dated archive) exists
- [ ] `docs/perf-hitch-capture.md` exists with required sections
- [ ] Either:
  - **DONE path**: `docs/pro-time-profiler.md` and/or updated `docs/pro.md`
    contains Dart/CPU stack symbols; `docs/pro-scenario.md` filled for
    Clusters A & D; README 032 = DONE
  - **BLOCKED path**: playbook + empty scenario template committed; README
    032 = `BLOCKED (awaiting device Time Profiler capture)`; **no** fake stacks
- [ ] No product code files modified
- [ ] `plans/README.md` Remeasure gate points at the playbook

## STOP conditions

- Temptation to “optimize chat open” or menu `toImage` again **without** new
  stacks — STOP; file a new plan only after 032 DONE path.
- Instruments unavailable and someone asks to mark DONE anyway — use BLOCKED,
  not DONE.
- New export still Display-only with no stacks — do not replace the archive’s
  role as “known incomplete”; keep playbook; status BLOCKED or TODO.
- Any change to `third_party/...` or `lib/src/chat.dart` appears necessary —
  wrong plan; STOP.

## Maintenance notes

- After 032 DONE, run `/how` + `/improve` on the **new** stack file; expect
  code plans 033+ only then.
- Keep Display hitch exports — they remain useful for *when* frames missed;
  Time Profiler answers *what* ran.
- `[ChatOpenPerf]` is complementary wall-clock, not a substitute for CPU stacks.
