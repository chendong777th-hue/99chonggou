# Plan 014: Wire peer profile events so live nick/avatar reach local cache

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> any STOP condition is hit, stop and report — do not improvise. When done,
> update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpts against live files. If symbols or control
> flow changed materially, STOP and report before coding.
>
> **Prerequisite**: Land **plan 013** first (merge accepts remote nick/avatar).
> Without 013, wiring `saveFriendInfo` still no-ops on public fields.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED (extra profile writes / UI bus notifies; must not re-apply IM
  remarks under SelfHosted)
- **Depends on**: plan 013
- **Category**: bug / correctness
- **Planned at**: working tree 2026-08-21 (NO_GIT)
- **Issue**: omit

## Why this matters

Even with plan 013’s merge fix, this client often **never calls**
`saveFriendInfo` / `saveUserFullInfo` when a peer changes public profile:

1. With `SelfHostedFriendshipBridge.enabled`, `onFriendInfoChanged` **returns
   early** after `loadContactListData()` — it does **not** persist nick/face
   into `UserProfileLocalService`.
2. Non-friends may never get `onFriendInfoChanged`; the only signals are new
   messages (snapshot fields) or explicit `getUsersInfo` / backend fetch.
3. UI reads local cache first; without a write + `PeerProfileRefreshBus`,
   lists stay on old avatar/name.

This plan wires **ingest paths** so live public profile reaches local cache
(and thus existing listeners), without letting IM SNS remarks overwrite
self-hosted remarks.

## Product decisions (locked)

| Trigger | Action |
|---------|--------|
| `onFriendInfoChanged` (SelfHosted on or off) | Persist **public** nick/face via bridge `saveUserInfo` / `saveFriendInfo`; **do not** apply IM `friendRemark` into Store when SelfHosted is on |
| New incoming C2C/group message from peer with non-empty nick/face differing from local | Upsert public fields (thin helper) |
| Open C2C chat / peer profile page | Best-effort refresh: `getUsersInfo` and/or existing `UserApi.tryFetchUserById` → `saveBackendProfile` / `saveUserFullInfo` (debounce) |
| DisplayNameStore + empty IM remark | After local write, rely on `_saveAndPublish` (remark > nick). Only change `resolveImSyncShowName` if still blocking after 013+wiring — see Step 4 |

## Current state

### SelfHosted skips profile persist

`third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_friendship_view_model.dart`:

```dart
onFriendInfoChanged: (infoList) {
  if (SelfHostedFriendshipBridge.enabled) {
    // 备注以自托管为准，不把 IM SNS 里未清空的旧备注写回 Store。
    loadContactListData();
    return; // ← never save nick/face locally
  }
  // ... applyImFriendShowName + loadContactListData
},
```

### Bridge already exposes savers

`UserProfileLocalBridge.saveFriendInfo` / `saveUserInfo` are installed from
`lib/src/platform/uikit_user_profile_local_bridge.dart`.

### AppBar listener updates Store only (not local DB)

`tim_uikit_appbar.dart` `onFriendInfoChanged` → `DisplayNameStore.setC2C` —
does not call `UserProfileLocalBridge`. Conversation list still prefers
local DB avatar via `ConversationFaceUrl.resolve`.

### Message path syncs GroupMemberStore, not UserProfileLocal

`tui_chat_global_model.dart` `_syncGroupMemberFromMessage` updates
`GroupMemberStore` nick/face from the message; C2C local profile may stay
stale.

## Desired end state

1. **Friend info changed (always)**: for each changed user, call
   `UserProfileLocalBridge.saveUserInfo(info.userProfile)` when profile is
   non-null (nick/face). Under SelfHosted, **skip**
   `DisplayNameStore.applyImFriendShowName` with IM remark (keep today’s
   remark protection), but **do not** skip the public-profile save.
2. **Optional `saveFriendInfo`**: only if remark field is stripped / ignored
   by merge (013 keeps local remark). Prefer `saveUserInfo` for SelfHosted
   to avoid any remark confusion.
3. **Incoming message upsert** (minimal): shared helper
   `upsertPeerPublicProfileFromIm({userId, nickName, faceUrl})` that:
   - no-ops if both nick and face empty
   - no-ops if both equal to `readCached`
   - otherwise `saveUserFullInfo` with those fields
   Call from one existing hot path (prefer chat global model after receive,
   or app-level message hook already used for group member sync). Debounce
   per userId (≥2s) to avoid write storms.
4. **Open C2C / profile refresh**: reuse existing
   `UserAvatarHelper.resolveChatPeerFaceUrl(..., preferLiveProfile: true)`
   or `UserApi.tryFetchUserById` + `saveBackendProfile` on chat open / profile
   open if not refreshed recently (e.g. 60s). Prefer extending an existing
   peer-load method in `lib/src/chat.dart` / `lib/src/user_profile.dart`
   rather than a new service file unless none exists.
5. UI already listening to `PeerProfileRefreshBus` should update without new
   list widgets.

## Out of scope

- Changing remark ownership or SelfHosted friend request flows
- Rewriting all historical bubbles’ embedded nick/face
- Full contact-list periodic polling of every friend
- Plan 013 merge math (assume already landed)

## Implementation steps

### Step 1 — Confirm 013 landed

```bash
rg -n "_preferRemoteNonEmpty|nickname: _preferLocal" lib/src/models/user_profile_record.dart
```

Expected: nick/avatar use remote-non-empty helper; `_preferLocal` **not** used
for those two fields. If not, STOP and finish 013 first.

### Step 2 — Fix `onFriendInfoChanged` for SelfHosted + always persist public profile

In `tui_friendship_view_model.dart`, replace the early-return body with
something equivalent to:

```dart
onFriendInfoChanged: (infoList) async {
  for (final info in infoList) {
    final userID = info.userID.trim();
    if (userID.isEmpty) continue;
    final profile = info.userProfile;
    if (profile != null) {
      // Public nick/face only; remark stays self-hosted / local merge policy.
      await UserProfileLocalBridge.saveUserInfo(profile);
    }
  }
  if (SelfHostedFriendshipBridge.enabled) {
    loadContactListData();
    return;
  }
  var storeChanged = false;
  for (final info in infoList) {
    // existing applyImFriendShowName loop
  }
  if (storeChanged) {
    DisplayNameStore.instance.notifyBatch();
  }
  loadContactListData();
},
```

Import `user_profile_local_bridge.dart` if missing.

**Do not** call `applyImFriendShowName` under SelfHosted (remark pollution).

Add a **contract/source test** under `test/` (string contains check) or a small
unit test with a fake if the project already mocks friendship VM — prefer a
focused test file that documents the SelfHosted path must call
`saveUserInfo` / bridge. If VM is hard to unit-test, add:

`test/peer_profile_friend_info_changed_contract_test.dart` reading the
view_model source and asserting it contains
`UserProfileLocalBridge.saveUserInfo` **before** any SelfHosted `return`.

```bash
flutter test test/peer_profile_friend_info_changed_contract_test.dart
```

### Step 3 — Message / open refresh helper

Add a small app-side helper, e.g.
`lib/src/services/peer_public_profile_ingest.dart`:

```dart
class PeerPublicProfileIngest {
  static final Map<String, int> _lastMs = {};
  static const _minInterval = Duration(seconds: 2);

  static Future<void> upsertFromImSnapshot({
    required String userId,
    String? nickName,
    String? faceUrl,
  }) async { ... }
}
```

- Normalize id with `ChatIdFormat.rawUserUid`.
- Debounce with `_minInterval`.
- Build `V2TimUserFullInfo` and `UserProfileLocalService.instance.saveUserFullInfo`.
- Unit-test debounce + no-op when unchanged (mock/fake store is hard; test
  pure “shouldWrite” decision if extracted).

Wire **one** call site (pick the highest leverage, not all):

**Preferred**: after `_syncGroupMemberFromMessage` in
`tui_chat_global_model.dart`, also call ingest for the sender (group + C2C).
Keep it fire-and-forget (`unawaited`) to avoid blocking receive path.

**Also preferred**: in existing chat peer profile load
(`lib/src/chat.dart` paths that already `UserProfileLocalService.read` /
`resolveChatPeerFaceUrl`), ensure `preferLiveProfile: true` once on open and
persist via existing `saveBackendProfile` when network returns.

If `chat.dart` already fetches and saves backend profile on open, document
the line numbers in the plan delivery notes and skip duplicate fetches.

### Step 4 — DisplayNameStore only if still needed

Re-read `DisplayNameStore.resolveImSyncShowName`. After 013+Step2, local
`_saveAndPublish` sets Store from `friendRemark > nickname`. If Store still
shows an old nick because `applyImFriendShowName` refused to update when
SelfHosted is off and remark empty:

Update policy to:

- IM remark non-empty → remark (unchanged)
- IM remark empty + **local cached remark non-empty** (via
  `UserProfileLocalBridge.readCached`) → return null (protect remark)
- IM remark empty + local remark empty + IM nick non-empty → return nick
  (**allow overwrite** of previous store nick)

Update `test/friend_display_name_display_store_test.dart` accordingly:

- Keep “does not overwrite existing with nick” **only when** that existing
  represents a remark — implement by setting local cache remark in the test
  **or** change the test to use Bridge. If Bridge is null in unit tests,
  pass an optional `localRemark` into `resolveImSyncShowName` for testability:

```dart
static String? resolveImSyncShowName({
  required String imRemark,
  required String imNickName,
  required String userID,
  required String? existingStoreName,
  String? localRemark, // optional override; default read bridge
})
```

STOP if this becomes a large API churn — shipping Steps 2–3 alone may be
enough because `_saveAndPublish` already `setC2C`.

### Step 5 — Verification

```bash
flutter test \
  test/user_profile_record_remark_test.dart \
  test/user_profile_record_public_merge_test.dart \
  test/friend_display_name_display_store_test.dart \
  test/peer_profile_friend_info_changed_contract_test.dart
```

(Adjust filenames to what Step 2–3 actually created.)

Manual checklist (NOT RUN OK without device):

1. Two accounts friends; B changes nick+avatar.
2. A stays in foreground: within friend-info callback or next B message,
   A’s conversation row + chat header update.
3. A has a local remark on B: display name stays remark; avatar still updates.
4. SelfHosted enabled build: IM dirty remark does **not** replace local remark.

## Done criteria

- [ ] SelfHosted `onFriendInfoChanged` persists public profile via bridge
      before return.
- [ ] At least one message or open-chat ingest path writes local nick/avatar
      when IM snapshot differs.
- [ ] Remark under SelfHosted not applied from IM SNS into DisplayNameStore.
- [ ] Tests in Step 5 PASS.
- [ ] Plan 013 still green.

## In-scope files

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_friendship_view_model.dart`
- Optionally `tui_chat_global_model.dart` (one ingest call)
- Optionally `lib/src/services/peer_public_profile_ingest.dart` (**new**)
- Optionally `lib/src/chat.dart` / `lib/src/user_profile.dart` (open refresh)
- Optionally `display_name_store.dart` + friend display tests (Step 4 only)
- New contract/unit tests under `test/`

## Explicitly out of scope files

- Wallet, LiveKit, moments author pipeline (unless shared ingest is reused)
- `FriendLocalStore` schema migrations
- Conversation list item layout

## STOP conditions

- `UserProfileLocalBridge` not installed at runtime when friendship VM runs —
  STOP; fix install order first (`UikitUserProfileLocalBridge.install`).
- Saving `userProfile` from friend info clears nickname because SDK sends
  nulls — verify with a log/test; may need to only copy non-empty fields into
  a partial `V2TimUserFullInfo` before save.
- Ingest on every message causes jank/DB thrash — tighten debounce or limit
  to C2C + when `faceUrl`/`nickName` differ; do not remove debounce.

## Test plan

1. Contract test for SelfHosted + `saveUserInfo`.
2. Helper unit tests for should-write / debounce if extracted.
3. Existing remark + display-store tests.
4. Manual two-device checklist above.

## Maintenance notes

- New profile signals (e.g. custom backend push) should call the same ingest
  helper, not fork another prefer-local path.
- Keep SelfHosted remark comments accurate after the edit.

## Escape hatches

If IM `onFriendInfoChanged` never fires for nick-only changes on this SDK
version: lean on message ingest + open-chat `getUsersInfo` /
`saveBackendProfile` and document in README as known SDK limitation.
