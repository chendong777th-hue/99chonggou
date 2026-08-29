# Plan 059: Stagger gallery bubble decode and use one settled bottom pin

> **Executor instructions**: Execute only after Plan 058 is DONE. Follow every
> verification gate. This plan changes scheduling, not image quality or message
> semantics.
>
> **Drift check (run first)**:
> `git diff --stat 9f7c46e..HEAD -- third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_image_elem.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
> STOP if Plan 058 is not present or if outgoing-media settle ownership changed.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/058-stream-gallery-placeholders-before-photokit.md
- **Category**: perf
- **Planned at**: commit `9f7c46e`, 2026-08-23
- **Current state**: implementation complete; 37 targeted tests pass; awaiting manual iPhone Profile comparison

## Why this matters

After multi-image placeholders become visible, several local images can start
decode, texture upload, row measurement, and bottom compensation in adjacent
frames. The code limits decode dimensions, but does not limit how many outgoing
local images begin decode together. The batch also requests an immediate pin and
a post-layout pin. This plan spreads decode admission across frames and makes
bottom positioning one explicit settled transaction.

## Current state

- `tim_uikit_chat_image_elem.dart::buildLocalImage` immediately constructs
  `ResizeImage(FileImage(...))` and `Image.file` for every visible local path.
- `tim_uikit_chat_history_message_list.dart` holds outgoing-media settle for
  1200ms and performs measurement/list-push compensation.
- `beginOptimisticImagePlaceholders` calls `requestPinToBottom(force: true)`;
  `tim_uikit_more_panel.dart` requests another force pin after `endOfFrame`.
- Target decode dimensions and existing scroll-defer behavior are authoritative;
  do not reduce visual quality.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Decode contracts | `flutter test test/chat_bubble_local_image_test.dart test/chat_image_message_prefetch_test.dart test/chat_open_image_decode_contract_test.dart` | all pass |
| Media/scroll contracts | `flutter test test/chat_media_optimistic_send_contract_test.dart test/media_preview_chat_scroll_lock_contract_test.dart test/outgoing_image_bubble_dedupe_contract_test.dart` | all pass |
| Hygiene | `git diff --check` | exit 0 |

## Scope

**In scope**:
- local outgoing-image decode admission in `tim_uikit_chat_image_elem.dart`
- outgoing-media settle/pin coordination in the history list and more panel
- narrowly scoped tests for decode scheduling and one settled pin

**Out of scope**:
- changing `cacheWidth/cacheHeight`, filter quality, preview/original selection,
  received network-image behavior, general list virtualization, or media payloads
- changing PhotoKit/export/upload concurrency

## Git workflow

- Branch: `codex/059-stagger-gallery-decode`
- Commit example: `perf: stagger outgoing gallery decode`.
- Do not push unless instructed.

## Steps

### Step 1: Characterize current burst behavior

Add tests that model a batch of outgoing local image rows and assert the desired
contract: only a bounded number receive decode admission per frame, admission is
FIFO for equally visible rows, offscreen rows wait, and disposal cancels pending
admission. Add a scroll contract proving the batch owns one settled force pin.

**Verify**: new assertions fail before implementation; existing decode tests pass.

### Step 2: Add a conversation-scoped decode admission coordinator

Implement a small coordinator keyed by canonical conversation and stable message
identity. It may admit at most one or two new local outgoing decodes per frame;
choose the smallest value that passes the iPhone Profile gate. Visible rows have
priority over prefetch rows. The coordinator must remove disposed rows, reset on
conversation change, and never delay an already cached image.

Before admission, render the fixed-size pending/skeleton state established by
Plan 058. After admission, reuse the existing `ResizeImage`, `cacheWidth`,
`cacheHeight`, frame builder, and error handling unchanged.

**Verify**: decode admission tests and existing image tests pass.

### Step 3: Replace double pin with one settled batch transaction

Give the optimistic batch a token/generation. The immediate list commit records
the intent to pin but does not run a competing force pin. After the first stable
layout frame, the history list consumes the token once and performs one force
pin while retaining the existing retry/settle protections. Path hydration,
decode completion, adoption, and upload receipt must not create new force pins.

**Verify**: a test counts exactly one consumed force-pin transaction for a batch,
including delayed decode and picker dismissal.

### Step 4: Profile the burst

On iPhone Profile, send 1, 5, 10, and maximum images in a 360-message chat.
Compare build/raster slow frames, peak memory, scroll stability, and time until
the newest placeholder is visible. Ensure single-image behavior does not regress.

## Test plan

- Cached vs uncached local images; portrait, ultra-tall, HEIC-derived JPEG.
- Rows entering/leaving viewport quickly; user scroll during batch settle.
- Conversation switch and widget disposal with queued decode admissions.
- Keyboard open, picker dismissal, long-history list, reduced-motion setting.

## Done criteria

- [ ] Decode starts are bounded per frame and prioritize visible rows.
- [ ] Existing target decode dimensions and image quality are unchanged.
- [ ] One batch produces exactly one settled force-pin transaction.
- [ ] All named tests pass and `git diff --check` exits 0.
- [ ] iPhone Profile shows lower burst build/raster hitch without memory growth.

## STOP conditions

- Deferring decode causes a visible blank row without a stable sized placeholder.
- Cached images are delayed or full-screen preview quality changes.
- One-pin ownership cannot keep the newest row visible on picker dismissal.
- Fix requires changing general received-image virtualization or SDK behavior.

## Maintenance notes

The decode coordinator is scheduling infrastructure, not another image cache.
Do not retain files, providers, or widget contexts beyond row lifetime. Review
generation cleanup and cached-image fast paths carefully.
