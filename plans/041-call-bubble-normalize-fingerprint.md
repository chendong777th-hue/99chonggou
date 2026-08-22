# Plan 041: Skip redundant `call_bubble.normalize` when list fingerprint matches

> **Executor instructions**: Follow step by step. Verify each gate. STOP on
> drift. Update `plans/README.md` when done.
>
> **Drift check**: Confirm
> `CallBubbleDedupe.normalizeCallHistoryMessages` still wraps work in
> `RegExpProbe.measure('call_bubble.normalize', …)` in
> `lib/src/utils/call_bubble_dedupe.dart`, and per-message `_metaFor` /
> `_metaCache` already exist. Confirm post-037 `docs/pro-scenario.md` still
> shows first-open `call_bubble.normalize: calls≈17 us≈1148` with later dumps
> much smaller.

## Status

- **Priority**: P1
- **Effort**: S–M
- **Risk**: MED (dedupe correctness — wrong fingerprint → stale drop/keep)
- **Depends on**: 038 DONE (RegExp/print trim already landed; remaining cost
  is JSON/meta for call-like rows)
- **Category**: perf
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Status**: DONE (2026-08-22) — list fingerprint cache on
  `normalizeCallHistoryMessages`; clears with meta cache; fingerprint unit
  test in `call_bubble_meta_alloc_test.dart` green.

## Why this matters

After 037/038, Probe on list→chat (`docs/pro-scenario.md`):

| dump | call_bubble.normalize |
|------|------------------------|
| first history land | ~17 calls / ~1.15ms |
| later dumps | ~1–3 calls / ≪0.2ms |

038 removed RegExp/print waste. Remaining ~1ms is real
`CallingMessageDataProvider` / JSON work for call-like messages. Chat open
often runs normalize **more than once** on the same window (merge / tip /
dedupe schedule). Per-message `_metaCache` helps within a pass; it does
**not** skip a full second normalize of an identical list.

Lossless goal: if the input list identity is unchanged since the last
successful normalize for that conversation, return the previous output
without rebuilding metas again.

## Current state

**File**: `lib/src/utils/call_bubble_dedupe.dart`

```dart
static List<V2TimMessage> normalizeCallHistoryMessages(
  List<V2TimMessage> messages, {
  bool preserveTipIdentity = false,
}) {
  return RegExpProbe.measure('call_bubble.normalize', () {
    // walks messages via _metaFor → _buildMeta → CallingMessageDataProvider
    ...
  });
}
```

Callers (inventory; do not miss any):

- `lib/src/chat.dart` — `_normalizeCallHistoryMessages` / open merge paths
- In-file schedule/dedupe helpers that call `normalizeCallHistoryMessages`
- Tests: `test/call_bubble_meta_alloc_test.dart`, `test/call_bubble_display_test.dart`

`_metaFor` already caches by message key; fingerprint cache is **list-level**.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Call-bubble suite | `flutter test test/call_bubble_meta_alloc_test.dart test/call_bubble_display_test.dart test/call_bubble_dedupe_key_test.dart` | All pass (skip missing files) |
| Analyze | `dart analyze lib/src/utils/call_bubble_dedupe.dart` | No new errors |

## Scope

**In scope**

- `lib/src/utils/call_bubble_dedupe.dart`
- Existing call_bubble tests (+ fingerprint unit tests)
- `plans/README.md`

**Out of scope**

- Changing which signals display / dedupe keys
- Isolates / rewriting `CallingMessageDataProvider`
- Chat.dart jitter logs / UI
- Touching `msgId.isLikelySdk` (rejected — ≪0.1ms)

## Locked decisions

| Decision | Value |
|----------|--------|
| Fingerprint | Stable, cheap: `messages.length` + first/last `msgID` + mid sample + sum of `msgID.hashCode`. Include `preserveTipIdentity` in the cache key |
| Conversation scope | One entry per conversationId when known; else fingerprint-only with max 1–2 global slots |
| Invalidation | Different fingerprint replaces cache. Every `_metaCache.clear` site must also clear fingerprint cache |
| Probe | Prefer early return **before** `RegExpProbe.measure` on hit so dumps show fewer calls |
| Safety | If tip identity matters, include tip `msgID` / localCustomData length when `preserveTipIdentity` is true |

## Steps

### Step 1: Inventory callers + clear sites

Find all `normalizeCallHistoryMessages` call sites and all `_metaCache.clear`
sites. Fingerprint cache clears with meta cache.

### Step 2: Implement fingerprint short-circuit

```dart
static List<V2TimMessage> normalizeCallHistoryMessages(...) {
  final fp = _listFingerprint(messages, preserveTipIdentity: ...);
  final hit = _normalizeCache[convKey];
  if (hit != null && hit.fingerprint == fp) {
    return hit.output;
  }
  final out = RegExpProbe.measure('call_bubble.normalize', () { ... });
  _normalizeCache[convKey] = _NormalizeCacheEntry(fp, out);
  return out;
}
```

Match existing growable/mutation expectations of callers.

**Verify**: `dart analyze` clean.

### Step 3: Tests

1. Same list twice → second call does not increment
   `CallBubbleDedupe.debugJsonDecodeCount` (or equivalent).
2. Change one `msgID` → second call decodes again.
3. Existing display/dedupe tests stay green.

### Step 4: Scenario gate

Fresh list→chat Probe: subsequent dumps in the same open should show
`call_bubble.normalize` near 0. If only one normalize per open remains,
document limited benefit in Status.

## Done when

- [ ] Fingerprint short-circuit landed + cleared with meta cache
- [ ] Tests prove second identical normalize skips JSON work
- [ ] Display/dedupe tests green
- [ ] `plans/README.md` row 041 → DONE

## STOP conditions

- Fingerprint would require hashing full `customElem.data` for every row → STOP
- Callers mutate returned lists and require identity with input → STOP/report
- Post-change Probe shows no reduction on multi-dump opens → REJECTED

## Out of scope reminder

Do not rewrite provider JSON parsing; that is a different risk class.
