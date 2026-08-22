# Plan 030: Open long-press menu before / cheaper bubble `toImage`

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
- **Risk**: MED (brief visual difference: menu may appear before extracted
  bitmap; super-long scroll path stays await-first)
- **Depends on**: plans/027-message-menu-scrim-close-before-work.md (DONE —
  solid scrim; do not reintroduce live full-screen blur)
- **Category**: perf
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Issue**: omit
- **Status**: DONE (2026-08-22) — non-scrollable insert-first + ratio cap 2.0;
  scrollable still awaits; contract tests green.
Users can still feel lag on **long-press open**: the list item **awaits**
`RepaintBoundary.toImage` **before** inserting the Overlay, so the first frame
of the menu is gated on a GPU readback at full device pixel ratio (often 3×).

027 explicitly deferred this as **M4**. Goal after this plan: ordinary bubbles
show dim + action menu **without waiting** for `toImage`; the extracted bitmap
arrives a frame or two later. Super-long scrollable menus still wait for a
snapshot (they need the image to scroll) but use a **capped** pixel ratio so
capture is cheaper.

## Product decisions (locked)

| Decision | Value |
|----------|--------|
| Keep Telegram extracted-bubble menu | Yes — do not switch to stock `PopupMenu` |
| Full-screen scrim | Keep Plan 027 solid `ColoredBox` (~38% black). **No** `BackdropFilter` on the controller scrim |
| Ordinary (non-scrollable) open | **Insert Overlay first** with `extractedSnapshot: null`; keep list bubble visible (`_isBubbleExtracted == false`) until capture completes; then assign snapshot, set `_isBubbleExtracted = true`, `markNeedsBuild` |
| Super-long scrollable open (`useScrollableMenu == true`) | **Keep await-before-insert** (need bitmap for `scrollableBubbleImage`); still apply **pixel-ratio cap** |
| Menu capture pixel ratio | Cap with a named const **`2.0`**: effective ratio = `min(devicePixelRatio, 2.0)` then existing 4096 longest-side clamp |
| Dismiss during in-flight capture | Dispose orphan `ui.Image`; do **not** extract / do **not** apply to a closed menu (compare `openedAt` / overlay still mounted) |
| Crop path | Preserve existing `cropInScreenSpace` math; ratio used for crop must match the ratio passed to `toImage` |
| Reaction-bar blur | **Out of scope** — Plan 031 |

## Current state

### Await-before-insert (the hitch)

`third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart`
`_presentMobileTelegramContextMenu` (~1341–1407):

```dart
    // Capture the bubble snapshot before showing the overlay so menu + bubble
    // appear together (Telegram-style, avoids pop-in after async toImage).
    final snapshot = await TelegramMessageContextController.captureSnapshot(
      _messageExtractBoundaryKey,
      context,
    );
    if (!mounted) {
      snapshot?.dispose();
      _endMessageContextMenuOverlayPresentation();
      return;
    }

    _contextMenuSnapshot = snapshot;
    if (snapshot != null && mounted) {
      setState(() {
        _isBubbleExtracted = true;
      });
    }
    // ...
    insertMenuOverlay();
```

`insertMenuOverlay` builds `TelegramMessageContextController` with
`extractedSnapshot: _contextMenuSnapshot`. List bubble opacity uses
`_isBubbleExtracted` (~3182).

### Capture uses full device DPR until 4096 clamp

`tim_uikit_telegram_message_context_controller.dart` `captureSnapshot` (~82–102):

```dart
      final deviceRatio = MediaQuery.devicePixelRatioOf(context);
      const maxTextureDimension = 4096.0;
      final size = boundary.size;
      final longestSide = max(size.width, size.height);
      final ratio = longestSide * deviceRatio > maxTextureDimension
          ? max(1.0, maxTextureDimension / longestSide)
          : deviceRatio;
      final fullImage = await boundary.toImage(pixelRatio: ratio);
```

No soft cap below device DPR for typical bubble sizes.

### Null snapshot behavior (safe for fast open)

Controller `build` (~275–276): extracted row is only built when
`widget.extractedSnapshot != null && !_scrollableMode`. Menu chrome still
builds. So null snapshot + list bubble still visible under solid scrim is a
valid interim state.

### Call sites of `captureSnapshot`

Only the list-item long-press path (grep should show this file). Do not invent
other callers; if a second call site appears, apply the same `maxPixelRatio`
const when it is menu-related, else STOP.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Analyze | `cd /Users/qiu/Downloads/9925banben && dart analyze third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_telegram_message_context_controller.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart test/message_context_menu_open_snapshot_contract_test.dart` | No errors |
| Contract test | `cd /Users/qiu/Downloads/9925banben && flutter test test/message_context_menu_open_snapshot_contract_test.dart` | All pass |
| Keep 027 green | `cd /Users/qiu/Downloads/9925banben && flutter test test/message_context_menu_scrim_contract_test.dart` | All pass |

Prefer source-scan contract tests (same style as
`test/message_context_menu_scrim_contract_test.dart`). Do **not** pump full chat UI.

## Scope

**In scope** (only these):

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_telegram_message_context_controller.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart` (open-path reorder + call args only)
- `test/message_context_menu_open_snapshot_contract_test.dart` (create)
- `plans/README.md` (status row only)

**Out of scope**:

- Plan 031 reaction-bar `useBackdropBlur`
- Reintroducing full-screen `BackdropFilter` scrim
- Changing delete/copy close-before-work (027)
- Long-press duration / haptic / 320ms dismiss guard
- Desktop hover bar
- `media_preview_slide_frame_capture.dart` / video `toImage`
- Skipping snapshot entirely forever (must still capture for extract UX)
- Raising or removing the 4096 texture clamp

## Git workflow

- No `.git` historically — do not `git init`.
- If git exists: branch `advisor/030-message-menu-fast-open-snapshot`,
  commit style `perf(chat): open message menu before bubble toImage`.

## Steps

### Step 1: Cap menu capture pixel ratio in `captureSnapshot`

In `tim_uikit_telegram_message_context_controller.dart`:

1. Add a public const on `TelegramMessageContextController`, e.g.

```dart
  /// Soft cap for long-press menu captures. Device DPR is often 3×; menu
  /// extract does not need full framebuffer sharpness.
  static const double menuCaptureMaxPixelRatio = 2.0;
```

2. Extend `captureSnapshot` with optional `double? maxPixelRatio`. When non-null,
   set `baseRatio = min(deviceRatio, maxPixelRatio)`; when null, `baseRatio =
   deviceRatio` (preserve any non-menu future callers).

3. Replace the ratio computation so the 4096 clamp uses `baseRatio` instead of
   raw `deviceRatio`:

```dart
      final ratio = longestSide * baseRatio > maxTextureDimension
          ? max(1.0, maxTextureDimension / longestSide)
          : baseRatio;
```

4. Keep crop math using the same `ratio` variable as today.

**Verify**:

```bash
rg -n "menuCaptureMaxPixelRatio|maxPixelRatio" \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_telegram_message_context_controller.dart
```

→ both symbols present; `toImage(pixelRatio: ratio)` still single call site.

### Step 2: Split open paths — fast insert vs await for scrollable

In `_presentMobileTelegramContextMenu` in
`tim_uikit_chat_history_message_list_item.dart`:

Keep computing `useScrollableMenu`, rects, `openedAt`, clearing prior overlay,
`_beginMessageContextMenuOverlayPresentation()` as today.

Then:

**A. If `useScrollableMenu` is true** (super-long):

- `await captureSnapshot(..., maxPixelRatio: TelegramMessageContextController.menuCaptureMaxPixelRatio)`
- dispose / end presentation on `!mounted` as today
- assign `_contextMenuSnapshot`, `setState` extract if non-null
- `insertMenuOverlay()`

**B. If `useScrollableMenu` is false** (ordinary bubbles — the common case):

1. Ensure `_contextMenuSnapshot == null` and **do not** set `_isBubbleExtracted`
   yet.
2. Call `insertMenuOverlay()` **immediately** (menu + solid scrim; no extracted
   `RawImage` yet; list bubble still visible under dim).
3. Start capture without blocking insert:

```dart
    final captureOpenedAt = openedAt;
    unawaited(() async {
      final snapshot =
          await TelegramMessageContextController.captureSnapshot(
        _messageExtractBoundaryKey,
        context,
        maxPixelRatio:
            TelegramMessageContextController.menuCaptureMaxPixelRatio,
      );
      if (!mounted ||
          _mobileMenuOpenedAt != captureOpenedAt ||
          _mobileTelegramMenuOverlay == null) {
        snapshot?.dispose();
        return;
      }
      _contextMenuSnapshot?.dispose();
      _contextMenuSnapshot = snapshot;
      if (snapshot != null) {
        setState(() {
          _isBubbleExtracted = true;
        });
      }
      _mobileTelegramMenuOverlay?.markNeedsBuild();
    }());
```

Adapt to file style (`unawaited` already imported). If the file prefers a
named private method `_finishContextMenuSnapshot(...)`, that is fine — keep
the guards identical.

4. **Do not** call `_endMessageContextMenuOverlayPresentation()` merely
   because snapshot is null; menu is already up. Only dispose orphan images on
   stale capture.

Ensure `closeTooltip` still disposes `_contextMenuSnapshot` and clears extract
(existing path ~1238+). Stale async must not resurrect a disposed image after
close — the `openedAt` / overlay-null guards are mandatory.

**Verify** (mental + ripgrep):

```bash
rg -n "await TelegramMessageContextController.captureSnapshot|insertMenuOverlay\(" \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list_item.dart
```

→ For the non-scrollable path, `insertMenuOverlay` must appear **before** any
`await captureSnapshot` on that branch (await only inside the `unawaited`
callback, or only on the scrollable branch).

### Step 3: Contract tests

Create `test/message_context_menu_open_snapshot_contract_test.dart` modeled on
`test/message_context_menu_scrim_contract_test.dart` (read files as strings):

1. Controller source contains `menuCaptureMaxPixelRatio` and the literal `2.0`
   (or the const initializer equals 2.0).
2. `captureSnapshot` signature / body mentions `maxPixelRatio`.
3. List-item source contains `menuCaptureMaxPixelRatio` at the capture call
   site(s).
4. List-item source still contains solid-scrim-era safety: controller file must
   **not** regain `BackdropFilter` for the menu scrim (027 contract file already
   covers this — re-run it; optionally assert list-item open path mentions
   `markNeedsBuild` after snapshot for the deferred path).

**Verify**:

```bash
cd /Users/qiu/Downloads/9925banben && flutter test \
  test/message_context_menu_open_snapshot_contract_test.dart \
  test/message_context_menu_scrim_contract_test.dart
```

→ all pass.

### Step 4: Analyze + mark DONE

Run `dart analyze` on the in-scope Dart files (table above). Update
`plans/README.md` row **030** to `DONE` with one-line note.

**Verify**: analyze clean; README status updated; `git status` (if any) shows
only in-scope paths (+ README).

## Test plan

- New: `test/message_context_menu_open_snapshot_contract_test.dart` as Step 3.
- Regression: `test/message_context_menu_scrim_contract_test.dart` must stay green.
- Manual (operator, not executor-blocking): long-press a short text bubble —
  menu should appear with near-zero wait; bubble may dim in-list then swap to
  extract. Long-press a multi-screen text bubble — menu may still wait for
  capture, but should not soft-lock; scrollable preview still works.

## Done criteria

- [ ] Non-scrollable open inserts Overlay **before** awaiting `toImage`
- [ ] Scrollable open still awaits capture before insert, with ratio cap
- [ ] `menuCaptureMaxPixelRatio == 2.0` used for menu captures
- [ ] Stale capture after dismiss disposes image and does not extract
- [ ] `flutter test test/message_context_menu_open_snapshot_contract_test.dart`
      and `test/message_context_menu_scrim_contract_test.dart` pass
- [ ] `dart analyze` on touched files: no errors
- [ ] No files outside Scope modified
- [ ] `plans/README.md` row 030 → DONE

## STOP conditions

- Current state excerpts no longer match (open path already reordered, or
  `captureSnapshot` API changed incompatibly).
- Implementing fast-open appears to require changing
  `MobileTelegramMessageContextMenu` layout API beyond null-snapshot support.
- Super-long path breaks without a larger redesign — do **not** skip snapshot
  for scrollable; report instead of inventing a live-widget scroll preview.
- A step’s verification fails twice after a reasonable fix.
- Temptation to reintroduce `BackdropFilter` “to hide pop-in” — STOP; that
  undoes 027.

## Maintenance notes

- Reviewers: watch for double-bubble flash if `_isBubbleExtracted` is set too
  early, and for leaked `ui.Image` when dismissing mid-capture.
- If Instruments still shows open hitch dominated by `toImage` after this plan,
  next lever is lowering the cap to `1.5` or skipping extract for tiny text —
  **not** restoring live blur.
- Plan **031** (reaction-bar blur off) is independent and may land in either
  order; prefer 030 first if only one can ship (larger user-visible win).
