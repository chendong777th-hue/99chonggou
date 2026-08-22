# Plan 027: Lighten long-press message menu (scrim + close-before-work)

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
- **Risk**: MED (scrim visual change; delete/revoke confirm timing change)
- **Depends on**: none
- **Category**: perf / UX
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Issue**: omit
- **Status**: DONE (2026-08-22) — solid scrim; close-before-work for copy/delete;
  contract test green.

## Why this matters

Users report that **tapping items in the long-press message menu** (especially
复制 / 删除) feels **沉重** — sticky, laggy, not “instant.”

This is mostly **not** Clipboard or delete-SDK cost. Mobile chat uses a
Telegram-style root Overlay that:

1. Awaits `RepaintBoundary.toImage` snapshot of the bubble,
2. Composites a full-screen `BackdropFilter` blur (σ=22) every frame while open,
3. On menu-item tap calls `onCloseTooltip` → `closeTooltip()` which **synchronously
   tears down** Overlay + blur + snapshot + bubble re-insert `setState`,
4. Then runs the actual action (`Clipboard.setData`, confirm dialog, `deleteMsg`).

So the tap frame pays for **expensive layer teardown + business work together**.
Delete is worse: confirm dialog is shown **while the blurred menu is still up**.

Goal after this plan: menu items feel light; copy returns to chat quickly;
delete/revoke still require confirmation but not on top of a live blur menu.

## Product decisions (locked)

| Decision | Value |
|----------|--------|
| Keep Telegram-style extracted bubble + action menu | Yes — do **not** revert to a plain `PopupMenu` |
| Full-screen dim while menu open | Keep a dim scrim; **replace** `BackdropFilter(blur σ=22)` with a **solid** (or near-solid) color overlay — no live blur filter on the menu path |
| Legacy `_MessageTooltipBlurOverlay` | Same scrim policy if that path still builds (desktop / old tooltip sync). Do not leave σ=22 live blur on either path |
| Copy / reply / multiSelect / translate / voiceToText | **Close menu first**, then run work on next frame (or `unawaited` after close). Toast may appear after close |
| Delete / revoke | **Close menu first**, then show confirm on root Overlay / navigator. Keep confirmation — do **not** one-tap delete |
| Snapshot `toImage` on open | **Out of scope** this plan (open lag is separate; do not remove capture) |
| Long-press duration / 320ms anti-mis-tap | Keep existing (~450ms press, 320ms dismiss guard for **background** tap). Menu **item** taps already bypass reverse animation — keep that |
| Orphan overlay dismissers | Must still unregister / `endMessageContextMenuOverlay` on every close path |

## Current state

### Mobile menu shell — live blur

`third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_telegram_message_context_controller.dart`
(~259–270):

```dart
child: GestureDetector(
  onTap: () => unawaited(_dismissIfAllowed()),
  behavior: HitTestBehavior.opaque,
  child: BackdropFilter(
    filter: ui.ImageFilter.blur(sigmaX: 22, sigmaY: 22),
    child: Container(
      color: Colors.black.withValues(alpha: 0.38),
    ),
  ),
),
```

Menu-item `onClose` is wired to list-item `closeTooltip` (hard remove, no
`reverse()`):

```dart
onClose: widget.onDismiss, // → closeTooltip in list item
```

Background dismiss still `await _presentController.reverse()` (~220ms) then
`onDismiss` — leave as-is unless a step below needs a shared close helper.

### Legacy blur overlay (still in tree)

`tim_uikit_chat_history_message_list_item.dart` `_MessageTooltipBlurOverlay`
(~3473–3477) also uses `BackdropFilter` + σ=22. Still used from layout sync
when old `tooltip?.isOpen` path runs (~1142–1143).

`closeTooltip()` (~1259–1262) always removes mobile Telegram overlay **and**
blur overlay via `_removeTooltipBlurOverlay()`.

### Copy / delete tap order

`tim_uikit_chat_message_tooltip.dart` `_onTap`:

- **Delete/revoke** (~1059–1124): show `showUIKitOverlayConfirmDialog` **first**
  (menu still open), only then `widget.onCloseTooltip()`, then `deleteMsg` /
  `revokeMsg`.
- **Copy and other light ops** (~1127+): `widget.onCloseTooltip()` then
  `await Clipboard.setData` + `onTIMCallback` toast — close and clipboard on
  the same async chain without yielding a frame between teardown and work.

```dart
widget.onCloseTooltip();
// ...
case "copyMessage":
  await Clipboard.setData(...);
  onTIMCallback(...); // 「已复制」
```

### Delete SDK (do not rewrite)

`tui_chat_separate_view_model.dart` `deleteMsg` (~6827–6848): awaits
`deleteMessages`, then `setMessageList`. Leave API intact; only change **when**
menu closes relative to confirm.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze touched files | `dart analyze third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_telegram_message_context_controller.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_message_tooltip.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart test/message_context_menu_scrim_contract_test.dart` | No errors (warnings OK if pre-existing) |
| Contract test | `flutter test test/message_context_menu_scrim_contract_test.dart` | All pass |
| Broader smoke (optional) | `flutter test test/merge_group_members_prefer_incoming_test.dart` | Pass (sanity toolchain) |

Match existing contract-test style (string/source scan) used by plans like
`test/chat_gallery_pick_routing_contract_test.dart` if present — prefer reading
source files as text and asserting absences / required sequences over pumping
full chat UI.

## Scope

**In scope** (only these):

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_telegram_message_context_controller.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart` (scrim widget only + any tiny shared const if colocated)
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_message_tooltip.dart`
- Optional small shared helper file under the same folder, e.g.
  `message_context_menu_scrim.dart`, **only if** both call sites need one widget
- `test/message_context_menu_scrim_contract_test.dart` (create)
- `plans/README.md` (status row only)

**Out of scope**:

- `captureSnapshot` / `toImage` open path — follow-up plan if open still lags
- Removing confirmation for delete/revoke
- Changing menu item set / ToolTipsConfig product flags
- Desktop hover bar redesign
- `deleteMsg` / conversation preview sync internals
- Long-press detector duration / haptic
- Wallet / call / pin message actions beyond sharing the same `_onTap` close order
- Reintroducing orphan overlays (must keep dismisser unregister)

## Git workflow

- No `.git` in this workspace historically — do not `git init`.
- If git exists when executing: branch `advisor/027-message-menu-scrim`,
  conventional commits like `perf(chat): lighten message context menu scrim`.

## Steps

### Step 1: Replace live BackdropFilter with solid scrim

In `tim_uikit_telegram_message_context_controller.dart`, replace the
`BackdropFilter` + blur child with a full-screen `Container` (or `ColoredBox`)
using the **same** black alpha ≈0.38 (or a named const). Keep
`HitTestBehavior.opaque` and background dismiss → `_dismissIfAllowed`.

In `tim_uikit_chat_history_message_list_item.dart` `_MessageTooltipBlurOverlay`,
apply the **same** solid scrim (no `ImageFilter.blur`). Keep hole clip /
spotlight behavior if the clipper is load-bearing for the legacy path; if
clipping only existed to punch a hole through blur, a solid full-screen dim
**without** hole is acceptable for legacy path — prefer **minimal change**:
same clipper + solid fill, no BackdropFilter.

Remove unused `dart:ui` ImageFilter imports only if nothing else needs them
in that file.

**Verify**:

```bash
rg -n "BackdropFilter|ImageFilter\.blur" \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_telegram_message_context_controller.dart \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart
```

→ **no matches** for those symbols in the menu/scrim widgets (snapshot code in
the controller may still import `dart:ui` for `ui.Image` — that is fine; only
blur/BackdropFilter must be gone).

### Step 2: Close-before-work for light operations

In `tim_uikit_chat_message_tooltip.dart` `_onTap`, for operations that do **not**
need the menu widget tree:

- `copyMessage`, `replyMessage`, `multiSelect`, `translate`, `voiceToText`,
  `open`, `finder` (and any other non-destructive cases in the switch)

Change order to:

1. Capture any data needed from `widget.message` / `model` into locals **before** close.
2. `widget.onCloseTooltip();`
3. Yield at least one frame: e.g.
   `await Future<void>.delayed(Duration.zero);`
   and/or `await WidgetsBinding.instance.endOfFrame;`
   (match the pattern already used in the delete navigator fallback ~1081–1082).
4. Then run Clipboard / model updates / toast.

Do **not** await Clipboard before close.

**Verify**: `dart analyze` on the tooltip file — no errors. Manual mental check:
copy path text order is close → yield → clipboard.

### Step 3: Delete / revoke — close then confirm

Rewrite the `delete` / `revoke` branch so that:

1. Resolve `msgID` / `messageItem` / labels first.
2. `widget.onCloseTooltip();`
3. Yield a frame (same as step 2).
4. Show confirm via `showUIKitOverlayConfirmDialog` using
   `Overlay.maybeOf(context, rootOverlay: true)` **if context still mounted**,
   else navigator `_confirmDestructiveAction` path.
5. On confirm, call `_executeDelete` / `_executeRevoke` as today.

If after close `context` is unmounted (tooltip disposed), you **must** obtain
a stable Overlay/Navigator **before** close:

- Prefer: `final overlay = Overlay.maybeOf(context, rootOverlay: true);`
  and `final nav = resolveUIKitRootNavigator(context);` **before**
  `onCloseTooltip()`, then pass those into the confirm helpers after yield.

Cancel on confirm must leave chat usable (no stuck overlay) — confirm dialog
must pop itself; menu already closed.

**Verify**: read the branch; confirm dialog is never started while Telegram
menu OverlayEntry is still inserted. Grep that delete branch calls
`onCloseTooltip` **before** `showUIKitOverlayConfirmDialog`.

### Step 4: Contract test

Create `test/message_context_menu_scrim_contract_test.dart` that:

1. Reads the two UIKit source files as strings (paths relative to package /
   repo root — follow how other contract tests resolve paths in this repo).
2. Asserts `BackdropFilter` and `ImageFilter.blur` do **not** appear in the
   telegram controller file (except allow `toImage` / `ui.Image` usage).
3. Asserts list-item file has no `ImageFilter.blur` / `BackdropFilter` in the
   overlay widget section (whole-file absence is OK if snapshot-free).
4. Asserts tooltip `_onTap` source contains a delete/revoke ordering cue:
   e.g. `onCloseTooltip` appears before `showUIKitOverlayConfirmDialog` in the
   delete branch (simple indexOf comparison is enough).

**Verify**:

```bash
flutter test test/message_context_menu_scrim_contract_test.dart
```

→ all pass.

### Step 5: Analyze + index

Run analyze command from the table. Update `plans/README.md` row 027 → DONE
(or leave TODO if operator runs later — executor marks DONE when criteria met).

## Test plan

- New: `test/message_context_menu_scrim_contract_test.dart` as above.
- Pattern: source-contract tests already used for gallery/routing (string
  assertions on file contents) — do **not** require a full TIMUIKitChat pump.
- No golden screenshot required; visual check is operator manual (dim still
  readable, menu items still tappable).

## Done criteria

- [ ] No `BackdropFilter` / `ImageFilter.blur` on message context menu scrim
      paths in the two in-scope UI files
- [ ] Light ops: close tooltip before Clipboard / model mutation; at least one
      frame yield between close and work
- [ ] Delete/revoke: close tooltip before confirm dialog; confirmation retained
- [ ] `flutter test test/message_context_menu_scrim_contract_test.dart` passes
- [ ] `dart analyze` on in-scope Dart files: no **errors**
- [ ] No files outside Scope modified
- [ ] `plans/README.md` status updated

## STOP conditions

- Telegram menu no longer uses Overlay / extracted bubble (someone already
  rewrote presentation) — STOP; plan assumes that shell.
- Delete confirmation was product-removed elsewhere — STOP; do not reintroduce
  one-tap delete without operator OK.
- Closing tooltip always disposes the only Overlay that can host confirm, and
  capturing Overlay/Navigator before close is impossible — STOP and report
  rather than showing confirm under a still-blurred menu.
- Contract test cannot locate source files from test cwd — fix path like sibling
  contract tests; if none exist, STOP with path attempt log.
- Fix appears to require editing `deleteMsg` / global model / chat.dart — STOP.

## Maintenance notes

- Reviewers: watch for **stuck** `isMessageContextMenuOverlayOpen` / missing
  dismisser unregister after reorder.
- If open-menu lag remains dominant, schedule a follow-up for deferred /
  lower-res `captureSnapshot` — do not fold into this PR.
- If design insists on blur later, use a **pre-blurred static image** or
  σ≤4 one-shot — never restore σ=22 live BackdropFilter without profiling.
- Manual QA: long-press text → 复制 (toast after menu gone); long-press → 删除
  cancel; long-press → 删除 confirm; background tap still dismisses; no
  full-screen dead overlay after.
