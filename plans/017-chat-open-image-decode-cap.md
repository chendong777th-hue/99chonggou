# Plan 017: Cap image-bubble decode cost on chat open (image-heavy rooms)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> the "Current state" excerpts to live files. If any in-scope symbol already
> matches the target behavior (layout probe never calls
> `ScreenshotHelper.getImageSize`, local bubble images always pass
> `cacheWidth`/`cacheHeight` or `ResizeImage`, and open-settling forces
> `deferHeavyDecode`), STOP and report — do not duplicate.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (brief softer thumbs on open; layout size must stay correct)
- **Depends on**: none (independent of 016 gallery flash)
- **Category**: perf
- **Planned at**: working tree 2026-08-22 (`NO_GIT` — no `git rev-parse`)
- **Execution**: DONE (2026-08-22) — layout probe uses `readLocalImageSizeSync`;
  local/network bubbles always `ResizeImage`/`cacheWidth`; open settling
  `beginChatOpenImageDecodeDefer` (700ms) via history list probe; covered by
  `test/chat_open_image_decode_contract_test.dart`.

## Why this matters

Entering a chat whose recent window is mostly images feels slow and hitchy.
The product already pulls ~40 messages on open
(`HistoryMessageDartConstant.initialOpenFetchCount`) and mounts many
`TIMUIKitImageElem` widgets near the reversed list viewport + `cacheExtent`.

Two concrete costs dominate **after** history is already in memory:

1. **Unbounded / oversized bitmap decode** — when the bubble source is treated
   as a “thumb”, local `Image.file` / `FileImage` omit `cacheWidth` /
   `cacheHeight` and skip `ResizeImage`, so the engine may decode the full
   file pixels even though the bubble is only ~132–176 logical px tall.
   Non-thumb path still allows up to `kChatBubbleImageDecodeMaxPx` (1920)
   while the list is idle at the bottom (open case), so many bubbles decode
   “full iron” in the same frame window.
2. **Layout probe full decode** — when SDK/meta size is missing,
   `_probeLocalImageLayout` calls `ScreenshotHelper.getImageSize`, which
   `readAsBytes()` the **entire** file and resolves `Image.memory` — a full
   decode into the image pipeline — just to learn width/height. A cheaper
   header reader (`readLocalImageSizeSync`) already exists for JPEG/PNG.

Prefetch (`ChatImageMessagePrefetch`) only warms ~10 thumbs and does not
remove first-paint decode storms. This plan does **not** change first-window
message count, URL resolve batching, or transcript semantics.

## Current state

Relevant files:

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart`
  — image bubble; layout probe + local/network paint
- `third_party/tencent_cloud_chat_uikit/lib/ui/utils/screen_shot.dart`
  — `ScreenshotHelper.getImageSize` full-file decode
- `third_party/tencent_cloud_chat_uikit/lib/ui/utils/chat_media_send_utils.dart`
  — `readLocalImageSizeSync`, `resolveChatBubbleImageDecodeTarget`,
    `kChatBubbleImageDecodeMaxPx` / `kChatBubbleImageDecodeScrollDeferMaxPx`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
  — `shouldSkipHeavyChatListPresentation` / Android history defer
- `third_party/tencent_cloud_chat_uikit/lib/ui/constants/history_message_constant.dart`
  — `initialOpenFetchCount = 40` (**do not change** in this plan)
- `lib/utils/chat_image_message_prefetch.dart` — open prefetch (out of scope
  except do not break cache keys)
- `lib/src/services/chat_open_perf_log.dart` — optional operator measurement

### Excerpt A — thumb path skips resize / cache dims

```dart
// tim_uikit_chat_image_elem.dart (~1596–1702)
final decodeNativeThumb = sourceIsThumb;
final decodeTarget = decodeNativeThumb
    ? const ChatBubbleImageDecodeTarget()
    : resolveChatBubbleImageDecodeTarget(...);

final ImageProvider localProvider = decodeNativeThumb
    ? FileImage(File(imgPath)) as ImageProvider
    : ResizeImage(FileImage(File(imgPath)),
        width: decodeTarget.width, height: decodeTarget.height);

// Image.file(..., cacheWidth: decodeNativeThumb ? null : decodeTarget.width, ...)
```

### Excerpt B — layout probe full decode

```dart
// tim_uikit_chat_image_elem.dart (~515–526)
Future<void> _probeLocalImageLayout(String path, int token) async {
  final size = await ScreenshotHelper.getImageSize(path);
  // ...
}

// screen_shot.dart (~93–102)
static Future<Size> getImageSize(String imagePath) async {
  final bytes = await File(imagePath).readAsBytes();
  final imageStream =
      Image.memory(bytes).image.resolve(ImageConfiguration.empty);
  // completes with decoded width/height
}
```

### Excerpt C — cheap header size already exists

```dart
// chat_media_send_utils.dart (~832–861)
/// 同步读取本地图片显示尺寸（JPEG/PNG 头 + EXIF 方向），冷启动首帧可用。
Size? readLocalImageSizeSync(String sourcePath) { ... }
```

### Excerpt D — defer only while scrolling / Android off-bottom

```dart
// tui_chat_global_model.dart (~324–352)
bool get shouldSkipHeavyChatListPresentation {
  if (isChatListUserScrolling) return true;
  // ... post-scroll window ...
  return _shouldDeferHeavyBubbleDecodeForAndroidHistory();
}
```

Open-at-bottom on iOS currently does **not** defer → many bubbles use 1920px
decode budget together.

### Conventions to match

- Prefer pure helpers + unit tests under
  `third_party/tencent_cloud_chat_uikit/test/chat_bubble_image_display_size_test.dart`
  and app `test/chat_bubble_local_image_test.dart` style (small focused groups).
- Chinese comments explaining **why** are OK on non-obvious perf gates (see
  existing comments on `kChatBubbleImageDecodeScrollDeferMaxPx`).
- Do not change which SDK image **type** the bubble selects for display
  (still prefer thumb for list); only change decode **pixel budget** and
  size-probe IO.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| UIKit bubble decode tests | `flutter test third_party/tencent_cloud_chat_uikit/test/chat_bubble_image_display_size_test.dart` | All pass |
| App local-image contract | `flutter test test/chat_bubble_local_image_test.dart` | All pass |
| New open-decode contract (after Step 4) | `flutter test test/chat_open_image_decode_contract_test.dart` | All pass |
| Prefetch cache key smoke | `flutter test test/chat_image_message_prefetch_test.dart` | All pass |

Do **not** require full-repo `flutter analyze` green (historical noise).

## Scope

**In scope** (only these may change):

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/utils/chat_media_send_utils.dart`
  (only if you add a tiny pure helper for “always resolve decode target for
  bubble display”; prefer keeping logic here over bloating the widget)
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
- Optional thin arming call from **one** of:
  - `lib/src/chat.dart` (after prepare gate / layout ready), **or**
  - `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart`
    when `ChatHistoryOpenLayoutReady.signal` / first messages visible
  Prefer **global model API** + **one** call site; do not arm from both.
- Tests:
  - `third_party/tencent_cloud_chat_uikit/test/chat_bubble_image_display_size_test.dart`
    (extend)
  - `test/chat_open_image_decode_contract_test.dart` (**create**)
- `plans/README.md` status row for 017

**Out of scope** (do NOT touch):

- `HistoryMessageDartConstant.initialOpenFetchCount` / peek counts
- `ChatImageMessagePrefetch` concurrency / warm caps (unless a test import
  breaks — then only fix imports)
- Fullscreen preview / gallery (`ImageScreen`, `ChatMediaGalleryScreen`)
- `ScreenshotHelper.getImageSize` itself (other callers may still need it;
  only stop **bubble layout probe** from using it as the primary path)
- Conversation list, wallet, calls, moments, QR, link/mention plans 006–008
- Changing bubble max **layout** width/height constants
- Turning `ChatOpenPerfLog.enabled` on permanently

## Git workflow

- No `.git` in this workspace historically — do not `git init`.
- If the operator has git: branch `advisor/017-chat-open-image-decode`,
  commit message style like existing plans:
  `perf(chat): bound bubble image decode on open`

## Steps

### Step 1: Layout probe — prefer header sync size; never full-decode first

In `_probeLocalImageLayout` (`tim_uikit_chat_image_elem.dart`):

1. Call `readLocalImageSizeSync(path)` first.
2. If it returns a positive size, use it (same setState / silent rules as
   today).
3. Only if sync returns null, you may keep a **fallback**. Prefer:
   - no fallback (leave placeholder aspect until network meta arrives), **or**
   - a documented last resort that does **not** use
     `ScreenshotHelper.getImageSize` (full `readAsBytes` + `Image.memory`).
4. Add a one-line comment: probe must not full-decode for layout.

Also ensure `_scheduleLocalImageLayoutProbe` is still only reached when
`_localLayoutSizeForRender` already failed meta / sync paths (current
control flow around lines 631–654). Do not schedule probes when
`preferChatBubbleImageLayoutMeta` already produced size.

**Verify**:

```bash
rg -n "ScreenshotHelper\.getImageSize" \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart
```

→ **no matches** (probe no longer calls it).

```bash
rg -n "readLocalImageSizeSync" \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart
```

→ at least one hit inside `_probeLocalImageLayout` (or probe deleted because
sync path already covered — then document in PR note).

### Step 2: Always bound local bubble decode to display size

In `_renderAllImage` local paint path:

1. **Remove** the special case that sets
   `decodeNativeThumb ? const ChatBubbleImageDecodeTarget()` and
   `FileImage` without `ResizeImage`.
2. Always compute `decodeTarget` via
   `resolveChatBubbleImageDecodeTarget(...)` (same args as today for
   non-thumb: display size, dpr, `deferHeavyDecode`, tall-crop flag).
3. Always use `ResizeImage` **or** `Image.file` with non-null
   `cacheWidth`/`cacheHeight` from `decodeTarget` (match existing non-thumb
   pattern). Thumb sources still use **thumb files/URLs** — only the decode
   budget changes.
4. Keep `FilterQuality` reasonable (medium for thumb-sized sources is OK).

Target invariant for list bubbles:

> Local bubble paint must never request an unbounded decode when
> `displaySize` is known.

**Verify**:

```bash
rg -n "decodeNativeThumb" \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart
```

→ either **zero** matches, or only used for non-decode concerns (e.g.
filterQuality) — **must not** gate `cacheWidth`/`ResizeImage` off.

```bash
flutter test third_party/tencent_cloud_chat_uikit/test/chat_bubble_image_display_size_test.dart
```

→ all pass (extend tests if you add a helper).

### Step 3: Open-settling window forces light decode budget

Extend `TUIChatGlobalModel`:

1. Add something equivalent to:
   - `void beginChatOpenImageDecodeDefer({Duration ttl = const Duration(milliseconds: 700)})`
   - clears via `Timer` / timestamp compare
   - `bool get isChatOpenImageDecodeDeferActive`
2. Fold into `shouldSkipHeavyChatListPresentation` (or
   `_shouldDeferHeavyBubbleDecode` path used by image elem):
   if open-defer active → treat like scroll defer (`true`).
3. Arm **once** when open history becomes interactively ready, e.g. after
   `ChatHistoryOpenLayoutReady` becomes ready / first messages visible /
   `prepare_gate_complete` sibling — pick the earliest moment that is **after**
   the list will mount images, not before route push (or defer is useless).
4. Clear early on user scroll start if easy (optional); TTL alone is enough.
5. Do **not** lengthen beyond ~1s without operator approval.

This makes open-at-bottom use `kChatBubbleImageDecodeScrollDeferMaxPx` (720)
instead of 1920 for the first burst, then upgrades naturally on rebuild when
defer ends (gaplessPlayback should avoid flash if same provider key — if
keys change, prefer keeping provider cache key stable; STOP if you must
change keys and cannot avoid flash).

**Verify**:

```bash
rg -n "beginChatOpenImageDecodeDefer|isChatOpenImageDecodeDeferActive|ChatOpenImageDecodeDefer" \
  third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart \
  lib/src/chat.dart \
  third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart
```

→ arming API exists on global model; **exactly one** production call site
arms it.

### Step 4: Contract tests

Create `test/chat_open_image_decode_contract_test.dart` that asserts **source
text** contracts (same style as other `*_contract_test.dart` files in `test/`):

1. `tim_uikit_chat_image_elem.dart` does not contain
   `ScreenshotHelper.getImageSize`.
2. Local bubble path does not contain the pattern
   `cacheWidth: decodeNativeThumb ? null` (or equivalent unbounded gate).
3. `tui_chat_global_model.dart` contains the open-defer symbol and
   `shouldSkipHeavyChatListPresentation` references it.

Optional pure unit: if you extracted
`resolveChatBubbleImageDecodeTarget` usage helper, assert thumb+defer yields
≤ `kChatBubbleImageDecodeScrollDeferMaxPx`.

**Verify**:

```bash
flutter test test/chat_open_image_decode_contract_test.dart \
  test/chat_bubble_local_image_test.dart \
  test/chat_image_message_prefetch_test.dart \
  third_party/tencent_cloud_chat_uikit/test/chat_bubble_image_display_size_test.dart
```

→ all pass.

### Step 5: Update plans index

Set plan 017 status to `DONE` in `plans/README.md` (or `IN PROGRESS` while
working). Do not rewrite unrelated rows.

## Test plan

| Case | Where |
|------|--------|
| Header size still preferred over probe | Existing `_localLayoutSizeForRender` + Step 1 |
| Decode target under defer ≤ 720 | Extend `chat_bubble_image_display_size_test.dart` |
| Source contracts for open decode | New `test/chat_open_image_decode_contract_test.dart` |
| Prefetch cache key unchanged | `test/chat_image_message_prefetch_test.dart` |

Manual (operator, not blocking DONE):

1. Open a C2C/group chat with ≥15 recent images (warm and cold).
2. Confirm first paint shows roughly correct bubble aspect (no long stretch
   flash).
3. Optional: temporarily enable `ChatOpenPerfLog.enabled` and compare
   `messages_first_visible` / hitch feel — do not leave enabled.

## Done criteria

Machine-checkable. ALL must hold:

- [ ] `rg ScreenshotHelper.getImageSize …/tim_uikit_chat_image_elem.dart` → no matches
- [ ] Local list bubbles always pass bounded `cacheWidth`/`cacheHeight` or `ResizeImage` (no thumb unbounded gate)
- [ ] Open-settling defer exists on `TUIChatGlobalModel` and is armed from exactly one call site
- [ ] `flutter test test/chat_open_image_decode_contract_test.dart` passes
- [ ] `flutter test third_party/tencent_cloud_chat_uikit/test/chat_bubble_image_display_size_test.dart` passes
- [ ] `flutter test test/chat_bubble_local_image_test.dart test/chat_image_message_prefetch_test.dart` pass
- [ ] No files outside Scope modified
- [ ] `plans/README.md` row 017 updated

## STOP conditions

Stop and report (do not improvise) if:

- Excerpts A–D no longer match live code in a way that makes Steps 1–3
  ambiguous.
- Bounding decode causes systematic wrong aspect (e.g. square thumbs force
  wrong bubble) — do not “fix” by switching layout meta to thumb pixels;
  report with a sample msgID.
- Open defer causes permanent soft/blurry bubbles (timer never clears) —
  fix timer or STOP.
- You believe the only fix is lowering `initialOpenFetchCount` or rewriting
  list virtualization — out of scope; report as follow-up finding.
- Fix appears to require editing fullscreen preview / gallery / prefetch
  caps.

## Maintenance notes

- Reviewers should check: open-defer TTL, single arm site, no double
  `setState` storms, and that preview-on-tap still loads large/original
  (list path only).
- If Instruments later shows URL resolve (`getMessageOnlineUrl`) dominating
  instead of decode, file a **separate** plan — do not expand 017.
- Follow-up (not this plan): visibility-gated decode (only paint when
  `VisibilityDetector` fraction > 0) — higher risk of blank tiles; defer.
- `ScreenshotHelper.getImageSize` remains for non-bubble callers; do not
  delete the API unless a later plan migrates all call sites.
