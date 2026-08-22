# Plan 040: Defer wallet order-card network until after first chat paint

> **Executor instructions**: Follow step by step. Verify each gate. STOP on
> drift. Update `plans/README.md` when done.
>
> **Drift check**: Confirm
> `lib/utils/custom_message/custom_message_element.dart` still calls
> `unawaited(_fetchAndMergeWalletCard(data))` inside `presentImmediateCard`
> (after local/cached card paint), and `_maybeResolvePacketType` can fire
> `WalletApi.instance.getRedPacketOrder` when packet type is missing.
> Confirm `docs/pro-scenario.md` logs
> `[red-packet] GET … (order-card)` during list→chat open.

## Status

- **Priority**: P0
- **Effort**: S–M
- **Risk**: LOW–MED (stale card status if defer is too long; must still
  refresh — only **when**, not **whether**)
- **Depends on**: none (independent of 039; soft: land after 037/038)
- **Category**: perf (list→chat open contention)
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Status**: DONE (2026-08-22) — local/cached card paints first; quiet
  order-card / packetType network refresh deferred to post-frame (+1s
  fallback); cancelled on dispose / cache-key change.

## Why this matters

Post-037 Probe in `docs/pro-scenario.md` shows RegExp cost is largely gone.
On the **same open**, the log still fires multiple:

```text
[red-packet] GET /wallet/red-packet/972 (order-card)
[red-packet] GET /wallet/red-packet/971 (order-card)
```

These run while history is landing and the first frames paint. Cards already
have a local/cached shell (`presentImmediateCard` path). The network merge
is a **quiet refresh**, not required for first paint — but it currently
starts in the same turn as first `setState`, competing with open-path work
(DB reopen, sound cache, layout).

Lossless goal: first paint still shows the local/cached card; network
order-card / packetType fetch still happens — just **after** the first
frame(s) / idle, without changing card semantics when the response arrives.

Note: README previously **rejected “cut”** red-packet GETs as a RegExp
finding. This plan **defers** them — different decision, same evidence.

## Current state

**File**: `lib/utils/custom_message/custom_message_element.dart`

Inside `_scheduleWalletCardLoad` → `presentImmediateCard`:

```dart
await _hydrateRedPacketOpenedBeforeFirstPaint(data);
_maybeResolvePacketType(data);
_scheduleRedPacketOpenedCheck(data);
if (mounted) {
  setState(() {});
}
if (!kIsWeb) {
  unawaited(_fetchAndMergeWalletCard(data));
}
```

`_maybeResolvePacketType` (when type empty) →
`WalletApi.instance.getRedPacketOrder` (logged as `order-card` via
`lib/src/api/wallet_api.dart`).

Other `_fetchAndMergeWalletCard` call sites (~499, ~694, ~735) — inventory
them; only **defer the open/first-paint path** that races with history land.
Do not break explicit retry paths.

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| Related tests | `ls test/*wallet* test/*red_packet* test/*custom_message* 2>/dev/null; flutter test <matching>` | Pass |
| Analyze | `dart analyze lib/utils/custom_message/custom_message_element.dart` | No new errors |

## Scope

**In scope**

- `lib/utils/custom_message/custom_message_element.dart`
- Tests that cover wallet card first paint / merge (extend or add small test)
- `plans/README.md`

**Out of scope**

- Changing order-card API contract or card UI layout
- Removing network refresh entirely
- Sqflite lifecycle (039) / call_bubble fingerprint (041)
- Prefetching red packets on conversation list scroll

## Locked decisions

| Decision | Value |
|----------|--------|
| Defer mechanism | `WidgetsBinding.instance.addPostFrameCallback` (1–2 frames) or the same idle/post-frame pattern already used in `CallBubbleDedupe`; optional ≤1s fallback timer |
| When local/cached card exists | Defer `_fetchAndMergeWalletCard` and **network** `_maybeResolvePacketType` until after first paint |
| When no local/cached card | Keep immediate fetch |
| packetType already in payload | `_maybeResolvePacketType` already no-ops — unchanged |
| Cancellation | Cancel scheduled work in `dispose` / when wallet cache key changes |

## Steps

### Step 1: Inventory call sites

Label every `_fetchAndMergeWalletCard` / `_maybeResolvePacketType` caller:
`first_paint` vs `retry` vs `user_action`. Only change `first_paint` with
local/cached card.

### Step 2: Defer quiet refresh after paint

When `presentImmediateCard` runs for cached/local:

1. Paint + `setState` as today.
2. Schedule `_fetchAndMergeWalletCard` (+ network packet type if still needed)
   after first frame(s), with ≤1s fallback.
3. Cancel on dispose / cache-key change.

When there is **no** local/cached card, keep immediate fetch.

**Verify**: `dart analyze` clean.

### Step 3: Tests

Prove first build with local card does not require mocked HTTP for amount;
prove pumped frame still merges when fake async completes.

### Step 4: Scenario check

List→chat with red packets: card shell on first paint; `order-card` GETs
shift after history Probe dump (document ordering in Status).

## Done when

- [ ] Quiet order-card refresh deferred when local/cached card exists
- [ ] No-local path still fetches immediately
- [ ] dispose / key-change cancels pending defer
- [ ] Tests green
- [ ] `plans/README.md` row 040 → DONE

## STOP conditions

- Defer causes visible wrong amount/status for >1s on common COMPLETED cards
  with full local payload → tighten to post-frame only, or STOP and report
- Requires changing Wallet API URLs or auth → out of scope
- Only remaining GETs are user tap to open packet detail → REJECT this plan

## Out of scope reminder

Do not change claim/open flows beyond defer timing.
