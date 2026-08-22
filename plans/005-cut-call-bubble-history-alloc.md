# Plan 005: Cut redundant JSON decode / alloc on call-bubble history path

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt below to the live files. If `_buildMeta` no
> longer calls both `CallingMessageDataProvider` and
> `hangupDurationSecFromRaw`/`extractRoomIdFromRaw` on the same message, the
> primary finding may already be fixed — STOP and report before rewriting.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: none (003/004 are orthogonal RegExp work; already DONE)
- **Category**: perf
- **Planned at**: working tree 2026-08-20 (no git SHA available)
- **Execution**: DONE (2026-08-20) — provider getters + `_buildMeta` /
  `_parseLocalBubble` decode reuse; `call_bubble_*` + meta_alloc tests green.

## Why this matters

Instruments `docs/pro.md` showed **DartWorker** ~26% of samples, dominated by
concurrent GC (Marking / Sweep). That is allocation pressure, not "GC is
slow by itself."

On chat open / history load, logs show
`[CHAT_JITTER] event=call_bubble_normalize`. That path runs
`CallBubbleDedupe.normalizeCallHistoryMessages` then
`TUIChatGlobalModel.dedupeMessages`. For each call-looking message,
`_buildMeta` already constructs `CallingMessageDataProvider` (which
`jsonDecode`s custom payload into `_jsonData` and derives duration/room),
then **decodes the same strings again** via `hangupDurationSecFromRaw` +
`extractRoomIdFromRaw` (and nested `jsonDecode` inside `_readDuration` /
`_readRoomId`). Local bubbles decode `localCustomData` once, then may
decode again for duration/room fallbacks.

This plan removes that redundant decode / map churn on the call-bubble
meta build path. Goal: same normalize/dedupe **behavior**, fewer
`jsonDecode` and temporary `Map`s per message → less young-gen GC during
history open spikes.

## Current state

### Hot path (chat history)

`lib/src/chat.dart` `didGetHistoricalMessageList` (~7967+):

```dart
final normalized = CallBubbleDedupe.normalizeCallHistoryMessages(
  messageList,
  preserveTipIdentity: true,
);
final deduped = TUIChatGlobalModel.dedupeMessages(normalized);
```

Same pattern: `CallBubbleDedupe.prepareOpenHistoryMessages`,
`_normalizeCallHistoryMessages` elsewhere in `chat.dart`.

### Redundant decode in `_buildMeta`

File: `lib/src/utils/call_bubble_dedupe.dart`

`_metaFor` caches `_CallMsgMeta` by msgID (good). On miss, `_buildMeta`:

```490:506:lib/src/utils/call_bubble_dedupe.dart
  static _CallMsgMeta _buildMeta(V2TimMessage message) {
    final local = _parseLocalBubble(message);
    ...
    final provider = CallingMessageDataProvider(message);
    ...
    final duration = hangupDurationSecFromRaw(message);
    final roomId = extractRoomIdFromRaw(message);
```

`CallingMessageDataProvider` already parses JSON into `_jsonData` and has
private `_hangupDurationSec()` / `_extractRoomId()` used by
`callStableKey` / `callNearDuplicateKey`
(`lib/utils/custom_message/calling_message/calling_message_data_provider.dart`
~156–237, ~179–220).

Meanwhile `hangupDurationSecFromRaw` / `extractRoomIdFromRaw` (~643–686)
loop customElem / localCustomData / cloudCustomData and `jsonDecode` each
candidate, then `_readDuration` / `_readRoomId` may `jsonDecode` nested
`data` strings again.

### Local bubble path

`_parseLocalBubble` (~575+) `jsonDecode`s `localCustomData`, then if
duration ≤ 0 calls `hangupDurationSecFromRaw(message)` / may call
`extractRoomIdFromRaw` — second pass over the same or sibling blobs.

### Existing meta cache (keep; only touch eviction if cheap)

```461:477:lib/src/utils/call_bubble_dedupe.dart
  static _CallMsgMeta _metaFor(V2TimMessage message) {
    ...
    if (_metaCache.length >= _maxMetaCache) {
      final keys = _metaCache.keys.take(_maxMetaCache ~/ 2).toList();
      ...
    }
```

### Tests to treat as behavioral gate

- `test/call_bubble_display_test.dart` — group
  `CallBubbleDedupe.normalizeCallHistoryMessages` (invite/hangup collapse,
  prefer IM over local, open-hold)
- `test/call_bubble_dedupe_key_test.dart` — key shape only
- `test/call_bubble_insert_service_test.dart` — insert path; run if
  touched behavior might interact

### Product boundary

Do **not** change: which call rows appear in history, preference between
local vs IM hangup, open-hold deferral, LiveKit/CallKit, wallet, conversation
list Feed, or `TUIChatGlobalModel.dedupeMessages` algorithm.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Normalize behavior | `flutter test test/call_bubble_display_test.dart` | all pass |
| Key helpers | `flutter test test/call_bubble_dedupe_key_test.dart` | all pass |
| Insert smoke | `flutter test test/call_bubble_insert_service_test.dart` | all pass |
| New decode-count test | `flutter test test/call_bubble_meta_alloc_test.dart` | all pass |

No `.git` — do not `git init`.

## Scope

**In scope**:

- `lib/src/utils/call_bubble_dedupe.dart`
- `lib/utils/custom_message/calling_message/calling_message_data_provider.dart`
  — **only** add thin public getters that expose existing private
  duration/room helpers (no protocol logic changes)
- `test/call_bubble_meta_alloc_test.dart` (create)
- Optionally extend `test/call_bubble_display_test.dart` if easier than a
  new file — prefer new file to keep display tests readable

**Out of scope**:

- Rewriting `TUIChatGlobalModel.dedupeMessages` / msgID RegExp (003/004)
- Moving normalize to an isolate
- Changing `_maxMetaCache` policy beyond a tiny eviction alloc tweak
- Link-preview / text RegExp allocation
- Editing `docs/pro.md`

## Suggested approach (do this, not a broader rewrite)

### A — Prefer provider fields in `_buildMeta` (primary)

1. On `CallingMessageDataProvider`, add public getters that delegate only:

```dart
int get hangupDurationSec => _hangupDurationSec();
String get roomId => _extractRoomId();
```

Name them to match existing style; if `roomId` collides with another
member, use `callRoomId` instead — grep the class first.

2. In `_buildMeta`, after `final provider = CallingMessageDataProvider(message)`:

```dart
final duration = provider.hangupDurationSec; // or whatever name
final roomId = provider.callRoomId;
```

**Delete** the `hangupDurationSecFromRaw(message)` /
`extractRoomIdFromRaw(message)` calls from this function only.

3. Keep using `provider.callStableKey` / `inviteID` / `conversationID` as
   today. Fallback key logic that uses `duration` / `roomId` locals must
   keep the same string results as before for the same payloads.

### B — Single decode in `_parseLocalBubble` (secondary)

1. After successful `jsonDecode` into `decoded` Map, read duration/room
   via `_readDuration(decoded)` / `_readRoomId(decoded)` first.
2. Only if still missing, call raw helpers **or** (better) decode
   `customElem?.data` **once** into a Map and read from that — do not call
   both `hangupDurationSecFromRaw` and `extractRoomIdFromRaw` in a way that
   each re-decodes the same string.

### C — Optional: decode counter for tests

Add a tiny `@visibleForTesting` counter on `CallBubbleDedupe`:

```dart
static int debugJsonDecodeCount = 0;
```

Increment it in a single private `_tryDecodeMap(String raw)` used by
`hangupDurationSecFromRaw`, `extractRoomIdFromRaw`, `_parseLocalBubble`,
and nested `_readDuration` / `_readRoomId` string branches. Production
cost: one int++ per decode when you route all decodes through the helper.

If routing every decode is too invasive, increment only in the raw helpers
+ `_parseLocalBubble` and document that provider-internal decodes are
outside the counter — then the alloc test asserts **CallBubbleDedupe-side**
decode count dropped for `_buildMeta` path (may be 0 after step A).

### D — Optional micro: meta cache eviction without `toList()`

Replace half-eviction `keys.take(...).toList()` with clearing the whole
cache when over max, or remove while iterating keys without copying.
**Only if** Step A/B are done and tests green. Do not change `_maxMetaCache`
value.

## Steps

### Step 1: Expose provider duration / room getters

Edit `calling_message_data_provider.dart` — add getters only.

**Verify**: `dart analyze lib/utils/custom_message/calling_message/calling_message_data_provider.dart`
→ no issues (or project-equivalent)

### Step 2: Wire `_buildMeta` to provider; remove duplicate raw calls

Edit `_buildMeta` in `call_bubble_dedupe.dart` as in approach A.

**Verify**: `flutter test test/call_bubble_display_test.dart` → all pass

### Step 3: Deduplicate `_parseLocalBubble` fallbacks

Implement approach B.

**Verify**: `flutter test test/call_bubble_display_test.dart` → all pass

### Step 4: Characterization test for fewer CallBubble-side decodes

Create `test/call_bubble_meta_alloc_test.dart`:

1. Build N hangup-shaped `V2TimMessage`s with JSON customElem (reuse
   helpers from `call_bubble_display_test.dart` — copy minimal factory,
   do not invent new protocol shapes).
2. Reset `debugJsonDecodeCount` (if added).
3. Call `CallBubbleDedupe.normalizeCallHistoryMessages(list)` once.
4. Assert decode count is **strictly less than** a documented baseline
   you measure **before** the change on the same test fixtures
   (executor: run once on old code or compute: previously ≥2 raw passes
   per signal message; after A, CallBubble-side raw decodes for pure
   customElem hangups should be 0 beyond provider — set expect
   accordingly and comment the invariant).

If adding a counter is skipped, instead add a test that
`normalizeCallHistoryMessages` is idempotent on keys
(`stableKey` / length) — weaker, but still required. Prefer the counter.

**Verify**: `flutter test test/call_bubble_meta_alloc_test.dart` → pass

### Step 5: Full call-bubble suite

**Verify**:

```bash
flutter test test/call_bubble_display_test.dart \
  test/call_bubble_dedupe_key_test.dart \
  test/call_bubble_insert_service_test.dart \
  test/call_bubble_meta_alloc_test.dart
```

→ all pass

### Step 6: Optional eviction tweak (D)

Only if time and Step 5 green.

**Verify**: re-run Step 5.

## Test plan

- New: `test/call_bubble_meta_alloc_test.dart` — decode-count or idempotent
  normalize on hangup/invite fixtures.
- Regression: existing `call_bubble_display_test` normalize group must
  remain the behavioral source of truth (invite dropped, hangup kept,
  IM preferred over local).

## Done criteria

- [ ] `_buildMeta` does not call `hangupDurationSecFromRaw` /
      `extractRoomIdFromRaw`
- [ ] Provider exposes duration/room via thin getters; protocol logic
      unchanged
- [ ] `_parseLocalBubble` does not double-decode the same local JSON for
      duration+room when the first decode succeeded
- [ ] `flutter test` commands in Step 5 exit 0
- [ ] No files outside Scope modified
- [ ] `plans/README.md` status row for 005 updated

## STOP conditions

- Preferring provider duration/room changes which bubbles survive
  normalize (display tests fail) — revert Step 2 and report; do not
  "fix" by weakening `_preferMessage`.
- `CallingMessageDataProvider` duration/room disagree with raw helpers for
  a fixture in `call_bubble_display_test` — stop and report the fixture;
  may need raw fallback only when `provider.hangupDurationSec == 0` **and**
  document why (do not silently merge divergent sources without a test).
- Fix appears to require editing `tui_chat_global_model.dart` dedupe —
  out of scope; stop.

## Maintenance notes

- Reviewer: diff should be mostly "read from provider / decode once", not
  new dedupe rules.
- After landing, a new Instruments capture (optional) should show lower
  DartWorker Mark/Sweep share during chat open **if** call-heavy history
  was the spike driver; not required for Done criteria.
- Follow-ups deferred: isolate for huge histories; `dedupeMessages` list
  churn; link-preview alloc (wait for RegExpProbe dump from plan 003).
