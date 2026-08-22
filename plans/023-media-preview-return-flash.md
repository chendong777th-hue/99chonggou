# Plan 023: Skip aggressive Chat overlay recover on media-preview return

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: There may be **no `.git`** in this workspace.
> Compare the "Current state" excerpts below against live files. If
> `activate` / `_recoverChatHistoryAfterOverlayReturn` no longer match, STOP.
> If `.git` exists: `git diff --stat <planned-at>..HEAD -- lib/src/chat.dart test/`

## Status

- **Priority**: P0
- **Effort**: S
- **Risk**: LOW
- **Depends on**: plans/021-media-preview-scroll-unlock.md (DONE — keep unlock contract green)
- **Category**: bug
- **Planned at**: workspace snapshot `NO_GIT` / 2026-08-22 (no commit SHA available)
- **Issue**: omit
- **Execution**: DONE 2026-08-22 — activate overlay gate + recover skip_aggressive; contracts green

## Why this matters

After the user opens a chat image/video fullscreen preview and swipe-dismisses
back to the conversation, the message list often **flashes or jumps once**.
Root cause: `ChatState.activate` treats *every* route reactivation the same —
including media preview — and runs `_recoverChatHistoryAfterOverlayReturn`,
which was written for profile/settings “blank list” recovery: it
`jumpTo(minScrollExtent)`, clears the mounted display-list cache, and
`setState`s the whole Chat page. Media preview already keeps the list alive
(`MediaPreviewOverlayRoute.maintainState: true`) and owns scroll restore via
`pushMediaPreview` → `restoreScrollAfterMediaPreview` (Plan 021). The
aggressive recover fights that path and paints a visible flash under the
closing transition (`opaque: false`).

## Current state

### Relevant files

- `lib/src/chat.dart` — Chat page; `activate` → blanket overlay recover;
  `_recoverChatHistoryAfterOverlayReturn` does jumpTo + setState when messages
  exist.
- `third_party/tencent_cloud_chat_uikit/lib/ui/utils/media_preview_presenter.dart`
  — `pushMediaPreview` always restores scroll in `finally` (do **not** change
  unlock ownership).
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
  — `isMediaPreviewOverlayOpen`, `isRestoringScrollAfterMediaPreview`,
  `shouldLockChatScrollForMediaPreview`.
- `test/media_preview_chat_scroll_lock_contract_test.dart` — Plan 021 contract
  pattern (source-scan tests). Model new tests after this file.

### Excerpts (confirm before editing)

`activate` always recovers — no media-preview skip:

```8518:8528:lib/src/chat.dart
  @override
  void activate() {
    super.activate();
    final route = ModalRoute.of(context);
    if (route != null && route.isCurrent) {
      _restoreActiveChatRegistry(routeVisible: true);
      // 任意盖层返回都走恢复：空列表重拉，有消息则贴底刷新，避免整页空白。
      unawaited(
        _recoverChatHistoryAfterOverlayReturn(reason: 'route_reactivated'),
      );
    }
  }
```

Contrast: `deactivate` **already** excludes media / wallet / picker overlays:

```8501:8515:lib/src/chat.dart
  @override
  void deactivate() {
    final route = ModalRoute.of(context);
    final globalModel = serviceLocator<TUIChatGlobalModel>();
    if (route != null &&
        !route.isCurrent &&
        !globalModel.isMediaPreviewOverlayOpen &&
        !globalModel.isWalletOverlayOpen &&
        !globalModel.isMediaPickerOverlayOpen) {
      ActiveChatRegistry.instance.updateRouteVisible(false);
      ...
    }
    super.deactivate();
  }
```

Aggressive body when history is visible:

```6756:6795:lib/src/chat.dart
  Future<void> _recoverChatHistoryAfterOverlayReturn({
    required String reason,
  }) async {
    ...
    _clearMountedDisplayListCache();
    ...
    if (!_hasVisibleHistoryMessages()) {
      await _reloadChatHistoryIfEmpty(reason: reason);
    } else {
      try {
        final scroll = _chatController.scrollController;
        if (scroll != null && scroll.hasClients) {
          scroll.jumpTo(scroll.position.minScrollExtent);
        }
      } catch (_) {}
      ...
    }
    if (mounted) {
      setState(() {});
    }
  }
```

Explicit profile/settings callers keep dedicated reasons (must **still** get
full recover):

- `return_from_settings` / `return_from_profile` (header navigation)
- `return_from_my_profile` / peer profile returns
- `return_from_group_live_settings`

Media scroll ownership (leave intact — Plan 021):

- `pushMediaPreview(..., restoreChatScrollConversationID:)` → `finally` →
  `restoreScrollAfterMediaPreview`
- List listens to `scrollLockedForOverlay` / `mediaPreviewRestoreVersion`

### Conventions

- Prefer **source-scan contract tests** under `test/` (no full widget pump of
  Chat) — see `test/media_preview_chat_scroll_lock_contract_test.dart`.
- Chinese comments OK where neighboring chat lifecycle comments are Chinese.
- Do not invent new global flags if existing overlay getters suffice.
- Match `deactivate`’s overlay exclusion list when gating `activate`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Contract tests | `flutter test test/media_preview_return_flash_contract_test.dart test/media_preview_chat_scroll_lock_contract_test.dart` | All pass |
| Analyze chat | `dart analyze lib/src/chat.dart` | No **errors** (pre-existing warnings OK) |
| Broader open/gate smoke (optional) | `flutter test test/chat_open_gate_visual_contract_test.dart` | Pass |

## Scope

**In scope** (only these):

- `lib/src/chat.dart` — gate `activate` / soften `route_reactivated` recover for
  media (and sibling) overlays as specified below.
- `test/media_preview_return_flash_contract_test.dart` — **create**.
- `plans/README.md` — status row for 023.

**Out of scope** (do NOT touch):

- `media_preview_presenter.dart` / Hero registry / `ImageScreen` slide math
  (Plan 021 unlock and Hero timing stay).
- `tui_chat_global_model.dart` scroll lock / restore implementation (unless a
  STOP forces a one-line getter — prefer not).
- `tim_uikit_chat_history_message_list.dart` physics / `_restoreRouteScroll`.
- Gallery picker flash (016), chat-open pin/shell (019–022), decode caps (017).
- Changing `opaque` / transition durations of the preview route.
- Removing `_recoverChatHistoryAfterOverlayReturn` for profile/settings reasons.

## Git workflow

- Workspace often has **no `.git`**. Do not `git init`. Do not push.
- If git exists: branch `advisor/023-media-preview-return-flash`; commit message
  style like nearby plans, e.g. `fix(chat): skip overlay jumpTo on media preview return`.

## Recommended fix (do this — do not improvise a third design)

### Design

1. **Primary gate in `activate`** (mirror `deactivate`):
   - Always `_restoreActiveChatRegistry(routeVisible: true)` when
     `route.isCurrent`.
   - **Do not** call `_recoverChatHistoryAfterOverlayReturn` when any of:
     - `globalModel.isMediaPreviewOverlayOpen`
     - `globalModel.isRestoringScrollAfterMediaPreview`
     - `globalModel.isMediaPickerOverlayOpen`
     - `globalModel.isWalletOverlayOpen` (same sibling overlays as deactivate)
   - Otherwise keep today’s `route_reactivated` recover for true secondary
     pages that did not go through an explicit `return_from_*` await.

2. **Defense in depth inside `_recoverChatHistoryAfterOverlayReturn`**:
   - When `reason == 'route_reactivated'` **and**
     (`isMediaPreviewOverlayOpen || isRestoringScrollAfterMediaPreview`):
     - Still allow empty-list reload via `_reloadChatHistoryIfEmpty` if
       `!_hasVisibleHistoryMessages()`.
     - **Skip** `_clearMountedDisplayListCache()`, **skip**
       `jumpTo(minScrollExtent)`, **skip** unconditional `setState`.
     - Log a distinct diag event, e.g. `overlay_return_skip_aggressive`
       with `reason` + which flags were true (reuse `ChatDiagLog.log` style
       already used in this method).
   - All other reasons (`return_from_profile`, `return_from_settings`, …)
     keep current aggressive behavior unchanged.

Why both layers: `activate` may race a frame where flags already cleared;
the recover guard catches late `route_reactivated` calls while restore is
still in progress. Explicit `return_from_*` paths never use
`route_reactivated`, so profile blank-page recovery stays intact.

### Comment to leave (short)

Near the `activate` gate, note in Chinese or English that media/picker/wallet
overlays own their own restore (021) and must not force pin-to-bottom refresh.

## Steps

### Step 1: Drift-check live `activate` / recover

Open `lib/src/chat.dart` and confirm the excerpts above still exist
(`jumpTo(scroll.position.minScrollExtent)` inside recover; unguarded
`route_reactivated` in `activate`).

**Verify**:  
`rg -n "route_reactivated|jumpTo\\(scroll.position.minScrollExtent\\)|isMediaPreviewOverlayOpen" lib/src/chat.dart`  
→ shows `activate` recover call, recover `jumpTo`, and deactivate already
checking `isMediaPreviewOverlayOpen`.

### Step 2: Gate `activate`

Implement the overlay skip listed in “Recommended fix” §1.

**Verify**:  
`rg -n -A20 "void activate\\(\\)" lib/src/chat.dart`  
→ body checks the four overlay/restoring flags before calling recover;
`_restoreActiveChatRegistry` still runs when `route.isCurrent`.

### Step 3: Soften recover for media `route_reactivated`

Implement “Recommended fix” §2 early-return / skip-aggressive branch.

**Verify**:  
`rg -n "overlay_return_skip_aggressive|route_reactivated" lib/src/chat.dart`  
→ skip path exists; `return_from_profile` call sites unchanged
(`rg -n "return_from_profile" lib/src/chat.dart` still present).

### Step 4: Contract tests

Create `test/media_preview_return_flash_contract_test.dart` modeled on
`test/media_preview_chat_scroll_lock_contract_test.dart` (`dart:io` +
`readAsStringSync`).

Required assertions (all must pass):

1. `activate` source region contains checks for
   `isMediaPreviewOverlayOpen` and `isRestoringScrollAfterMediaPreview`
   **before** `_recoverChatHistoryAfterOverlayReturn` / `route_reactivated`.
2. `_recoverChatHistoryAfterOverlayReturn` contains a skip path mentioning
   `route_reactivated` and media preview / restoring flags (string match
   `overlay_return_skip_aggressive` or equivalent stable token you chose).
3. Aggressive `jumpTo(scroll.position.minScrollExtent)` still exists in the
   recover method (profile path preserved) — assert the string remains in
   `chat.dart`.
4. Plan 021 invariant still holds: re-run
   `test/media_preview_chat_scroll_lock_contract_test.dart`.

**Verify**:  
`flutter test test/media_preview_return_flash_contract_test.dart test/media_preview_chat_scroll_lock_contract_test.dart`  
→ all pass.

### Step 5: Analyze + mark DONE

**Verify**:  
`dart analyze lib/src/chat.dart` → no errors.  
Update `plans/README.md` row 023 → **DONE**.

## Test plan

| Case | How |
|------|-----|
| Media preview return does not force activate recover | Contract on `activate` gate |
| Late route_reactivated during restore skips jumpTo/setState | Contract on recover skip token |
| Profile/settings still have jumpTo | Contract that jumpTo string remains; do not delete recover |
| Scroll unlock still owned by pushMediaPreview | Existing 021 contract file |

Manual (operator, not required for DONE): open chat image → swipe down →
list should not flash/jump; scroll still works (021). Open chat settings →
return → blank-list recovery still works if list was empty/broken.

## Done criteria

- [ ] `activate` skips `_recoverChatHistoryAfterOverlayReturn` when media /
      picker / wallet overlay (or media scroll restoring) is active
- [ ] `route_reactivated` + media restore does not `jumpTo` / blank `setState`
- [ ] Explicit `return_from_*` recover paths unchanged
- [ ] `flutter test test/media_preview_return_flash_contract_test.dart test/media_preview_chat_scroll_lock_contract_test.dart` exits 0
- [ ] `dart analyze lib/src/chat.dart` has no errors
- [ ] No files outside Scope modified
- [ ] `plans/README.md` status for 023 = DONE

## STOP conditions

Stop and report (do not improvise) if:

- Excerpts drifted: no `route_reactivated` in `activate`, or recover no longer
  `jumpTo`s (someone already “fixed” differently).
- Fix appears to require changing `pushMediaPreview` / list physics to stop
  the flash (re-investigate; this plan assumes Chat recover is the flash).
- Removing aggressive recover for **all** `route_reactivated` (including
  non-media) seems necessary — report; do not broaden without operator OK
  (may regress true secondary-route blank pages that lack `return_from_*`).
- Profile return starts blanking after your change — revert and report.
- Plan 021 scroll-lock contract fails after your edit.

## Maintenance notes

- Reviewers: ensure `deactivate` and `activate` stay **symmetric** on overlay
  flags; if a new overlay type is added to `deactivate`, update `activate`
  the same day.
- Future: if wallet/picker still flash via the same recover path, the
  `activate` gate already covers them; do not re-open 016/021 unless unlock
  regresses.
- Deferred: Hero `scheduleRevealAll` delay tuning; list Selector rebuild on
  `scrollLockedForOverlay` — secondary flash sources; only chase if 023
  does not fix the reported flash.
