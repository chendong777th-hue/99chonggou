# Plan 101: 收口用户资料页的资料竞态、备注行和刷新回环

> **Executor instructions**: 先执行 drift check，再按阶段实施。每个阶段完成后运行对应的 focused tests；如果资料来源优先级、好友关系语义或现有未提交改动与本计划不一致，停止并重新评估，不要回退用户改动。

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED（资料页同时依赖 TIM SDK、后端好友资料、IM 公开资料和本地缓存；不能影响好友关系、备注保存、会话列表资料同步）
- **Depends on**: Plan 035 已完成；不重开 013–015 的资料合并策略
- **Category**: bug / UX / async consistency
- **Planned at**: workspace snapshot `9f7c46e` / 2026-08-25
- **Issue**: 用户详细资料页偶发不显示备注行，头像和昵称在打开或刷新时反复跳变
- **Status**: TODO

## Diagnosis

### 1. 资料模型存在多次异步覆盖，旧请求可以覆盖新结果（P0）

`TUIProfileViewModel.loadData` 会依次执行内存缓存 seed、本地好友资料、SDK 好友资料、好友关系检查、后端 enrichment 和 IM 公开资料合并，并在多个阶段替换 `_userProfile` 后 `notifyListeners()`。资料页刷新时又可以再次启动 `loadData`。当前没有 user/generation/请求提交令牌，因此较早启动的请求可能在较晚请求之后提交，造成昵称和头像来回切换。

### 2. 备注行只由 SDK `friendType` 控制，和应用好友关系不是同一个事实源（P0）

`TIMUIKitProfile` 的 `ProfileWidgetEnum.remarkBar` 目前在 `isFriend == false` 时直接返回空容器，而 `isFriend` 来自 `TUIProfileViewModel.friendType`。应用侧已有 `_friendRelation` / `MeFriendApi` 关系数据；当 SDK 检查结果尚未完成、返回 0、或两套关系状态到达顺序不一致时，备注行会被隐藏，即使应用侧已确认是好友。

### 3. 资料打开路径会触发自己的刷新事件，刷新总线的事件又是永久匹配（P0）

`_enrichFriendInfoFromBackend` 完成后调用 `_publishConversationProfile`，后者无条件 `PeerProfileRefreshBus.notify(userId)`；当前页监听该总线并再次调用 `loadData`。同时总线把 user id 永久留在 `_changedUserIds`，`matches()` 在后续任何 revision 上仍然为 true。这会放大重复加载和 UI 跳变，也会让不相关的后续事件重新触发旧页面。

## Product decisions

| Decision | Value |
|----------|-------|
| 资料提交模型 | 同一用户同一时刻只允许最新 generation 提交 UI；旧请求结果只能被丢弃，不能覆盖头像、昵称、备注或关系状态 |
| 首屏策略 | 已有可用缓存时立即显示；之后只做字段级合并，不用空字段或低优先级快照覆盖已有可用值 |
| 资料来源优先级 | 应用好友资料/备注 > 已确认的本地资料 > SDK/IM 公开资料；空值不覆盖非空值；头像继续沿用 Plan 035 的 fill-only 规则 |
| 备注行可见性 | 以应用好友关系和 SDK 关系的统一解析结果为准，不以备注内容是否为空决定；关系未解析完成时保持布局稳定，不能先删行再插入 |
| 刷新事件 | 外部资料/好友关系变更才发布刷新；资料页打开时的 enrichment 不能回调刷新自身 |
| 兼容范围 | 不改底部导航、消息会话列表布局、SDK 版本、备注保存 API 和非好友页面的操作语义 |

## Scope

### In scope

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_profile_view_model.dart`
  - generation/request token
  - stale result suppression
  - stable field-level merge and single authoritative UI commit
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitProfile/tim_uikit_profile.dart`
  - remark bar visibility contract
  - relation-resolving state下的稳定占位/布局策略
- `lib/src/user_profile.dart`
  - relation resolution wiring
  - `_publishConversationProfile` 的 effective-change gate
  - profile-open enrichment 与外部刷新事件解耦
  - profile refresh single-flight/coalescing
- `lib/src/services/peer_profile_refresh_bus.dart`
  - event-scoped or revision-scoped matching/consume semantics
  - preserve current listeners for chat header, conversation list and group profile
- focused tests under `test/`

### Out of scope

- 重做 Plan 035 的头像 placeholder、缓存 seed 或 `UserAvatarHelper` 规则
- 修改 013–015 的远程资料合并/IM face 覆盖策略
- 修改好友关系后端协议、备注接口或好友列表产品逻辑
- 重做消息会话页面和底部导航

## Implementation steps

### Step 0 — Drift check and baseline

1. Run `git diff --stat HEAD --` for every in-scope path. `lib/src/user_profile.dart` 当前已有未提交改动，必须保留并以 live code 为准。
2. Reconfirm the current call chain:
   `loadData → didGetFriendInfo → _enrichFriendInfoFromBackend → _publishConversationProfile → PeerProfileRefreshBus → _reloadProfileAfterFriendChange`.
3. Run the existing profile stability contracts before editing.

**STOP** if the call chain or relation source has materially changed and this plan no longer describes the code.

### Step 1 — Add generation-safe profile loading

1. Add a monotonically increasing load generation (or equivalent cancellation token) owned by the profile view model/controller.
2. Capture the generation and requested user id at the beginning of every `loadData` invocation.
3. Before every intermediate `notifyListeners`, before the final `_userProfile` assignment, and after every awaited source, verify the request is still current and the model is not disposed.
4. Prefer one final authoritative commit after all sources are merged. If an early cache paint is retained, merge it into the existing snapshot and never replace a usable field with empty/stale data.
5. Reset relation/loading state atomically when the page changes user id; do not let a previous user’s friend type or profile remain visible for the new user.

### Step 2 — Make profile fields monotonic during one open

1. Centralize the merge policy for nickname, avatar and remark instead of replacing the entire `UserProfile` from each source.
2. Preserve non-empty nickname/avatar from a higher-confidence current snapshot when a later source is empty or only a different CDN representation.
3. Keep Plan 035’s avatar fill-only behavior; do not solve the jump by suppressing legitimate explicit avatar changes globally.
4. Add a stable `relationResolved`/equivalent state so the UI can distinguish “not yet known” from “confirmed non-friend”.

### Step 3 — Unify remark-row visibility

1. Resolve `isFriend` from the application relation (`_friendRelation` / `MeFriendApi`) and SDK relation with an explicit precedence and conflict rule.
2. Pass the resolved relation state into the profile view model/UI; do not use `friendType != 0` as the only gate.
3. Render the remark row when the user is a confirmed friend, even if the remark text is empty. Hide it only after relation resolution positively confirms non-friend/self rules.
4. While relation is unresolved, keep the row’s height/position stable according to the chosen product policy; avoid remove-then-insert layout jumps.
5. Apply the same rule to mobile and wide-screen profile builders.

### Step 4 — Break the refresh feedback loop

1. Make `_publishConversationProfile` compare the effective display name/avatar/remark with the cached values before publishing. No effective change means no bus event.
2. Mark profile-open enrichment as a local cache synchronization operation. It may update the cache, but must not notify the same profile page to reload itself.
3. Keep `PeerProfileRefreshBus` notifications for external friend/profile mutations. Change `matches()` from permanent-set semantics to event/revision-scoped semantics, or provide an explicit per-listener consume/last-seen revision API.
4. Add single-flight/coalescing in `UserProfileState._reloadProfileAfterFriendChange` so multiple revisions cannot start overlapping `loadData` and relation loads.
5. Verify other listeners (chat header, conversation list, group profile) still receive one refresh for a real effective change.

### Step 5 — Tests and verification

Add focused tests for:

- older `loadData` finishing after newer `loadData` cannot overwrite nickname/avatar/remark;
- cache/local/remote/IM merge keeps authoritative non-empty fields and does not paint intermediate blanks;
- SDK `friendType == 0` plus application friend relation true still shows the remark row;
- both relation sources false hides the row; unresolved relation preserves stable layout;
- profile-open enrichment does not recursively trigger its own reload;
- an unchanged effective profile does not publish `PeerProfileRefreshBus`;
- one real external change is consumed once by the profile page, while unrelated user changes do not match it;
- existing Plan 035 avatar stability and remark persistence contracts remain green.

Recommended focused commands from the repository root:

```sh
flutter test \
  test/user_profile_open_avatar_stability_test.dart \
  test/user_profile_record_remark_test.dart \
  test/peer_profile_friend_info_changed_contract_test.dart \
  test/peer_face_url_live_priority_test.dart \
  test/conversation_peer_profile_realtime_test.dart
```

Then run analyzer on only the changed Dart files and a manual/profile-mode regression matrix:

- open a cached friend with remark;
- open a friend with empty remark;
- open a non-friend;
- open while SDK relation and app relation return in opposite order;
- trigger an external nickname/avatar/remark change while the page is open;
- rapidly open two different profiles and return/reopen the first one.

## Acceptance criteria

- During a profile open, the same user’s avatar and nickname do not alternate between cache/SDK/backend values; at most one intentional authoritative update is visible.
- A confirmed friend always has a remark row, including an empty remark; a confirmed non-friend does not.
- Relation resolution does not create a visible remove/insert jump in the settings list.
- Opening a profile does not recursively reload itself through `PeerProfileRefreshBus`.
- Real external profile changes still update the open profile, chat header and conversation list exactly once per effective change.
- No regression in Plan 035 avatar stability, remark save/clear behavior, blocked-user controls, or non-friend add-friend actions.

## Stop conditions

- Any test shows an explicit user avatar change being suppressed rather than applied.
- SDK and application friend relation semantics cannot be reconciled without a product decision.
- A proposed bus change causes unrelated chat/conversation/group listeners to stop refreshing.
- The fix requires changing backend APIs, SDK protocol behavior, or unrelated message/session code.
