# Plan 058: Show stable gallery placeholders before PhotoKit export finishes

> **Executor instructions**: Follow this plan step by step. Run every verification
> command before moving on. Do not change image bytes, compression settings, SDK
> payloads, ordering, or retry semantics. When done, update this plan's row in
> `plans/README.md`.
>
> **Drift check (run first)**:
> `git diff --stat 9f7c46e..HEAD -- third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_more_panel.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart test/chat_media_optimistic_send_contract_test.dart test/chat_image_send_performance_contract_test.dart`
> If the media pipeline or optimistic identity code changed, compare the live code
> with Current state. STOP if stable identity or picker ownership no longer matches.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/054-media-send-off-main-isolate.md, plans/018-outgoing-image-dual-bubble.md
- **Category**: perf
- **Planned at**: commit `9f7c46e`, 2026-08-23
- **Current state**: implementation complete; automated tests pass; awaiting manual iPhone Profile interaction because wireless Xcode attach timed out after a successful build/install

## Why this matters

On iOS, a selected `AssetEntity` must be exported through PhotoKit before upload.
The current implementation resolves every selected image serially and only then
inserts optimistic bubbles. The 052 Profile measured about 31–80ms per image, so
the no-feedback interval grows linearly and feels like a frozen chat page. Keep
PhotoKit serial for memory safety, but make the chosen rows visible immediately.

## Current state

- `tim_uikit_more_panel.dart::_dispatchCustomPickedGalleryMedia` first builds
  `resolvedImages` in a serial loop, awaits `_resolveGalleryImageAsset`, then
  awaits `endOfFrame` for every item. Only after the loop does it call
  `beginOptimisticImagePlaceholders`.
- `editable_asset_picker.dart::resolveFileForChatSend` crosses the PhotoKit
  plugin boundary through `asset.file` and then `asset.originFile`. These objects
  must remain on the platform/plugin path and must not cross a Dart isolate.
- `tui_chat_separate_view_model.dart::beginOptimisticImagePlaceholders` already
  batches list insertion and assigns an outgoing stable ID, but assumes a usable
  local path.
- `tim_uikit_chat_image_elem.dart` currently treats a missing local path as a
  load failure. A pre-export placeholder therefore needs an explicit lightweight
  rendering state, not a fake filesystem path.
- Existing conventions to preserve: batched insertion, `existingOptimisticId`,
  `applyOutgoingStableIdToMessage`, cancellation by optimistic ID, iOS resolver
  concurrency of one, and Android upload concurrency of at most two.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Diff hygiene | `git diff --check` | exit 0 |
| Media contracts | `flutter test test/chat_media_optimistic_send_contract_test.dart test/chat_image_send_performance_contract_test.dart test/outgoing_image_bubble_dedupe_contract_test.dart` | all pass |
| Ordering | `flutter test test/message_ordering_test.dart` | all pass |
| Static check | `flutter analyze <changed Dart files>` | no new analyzer errors; repository-wide legacy diagnostics are out of scope |

## Scope

**In scope**:
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_more_panel.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/utils/chat_media_send_utils.dart` only if a typed placeholder marker belongs there
- the targeted media contract tests named above

**Out of scope**:
- increasing PhotoKit, compression, or Tencent SDK concurrency
- changing JPEG quality, dimensions, original bytes, SDK payload, retry policy,
  message ordering, upload protocol, or gallery product UI
- moving `AssetEntity`, plugin objects, or SDK messages into an isolate
- changing ordinary received-image rendering

## Git workflow

- Branch: `codex/058-stream-gallery-placeholders`
- Use focused conventional commits such as
  `perf: show gallery placeholders before export`.
- Do not push unless explicitly instructed.

## Steps

### Step 1: Add characterization tests before changing the pipeline

Extend `test/chat_media_optimistic_send_contract_test.dart` with source-contract
or unit tests proving:

- the batch placeholder call occurs before the first awaited PhotoKit resolve;
- one optimistic ID is created per selected image in original selection order;
- resolver failure cancels only its matching optimistic row;
- conversation switch cancels unresolved rows and cannot send into the old chat;
- PhotoKit remains serial on iOS;
- each successful resolve feeds the same `existingOptimisticId` into send.

**Verify**: run the media contract command. The new pre-export assertion should
fail against the old implementation; existing tests must stay green.

### Step 2: Represent a pre-export image row explicitly

Introduce a narrow placeholder input/state that contains only stable identity,
known `AssetEntity.orientatedWidth/Height`, selection position, and a boolean or
typed local marker meaning “source file pending.” Do not store `AssetEntity` in
the global model or a `V2TimMessage` payload. Do not invent a fake path.

Update `beginOptimisticImagePlaceholders` so it can batch-create these pending
rows with the same stable-ID machinery. Update `tim_uikit_chat_image_elem.dart`
to render a fixed-size neutral skeleton for this explicit state and to avoid
starting `FileImage` until a real path is bound.

**Verify**: media contracts pass; add a test proving the pending state does not
construct `FileImage(File(''))` and preserves the known aspect ratio.

### Step 3: Insert all placeholders before serial export

In `_dispatchCustomPickedGalleryMedia`, create the placeholder inputs directly
from `imageAssets` and call the batch insertion once before the resolve loop.
Keep the resolve loop serial. Map item index to its pre-created optimistic ID.
For each resolved file:

- validate size exactly as today;
- stage the exact same file;
- atomically bind the real local path and size to the existing row;
- enqueue send using that row's `existingOptimisticId`;
- on failure, oversize, cancellation, or conversation change, remove only that
  unresolved row.

Do not wait for all items before starting the first valid send. Use one bounded
producer/consumer queue: PhotoKit producer concurrency remains one on iOS;
existing upload workers remain one on iOS and at most two on Android.

**Verify**: media and ordering tests pass. Add a deterministic fake-resolver
test showing placeholder count becomes N before resolver 0 completes and item 0
can enter send while item 1 is still resolving.

### Step 4: Keep picker teardown and scroll ownership unchanged

Retain `_runMediaTask.finally` ownership of dismiss settle and
`endMediaPickerOverlay`. Issue no per-image global pin. The placeholder batch may
request one layout-settled pin; later path hydration and send completion must be
row-local.

**Verify**: existing picker close/scroll-lock tests pass and the new tests find
no `requestPinToBottom` inside the per-item resolve/send loop.

### Step 5: Profile on an iPhone

Run Profile mode with 1, 5, 10, and the configured maximum number of images,
including one HEIC and one iCloud-backed image. Capture:

- picker-confirm to placeholder-visible latency;
- per-item PhotoKit resolve time;
- build/raster slow frames;
- peak memory;
- send order and duplicate-row count.

Expected: placeholder-visible latency no longer scales with image count; upload
bytes and ordering match the pre-change baseline; no duplicate bubbles.

## Test plan

- Empty selection, one image, maximum images.
- Local JPEG, HEIC, iCloud image, oversize image, deleted/unavailable asset.
- Permission denial, cancel, conversation switch during resolve, app background.
- Slow upload, upload failure, retry, SDK echo arriving before/after adoption.
- Assert identical compression constants and final payload/path behavior.

## Done criteria

- [ ] Placeholders appear before the first PhotoKit resolve completes.
- [ ] PhotoKit and iOS upload concurrency remain one.
- [ ] Every selected row has one stable identity from placeholder through receipt.
- [ ] Failure/cancellation affects only the corresponding row.
- [ ] Targeted media and ordering tests pass.
- [ ] iPhone Profile shows placeholder latency independent of selection count.
- [ ] `git diff --check` passes and no out-of-scope files changed.

## STOP conditions

- A plugin or SDK object would need to cross a Dart isolate.
- Immediate placeholders require fake SDK messages that cannot retain stable IDs.
- The proposed path changes uploaded bytes, compression output, ordering, or retry.
- The picker no longer provides stable item order or oriented dimensions.
- Any test shows duplicate bubbles, cross-conversation send, or message loss.

## Maintenance notes

Reviewers should scrutinize cancellation and stable-ID ownership more than visual
polish. Future picker changes must preserve the rule: selection creates identity;
PhotoKit resolution only hydrates that identity and never creates another row.
