# Plan 015: Lazy-refresh public profile for visible chat senders

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> any STOP condition is hit, stop and report — do not improvise. When done,
> update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt against live files. If symbols or control flow
> changed materially, STOP and report before coding.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (extra `getUsersInfo` during scroll; must be capped so
  10k–50k member groups stay safe)
- **Depends on**: plans 013–014 (DONE — local merge accepts remote nick/avatar;
  ingest + bus already exist)
- **Category**: bug / correctness (perf-constrained)
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Issue**: omit

## Why this matters

Plans 013–014 refresh a peer’s nick/avatar when:

- friend-info changes, or
- they **send a new message** (snapshot upsert), or
- C2C open does a live face fetch.

**Silent group members** (changed avatar/nick, never speak while you watch)
stay stale. Product want: update those faces/names **without** full-group
`getUsersInfo`.

Constraint (locked): groups may have **tens of thousands** of members.
**Forbidden**: on group enter / member-list open, pull all member IDs.
**Required**: cost scales with **visible (or near-visible) unique senders**,
not group size.

## Product decisions (locked)

| Decision | Value |
|----------|--------|
| Scope | Group chat message list (C2C optional no-op or single peer already covered by 014) |
| Trigger | Senders of messages that the list **builds** while scrolling / after settle — proxy for “visible or in cacheExtent” |
| Batch | `getUsersInfo` chunks ≤ **100** (SDK doc); practical flush ≤ **20–30** unique IDs |
| TTL | Per-user live refresh cooldown **10 minutes** (constant, tunable) |
| Debounce | Coalesce schedule **300–500ms** after last enqueue (scroll settle) |
| Self | Never refresh login user via this path |
| Remark | Never write IM remark; only nick + face via existing `saveUserInfo` / merge |
| Fail soft | Network errors: skip; keep TTL so we don’t hammer |

## Current state

### SDK batch limit

`third_party/tencent_cloud_chat_sdk/lib/manager/v2_tim_manager.dart`:

```dart
/// userIDList 建议一次最大 100 个，因为数量过多可能会导致数据包太大被后台拒绝，后台限制数据包最大为 1M。
Future<V2TimValueCallback<List<V2TimUserFullInfo>>> getUsersInfo({
```

### Existing ingest (014)

`UserProfileLocalBridge.upsertPublicProfileFromSnapshot` — good for message
snapshots; **not** a live `getUsersInfo`.

`saveUserInfo` → `UserProfileLocalService.saveUserFullInfo` → merge (013
remote-non-empty nick/avatar) → `PeerProfileRefreshBus`.

### Message list build site

`tim_uikit_chat_history_message_list.dart` uses `SliverChildBuilderDelegate`
(~9885+). Each built row has a `V2TimMessage` with `sender` / `userID`,
`nickName`, `faceUrl`. This is the right **enqueue** hook: builder runs for
visible + cacheExtent children only, **not** for all group members.

### C2C already live-fetches peer

`lib/src/chat.dart` `_loadPeerFaceUrl` + `UserAvatarHelper.resolveChatPeerFaceUrl(preferLiveProfile: true)` after 014. Plan 015 may skip C2C or no-op when only one peer.

## Desired end state

1. New small scheduler (name suggestion):
   `VisibleSenderProfileRefresh` in UIKit
   (`lib/business_logic/services/visible_sender_profile_refresh.dart`)
   **or** under `data_services/profile/`.

2. API sketch:

```dart
class VisibleSenderProfileRefresh {
  static const ttl = Duration(minutes: 10);
  static const debounce = Duration(milliseconds: 400);
  static const maxPerFlush = 25; // << 100 SDK cap

  /// Enqueue a sender seen while building a message row.
  static void noteSender(String? userId, {String? selfUserId});

  /// Optional: call when chat disposed to cancel timer.
  static void cancelPending();
}
```

3. Internals:
   - `_pending` set of userIds
   - `_lastLiveRefreshMs` map (or reuse a dedicated map; do **not** confuse
     with upsert snapshot debounce)
   - Timer debounce → `_flush()`:
     - take up to `maxPerFlush` IDs whose TTL expired
     - `getUsersInfo(userIDList: chunk)` via existing friendship/core SDK
       accessor already used in UIKit (`FriendshipServices.getUsersInfo` or
       `TIMUIKitCore.getSDKInstance().getUsersInfo`)
     - for each returned profile: `UserProfileLocalBridge.saveUserInfo(info)`
       (or `upsert` only if you also want snapshot path — prefer **saveUserInfo**
       so empty fields don’t block via upsert’s “both empty” rules; 013 merge
       keeps local when remote empty)
     - if more pending remain, schedule another flush after short delay
       (e.g. 200ms) — **never** unbounded parallel storms

4. Wire `noteSender` from message list item build path once per message
   (cheap): when constructing the row for a non-self message, call
   `VisibleSenderProfileRefresh.noteSender(senderId, selfUserId: ...)`.

   Prefer a **single** call site in the list’s builder / shared row factory
   used by `SliverChildBuilderDelegate`, not deep inside every bubble widget
   (avoids duplicate notes from nested rebuilds — Set + TTL handles dupes
   anyway).

5. Unit tests for pure scheduling logic (extract testable helpers):
   - TTL skips recent IDs
   - flush respects `maxPerFlush`
   - self id filtered
   - empty id ignored

6. Contract test (optional): list file contains
   `VisibleSenderProfileRefresh.noteSender`.

## Out of scope

- Full group member list refresh / enter-group fan-out
- Changing avatar image disk cache / CDN
- Rewriting historical `message.faceUrl` bytes on every message object
  (UI should follow local cache + `PeerProfileRefreshBus` like today)
- Moments / wallet / call UI
- Changing 013/014 merge or remark policy

## Implementation steps

### Step 1 — Drift check

```bash
rg -n "getUsersInfo|upsertPublicProfileFromSnapshot|SliverChildBuilderDelegate" \
  third_party/tencent_cloud_chat_sdk/lib/manager/v2_tim_manager.dart \
  third_party/tencent_cloud_chat_uikit/lib/data_services/profile/user_profile_local_bridge.dart \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart
```

Confirm 013/014 still present (`_preferRemote` for nick/avatar;
`upsertPublicProfileFromSnapshot` on receive).

### Step 2 — Implement scheduler + tests

Add `visible_sender_profile_refresh.dart` with the API above.

Keep SDK / bridge calls behind a small injectable typedef **or** call static
bridge directly and unit-test only the pure “which ids to flush” function:

```dart
@visibleForTesting
List<String> selectIdsForFlush({
  required Iterable<String> pending,
  required Map<String, int> lastRefreshMs,
  required int nowMs,
  required int ttlMs,
  required int maxPerFlush,
  required String? selfUserId,
});
```

```bash
flutter test test/visible_sender_profile_refresh_test.dart
```

Expected: PASS.

### Step 3 — Wire message list builder

In `tim_uikit_chat_history_message_list.dart` (or the private method that
builds each `messageItem` for the sliver):

```dart
final sender = message?.sender ?? message?.userID;
VisibleSenderProfileRefresh.noteSender(
  sender,
  selfUserId: /* login user id from self VM or TIMUIKitCore */,
);
```

Resolve self id the same way other list code does (existing helper /
`TUISelfInfoViewModel`). Do **not** block the build method on awaits.

On chat list `dispose`, call `cancelPending()` if the scheduler is
process-global; if keyed by conversation, clear that key only.

### Step 4 — Verify related suites

```bash
flutter test \
  test/visible_sender_profile_refresh_test.dart \
  test/user_profile_record_remark_test.dart \
  test/peer_profile_friend_info_changed_contract_test.dart
```

Expected: PASS.

### Step 5 — Manual checklist (NOT RUN OK without device)

1. Group with ≥1 silent member who changed avatar on another client.
2. Open group; scroll until that member’s **old** bubbles are on screen.
3. Within ~1s after scroll settle, avatars/names should refresh (bus).
4. Fast fling through history: no multi-second hitch; network should show
   small batched `getUsersInfo`, not thousands of IDs.
5. Re-scroll same senders within 10 minutes: no repeat storm (TTL).

## Done criteria

- [ ] No code path pulls all group members for profile refresh.
- [ ] `getUsersInfo` requests use ≤100 IDs; flush default ≤25.
- [ ] Per-user TTL ≥5 minutes (plan default 10).
- [ ] Build path only `noteSender` (sync); network off build thread via timer.
- [ ] Tests in Step 4 PASS.
- [ ] Self-hosted remark behavior unchanged (013/014 tests still green).

## In-scope files

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/services/visible_sender_profile_refresh.dart` (**new**) — or under `data_services/profile/`
- `third_party/.../tim_uikit_chat_history_message_list.dart` (noteSender wire)
- `test/visible_sender_profile_refresh_test.dart` (**new**)
- Optional one-line contract test update

## Explicitly out of scope files

- `group_membership_sync_service.dart` full member sync
- Conversation list
- `display_name_store.dart` remark policy
- Plans 001–014 completed code unless a compile fix is required

## STOP conditions

- Only way to know “visible” seems to require rewriting the entire list to
  `ScrollablePositionedList` — STOP and report; **builder-based noteSender
  is the accepted proxy** for this plan (cacheExtent ≈ near-visible).
- `getUsersInfo` unavailable when bridge not installed — still enqueue but
  flush must no-op safely when `UserProfileLocalBridge` savers null.
- Profiling shows scroll jank from `noteSender` itself — then move note to
  post-frame callback batching only indexes, not per-rebuild; do not remove
  TTL/caps.

## Test plan

1. Pure `selectIdsForFlush` unit tests.
2. Regression 013/014 tests.
3. Manual silent-member scroll scenario (Step 5).

## Maintenance notes

- If product later adds server profile-revision push, feed the same
  `saveUserInfo` path; keep this lazy refresh as fallback.
- Do not raise `maxPerFlush` above 100. Do not set TTL to zero.

## Escape hatches

If live refresh fights offline-first UX: gate behind a const
`VisibleSenderProfileRefresh.enabled = true` for one release.
If C2C double-fetches: `noteSender` no-op when `groupID` empty.
