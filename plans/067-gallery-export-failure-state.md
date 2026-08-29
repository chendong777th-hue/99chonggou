# Plan 067: Make gallery export failures visible and retryable

> **Executor instructions**: Follow the steps in order. This plan fixes the point before Tencent SDK message creation where selected assets can disappear silently.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED
- **Depends on**: none
- **Category**: bug
- **Planned at**: commit `9f7c46e`, 2026-08-23

## Why this matters

`EditableAssetPicker.resolveFileForChatSend` can return null or throw for iCloud/PhotoKit, limited permissions, deleted assets, or Android MediaStore failures. `_resolveGalleryImageAsset` converts that to null and the caller removes the placeholder without a user-visible error. The result is exactly “no bubble, no send, nothing after restart.”

## Current state

- `third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_edit/editable_asset_picker.dart:138-171` tries edited file, `asset.file`, then `asset.originFile`.
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitTextField/tim_uikit_more_panel.dart:503-535` returns null on missing file, size read failure, or exception.
- `.../tim_uikit_more_panel.dart:642-660` cancels the matching optimistic row on resolve failure without a user-visible failure state.
- `third_party/tencent_cloud_chat_uikit/lib/ui/utils/gallery_send_perf_trace.dart` already provides non-release stage logging; extend it without logging real paths or PII.

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Tests | `flutter test test/chat_media_optimistic_send_contract_test.dart test/gallery_send_perf_trace_contract_test.dart` | all pass |
| Static check | `flutter analyze third_party/tencent_cloud_chat_uikit/lib/ui/utils/image_edit third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitTextField` | no new analyzer errors |

## Scope

**In scope**: gallery resolver, mobile gallery dispatch, media operation UI state, performance trace fields, and focused tests.

**Out of scope**: image bytes, compression quality/dimensions, Tencent SDK payload, upload concurrency, picker visual design, and message ordering.

## Steps

### Step 1: Define typed export outcomes

Replace nullable-only resolution with a typed outcome distinguishing success, permission denied/limited, cloud download timeout, missing resource, unsupported/corrupt file, oversize, and transient platform failure. Keep asset IDs opaque and never log filesystem paths.

**Verify**: unit tests cover every outcome and assert no sensitive path is present in trace output.

### Step 2: Add bounded retry and fallback

For transient PhotoKit/MediaStore failures, retry a small fixed number with backoff and a hard timeout. If the custom resolver cannot produce a stable file, attempt the existing system picker fallback where platform-appropriate. Do not retry indefinitely or block the UI isolate.

**Verify**: fake resolver tests prove timeout terminates, retry count is bounded, and fallback is invoked only for recoverable platform failures.

### Step 3: Separate operation state from message rows

Expose a `PendingMediaUiState` keyed by operation ID. Show “processing”, “download required”, “failed—retry”, or “unsupported” independently of the canonical message list. Do not create or delete a fake `V2TimMessage` for pre-SDK export work.

**Verify**: a failed export leaves no business message but does leave a visible retryable operation state; a successful export clears the operation state before SDK message creation.

### Step 4: Instrument the full boundary

Add trace events for asset type/platform, permission class, resolver source, elapsed time, outcome category, retry count, and fallback outcome. Preserve existing event names where tests depend on them. Never include actual asset paths, user IDs, or image bytes.

**Verify**: a synthetic failure trace contains `resolve_file_begin`, a categorized terminal event, and no `send_begin`; a successful trace contains `image_send_queue_start` and `send_begin`.

## Done criteria

- [ ] No gallery resolve failure silently disappears without a visible retry/error state.
- [ ] Retries and fallback are bounded and tested.
- [ ] Trace output is categorized and privacy-safe.
- [ ] Existing media and trace tests pass.

## STOP conditions

- Platform APIs cannot distinguish transient download from permanent permission/resource failure; stop and document the limitation rather than guessing.
- Fallback requires changing SDK versions or public picker contracts.

## Maintenance notes

Keep this boundary independent from SDK message projection. A file that never reaches `createImageMessage` must be represented as an operation failure, not as a chat message.
