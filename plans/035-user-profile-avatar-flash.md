# Plan 035: Stop user-profile header avatar flash on open

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving on. If
> any STOP condition is hit, stop and report — do not improvise. When done,
> update the status row for this plan in `plans/README.md` — unless a
> reviewer dispatched you and told you they maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt against live files. If symbols or control
> flow changed materially, STOP and report before coding. If `.git` exists:
> `git diff --stat HEAD --` the in-scope paths below.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (shared `Avatar` is used in chat/contacts; empty URL must
  still show default head; must not blank-hole slow networks)
- **Depends on**: none (orthogonal to 013–015 peer-profile merge/ingest;
  do **not** reopen merge-prefer-remote / IM-face overwrite policy)
- **Category**: bug / UX
- **Planned at**: workspace snapshot `NO_GIT` / 2026-08-22
- **Issue**: omit
- **Status**: DONE (2026-08-22) — sync `readCached` seed in `loadData`;
  neutral `Avatar` placeholder for real URLs; fill-only
  `_applyBackendProfile` via `UserAvatarHelper.shouldReplaceProfileFaceUrl`;
  `test/user_profile_open_avatar_stability_test.dart` + merge tests green.

## Why this matters

Opening **用户详细资料页**, the header avatar (and sometimes nick) **闪一下**:
default C2C head or loading dots, then the real photo. Intermittent because
warm image/disk cache hides it.

Three stacked causes (code-backed):

1. **Two-phase `loadData`**: first Consumer frame often has
   `userProfile?.friendInfo == null` → full-page loading dots until async
   work finishes; a later `notifyListeners` may change `faceUrl`.
2. **Sync cache unused on open**: `UserProfileLocalBridge.readCached` /
   `cachedAvatarUrl` already exist, but `loadData` only **awaits**
   `loadLocal` — memory-hot peers still miss a same-frame seed.
3. **`Avatar` placeholder = `defaultAvatar()`**: even with a correct
   network `faceUrl`, cold `CachedNetworkImage` shows the default head
   until decode completes — visible when navigating from a list that
   already showed the same face.

## Product decisions (locked)

| Decision | Value |
|----------|--------|
| First paint when sync cache has avatar/nick | Show header immediately (no loading dots for that user) |
| `Avatar` placeholder while real `faceUrl` non-empty | Neutral hold (opaque gray / surface) — **not** default C2C head |
| Empty / default-avatar URL | Still use `defaultAvatar()` (unchanged) |
| Backend enrich vs already-usable local face | **Fill-only**: keep usable current face; apply incoming only when current empty/default |
| Navigator seed args from every caller | **Out of scope** (optional follow-up) |
| Hero / shared-element | Out of scope |
| Reopen Plans 013–015 / make `mergeImPublicProfile` copy IM face | Out of scope / forbidden |

## Current state

### Relevant files

| Path | Role |
|------|------|
| `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_profile_view_model.dart` | `loadData` two-phase notify |
| `third_party/tencent_cloud_chat_uikit/lib/data_services/profile/user_profile_local_bridge.dart` | sync `readCached` / `cachedAvatarUrl`; async `loadLocal` |
| `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/avatar.dart` | `Avatar.faceUrl`; CNI `placeholder → defaultAvatar()` |
| `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitProfile/tim_uikit_profile.dart` | `friendInfo == null` → loading dots |
| `lib/src/user_profile.dart` | `didGetFriendInfo` → `_enrichFriendInfoFromBackend` → `_applyBackendProfile` |
| `test/chat_header_avatar_stability_test.dart` | source-scan contract exemplar |
| `test/im_public_profile_merge_test.dart` | IM must **not** overwrite hosted face |

### Excerpts (confirm before editing)

`loadData` — first notify only after **await** `loadLocal` (no sync seed):

```73:100:third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_profile_view_model.dart
  loadData({required String userID, bool isNeedConversation = true}) async {
    if (userID.isEmpty) {
      return;
    }

    V2TimConversation? conversation;
    if (isNeedConversation) {
      conversation = await _conversationService.getConversation(
        conversationID: "c2c_$userID",
      );
      _isDisturb = conversation?.recvOpt == 2;
    }

    final localFriend = await UserProfileLocalBridge.loadLocal(userID);
    if (localFriend != null) {
      _userProfile = UserProfile(
        friendInfo: localFriend,
        conversation: conversation,
      );
      // ...
      notifyListeners();
    }
```

Later same method: `didGetFriendInfo` (app enrich) then second notify (~L128–165).

Bridge sync API (unused by `loadData` today):

```82:107:third_party/tencent_cloud_chat_uikit/lib/data_services/profile/user_profile_local_bridge.dart
  static UserProfileCachedSnapshot? readCached(String? userId) { ... }

  static String cachedAvatarUrl(String? userId, {String? fallback}) { ... }

  static Future<V2TimFriendInfo?> loadLocal(String userId) async {
    final loader = _loadFriendInfo;
    if (loader == null) {
      return null;
    }
    return loader(userId);
  }
```

Profile UI null → loader:

```164:172:third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitProfile/tim_uikit_profile.dart
          final V2TimFriendInfo? userInfo = model.userProfile?.friendInfo;

          if (userInfo == null) {
            return Center(
              child: LoadingAnimationWidget.staggeredDotsWave(
```

Avatar cold placeholder = default head:

```116:131:third_party/tencent_cloud_chat_uikit/lib/ui/widgets/avatar.dart
            child: CachedNetworkImage(
              imageUrl: faceUrl,
              cacheKey: faceUrl,
              useOldImageOnUrlChange: true,
              // ...
              fadeInDuration: const Duration(milliseconds: 0),
              fadeOutDuration: Duration.zero,
              // 首次加载（磁盘缓存未命中）期间显示默认头像占位，
              // 避免从空白/透明突然翻转成图片造成的闪动。
              placeholder: (context, url) => defaultAvatar(),
```

Also fix the **web** branch in the same file (~L89–106) if
`loadingBuilder` / progress path still returns `defaultAvatar()` while
`faceUrl` is a real network URL.

Enrich always writes non-empty avatar:

```255:269:lib/src/user_profile.dart
  V2TimFriendInfo _applyBackendProfile(
    V2TimFriendInfo info, {
    String? nickname,
    String? avatarUrl,
    String? remark,
  }) {
    final profile = info.userProfile ?? V2TimUserFullInfo(userID: info.userID);
    // ...
    final avatar = avatarUrl?.trim();
    if (avatar != null && avatar.isNotEmpty) {
      profile.faceUrl = avatar;
    }
```

Called from `_enrichFriendInfoFromBackend` (friend record + remote user
fetch) via `ProfileLifeCycle.didGetFriendInfo`.

Usable-face helper already in app: `UserAvatarHelper.usableAvatarOrEmpty`
and `UserAvatarHelper.isDefaultPlaceholder` (`lib/utils/user_avatar.dart`).
Use these for fill-only gating (same file ~L301 / ~L375 already calls
`usableAvatarOrEmpty`).

## Commands you will need

| Purpose | Command | Expected |
|---------|---------|----------|
| New + regression | `cd /Users/qiu/Downloads/9925banben && flutter test test/user_profile_open_avatar_stability_test.dart test/im_public_profile_merge_test.dart test/chat_header_avatar_stability_test.dart` | all pass |
| Optional peer contracts | `flutter test test/peer_profile_friend_info_changed_contract_test.dart` | pass |

Run tests from **repo root**. Do not rewrite uikit `example/` pubspec if path deps fail.

## Scope

**In scope** (only):

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_profile_view_model.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/avatar.dart`
- `lib/src/user_profile.dart` — avatar apply policy inside
  `_applyBackendProfile` / `_enrichFriendInfoFromBackend` only
- Optional tiny pure helper (app or uikit) for
  `shouldReplaceProfileFaceUrl` — must be unit-tested
- `test/user_profile_open_avatar_stability_test.dart` (create)
- `plans/README.md` status row

**Out of scope**:

- `ProfilePageNav` / Navigator seed `faceUrl` on all call sites
- Hero animations
- Plans 013–015 merge / friend ingest
- Changing `UserProfileLocalBridge.mergeImPublicProfile` to copy IM `faceUrl`
- Chat list / conversation widgets beyond shared `Avatar` placeholder
- Plan 024 fullscreen ORIGIN / long-image decode work

## Git workflow

- Historically **no `.git`** — do not `git init`.
- If `.git` exists: branch `fix/035-profile-avatar-flash`; short imperative
  commits. Do not push unless asked.

## Steps

### Step 1: Sync-seed `loadData` from `readCached` before any await

In `TUIProfileViewModel.loadData`, **before** the first `await`
(`getConversation` / `loadLocal`):

1. If `_userProfile?.friendInfo?.userID` already matches `userID`, skip seed.
2. `final snap = UserProfileLocalBridge.readCached(userID);`
3. If snap has any of non-empty `avatarUrl` / `nickname` / `remark`, build
   minimal `V2TimFriendInfo` + `V2TimUserFullInfo` (`userID`, `nickName`,
   `faceUrl`, `friendRemark` as available), set
   `_userProfile = UserProfile(friendInfo: …, conversation: null)`,
   `notifyListeners()` **synchronously**.
4. Continue existing async path unchanged (conversation → `loadLocal` →
   enrich → final notify).

Do not invent friendType from seed beyond what the existing local-hit
block already does.

**Verify**:

```bash
rg -n "readCached|loadLocal|getConversation" \
  third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_profile_view_model.dart
```

→ Inside `loadData`, a `readCached` (or `cachedAvatarUrl`) path and an early
`notifyListeners` appear **above** the first `await` in that method.

### Step 2: Neutral placeholder when `faceUrl` is a real URL

In `avatar.dart`:

- Add a small local helper, e.g. `_placeholderForFaceUrl(String url)`:
  - empty or `_isDefaultAvatarUrl(url)` → `defaultAvatar()`
  - else → opaque neutral `ColoredBox` / `DecoratedBox` (fixed gray is OK;
    do not use transparent)
- Wire CNI `placeholder:` and the web `Image.network` loading path to it.
- Keep `fadeInDuration: 0`, `useOldImageOnUrlChange: true`,
  `gaplessPlayback: true` on the success `Image`.
- Update the Chinese comment: real URL must not flash default C2C head.

**Verify**:

```bash
rg -n "placeholder:" third_party/tencent_cloud_chat_uikit/lib/ui/widgets/avatar.dart
```

→ not unconditionally `defaultAvatar()` for all URLs.

### Step 3: Fill-only avatar in `_applyBackendProfile`

In `lib/src/user_profile.dart` `_applyBackendProfile`:

When `avatarUrl` is non-empty, before assigning `profile.faceUrl`:

```dart
final incoming = UserAvatarHelper.usableAvatarOrEmpty(avatar);
final current = UserAvatarHelper.usableAvatarOrEmpty(profile.faceUrl);
if (incoming.isEmpty) {
  // no-op
} else if (current.isEmpty) {
  profile.faceUrl = incoming;
} else if (current == incoming) {
  // no-op
} else {
  // keep current — open-path stability (fill-only)
}
```

`usableAvatarOrEmpty` already treats default placeholders as empty — use it
as-is; do not invent a second classifier.

One-line comment: open-path stability; real avatar rotations stay on
profile-refresh buses, not first `didGetFriendInfo` paint.

Do **not** freeze nickname/remark in this plan unless they share the same
assignment block and you would otherwise leave a half-edited function —
prefer avatar-only gate.

**Verify**: unit cases in Step 4; enrich with usable local + different
backend URL leaves local face.

### Step 4: Tests

Create `test/user_profile_open_avatar_stability_test.dart` (model after
`test/chat_header_avatar_stability_test.dart` for source scans):

1. **Source — sync seed**: `tui_profile_view_model.dart` contains
   `readCached` (or `cachedAvatarUrl`) and, within `loadData`, that call
   appears before `loadLocal(` (string index assertion on method body is
   OK if carefully sliced).
2. **Source — Avatar**: `avatar.dart` must not solely use
   `placeholder: (context, url) => defaultAvatar()` for network faces
   (assert neutral helper / branched placeholder).
3. **Logic** (extract helper if cleaner):
   `shouldReplaceProfileFaceUrl(current:, incoming:)`:
   - empty → usable = true
   - usable → empty = false
   - usable → default = false
   - usable A → usable B = false
   - usable A → same A = false

Keep `test/im_public_profile_merge_test.dart` green.

**Verify**:

```bash
cd /Users/qiu/Downloads/9925banben
flutter test \
  test/user_profile_open_avatar_stability_test.dart \
  test/im_public_profile_merge_test.dart \
  test/chat_header_avatar_stability_test.dart
```

→ exit 0.

### Step 5: Manual smoke (optional)

1. Open C2C chat with visible peer avatar → enter 资料 — no default-head
   flash; no long loading-dots when peer was recently shown.
2. Cold image cache + non-empty seeded URL — neutral hold → photo is OK;
   default-head flash is not.

No device → mark `NOT RUN` in status note; automated tests still required.

## Done criteria

- [ ] Sync cache seeds `loadData` before first await when snapshot has fields
- [ ] Real non-empty `faceUrl` no longer uses default C2C head as CNI placeholder
- [ ] `_applyBackendProfile` avatar writes are fill-only for usable faces
- [ ] `flutter test` command above exits 0
- [ ] No files outside Scope modified
- [ ] `plans/README.md` row 035 → DONE (or BLOCKED with reason)

## STOP conditions

- Live excerpts no longer match (already fixed / renamed beyond recognition).
- Fix appears to require `mergeImPublicProfile` to copy IM `faceUrl` — STOP.
- Neutral placeholder leaves empty-URL users blank — STOP; restore
  `defaultAvatar()` for empty/default URLs.
- Example pubspec path failures — do not rewrite example; keep tests under
  app `test/`.

## Maintenance notes

- Reviewers: shared `Avatar` on slow networks must not show empty holes;
  empty URL → default head forever.
- Alternate CDN hosts on open must not fight fill-only; use refresh bus for
  true avatar changes.
- Follow-up (not this plan): optional `seedFaceUrl` on `UserProfile` /
  `ProfilePageNav.openUserProfile` when bridge cache cold but conversation
  `faceUrl` hot.
