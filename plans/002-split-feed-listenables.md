# Plan 002: Split Feed listenables so content notify skips notice/signature work

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md`.
>
> **Drift check (run first)**: Open
> `lib/src/widgets/conversation_feed/conversation_feed_body.dart`.
> Confirm `_buildFeedListenable` still `Listenable.merge`s
> `ConversationListNotifier.instance` **together with** archive / folder /
> group-notice / settings (and group-live on group tab). Confirm the
> `AnimatedBuilder` in `build` still calls `groupNoticeFeedSignature(...)`
> on **every** rebuild. If listenables are already nested, STOP.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: plans/001-skip-noop-conversation-sort.md (land 001 first so inbound messages stop bumping `structureRevision` when they do not move)
- **Category**: perf
- **Planned at**: working tree 2026-08-20 (no git SHA available)
- **Execution**: DONE (2026-08-20)

## Why this matters

`ConversationFeedBody` uses one `AnimatedBuilder` over a merged listenable. A single lastMessage/unread `notifyListeners` therefore re-runs:

- `widget.getVisibleConversations()` (filter chain in `conversation.dart`)
- `_notices()` copy + sort
- `groupNoticeFeedSignature` over **all** group applications and system notices
- `buildConversationFeedRows` / `patchConversationFeedRowsById`
- construction of `ListView.builder`

Row widgets already skip via `_ConversationFeedRowSlot` fingerprints. The waste is **parent CPU** (signature + visible materialization) and extra `ListView` rebuilds. Nested listenables keep group-notice hashing on the rare outer path; the inner path only reads `ConversationListNotifier`.

Visual result must stay the same: new preview/unread still appear (inner rebuild + row fingerprint). Group notice entry still moves/hides when applications/notices/settings change (outer rebuild).

## Current state

### Files

- `lib/src/widgets/conversation_feed/conversation_feed_body.dart` — Feed `build`, `_buildFeedListenable` (~157–178, ~392–630)
- `lib/src/widgets/conversation_feed/conversation_feed_rows.dart` — `groupNoticeFeedSignature`, `buildConversationFeedRows`, `patchConversationFeedRowsById`
- `lib/src/widgets/conversation_feed/conversation_feed_ui.dart` — `shouldReuseInactiveConversationFeed` (keep behavior)
- `lib/src/widgets/conversation_feed/group_notice_feed_listenable.dart` — notice+application notify
- `test/conversation_feed_row_slot_theme_test.dart` — inactive-tab cache rules
- `test/conversation_feed_rows_test.dart` — signature + row insert tests (do not weaken)

### Merged listenable (today)

```dart
  Listenable _buildFeedListenable() {
    final listenables = <Listenable>[
      ConversationListNotifier.instance,
      archivedConversationIDsNotifierFor(widget.archiveScope),
      archivedConversationIDsNotifierFor(/* other archive scope */),
      ArchivedConversationEntryVisibility.instance.notifierFor(widget.archiveScope),
      ConversationFolderStore.instance.foldersNotifier,
      _groupNoticeFeedListenable,
      GroupNoticeEntrySettingsService.instance,
    ];
    if (widget.isGroupTab) {
      listenables.add(GroupLiveIndexStore.instance);
    }
    return Listenable.merge(listenables);
  }
```

### Signature on every rebuild (today)

Inside the single `AnimatedBuilder` builder, after `getVisibleConversations()`:

```dart
            final noticeSignature = groupNoticeFeedSignature(
              applications: applications,
              notices: notices,
              includeGroupNoticeEntry: includeGroupNoticeEntry,
              groupNoticePinned: settings.isPinned,
              dismissWatermarkMs: settings.dismissWatermarkMs,
            );
```

`_notices()` copies and sorts the full notice list every time.

### Virtual list still needs inner rebuild

Virtual `itemBuilder` reads `notifier.conversationAtTypeIndex`. Inner `AnimatedBuilder` **must** still rebuild on `ConversationListNotifier` so visible `_ConversationFeedRowSlot`s re-check fingerprints. Do **not** reuse `_inactiveTabCachedChild` for the **active** tab (see `shouldReuseInactiveConversationFeed`: `tabActive` → false).

### Conventions

- Extract **pure** skip predicates into `conversation_feed_ui.dart` (or a tiny helper in `conversation_feed_rows.dart`) so tests do not pump a full `ConversationFeedBody`.
- Follow `conversation_feed_row_slot_theme_test.dart`: boolean helpers + `expect`.
- Do not log more on the inner path. Existing `feed_list_rebuild` logs may stay on outer or on structure change only — if you reduce log volume, that is OK.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Helper tests | `flutter test test/conversation_feed_row_slot_theme_test.dart test/conversation_feed_rows_test.dart` | all pass |
| Feed-adjacent | `flutter test test/conversation_list_row_pin_anim_test.dart test/conversation_ui_window_test.dart` | all pass |
| After 001 | `flutter test test/conversation_list_notifier_incremental_test.dart` | all pass |

## Suggested executor toolkit

- None. Do not add widget tests that require IM login.

## Scope

**In scope**:

- `lib/src/widgets/conversation_feed/conversation_feed_body.dart`
- `lib/src/widgets/conversation_feed/conversation_feed_ui.dart` (pure helpers only)
- `test/conversation_feed_row_slot_theme_test.dart` (new helper cases)

**Out of scope**:

- `lib/src/conversation.dart` — still listens to notifier for folder unread / visible cache; leaving it avoids a 6500-line blast. Document in Maintenance if inner rebuilds still call `getVisibleConversations` via the **inner** builder (see Step 2 — you may skip that call on the cheap path).
- `lib/src/services/conversation_local/**` except you must not edit notifier here (001 owns it)
- Group notice **tile** UI (`conversation_group_notice_entry_tile.dart`)
- `GroupLiveIndexStore` internals
- `FutureBuilder` insert-index SQL (`_virtualNoticeInsertAtFuture`) — do not redesign; outer rebuild may still run it when notice data changes. Do **not** create a new Future on every inner content notify (see Step 2).
- Archive **page**, folder CRUD, pin animations
- `third_party/tencent_cloud_chat_uikit/**`

## Git workflow

- If git exists: branch `advisor/002-split-feed-listenables`, commit `perf: split conversation feed listenables to skip notice work on content notify`. Do not push unless asked.

## Steps

### Step 1: Add a pure cheap-path predicate

In `conversation_feed_ui.dart` add something equivalent to:

```dart
/// Virtual Feed can skip visible-list materialization and row-array rebuild
/// when list identity (order / membership / archive+notice chrome) is unchanged.
bool conversationFeedCanSkipVisibleMaterialization({
  required bool useVirtual,
  required bool folderFilterActive,
  required int structureRevision,
  required int lastStructureRevision,
  required bool includeArchivedEntry,
  required bool cachedIncludeArchived,
  required bool includeGroupNoticeEntry,
  required bool cachedIncludeGroupNotice,
  required bool groupNoticePinned,
  required bool cachedGroupNoticePinned,
  required int noticeSignature,
  required int cachedGroupNoticeSignature,
}) {
  if (!useVirtual || folderFilterActive) {
    return false;
  }
  if (lastStructureRevision < 0) {
    return false; // first build
  }
  if (structureRevision != lastStructureRevision) {
    return false;
  }
  return includeArchivedEntry == cachedIncludeArchived &&
      includeGroupNoticeEntry == cachedIncludeGroupNotice &&
      groupNoticePinned == cachedGroupNoticePinned &&
      noticeSignature == cachedGroupNoticeSignature;
}
```

Tests in `conversation_feed_row_slot_theme_test.dart`:

- virtual + same structure + same chrome → true
- `lastStructureRevision == -1` → false
- structureRevision differs → false
- `folderFilterActive: true` → false
- `useVirtual: false` → false
- noticeSignature differs → false

**Verify**: `flutter test test/conversation_feed_row_slot_theme_test.dart` → pass including new tests.

### Step 2: Nest AnimatedBuilders in `ConversationFeedBody.build`

Replace the **single** `AnimatedBuilder(animation: _feedListenable)` with:

**Outer** animation = merge of everything **except** `ConversationListNotifier.instance`:

- both archive ID notifiers
- `ArchivedConversationEntryVisibility`
- `ConversationFolderStore.instance.foldersNotifier`
- `_groupNoticeFeedListenable`
- `GroupNoticeEntrySettingsService.instance`
- `GroupLiveIndexStore.instance` if `widget.isGroupTab`

**Inner** animation = `ConversationListNotifier.instance` only.

Keep inactive-tab reuse (`shouldReuseInactiveConversationFeed`) on the **inner** builder so content-only updates on a hidden tab still skip work.

**Outer builder** (rare):

1. Read applications/notices/settings.
2. Compute `includeArchivedEntry`, `includeGroupNoticeEntry`, `noticeSignature` (this is the only place `groupNoticeFeedSignature` and `_notices()` sort should run).
3. Return the inner `AnimatedBuilder`.

**Inner builder** (hot):

1. Read `structureRevision` / `contentRevision` from notifier.
2. `useVirtual` as today (`conversationVirtualListEnabled && !folderFilterActive`).
3. If `conversationFeedCanSkipVisibleMaterialization(...)` is true:
   - **Do not** call `widget.getVisibleConversations()`.
   - **Do not** call `buildConversationFeedRows` / `patchConversationFeedRowsById`.
   - **Do not** call `_compensateScrollForPinReorder` (structure unchanged ⇒ order unchanged).
   - Reuse `_cachedFeedRows` as-is (may be unused on virtual path).
   - Call `_buildVirtualFeedListView` with the **outer-computed** `includeArchivedEntry` / `includeGroupNoticeEntry` / `settings`.
4. Else: existing full path (`getVisibleConversations`, patch vs build rows, compensate, virtual or non-virtual list).

**FutureBuilder / insert future (boundary):**

- `_virtualNoticeInsertAtFuture` is keyed by `convType|noticeTs|noticeSignature|total|structureRevision`.
- On the cheap inner path, **do not** null out `_virtualNoticeInsertKey` / `_virtualNoticeInsertFuture`.
- `_buildVirtualFeedListView` may still wrap a `FutureBuilder`. That is OK if `insertFuture` is the **same** cached Future (same key). If a new Future is created every inner rebuild, STOP and cache the future more aggressively so content notify does not restart SQL.

**didUpdateWidget**: if `isGroupTab` / `archiveScope` change, rebuild outer listenables as today (`_feedListenable = _buildFeedListenable()`). Split into `_structureFeedListenable` vs notifier; update both when widget flags change.

**Verify**: `flutter test test/conversation_feed_row_slot_theme_test.dart test/conversation_feed_rows_test.dart test/conversation_list_row_pin_anim_test.dart` → pass.

### Step 3: Non-virtual / folder path unchanged

When `useVirtual` is false (folder filter, or flag off): inner builder **must** still call `getVisibleConversations` and row rebuild. Cheap path is virtual-only by helper contract.

**Verify**: no edits to folder chip behavior; `folderFilterActive` forces helper false.

### Step 4: Sanity tests already in repo

Run incremental notifier tests (preview/unread still notify Feed via inner listenable):

```bash
flutter test test/conversation_list_notifier_incremental_test.dart test/conversation_ui_window_test.dart
```

→ all pass.

## Test plan

- New pure-function cases in `conversation_feed_row_slot_theme_test.dart` (Step 1).
- Do **not** add a golden/widget test of `ConversationFeedBody` unless one already exists in-repo (there isn’t a full pump test; don’t start).
- Existing `groupNoticeFeedSignature` tests in `conversation_feed_rows_test.dart` remain the contract for when the entry must move.

## Done criteria

- [ ] `ConversationListNotifier` is **not** in the same `Listenable.merge` as group-notice/archive/folder/settings
- [ ] `groupNoticeFeedSignature` is not invoked from the inner-only cheap path (code inspection: only outer builder / full path)
- [ ] Cheap path never calls `widget.getVisibleConversations()`
- [ ] Active tab still rebuilds inner builder on notifier content changes (row fingerprints can update)
- [ ] Commands table tests pass
- [ ] No files outside Scope
- [ ] `plans/README.md` row 002 updated

## STOP conditions

Stop and report if:

- Group notice entry **position** would be computed only on inner rebuild (it must use outer-computed signature + existing insert future).
- Skipping `getVisibleConversations` breaks official-account injection / membership filter on the **virtual** list (virtual rows come from hydrate/store, not that function — if you discover itemBuilder depends on visible list, STOP).
- You need to modify `lib/src/conversation.dart` to make cheap path work.
- Outer/inner split causes a double ListView (two scroll controllers) or loses `widget.feedScrollController`.
- `FutureBuilder` on inner rebuild shows a loading flash of the group-notice slot (snapshot reset). Fix by keeping the same Future instance; if not possible, STOP.

## Maintenance notes

- Reviewer: scroll a group tab while messages arrive — preview/unread should update without the notice row jumping. Then add a group application — notice row may move; that is outer path.
- `Conversation._getVisibleConversations` is still used for search-adjacent and folder unread; this plan does not cache-bust that. In-place mutation of `V2TimConversation` on lastMessage/unread means a stale visible cache can still show new fields if the same instances are retained (001 mutates in place). Do not “fix” conversation.dart listeners here.
- Plan explicitly deferred: isolate `_virtualNoticeInsertAtFuture` SQL behind a notifier-owned cache; avatar scroll prefetch; UIKit last-msg store listeners.
