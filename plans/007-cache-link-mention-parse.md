# Plan 007: Cache link/mention parse output across rebuilds

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt below to the live files. If `LinkText._collectSegments`
> no longer calls `urlReg.allMatches` / mention `allMatches` on each build, or
> `MessageHyperlinkTextCache` already caches the **flagged content string**
> (not only the `LinkPreviewText` builder), STOP and report before rewriting.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/006-cut-link-regexp-invocations.md (DONE — candidate gates exist)
- **Category**: perf
- **Planned at**: working tree 2026-08-20 (no git SHA — `NO_GIT`)
- **Execution**: DONE (2026-08-20) — `LinkTextParseCache` LRU for flagged
  content / wrap / URL lists; tests in `test/link_text_parse_and_defer_test.dart`.

## Why this matters

Instruments `docs/pro.md` (Display hitch + Time Profiler) shows Main-thread
`dart::BytecodeRegExpMacroAssembler::Interpret` as the hottest named leaf,
aligned with hitch windows (worst ~125ms). Plan 006 reduced how often regex
runs for non-candidate text, but **candidate messages still re-run
`allMatches` on every Flutter rebuild**.

`MessageHyperlinkTextCache` only caches the `LinkPreviewText` **factory**
that returns a `LinkText` widget. `LinkText.timBuild` → `_getContentSpan` →
`_collectSegments` still executes RegExp every paint. Scroll/list updates
therefore pay Interpret cost again for the same `messageText`.

This plan caches the **parse product** (flagged content string / match lists)
keyed by text + scan mode, so rebuilds reuse prior work without changing URL
or mention semantics.

## Current state

### Outer cache (widget factory only)

`third_party/tencent_cloud_chat_uikit/lib/ui/utils/message_hyperlink_text_cache.dart`

```40:89:third_party/tencent_cloud_chat_uikit/lib/ui/utils/message_hyperlink_text_cache.dart
  LinkPreviewText getOrCreate({
    ...
  }) {
    final key = _buildKey(...);
    final cached = _cache.remove(key);
    if (cached != null) {
      if (identical(cached.onLinkTap, onLinkTap) &&
          identical(cached.onTapChatIdMention, onTapChatIdMention)) {
        _cache[key] = cached;
        return cached.text;
      }
    }
    final created = LinkPreviewEntry.getHyperlinksText(...)!;
    ...
    return created;
  }
```

Caller: `tim_uikit_chat_text_elem.dart` (~414–432) uses this cache, then
`textWithLink(style: textStyle)` which builds `LinkText`.

### Inner hot path (still re-parses every build)

`third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/widgets/link_text.dart`

```139:183:third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/widgets/link_text.dart
  List<_LinkTextSegment> _collectSegments(String text) {
    return RegExpProbe.measure('link.LinkText.scan', () {
      ...
      if (mayUrl) {
        for (final match in LinkUtils.urlReg.allMatches(text)) { ... }
      }
      if (mayMention) {
        final mentionMatches = [
          ...LinkUtils.chatIdMentionReg.allMatches(text),
          ...LinkUtils.groupAtMentionReg.allMatches(text),
        ]..sort(...);
        ...
      }
      ...
    });
  }
```

`_getContentSpan` builds the flagged string from segments; `timBuild` calls it
unconditionally.

### Related APIs (also re-parse)

`LinkUtils.wrapChatIdMentionsForExtendedText` / `LinkUtils.getURLMatches` in
`link_preview/common/utils.dart` — used when `urlPreviewType == none` (wrap
path in text elem ~488–490) and by `LinkPreviewEntry.getFirstLinkPreviewContent`.

### Conventions

- Keep `RegExpProbe.measure('link.…')` wrappers from plan 003 — do not remove.
- Keep plan 006 candidate gates (`_mayContainUrlCandidate` /
  `_mayContainMentionCandidate`).
- Match existing LRU style in `MessageHyperlinkTextCache` (`LinkedHashMap`,
  max entries, move-to-end on hit).
- Behavior-lock tests already exist: `test/chat_id_mention_full_group_id_test.dart`,
  `third_party/tencent_cloud_chat_uikit/test/message_hyperlink_text_cache_test.dart`.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Mention/URL behavior | `flutter test test/chat_id_mention_full_group_id_test.dart` | all pass |
| Hyperlink widget cache | `cd third_party/tencent_cloud_chat_uikit && flutter test test/message_hyperlink_text_cache_test.dart` | all pass |
| New parse-cache tests | `cd third_party/tencent_cloud_chat_uikit && flutter test test/link_text_parse_cache_test.dart` (path as created) | all pass |
| Analyze touched files | `dart analyze third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/widgets/link_text.dart third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/common/utils.dart third_party/tencent_cloud_chat_uikit/lib/ui/utils/message_hyperlink_text_cache.dart` | no new errors |

Run from repo root `/Users/qiu/Downloads/9925banben` unless noted.

## Scope

**In scope**:

- `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/widgets/link_text.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/common/utils.dart`
- Optional new helper under `third_party/tencent_cloud_chat_uikit/lib/ui/utils/`
  (e.g. `link_text_parse_cache.dart`) if keeping LRU out of widget file is cleaner
- `third_party/tencent_cloud_chat_uikit/lib/ui/utils/message_hyperlink_text_cache.dart`
  — only to stop **parse-irrelevant** thrashing (see Step 3); do not change
  public API of `getOrCreate` unless tests require it
- New/extended tests under `third_party/tencent_cloud_chat_uikit/test/` and/or
  `test/chat_id_mention_full_group_id_test.dart`

**Out of scope**:

- Changing `urlReg` / mention regex **pattern strings**
- Deferring first paint (that is plan 008)
- Call-bubble JSON / `CallBubbleDedupe` (plan 005)
- Conversation list (plans 001–002)
- Isolates / `compute` for parsing
- Editing `docs/pro.md`

## Git workflow

- No `.git` in this workspace — do not `git init`. Do not push.
- If a git repo appears later: branch `advisor/007-cache-link-parse`, conventional
  commits focused on why (perf), one logical commit for the cache + tests.

## Steps

### Step 1: Add LRU cache for LinkText flagged content

Introduce a small cache (new file or private top-level in `link_text.dart`):

- Key must include at least:
  - `messageText` (prefer full string equality; if using `hashCode`, also store
    the string and reject hash collisions)
  - `scanMentions` bool (`onTapChatIdMention != null`)
  - `scanUrls` bool (always true for `LinkText` today — keep explicit for clarity)
- Value: the **flagged content string** produced by today’s `_getContentSpan`
  (HttpText / ChatIdMentionText flags), OR an immutable list of segment
  ranges that `_getContentSpan` consumes — pick one; flagged string is simpler.
- Cap size (suggest **256**, same as `MessageHyperlinkTextCache`).
- On hit: return cached string **without** calling `urlReg.allMatches`.
- On miss: existing `_collectSegments` path (still wrapped in
  `RegExpProbe.measure('link.LinkText.scan', …)`), then store.

Wire `_getContentSpan` / `timBuild` to use the cache.

**Verify**: `dart analyze` on `link_text.dart` → no new errors.

### Step 2: Cache `LinkUtils.wrapChatIdMentionsForExtendedText` and `getURLMatches`

Same LRU pattern (can share one helper with different value types, or two
small caches):

- `wrapChatIdMentionsForExtendedText`: key = text; value = wrapped string.
  Keep probe site `link.wrapMentions`.
- `getURLMatches`: key = text; value = `List<String>` (immutable / unmodifiable).
  Keep probe site `link.getURLMatches`.
- Respect existing candidate gates before regex; empty/fast-path results may
  still be cached to skip repeated gate+regex decisions.

**Verify**: `flutter test test/chat_id_mention_full_group_id_test.dart` → pass.

### Step 3: Stop MessageHyperlinkTextCache from forcing rebuild on callback identity alone when text unchanged

Today a non-`identical` `onLinkTap` / `onTapChatIdMention` drops the cached
entry and calls `getHyperlinksText` again (new `LinkText` instance). That is
OK for **callback correctness**, but must not defeat Step 1:

- After Step 1, a new `LinkText` with the same `messageText` must hit the
  **parse** cache even if the outer widget cache misses.
- Optionally tighten Step 3: when text/key match but callbacks differ, replace
  only the stored callbacks / rebuild the thin `LinkPreviewText` closure
  without re-invoking markdown preprocess (`addSpaceBeforeHttp` etc.) if
  easy — **only if** you can do so without changing markdown behavior.
  If unclear, **skip optional half**; Step 1 alone is the required win.

Extend `message_hyperlink_text_cache_test.dart` so that two `getOrCreate`
calls with same text but different mention callbacks still produce widgets
that, when built, do not require a second full regex pass for the same text
(assert via a test-only counter **or** by asserting parse-cache hit count if
you expose `@visibleForTesting` stats — prefer a small `debugHitCount` behind
`kDebugMode` / test flag, cleared in `setUp`).

**Verify**: `cd third_party/tencent_cloud_chat_uikit && flutter test test/message_hyperlink_text_cache_test.dart` → pass.

### Step 4: Characterization tests for parse cache

Add `third_party/tencent_cloud_chat_uikit/test/link_text_parse_cache_test.dart`
(name OK to adjust):

1. Same text built twice → second build does not increase a
   `@visibleForTesting` miss counter (or probe invocation counter if you add
   one only for tests).
2. Text change → miss, new flagged output matches golden of uncached path.
3. Mention-enabled vs disabled → different cache keys (with `@user` text,
   outputs differ when `onTapChatIdMention` null vs non-null).
4. URL-only and mention-only fixtures still match current behavior (copy
   expectations from `chat_id_mention_full_group_id_test.dart` where useful).

**Verify**: run the new test file → all pass.

## Test plan

- New: parse-cache hit/miss + keying (Step 4).
- Existing: `chat_id_mention_full_group_id_test.dart`,
  `message_hyperlink_text_cache_test.dart` must stay green.
- Do **not** weaken mention/URL acceptance assertions to make tests pass.

## Done criteria

- [ ] `LinkText` rebuild with identical text + mention mode does not re-enter
      `urlReg.allMatches` / mention `allMatches` (proven by test counter or
      equivalent).
- [ ] `wrapChatIdMentionsForExtendedText` / `getURLMatches` reuse cached
      results for identical text.
- [ ] `flutter test test/chat_id_mention_full_group_id_test.dart` passes.
- [ ] UIKit hyperlink + new parse-cache tests pass.
- [ ] `dart analyze` on in-scope files: no new errors.
- [ ] No files outside Scope modified.
- [ ] `plans/README.md` row for 007 set to DONE.

## STOP conditions

- Drift: `_collectSegments` already cached, or RegExp sites moved — report.
- Fix appears to require changing regex pattern strings to “make cache work”.
- Mentions/URLs render differently vs pre-change golden tests after two fix
  attempts.
- Need to touch call-bubble / conversation list files.

## Maintenance notes

- Cache is process-wide; if message text is edited in place with same msgID
  but different body, keying by **text** (required) avoids stale spans.
  Do not key only by msgID.
- If sticker/markdown flags alter `LinkText` input text, they are already
  applied before `LinkText` — cache the string `LinkText` actually receives.
- Reviewer: confirm probe site names unchanged so Profile dumps stay comparable.
- Follow-up deferred to plan 008: delay first enrich until after first frame.
