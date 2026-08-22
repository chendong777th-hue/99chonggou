# Plan 024: Fullscreen preview upgrades to true ORIGIN (stop BIG/SMALL soft blur)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> the "Current state" excerpts to live files. If
> `hasResolvableOriginalUrl` / `_previewOriginalNetworkEntries` already
> **only** consider SDK type `ORIGINAL` (0), and `shouldUpgradeToOriginal`
> still requests upgrade when the current provider is BIG while ORIGIN is
> downloadable, STOP and report — do not duplicate.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED (more ORIGIN downloads / memory on large images; must keep
  thumb as placeholder only; must not regress Plan 017 bubble decode caps)
- **Depends on**: none (orthogonal to 016–023; do **not** reopen 017 bubble
  `ResizeImage` / `kChatBubbleImageDecodeMaxPx`)
- **Category**: bug
- **Planned at**: working tree 2026-08-22 (`NO_GIT` — no `git rev-parse`)
- **Execution**: DONE (2026-08-22) — ORIGIN-only
  `hasResolvableOriginalUrl` / `resolveOriginal` / `hasLocalOriginal`;
  `shouldUpgradeToOriginal` true for BIG+msgID; `resolve` omits SMALL primary;
  ImageScreen + gallery post-refresh no longer aborts on stale
  `shouldUpgradeToOriginal(current)`; covered by
  `chat_message_preview_image_resolver_test.dart`.
- **Issue**: omit

## Why this matters

**Primary symptom (operator)**: after opening fullscreen preview and waiting
for settle / fan-reveal, the image is **still soft** — not just a brief
thumb flash on entry. First-frame placeholder softness is expected;
persistent softness after upgrade is the bug.

Root cause is **source tier stuck on LARGE (~720) / THUMB**, not GPU and
not bubble list decode (Plan 017):

1. Many received messages only expose **BIG/SMALL** URLs until an ORIGIN
   download runs. First screen may intentionally show BIG.
2. Post-load upgrade *looks* like it runs (`isImagePreviewResolutionTooLow`
   fires more on high DPR), but `hasResolvableOriginalUrl` /
   `resolveOriginal` treat **BIG/SMALL as “original”**. `refreshOriginal`
   then `preview_refresh_skip_http` and returns the **same BIG** provider.
3. `ImageScreen` / gallery then hit:

   ```dart
   if (!shouldUpgradeToOriginal(message, currentProvider) ||
       isSameImageProvider(originalProvider, currentProvider)) {
     _lowResolutionRefreshAttempted.add(index);
     return; // permanent: never try again this session
   }
   ```

   So settle completes on ~720px painted to a 3× screen → **依旧模糊**.
   Smaller / low-DPR devices often never enter this path and look OK.

Fix: **ORIGIN type (0) is the only “original”** for upgrade / download
gating. BIG remains first-screen fallback; after settle the UI must either
paint a true ORIGIN provider or leave an explicit failed-upgrade state —
never silently accept BIG as “upgrade done”.

## Current state

### Roles

- `third_party/tencent_cloud_chat_uikit/lib/ui/utils/chat_message_preview_image_resolver.dart`
  — picks preview / placeholder / “original” providers; `refreshOriginal`;
  `wrapPreviewDecode`.
- `third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_preview_resolution_utils.dart`
  — screen×DPR decode caps; `isImagePreviewResolutionTooLow`; tall
  `fitWidth` display.
- `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/image_screen.dart`
  — `_scheduleOriginalRefreshIfNeeded` → `refreshOriginal` + fan reveal.
- `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/chat_media_gallery_image_page.dart`
  — same upgrade path for mixed gallery.
- `third_party/tencent_cloud_chat_uikit/test/chat_message_preview_image_resolver_test.dart`
  — existing resolver contract tests (extend these).

### Excerpts (verify before editing)

`_previewOriginalNetworkEntries` includes BIG and SMALL (bug for “original”
semantics) — `chat_message_preview_image_resolver.dart`:

```dart
  static List<(V2TimImage?, int)> _previewOriginalNetworkEntries(
    V2TimMessage message,
  ) {
    final originalType =
        HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['ORIGINAL']!;
    final bigType = HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['BIG']!;
    final smallType = HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES['SMALL']!;
    return [
      (_imageBySdkType(message, originalType), originalType),
      (_imageBySdkType(message, bigType), bigType),
      (_imageBySdkType(message, smallType), smallType),
    ];
  }
```

`hasResolvableOriginalUrl` uses that list — so **BIG-only messages return
true** and skip ORIGIN download:

```dart
  static bool hasResolvableOriginalUrl(V2TimMessage message) {
    for (final entry in _previewOriginalNetworkEntries(message)) {
      final url = TencentUtils.checkString(entry.$1?.url);
      if (url != null && url.startsWith('http')) {
        return true;
      }
    }
    return false;
  }
```

`refreshOriginal` skip path (when the above is true):

```dart
    if (!hasLocalOriginal(message)) {
      if (hasResolvableOriginalUrl(message)) {
        ChatImgTrace.log(
          '[ChatImg] event=preview_refresh_skip_http msgId=$msgID',
        );
      } else {
        // getMessageOnlineUrl + downloadMessage(ORIGINAL) …
      }
    }
```

`resolve` first-screen priority (keep ORIGIN→BIG→SMALL for *initial*
paint, but Step 2 narrows SMALL out of primary when BIG missing is optional
tightening — see Steps):

```dart
  /// 全屏预览首屏：优先原图（THUMB 只作占位，无原图时再降级大图）。
  static ImageProvider? resolve(V2TimMessage message) {
    // … local then _previewBigNetworkEntries (ORIGIN, BIG, SMALL)
  }
```

`isImagePreviewResolutionTooLow` (keep; explains device variance) —
`image_preview_resolution_utils.dart`:

```dart
  final targetPixels =
      (mq.size.shortestSide * mq.devicePixelRatio * screenCoverage).round();
  final longestSide = imageWidth > imageHeight ? imageWidth : imageHeight;
  return longestSide < targetPixels;
```

ImageScreen post-refresh abort when providers match (will keep aborting on
BIG↔BIG until resolver is fixed) — around `_scheduleOriginalRefreshIfNeeded`
`runRefresh` after `refreshOriginal`.

### Conventions

- SDK types: `ORIGINAL=0`, `SMALL=1`, `BIG=2` in
  `HistoryMessageDartConstant.V2_TIM_IMAGE_TYPES`.
- Preview network cache keys: `chatMediaPreviewImageCacheKey(msgID, imageType: …)`
  in `chat_media_gallery_utils.dart` — keep type in cacheKey so ORIGIN and
  BIG never share entries.
- Placeholder must keep **bubble** cacheKey via
  `resolvePlaceholder` / `_cachedNetworkBubbleProvider`.
- Match test style in
  `third_party/tencent_cloud_chat_uikit/test/chat_message_preview_image_resolver_test.dart`
  (`_imageMessage` helper, `V2TIM_IMAGE_TYPE.*`).
- Do **not** change chat bubble decode (`resolveChatBubbleImageDecodeTarget`,
  `kChatBubbleImageDecodeMaxPx`) — Plan 017.

## Commands you will need

Run from **repo root** `/Users/qiu/Downloads/9925banben` unless noted.

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Resolver tests | `flutter test third_party/tencent_cloud_chat_uikit/test/chat_message_preview_image_resolver_test.dart` | All pass |
| Decode/resolution utils | `flutter test third_party/tencent_cloud_chat_uikit/test/image_preview_resolution_utils_test.dart` | All pass |
| Optional contract (if you add app-level file) | `flutter test test/fullscreen_preview_origin_upgrade_contract_test.dart` | All pass (only if file created) |

## Scope

**In scope** (only these):

- `third_party/tencent_cloud_chat_uikit/lib/ui/utils/chat_message_preview_image_resolver.dart`
- `third_party/tencent_cloud_chat_uikit/test/chat_message_preview_image_resolver_test.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/image_screen.dart`
  (only `_scheduleOriginalRefreshIfNeeded` / `runRefresh` abort condition)
- `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/chat_media_gallery_image_page.dart`
  (same abort condition mirror)
- Optionally add **pure** helpers + tests in
  `third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_preview_resolution_utils.dart`
  and `…/test/image_preview_resolution_utils_test.dart` **only if** you need a
  shared “provider is ORIGIN tier” / cacheKey type parse — prefer keeping
  helpers private/static on the resolver first.
- `plans/README.md` status row for 024

**Out of scope** (do NOT touch):

- Bubble list decode / Plan 017 (`tim_uikit_chat_image_elem.dart` bubble
  `ResizeImage`, `kChatBubbleImageDecodeMaxPx`, open-defer decode).
- Changing `imagePreviewDecodeScreenFactor` (1.45) or huge-image staged
  decode as the *primary* sharpness fix — only revisit if ORIGIN upgrade
  works and 1x zoom is still soft (STOP and report).
- Forcing `BoxFit.scaleDown` for tall chat images (product wants fitWidth).
- Web lightbox (`chat_web_image_lightbox.dart`).
- Video preview / snapshot cache width.
- App `lib/src/chat.dart` overlay recover (Plan 023).
- Git init / commit / push unless the operator asks.

## Git workflow

- Workspace often has **no `.git`**. Do not `git init`.
- If git exists: branch `advisor/024-fullscreen-preview-origin-upgrade`;
  conventional commits, e.g. `fix(preview): upgrade fullscreen images to ORIGIN type`.
- Do NOT push or open a PR unless instructed.

## Steps

### Step 1: Make “original URL / resolveOriginal” ORIGIN-type-only

In `chat_message_preview_image_resolver.dart`:

1. Add a dedicated network entry list for **true ORIGIN only**, e.g.
   `_previewOriginTypeNetworkEntries` returning only
   `(_imageBySdkType(message, originalType), originalType)`.
2. Change `hasResolvableOriginalUrl` to iterate **only** that ORIGIN-type
   list (http URL on type 0). **BIG-only must return false.**
3. Change `resolveOriginal` network fallback to use **ORIGIN-type only**
   (still keep `_localOriginalPreviewFile` which already prefers self path /
   original localUrl / big localUrl — **narrow local fallback**: for
   *upgrade target*, prefer original localUrl / self path; do **not** treat
   big `localUrl` as satisfying `hasLocalOriginal` if that blocks ORIGIN
   download).

   Concrete `hasLocalOriginal` rule after this step:

   - `true` only when self `imageElem.path` exists **or** ORIGIN type
     `localUrl` file exists.
   - BIG `localUrl` alone must **not** make `hasLocalOriginal` true.

4. Keep `_previewBigNetworkEntries` / `resolve()` as first-screen ladder
   **ORIGIN → BIG → SMALL** for now (Step 3 optionally drops SMALL from
   primary).

**Verify**:

```bash
# Temporary expect: existing test 'returns true when original url exists' still
# passes; add failing tests in Step 4 if you write tests before code — prefer
# write tests in Step 4 in the same change set.
flutter test third_party/tencent_cloud_chat_uikit/test/chat_message_preview_image_resolver_test.dart
```

If you only changed production code first, some tests may still pass; Step 4
adds the BIG-only assertions.

### Step 2: Fix `shouldUpgradeToOriginal` + `refreshOriginal` download gate

**`shouldUpgradeToOriginal(message, currentProvider)`** must become true when
any of:

- True ORIGIN provider (local ORIGIN file or ORIGIN http with ORIGIN
  cacheKey) exists and differs from `currentProvider`; **or**
- Current provider is clearly non-ORIGIN (BIG/SMALL cacheKey, or decoded
  path already handled by ImageScreen’s too-low check) **and** ORIGIN is
  obtainable (`hasResolvableOriginalUrl` **or** non-empty `msgID` so
  `downloadMessage` can run).

When `resolveOriginal` is null but `msgID` is present, still return
**true** if `currentProvider` is not already ORIGIN-tier — so ImageScreen /
gallery will call `refreshOriginal`.

**`refreshOriginal`**:

- Skip HTTP-only path (`preview_refresh_skip_http`) **only** when
  `hasResolvableOriginalUrl` (ORIGIN type URL) **or** `hasLocalOriginal`
  (ORIGIN local / self path).
- If ORIGIN URL missing: keep `getMessageOnlineUrl`, then if still no ORIGIN
  URL, `downloadMessage(..., imageType: ORIGINAL)`.
- After download/online, return `resolveOriginal` (ORIGIN-only). If still
  null, return null (caller keeps BIG). Do **not** return BIG disguised as
  original.

**ImageScreen / gallery** (`image_screen.dart` +
`chat_media_gallery_image_page.dart`) — **required harden** for the
「进入后依旧模糊」abort:

In `runRefresh` after `refreshOriginal`:

- If `originalProvider == null`: mark attempted once (avoid spin); keep
  showing BIG (honest failure).
- If `isSameImageProvider(originalProvider, currentProvider)`: mark
  attempted; do **not** pretend upgrade succeeded (this is today’s
  permanent-blur path when BIG is returned as “original”).
- If providers differ: **apply upgrade** (`_completeOriginalUpgrade` /
  fan reveal). Do **not** also require
  `shouldUpgradeToOriginal(message, currentProvider)` to still be true —
  that gate already decided to call `refreshOriginal`; the second
  `shouldUpgradeToOriginal(current)` check is what aborts when
  `resolveOriginal` used to equal BIG. Remove that conjunct (keep only
  the same-provider / null checks).

Scope expansion: these two widget files are in-scope for this step only
(logic deletion / null-attempt mark). No Hero / slide / decode-factor
changes.

**Verify**: analyzer-clean; unit tests in Step 4; grep that the post-refresh
block no longer requires `shouldUpgradeToOriginal(message, currentProvider)`
as a reason to abort after a successful distinct `originalProvider`.

### Step 3 (optional but recommended): Do not use SMALL as fullscreen *primary*

In `_previewBigNetworkEntries` / `resolve` network loop: stop after ORIGIN
and BIG — **omit SMALL** from primary `resolve()`. Placeholder already
covers SMALL via `resolvePlaceholder`.

Update / replace test `prefers big image url for received when original missing`
still expects BIG. Add: when **only** SMALL URL exists, `resolve` returns
`null` (or only FileImage self-path), and placeholder returns SMALL.

**Verify**: resolver tests pass.

### Step 4: Tests (required)

Extend
`third_party/tencent_cloud_chat_uikit/test/chat_message_preview_image_resolver_test.dart`:

| Case | Expect |
|------|--------|
| `hasResolvableOriginalUrl` with **only BIG** http URL | `false` |
| `hasResolvableOriginalUrl` with ORIGIN http URL | `true` (existing) |
| `hasLocalOriginal` with only BIG `localUrl` file | `false` |
| `hasLocalOriginal` with ORIGIN `localUrl` file | `true` |
| `resolveOriginal` with only BIG URL | `null` |
| `resolveOriginal` with ORIGIN URL | ORIGIN provider + ORIGIN cacheKey |
| `shouldUpgradeToOriginal` when current is BIG provider and ORIGIN URL exists | `true` (existing pattern) |
| `shouldUpgradeToOriginal` when current is BIG and **only BIG** URL but `msgID` set | `true` (downloadable) |
| `shouldUpgradeToOriginal` when current is already ORIGIN provider | `false` |
| If Step 3 done: only SMALL URL → `resolve` null, placeholder non-null | |

Also add one pure test in
`image_preview_resolution_utils_test.dart` documenting device variance
(optional, documents intent):

- `isImagePreviewResolutionTooLow` for 720×960 vs logical 390×844 @ DPR 3
  → `true`
- same 720×960 vs logical 320×568 @ DPR 2 → may be `false` or true; assert
  the **formula** with fixed numbers so executors don’t bikeshed product
  thresholds — e.g. targetPixels = round(390*3*0.85)=994 → 960 < 994 → true.

**Verify**:

```bash
flutter test third_party/tencent_cloud_chat_uikit/test/chat_message_preview_image_resolver_test.dart \
  third_party/tencent_cloud_chat_uikit/test/image_preview_resolution_utils_test.dart
```

→ all pass, including new cases.

### Step 5: Index

Update `plans/README.md`: set plan **024** status to **DONE** (or leave
IN PROGRESS until verify), add dependency note, and the findings blurb
already drafted by the advisor if missing.

**Verify**: `rg "024" plans/README.md` shows status row.

## Test plan

- Primary: extend UIKit
  `chat_message_preview_image_resolver_test.dart` (table above).
- Pattern: existing `shouldUpgradeToOriginal when big and original differ`.
- Do **not** require instrumented SDK download in unit tests; assert pure
  gating (`hasResolvableOriginalUrl`, `shouldUpgradeToOriginal`,
  `resolveOriginal` null on BIG-only).
- Manual (operator, NOT RUN in CI) — **acceptance for「进入后依旧模糊」**:
  1. Open a received image that used to stay soft after fullscreen settle
     on a 3× device.
  2. Wait until entrance latch / fan reveal finishes (no spinner).
  3. Image must look sharp at 1× (not bubble-thumb soft). Logs should show
     real ORIGIN path (`preview_refresh_download` or ORIGIN http), **not**
     `preview_refresh_skip_http` when the message only had a BIG URL
     beforehand.
  4. Re-open the same message — still sharp (ORIGIN cached / localUrl).

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `hasResolvableOriginalUrl` is **false** for BIG-only / SMALL-only
      fixtures (new tests green)
- [ ] `resolveOriginal` does not return BIG/SMALL network providers
- [ ] `hasLocalOriginal` is **false** when only BIG local file exists
- [ ] `shouldUpgradeToOriginal` is **true** for BIG current + msgID when
      ORIGIN URL absent (download path can run)
- [ ] `flutter test third_party/tencent_cloud_chat_uikit/test/chat_message_preview_image_resolver_test.dart`
      exits 0
- [ ] `flutter test third_party/tencent_cloud_chat_uikit/test/image_preview_resolution_utils_test.dart`
      exits 0
- [ ] No edits under bubble decode / Plan 017 paths (`git status` /
      file list)
- [ ] `plans/README.md` row 024 updated

## STOP conditions

Stop and report (do not improvise) if:

- Live excerpts no longer match “Current state” (already ORIGIN-only).
- Fix appears to require raising `imagePreviewDecodeScreenFactor` or
  removing tall `fitWidth` to get sharpness **after** ORIGIN actually loads
  (that is a separate plan).
- `downloadMessage` / `MessageService` API for ORIGIN type changed and
  existing call site no longer compiles — report SDK signature; do not
  invent alternate download APIs.
- You believe bubble `ResizeImage` must change to fix fullscreen blur —
  that contradicts this plan; STOP.
- Tests need a fake `MessageService` registration you cannot wire without
  large test harness — keep tests pure on gating helpers; do not skip the
  gating tests.

## Maintenance notes

- Reviewers: confirm cacheKeys still embed `imageType` so ORIGIN and BIG
  never collide; confirm placeholder still uses **bubble** cacheKey.
- Future zoom-beyond-1.45× softness is expected with current decode cap —
  not this bug.
- If ORIGIN files are multi‑MB, staged huge-image decode
  (`imagePreviewHugeLongestSidePx`) still applies — do not disable it here.
- Follow-up (out of scope): prefetch ORIGIN on bubble visibility for
  zero-wait sharpness (bandwidth tradeoff).
