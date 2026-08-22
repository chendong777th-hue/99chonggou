# Plan 038: Lossless trim of `call_bubble.normalize` (secondary)

> **Executor instructions**: Follow step by step. Verify each gate. STOP on
> drift. Update `plans/README.md` when done.
>
> **Drift check**: Confirm `RegExpProbe.measure('call_bubble.normalize', …)`
> exists in `lib/src/utils/call_bubble_dedupe.dart`. Prefer **037 DONE** first;
> if a fresh Probe dump shows this site ≪ 0.5ms, mark this plan **REJECTED**
> (not worth it) instead of editing.

## Status

- **Priority**: P1
- **Effort**: S–M
- **Risk**: LOW–MED (call-bubble dedupe correctness)
- **Depends on**: 037 (soft — measure after; drafting in parallel OK)
- **Category**: perf
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Status**: DONE (2026-08-22) — no per-call RegExp in normalize (already
  none); gated hot-path `debugPrint` with `kDebugMode` so Profile/Release
  skip logging cost (~1.6ms site was mostly meta+prints). Also landed
  TextPainter skip/cache in `chat_message_height_cache.dart` for QoS text
  hitch (related open-path work).

## Why this matters

Same `docs/pro-scenario.md` dump:

| site | calls | us |
|------|------:|---:|
| `msgId.c2cWireIdentity` | 21596 | 18572 |
| `call_bubble.normalize` | 29 | **1660** |
| `msgId.isLikelySdk` | 1709 | 89 |
| `link.LinkText.scan` | 21 | 61 |

After 037, this is the next named cost on list→chat (~1–2ms). Small lossless
pass only — no redesign.

## Current state

- Wrapper (~303): `lib/src/utils/call_bubble_dedupe.dart`

```dart
return RegExpProbe.measure('call_bubble.normalize', () {
  // normalize body
});
```

- Related key helper may live in `lib/src/utils/call_bubble_dedupe_key.dart`.
- Tests: `test/call_bubble_dedupe_key_test.dart`,
  `test/call_bubble_display_test.dart`,
  `test/call_bubble_meta_alloc_test.dart`.

**Before editing**: inventory every `RegExp(` / `.hasMatch` / `.firstMatch`
inside the measure callback (and callees it always hits). Paste that inventory
in the commit message.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Call-bubble suite | `flutter test test/call_bubble_dedupe_key_test.dart test/call_bubble_display_test.dart test/call_bubble_meta_alloc_test.dart` | All pass |
| Ordering sanity | `flutter test test/message_ordering_test.dart` | All pass |

## Scope

**In scope**

- `lib/src/utils/call_bubble_dedupe.dart`
- `lib/src/utils/call_bubble_dedupe_key.dart` only if RegExp lives there
- Existing `test/call_bubble_*.dart` as needed
- `plans/README.md`

**Out of scope**

- Insert service / Chat.dart jitter logs / UI bubbles
- Changing which messages count as call bubbles
- Plan 037 model file (avoid new cross-package helpers)

## Locked decisions

| Decision | Value |
|----------|--------|
| Approach | (1) `static final` any per-call `RegExp`; (2) string checks only when equivalence is obvious + tested |
| Probe name | Keep `call_bubble.normalize` |
| Skip work | Only when existing preconditions already make a branch dead (same idea as 037 early-out) |

## Steps

### Step 1: Inventory + reject gate

If post-037 Probe shows `call_bubble.normalize` us &lt; ~500, set README status
**REJECTED** (not worth it) and stop.

Else list RegExp usages under the measure callback.

### Step 2: Smallest lossless edit

Apply in order; stop when clean or tests fail:

1. Per-call `RegExp(...)` → `static final` (identical pattern string).
2. Obvious `hasMatch` → `contains` / `startsWith` / digit scan with new tests.
3. Do **not** redesign dedupe keys.

**Verify**: call-bubble suite command above — all pass.

### Step 3: Index

Mark 038 DONE (or REJECTED) in `plans/README.md`.

## Done criteria

- [ ] No per-call `RegExp(` in normalize probe path **or** REJECTED with reason
- [ ] Call-bubble tests pass; ordering test still passes
- [ ] README row updated

## STOP conditions

- Probe site missing/renamed — STOP.
- String rewrite equivalence unclear — keep RegExp; only staticize.
- Tests fail — revert rewrite; do not expand into insert service.

## Maintenance notes

- Re-measure after 037 before investing here.
- Reviewers: confirm normalize keep/drop cases in
  `call_bubble_display_test.dart` unchanged.
