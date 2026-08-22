# Plan 013: Accept live peer nick/avatar into local profile (keep remark local)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> any STOP condition is hit, stop and report — do not improvise. When done,
> update the status row for this plan in `plans/README.md`.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt against live files. If symbols or control flow
> changed materially, STOP and report before coding.

## Status

- **Priority**: P0
- **Effort**: S–M
- **Risk**: MED (changes who wins when IM and local public profile disagree;
  remark semantics must stay untouched)
- **Depends on**: none (plan 014 wires events that feed this merge)
- **Category**: bug / correctness
- **Planned at**: working tree 2026-08-21 (NO_GIT)
- **Issue**: omit

## Why this matters

Users report: a peer changes avatar and nickname, but this client keeps
showing the **pre-change** values. Conversation list, chat header, and
bubbles all read **local-first**
(`UserProfileLocalService` / `FriendDisplayName` /
`UserDisplayProfile.pickBestPreferBackend`).

SDK writes into local cache go through
`UserProfileRecord.mergeSdkRemotePreferLocal` /
`mergeSdkRemoteUserInfoPreferLocal`, which use `_preferLocal` for
**nickname and avatarUrl**: once local is non-empty, **any newer IM value is
discarded**. `_saveAndPublish` then sees no change →
`PeerProfileRefreshBus` never fires → UI stays stale forever (until a rare
`saveBackendProfile` path overwrites).

Self-hosted **friend remark** must remain locally owned (empty remark means
cleared — already covered by tests). This plan only changes **public**
fields: nickname + avatar.

## Product decisions (locked)

| Field | Policy after this plan |
|-------|-------------------------|
| `friendRemark` | Unchanged: local/self-hosted owns it; SDK merge must **not** write IM remark over local |
| `nickname` | If remote non-empty → **take remote**; if remote empty → keep local |
| `avatarUrl` | Same as nickname |
| `selfSignature` / gender / birthday | Keep existing prefer-remote behavior |

Do **not** invent timestamps or “only if newer” unless already present on
`UserProfileRecord`. Non-empty remote is enough for this bug.

## Current state

### Prefer-local blocks live IM nick/avatar

`lib/src/models/user_profile_record.dart`:

```dart
static String _preferLocal(String current, String? incoming) {
  final local = current.trim();
  if (local.isNotEmpty) {
    return local;
  }
  return incoming?.trim() ?? '';
}

/// SDK 资料写入本地：昵称/头像/备注以本地（自建 API）为准；备注允许为空（已清空）。
UserProfileRecord mergeSdkRemotePreferLocal(V2TimFriendInfo? remote) {
  // ...
  return copyWith(
    nickname: _preferLocal(nickname, profile?.nickName),
    avatarUrl: _preferLocal(avatarUrl, profile?.faceUrl),
    // ...
    friendRemark: friendRemark, // local owned — keep
  );
}

UserProfileRecord mergeSdkRemoteUserInfoPreferLocal(V2TimUserFullInfo? remote) {
  return copyWith(
    nickname: _preferLocal(nickname, remote.nickName),
    avatarUrl: _preferLocal(avatarUrl, remote.faceUrl),
    // ...
  );
}
```

### Callers that feed the merge

`lib/src/services/user_profile_local/user_profile_local_service.dart`:

- `saveFriendInfo` → `mergeSdkRemotePreferLocal`
- `saveUserFullInfo` → `mergeSdkRemoteUserInfoPreferLocal`
- `mergePreferLocal` → same merge then `_saveAndPublish`

`_saveAndPublish` already updates `DisplayNameStore` (remark > nick) and
notifies `PeerProfileRefreshBus` when nick/avatar/remark change — no change
needed there if merge starts accepting remote public fields.

### Existing test that must stay green for remark

`test/user_profile_record_remark_test.dart` — `SDK merge keeps locally cleared
remark` expects `friendRemark` stays `''` when IM still has a remark string.

### Display layer (context — do not rewrite in 013)

`FriendDisplayName.resolveC2C` and `ConversationFaceUrl.resolve` prefer
`readCached` local nick/avatar. Fixing the merge is what makes those reads
fresh after a successful `save*`.

## Desired end state

1. Helper (name suggestion) `_preferRemoteNonEmpty(String current, String? incoming)`:
   - trimmed remote non-empty → return remote
   - else return trimmed local
2. `mergeSdkRemotePreferLocal` / `mergeSdkRemoteUserInfoPreferLocal` use it for
   `nickname` and `avatarUrl` only.
3. `friendRemark` assignment unchanged (`friendRemark: friendRemark`).
4. Comment on the merge methods updated to match reality:
   “公开昵称/头像：远端非空覆盖本地；备注仍以本地为准。”
5. Unit tests cover:
   - remote nick/avatar replace non-empty local
   - remote empty does not wipe local nick/avatar
   - cleared local remark still not restored from IM (existing test)

## Out of scope

- Changing `DisplayNameStore.resolveImSyncShowName` (plan **014** if still
  needed after merge + event wiring)
- `onFriendInfoChanged` / SelfHosted early-return (plan **014**)
- Rewriting conversation list widgets or bubble avatar widgets
- Historical message snapshot fields (`message.nickName` / `message.faceUrl`)
  — live UI should follow local cache; do not rewrite all history rows
- Wallet / LiveKit / moments author snapshots (unless a shared helper is
  already used and benefits automatically)

## Implementation steps

### Step 1 — Drift check

```bash
rg -n "_preferLocal|mergeSdkRemotePreferLocal|mergeSdkRemoteUserInfoPreferLocal" \
  lib/src/models/user_profile_record.dart
sed -n '160,198p' lib/src/models/user_profile_record.dart
```

Confirm excerpts match. If nick/avatar already prefer remote, STOP and jump
to plan 014.

### Step 2 — Implement prefer-remote for public fields

In `lib/src/models/user_profile_record.dart`:

```dart
/// Public profile: non-empty remote wins; empty remote does not clear local.
static String _preferRemoteNonEmpty(String current, String? incoming) {
  final remote = incoming?.trim() ?? '';
  if (remote.isNotEmpty) {
    return remote;
  }
  return current.trim();
}
```

Wire into both merge methods for `nickname` and `avatarUrl` only. Keep
`_preferLocal` if still used elsewhere, or leave it for remark-adjacent
helpers — do not use `_preferLocal` for nick/avatar anymore.

Update the Chinese/English comment on both merge methods.

### Step 3 — Extend unit tests

In `test/user_profile_record_remark_test.dart` (or new
`test/user_profile_record_public_merge_test.dart`):

1. Keep existing remark test green.
2. Add:

```dart
test('SDK merge replaces local nick and avatar when remote non-empty', () {
  final local = UserProfileRecord(
    userId: 'u1',
    nickname: '旧昵称',
    avatarUrl: 'https://old.example/a.png',
    friendRemark: '备注',
  );
  final merged = local.mergeSdkRemotePreferLocal(
    V2TimFriendInfo(
      userID: 'u1',
      friendRemark: 'IM脏备注',
      userProfile: V2TimUserFullInfo(
        userID: 'u1',
        nickName: '新昵称',
        faceUrl: 'https://new.example/b.png',
      ),
    ),
  );
  expect(merged.nickname, '新昵称');
  expect(merged.avatarUrl, 'https://new.example/b.png');
  expect(merged.friendRemark, '备注'); // local remark wins
});

test('SDK merge keeps local nick/avatar when remote empty', () {
  final local = UserProfileRecord(
    userId: 'u1',
    nickname: '本地昵称',
    avatarUrl: 'https://local.example/a.png',
  );
  final merged = local.mergeSdkRemoteUserInfoPreferLocal(
    V2TimUserFullInfo(userID: 'u1', nickName: '', faceUrl: ''),
  );
  expect(merged.nickname, '本地昵称');
  expect(merged.avatarUrl, 'https://local.example/a.png');
});
```

```bash
flutter test test/user_profile_record_remark_test.dart
# and the new file if created
```

Expected: PASS.

### Step 4 — Smoke related display-store tests (no intentional changes)

```bash
flutter test test/friend_display_name_display_store_test.dart
```

Expected: PASS unchanged. If something fails solely because of this merge,
STOP and report — 013 should not touch DisplayNameStore.

## Done criteria

- [ ] Nick/avatar merge uses remote-non-empty preference.
- [ ] Remark still never taken from IM in `mergeSdkRemotePreferLocal`.
- [ ] New + existing profile record tests PASS.
- [ ] No UI file edits in this plan.

## In-scope files

- `lib/src/models/user_profile_record.dart`
- `test/user_profile_record_remark_test.dart` and/or
  `test/user_profile_record_public_merge_test.dart`

## Explicitly out of scope files

- `display_name_store.dart`, `tui_friendship_view_model.dart` → 014
- `friend_display_name.dart`, `conversation_face_url.dart`, `chat.dart`
- Plans 001–012

## STOP conditions

- Product owner says IM must never overwrite local nick (self-hosted-only
  nick) — STOP; then 013 becomes “only `saveBackendProfile` + fetch on open”
  (different plan).
- `copyWith` does not distinguish empty vs omit for avatar — verify before
  clearing; this plan must **not** clear avatar on empty remote.
- Merge methods renamed/removed — STOP and report.

## Test plan

1. Unit tests in Step 3.
2. Manual (operator, NOT RUN OK): peer changes nick+avatar on another device →
   trigger any path that calls `saveFriendInfo`/`saveUserFullInfo` (after 014)
   → conversation list and chat header show new values without app reinstall.

## Maintenance notes

- Any new “seed local from IM once” path must use the same public-field
  policy or stale data returns.
- Do not reintroduce `_preferLocal` for nick/avatar “to protect backend”
  without a documented ADR — that is this bug.

## Escape hatches

If some callers pass stale IM into `saveFriendInfo` and overwrite a fresher
backend profile: add an optional `preferLocalPublic: true` parameter later;
do **not** guess in 013. Prefer fixing callers in 014 to pass live IM /
backend only.
