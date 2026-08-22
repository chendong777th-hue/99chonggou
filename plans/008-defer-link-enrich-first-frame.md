# Plan 008: Defer link/mention enrich until after first frame

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> excerpts to live code. If `TIMUIKitTextElem` already shows plain text for
> the first frame and only then swaps to `MessageHyperlinkTextCache` /
> `LinkText`, STOP and report. Prefer landing **plan 007** first; if 007 is
> not DONE, you may still implement 008 but expect less hitch reduction and
> keep both verifications green.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED (one-frame plain text before links/mentions highlight)
- **Depends on**: plans/007-cache-link-mention-parse.md (recommended; soft)
- **Category**: perf
- **Planned at**: working tree 2026-08-20 (no git SHA — `NO_GIT`)
- **Execution**: DONE (2026-08-20) — `DeferredHyperlinkText` + wired into
  text / reply / translate elems; covered by `test/link_text_parse_and_defer_test.dart`.

## Why this matters

Hitch spikes in `docs/pro.md` cluster around chat open / history mount
(~2–6s, ~15s, ~29s), not only steady scrolling. On open, many text bubbles
mount in one frame and each runs URL/mention parsing (even with plan 006
gates and plan 007 cache misses on first sight).

Deferring hyperlink/mention **enrichment** until after the first frame lets
Flutter present plain body text at 120Hz, then upgrade spans when idle.
Product tradeoff: links/mentions may appear unstyled for ≤1 frame (often
unnoticeable). Do **not** change which strings are eventually detected.

## Current state

`third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_text_elem.dart`

In `tuiBuild` (~400+):

- Computes `displayText`, `messageKey`.
- Synchronously calls `MessageHyperlinkTextCache.instance.getOrCreate(...)`.
- Builds `textWidget` from `textWithLink(style: …)` when
  `urlPreviewType != UrlPreviewType.none`, else `ExtendedText` with optional
  `LinkUtils.wrapChatIdMentionsForExtendedText(displayText)`.

There is already a post-frame callback for bubble height (~401–405) — reuse
that pattern; do not invent a second scheduling framework.

Also check reply/translate elems that call the same cache:

- `tim_uikit_chat_reply_elem.dart` (~307)
- `tim_uikit_chat_text_translate_elem.dart` (~133)

Include them in scope if they mount on the same open path; otherwise note
in Maintenance and only change the primary text elem in this plan.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Mention/URL behavior | `flutter test test/chat_id_mention_full_group_id_test.dart` | pass |
| Hyperlink cache | `cd third_party/tencent_cloud_chat_uikit && flutter test test/message_hyperlink_text_cache_test.dart` | pass |
| Parse cache (if 007 landed) | `cd third_party/tencent_cloud_chat_uikit && flutter test test/link_text_parse_cache_test.dart` | pass |
| Widget smoke (new) | test file created in Step 3 | pass |
| Analyze | `dart analyze` on touched `tim_uikit_chat_*_elem.dart` files | no new errors |

## Scope

**In scope**:

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_text_elem.dart`
- Same-pattern deferral in `tim_uikit_chat_reply_elem.dart` and/or
  `tim_uikit_chat_text_translate_elem.dart` **only if** they synchronously
  call `MessageHyperlinkTextCache.getOrCreate` / `wrapChatIdMentions` during
  `build`/`tuiBuild` on chat open
- New widget test under `third_party/tencent_cloud_chat_uikit/test/`

**Out of scope**:

- Changing RegExp patterns
- Call-bubble normalize / conversation list
- Removing `RegExpProbe` sites
- Isolates
- Changing `UrlPreviewType` product defaults

## Git workflow

- No `.git` — do not init/push.
- If git exists later: `advisor/008-defer-link-enrich`, one commit + tests.

## Steps

### Step 1: First-frame plain text in TIMUIKitTextElem

In the stateful text elem:

1. Add a bool (e.g. `_hyperlinkReady`) default **false** on first mount for
   a given `messageKey`+`displayText`.
2. While false and `urlPreviewType != none`: build **plain** `ExtendedText` /
   `Text` with the **same** `textStyle` / softWrap as the enriched path, but
   **without** calling `LinkText` segment scan / without
   `getOrCreate` (or call getOrCreate only after ready — prefer skip).
3. Schedule exactly one upgrade:
   `WidgetsBinding.instance.addPostFrameCallback` (or
   `SchedulerBinding.instance.scheduleFrameCallback`) → `if (mounted) setState(() => _hyperlinkReady = true)`.
4. When true: existing `MessageHyperlinkTextCache.getOrCreate` + `textWithLink`
   path unchanged.
5. Reset `_hyperlinkReady` to false when `messageKey` or `displayText`
   changes (didUpdateWidget).

For `urlPreviewType == none` with mentions enabled: likewise defer
`wrapChatIdMentionsForExtendedText` until after first frame; first frame
shows raw `displayText`.

**Layout stability**: plain and enriched text should use the **same** style
and softWrap so line breaks do not jump. Accept that underline/color on
links may appear one frame later. If jump highlight / measure depends on
final spans, keep existing height remember callback after enrich as today.

**Verify**: `dart analyze` on the text elem → clean.

### Step 2: Mirror on reply/translate only if needed

Grep for `MessageHyperlinkTextCache.instance.getOrCreate` in the message
item folder. If reply/translate mount during history open with the same
sync cost, apply the same `_hyperlinkReady` pattern. If they are rare /
already lazy, leave them and document in Maintenance.

**Verify**: analyze those files if touched.

### Step 3: Widget test

Add a test that pumps a minimal text elem (or a thin harness wrapping the
defer logic if constructing full `TIMUIKitTextElem` is too heavy):

1. After first `pump`, find plain text without requiring link gesture
   targets if links are not yet enriched (document the finder).
2. After `pump()` / `pumpAndSettle()` for the post-frame callback, link or
   mention styling/tappable special text becomes available for a fixture
   containing `https://example.com` or `@alice_01`.

If full elem construction needs too many SDK mocks, extract a tiny
`@visibleForTesting` helper widget `DeferredHyperlinkText` used by the elem
and test that helper — **preferred** to keep the test hermetic.

**Verify**: new test file passes.

### Step 4: Regression suite

Run:

- `flutter test test/chat_id_mention_full_group_id_test.dart`
- UIKit `message_hyperlink_text_cache_test.dart`
- plan 007 parse-cache test if present

**Verify**: all pass.

## Test plan

- New: first frame deferred, second frame enriched (Step 3).
- Existing behavior locks for URL/mention detection remain authoritative for
  **final** enriched output (not the transient first frame).

## Done criteria

- [ ] Chat text elem does not run `LinkText`/`getOrCreate` parse on the
      first frame of a new messageKey+text (proven by test or
      `@visibleForTesting` flag).
- [ ] After post-frame, enriched behavior matches pre-change for fixtures.
- [ ] Mention/URL characterization tests pass.
- [ ] No out-of-scope files modified.
- [ ] `plans/README.md` 008 → DONE.

## STOP conditions

- Enrichment deferral causes measurable layout jump >1 line on common
  bubbles and cannot be fixed by matching textStyle — STOP, report with
  screenshot/description; do not “fix” by changing bubble padding globally.
- Requires changing when `onTapLink` fires in a way that breaks product
  (taps ignored forever).
- Plan 007 parse cache tests fail because this plan bypasses cache
  incorrectly — fix integration, don’t delete 007 tests.

## Maintenance notes

- Reviewers: watch for double `setState` storms if history remounts every
  message each frame — gate with messageKey.
- If Profile still shows `link.LinkText.scan` dominated **after** first
  paint during scroll, plan 007 cache is the fix; 008 only helps open
  spikes.
- Optional later: defer only when `messageText.length` over a threshold or
  when candidate gates say regex would run — micro-opt, not required here.
