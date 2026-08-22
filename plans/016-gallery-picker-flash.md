# Plan 016: Reduce custom gallery open/close flash

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
- **Risk**: MED (changing PhotoKit init timing can resurrect empty-album cold
  start; changing dismiss settle affects send latency)
- **Depends on**: none
- **Category**: bug / UX perf
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Issue**: omit
- **Status**: DONE (2026-08-22) — delay=0; deferred iOS HQ upgrade; settle in
  `_runMediaTask.finally` before overlay end; contracts green.

## Why this matters

Users report **flashing when opening the album to pick images** in chat.
Mobile chat always uses the **custom** WeChat-style picker
(`EditableAssetPicker`), not the system Photo Picker.

Root causes (code-backed):

1. **Open**: `initializeDelayDuration: 250ms` delays PhotoKit query until after
   push → empty/loading shell then sudden grid fill.
2. **Open**: iOS thumbnail cells do a **second** `setState` after
   `DeliveryMode.highQualityFormat` upgrade → grid “pops” sharp.
3. **Close/cancel**: system + successful-custom paths call
   `waitForPickerDismissSettle` before `endMediaPickerOverlay`, but
   **cancel/empty custom return** falls through to `_runMediaTask` `finally`
   which ends the overlay **during** the slide-down animation → chat list
   notify races the transition (flash).

## Product decisions (locked)

| Decision | Value |
|----------|--------|
| Keep custom picker as default on iOS/Android | Yes (`shouldPreferCustomGalleryPicker` stays true) |
| Init delay | Cut default to **0ms**; optional one-shot **≤80ms** only if a measured empty-path regression returns (gate behind const / first-open flag — prefer 0 first) |
| iOS HQ thumbnail upgrade | **Defer** until after first visible frame + short idle (e.g. post-frame + 120ms), or skip upgrade while scrolling; do not remove first-frame decode |
| Dismiss settle | **Every** custom picker return (select **and** cancel) must settle before `endMediaPickerOverlay` notify |
| Empty-album safety | Do **not** reintroduce `PhotoManager.clearFileCache()` on open (contract forbids) |

## Current state

### Fixed 250ms delay (open empty → fill)

`third_party/.../editable_asset_picker.dart`:

```dart
static const Duration _providerInitializeDelay = Duration(milliseconds: 250);
// ...
initializeDelayDuration: _providerInitializeDelay,
```

Contract locks this today:

`test/chat_gallery_pick_routing_contract_test.dart` expects
`Duration(milliseconds: 250)` and
`initializeDelayDuration: _providerInitializeDelay`.

### iOS second-pass upgrade

`asset_picker_edit_builder_delegate.dart` — after first thumbnail bytes,
`_upgrade` requests highQuality and `setState` again on iOS/macOS.

### Dismiss settle gap on cancel

`tim_uikit_more_panel.dart`:

- Selected custom assets → `_dispatchCustomPickedGalleryMedia` settles then
  `endMediaPickerOverlay`.
- Cancel / empty → no settle; `_runMediaTask` `finally` always
  `endMediaPickerOverlay()` → pending chat `notifyListeners` during pop.

System picker path already settles before ending overlay.

### Route

`AssetPickerPageRoute` is a 250ms bottom `SlideTransition` (`opaque: true`).
Do **not** rewrite the package route in this plan; fix timing around it.

## Desired end state

1. `_providerInitializeDelay` is `Duration.zero` (or documented ≤80ms with
   comment + updated contract). Prefer **zero** unless STOP from empty-album
   QA.
2. iOS HQ upgrade does not run synchronously in the same turn as first paint;
   first paint stays; upgrade is deferred / cancelled if cell disposed.
3. After `EditableAssetPicker.pickAssets` returns (any result), more_panel
   (and other chat callers if same pattern) await
   `ChatGalleryPickUtils.waitForPickerDismissSettle` **before** the media-task
   finally path can notify — cleanest approach:

   **Option A (preferred)**: In `_runMediaTask` finally, if this task used a
   picker overlay, await settle once before `endMediaPickerOverlay`.

   **Option B**: After every `pickAssets` await in `_sendImageMessage`, settle
   then let finally end overlay; ensure cancel path also settles.

   Avoid **double** settle (dispatch already settles on success) — either
   remove settle from `_dispatchCustomPickedGalleryMedia` and centralize in
   finally, or settle only when finally would end and depth→0.

4. Contract tests updated for new delay value and for settle-on-cancel
   (source contains check).

5. Manual: open album feels continuous (no empty flash); cancel/close without
   chat list flash under the sliding picker.

## Out of scope

- Switching default to system Photo Picker
- Rewriting `wechat_assets_picker` route transitions
- Full chat list virtualization
- Sticker / moments pickers unless they share `EditableAssetPicker` and the
  delay constant (if they inherit delay=0 automatically, fine; do not expand
  QA to all surfaces unless broken)

## Implementation steps

### Step 1 — Drift check

```bash
rg -n "initializeDelayDuration|_providerInitializeDelay|waitForPickerDismissSettle|endMediaPickerOverlay|_upgrade" \
  third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_edit/editable_asset_picker.dart \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_more_panel.dart \
  third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_edit/asset_picker_edit_builder_delegate.dart \
  test/chat_gallery_pick_routing_contract_test.dart
```

Confirm excerpts match.

### Step 2 — Cut initialize delay

In `editable_asset_picker.dart`:

```dart
static const Duration _providerInitializeDelay = Duration.zero;
```

Update `test/chat_gallery_pick_routing_contract_test.dart` expectations from
`250` to `0` (or `Duration.zero` string match).

```bash
flutter test test/chat_gallery_pick_routing_contract_test.dart
```

Expected: PASS.

**If** device QA shows empty first open after this change: STOP and report;
do not silently jump to 250 again — propose a **one-shot** delay only for
cold permission grant (permission just became authorized), not every open.

### Step 3 — Defer iOS thumbnail upgrade

In the thumbnail StatefulWidget inside
`asset_picker_edit_builder_delegate.dart` (the `_upgrade` caller after first
bytes):

- After first successful decode/`setState`, schedule `_upgrade` with
  `WidgetsBinding.instance.addPostFrameCallback` then
  `Future<void>.delayed(const Duration(milliseconds: 120))` (or
  `SchedulerBinding.scheduleTask` with `Priority.idle` if already used nearby).
- Keep generation / mounted / cancel-token guards.
- Do **not** block first-frame assignment (Android comment: first frame must
  paint or cells stay gray).

Optional unit/contract: source contains delayed upgrade scheduling (string
check). Full widget test not required.

### Step 4 — Settle before overlay end on all picker exits

Centralize to avoid cancel flash:

In `_runMediaTask` `finally` (more_panel), **before**
`globalModel.endMediaPickerOverlay()`:

```dart
await ChatGalleryPickUtils.waitForPickerDismissSettle();
globalModel.endMediaPickerOverlay();
```

Then remove the settle+early `endMediaPickerOverlay` from
`_dispatchCustomPickedGalleryMedia` and from the system-picker success branch
**if** they would double-end. Keep a single owner:

- begin in `_runMediaTask` try entry
- settle + end only in finally

Verify depth: begin once per task; finally ends once. Remove intermediate
`endMediaPickerOverlay()` calls that assumed early end (system path ~1601,
custom dispatch ~575) so depth does not hit 0 early then finally no-ops
without settle on other paths.

Also check `wide.dart` chat text field gallery path for the same pattern;
apply the same finally settle if it uses begin/end overlay.

```bash
rg -n "beginMediaPickerOverlay|endMediaPickerOverlay|waitForPickerDismissSettle" \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitTextField/
```

### Step 5 — Tests

```bash
flutter test \
  test/chat_gallery_pick_routing_contract_test.dart \
  test/gallery_send_perf_trace_contract_test.dart
```

Add or extend a small contract test asserting more_panel `_runMediaTask`
finally contains `waitForPickerDismissSettle` before `endMediaPickerOverlay`
(order via `indexOf`).

Expected: PASS.

### Step 6 — Manual checklist (NOT RUN OK without device)

1. Chat → + → 相册: no empty flash; grid appears with transition.
2. Cancel album: chat does not flash/rebuild under sliding picker.
3. Pick 1–2 images and send: still works; no multi-second hitch.
4. Cold install first permission grant: album not empty (if empty → STOP per
   Step 2).

## Done criteria

- [ ] Init delay is 0 (or approved ≤80ms with updated contract).
- [ ] iOS HQ upgrade deferred past first paint.
- [ ] Cancel and success both settle before overlay end notify.
- [ ] No double `endMediaPickerOverlay` that skips settle on cancel.
- [ ] Contract tests green.
- [ ] No `PhotoManager.clearFileCache` on open.

## In-scope files

- `third_party/.../editable_asset_picker.dart`
- `third_party/.../asset_picker_edit_builder_delegate.dart`
- `third_party/.../tim_uikit_more_panel.dart`
- Optionally `wide.dart` if same overlay pattern
- `test/chat_gallery_pick_routing_contract_test.dart`
- Optional new/extended settle-order contract test

## Explicitly out of scope files

- `wechat_assets_picker` package sources under `.pub-cache`
- Conversation list / message enter animations
- Plans 001–015

## STOP conditions

- Setting delay to 0 causes reproducible empty album on first open after
  permission grant — STOP; implement permission-just-granted one-shot delay
  only and report.
- Deferring upgrade leaves Android cells gray — STOP; ensure first-frame path
  untouched.
- Removing early `endMediaPickerOverlay` breaks send because something else
  required overlay depth 0 mid-task — STOP and report call sites.

## Test plan

1. Updated routing contract (delay value).
2. Settle-before-end order contract.
3. Manual open/cancel/send (Step 6).

## Maintenance notes

- Perf traces (`picker_prepare_begin`, `picker_first_thumbnail_displayed`)
  remain the way to measure open flash; keep them.
- If product later enables system Photo Picker again, keep settle-before-end
  in `_runMediaTask` finally so both routes stay safe.

## Escape hatches

- Feature flag const `kGalleryInitDelay = Duration.zero` for quick revert.
- HQ upgrade can be disabled entirely on low-end Android profiles if needed
  (not default in this plan).
