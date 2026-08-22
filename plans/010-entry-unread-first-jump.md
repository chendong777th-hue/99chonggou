# Plan 010: Entry 「xxx条未读」tip → jump to first unread via read-cursor around-window

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
- **Effort**: L
- **Risk**: MED–HIGH (open-chat load path + unread tongue; high visibility)
- **Depends on**: 009 (reuse around-window jump / memory-window / return-to-bottom
  patterns; 009 is DONE)
- **Category**: direction → bug/feature (re-enable + harden existing tongue)
- **Planned at**: working tree 2026-08-20 (no git SHA available)
- **Execution**: DONE (2026-08-20) — tip re-enabled for group+C2C; open
  hydrate capped to initial window; jump uses `groupReadSequence+1` around
  window (count-fallback ≤200 only); entry copy「条未读」+ 9999+ format;
  tests green.

## Why this matters

Product ask: when opening a chat with a large unread count (example:
**10_000**), show an entry tip like「10000条未读」; tapping it jumps to the
**first unread** so the user can read forward from there; scrolling up/down
from that land must stay **contiguous**; return-to-bottom must stay **smooth**.

Most of this UI already exists in UIKit, but:

1. Entry tip is **hard-disabled** (`UnreadTonguePolicy.entryUnreadTongueEnabled
   = false`).
2. Open path tries to **preload `unreadCount + 12` messages** into memory
   (`_ensureInitialUnreadWindowLoaded`) — catastrophic at 10k.
3. Click path still **pages older** until `unreadCount` real messages are in
   RAM (`_ensureFirstUnreadAnchor`) — same class of failure as pre-009 @me
   chase.

SDK already exposes a read cursor on `V2TimConversation`:
`groupReadSequence` / `c2cReadTimestamp`. First unread is the first message
**after** that cursor. Jump must use **around-window** (reuse
`loadListForSpecificMessage` / plan 009 pattern), not “download all unread.”

## Product decisions (locked for this plan)

| Decision | Value | Rationale |
|----------|-------|-----------|
| Entry tip enabled | **on** (`entryUnreadTongueEnabled = true`) | User request |
| Scope | **Group + C2C** | User said「聊天对话」; C2C has `c2cReadTimestamp` |
| Min count to show tip | Keep **15** for both (reuse `groupMinUnreadCount`; rename conceptually to `entryMinUnreadCount` if touching the constant) | Avoid tip spam on tiny unread |
| Open behavior | Always land on **latest**; tip visible; **do not** preload full unread stack | 10k must open instantly |
| Jump target | **First unread** (message immediately after read cursor) | User:「从第一条开始往下读」 |
| Tip copy (entry) | Prefer「{{n}}条未读」for entry tip; live-while-scrolled tip may keep「新消息」 | Match user wording |
| Large n display | Entry tip shows full count up to **9999**, then `9999+` (today caps at `99+`) | 10000 must not look like `99+` |
| After jump | `notShowLatest`; bidirectional page; return-to-bottom via existing `reloadNewestMessageWindow` | Same contract as plan 009 |
| Mark-read | Do **not** mark conversation read merely because tip was shown; keep existing “user jumped / returned to bottom” mark-read behavior | Avoid wiping unread before user catches up |

If any row above conflicts with an explicit product owner veto, STOP and report
— do not invent a third behavior.

## Current state

### Kill switch (why tip never shows)

`third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/unread_tongue_policy.dart`:

```dart
/// 进入会话时「xxx条未读」入口提示。暂时关闭，后续可重新打开。
static const bool entryUnreadTongueEnabled = false;
// ...
static bool isEntryUnreadEnabled(...) {
  if (!entryUnreadTongueEnabled) return false;
  return isEnabled(conversation, unreadCount); // currently group-only + >=15
}
```

### Open path preloads all unread (broken for 10k)

`tim_uikit_chat.dart` → `_ensureInitialUnreadWindowLoaded` (~1498+):

```dart
// 首屏必须同时包含：首条未读 + 后续全部未读 + 少量已读上下文。
final requiredRealCount = math.max(
  HistoryMessageDartConstant.initialOpenFetchCount,
  unreadCount + 12,
);
const maxBatchCount = 80;
// while loaded < requiredRealCount: loadChatRecord previous...
```

Called from `_loadData` when entry unread policy is on (~1663).

### Click path pages by count (broken for 10k)

`tim_uikit_chat_history_message_list.dart`:

- `_scrollToFirstUnreadFromTongue` → `_ensureFirstUnreadAnchor(fallbackCount)`
- `_ensureFirstUnreadAnchor` loops `onLoadMore` / `loadChatRecord` until
  `_unreadAnchorMessageCount(list) >= unreadMessageCount` (batch clamp 80)
- Then `_firstUnreadGlobalIndex` / `_unreadAnchorFromCount`: walk newest-first
  until realCount == unreadCount

Unread tongue wiring:
`tim_uikit_chat_history_message_list_tongue_container.dart`
→ `_jumpToFirstUnreadMessage` → `scrollToFirstUnread`
→ at bottom uses `showPrevious` / `showUnread` capsules.

### Read cursor already on conversation model

`third_party/tencent_cloud_chat_sdk/lib/models/v2_tim_conversation.dart`:

- `groupReadSequence`
- `c2cReadTimestamp`
- `unreadCount`

App local store already persists these fields
(`lib/src/services/conversation_local/conversation_local_store.dart`).

### Correct jump primitive (reuse)

`TUIChatSeparateViewModel.loadListForSpecificMessage` (around OLDER+NEWER,
sets `HistoryMessagePosition.notShowLatest`, `haveMoreLatestData`).
Plan **009** rewired @me to this path + memory-window anchor + tongue
return-to-bottom. **Do the same for first-unread.**

### Tip UI copy / count format

`tim_uikit_tongue_item.dart`:

- `showPrevious` / `showUnread` →「{{n}}条新消息」
- `_formatCount`: `count > 99` → `'99+'`

### Conventions

- Match plan 009 patterns: single-flight jump, success/fail logging via
  `ChatHistoryTrace`, `_releaseSearchJumpMemoryWindowSuppress` after center,
  no rebuild re-entrancy loops.
- Tests: pure helpers + window trim style like
  `test/at_me_jump_window_test.dart` /
  `test/chat_message_window_test.dart`.
- Do not change wallet / LiveKit / conversation-list SDK primary flag.

## Commands you will need

Run from **repo root** unless noted (UIKit package `flutter test` may fail on
broken `example/` path — prefer root):

| Purpose | Command | Expected |
|---------|---------|----------|
| Policy / helper tests | `flutter test third_party/tencent_cloud_chat_uikit/test/unread_entry_jump_test.dart` | pass |
| Memory window | `flutter test third_party/tencent_cloud_chat_uikit/test/chat_message_window_test.dart` | pass |
| @me regression | `flutter test third_party/tencent_cloud_chat_uikit/test/at_me_jump_window_test.dart` | pass |
| Analyze touched | `dart analyze` on in-scope files listed below | no **new** errors |

## Scope

**In scope**:

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/unread_tongue_policy.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart`
  — `_ensureInitialUnreadWindowLoaded` / `_loadData` entry-unread branch only
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart`
  — `_scrollToFirstUnreadFromTongue` / `_ensureFirstUnreadAnchor` (or replace)
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/tim_uikit_chat_history_message_list_tongue_container.dart`
  — only if tip tap / visibility needs glue
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/tim_uikit_tongue_item.dart`
  — entry copy + large-count format (keep shared live tip behavior sane)
- New helper (preferred):  
  `third_party/tencent_cloud_chat_uikit/lib/ui/utils/first_unread_jump.dart`
  — pure: resolve jump seq/timestamp from conversation + unreadCount
- New tests:  
  `third_party/tencent_cloud_chat_uikit/test/unread_entry_jump_test.dart`
- `plans/README.md` status row

**Out of scope**:

- Changing SDK unread accounting / `markMessageAsRead` semantics beyond
  “don’t mark read just for showing the tip.”
- Archive HTTP / new roaming days.
- Redesigning tongue visuals (colors/position) beyond copy + count format.
- Conversation list badge UI.
- Reverting or rewriting plan 009 @me path.
- Auto-jump on open (must stay tip + click).

## Git workflow

- No `.git` historically; if present, branch
  `advisor/010-entry-unread-first-jump`.
- Do not push/PR unless asked.

## Target behavior

1. Open group/C2C with unread ≥ 15 → chat shows **latest** window quickly;
   entry capsule shows e.g.「10000条未读」(or `9999+` if larger).
2. Tap tip → around-window load centered on **first unread**; viewport lands
   on that message (divider/highlight may already exist — do not invent a new
   divider system unless one is already wired for unread).
3. Scroll **up** loads older contiguous pages; scroll **down** loads newer
   toward live tip (`haveMoreLatestData` / `notShowLatest` as in 009).
4. Tap return-to-bottom → `reloadNewestMessageWindow` path (existing tongue).
5. Open with unread 10_000 must **not** issue ~125×80 history pulls before
   first paint.

## Steps

### Step 1: Pure resolver + characterization tests

Create `first_unread_jump.dart` (names may vary; keep pure):

```dart
class FirstUnreadJumpTarget {
  final int? seq;          // group
  final int? timestampSec; // c2c
  final String strategy;   // 'group_read_seq' | 'c2c_read_ts' | 'count_fallback'
}

FirstUnreadJumpTarget? resolveFirstUnreadJump({
  required int unreadCount,
  required int? groupReadSequence,
  required int? c2cReadTimestamp,
  required int? lastMessageSeq,
  required int? lastMessageTimestamp,
  required bool isGroup,
});
```

Rules (document in tests):

1. unreadCount ≤ 0 → null.
2. **Group**: if `groupReadSequence != null && groupReadSequence > 0`,
   target seq = `groupReadSequence + 1` (first message after read cursor).
   If `lastMessageSeq` is present and `groupReadSequence >= lastMessageSeq`,
   treat as fully read → null.
3. **C2C**: if `c2cReadTimestamp != null && c2cReadTimestamp > 0`,
   target timestamp = `c2cReadTimestamp` (jump path must open a window of
   messages **newer than** this timestamp — see Step 3; helper may expose
   `timestampSec` only).
4. **Fallback** (cursor missing): do **not** claim a fake seq from
   `lastSeq - unreadCount` without documenting uncertainty. Prefer returning
   `strategy: count_fallback` and let Step 3 use a **bounded** previous-page
   probe (max rounds, e.g. 8×80) **only when unreadCount ≤ 200**; if
   unreadCount > 200 and no cursor → fail soft with toast, tip remains.
5. Unit-test (1)(2)(3)(4) boundaries in `unread_entry_jump_test.dart`.

Also add policy tests: with `entryUnreadTongueEnabled` true, C2C + group
≥15 enable; &lt;15 disable.

**Verify**:

```bash
flutter test third_party/tencent_cloud_chat_uikit/test/unread_entry_jump_test.dart
```

→ pass (may be red until Step 2 flips policy if tests import the flag —
structure tests so helpers are independent of the flag where possible).

### Step 2: Re-enable tip + extend policy to C2C

In `unread_tongue_policy.dart`:

- Set `entryUnreadTongueEnabled = true`.
- Change `isEnabled` / `isEnabledForConvType` to allow **C2C and group** when
  unreadCount ≥ min (15). Keep live-new-message tongue behavior unchanged
  (`isLiveNewMessageTongueEnabled`).

**Verify**: policy unit tests green; grep shows flag true.

### Step 3: Stop open-path full unread hydrate

In `tim_uikit_chat.dart` `_ensureInitialUnreadWindowLoaded`:

- Replace “requiredRealCount = unreadCount + 12” with:
  - Always load at most a **normal** initial window
    (`HistoryMessageDartConstant.initialOpenFetchCount` or ≤ 80).
  - Still `lockEntryUnreadForTongue` with the **entry** unread count.
  - Stay `HistoryMessagePosition.bottom`.
- Goal: open with 10k unread does **not** loop until 10012 messages loaded.

If other comments/docs claim “首屏必须包含全部未读”, update those comments
only (no new markdown docs).

**Verify**:

```bash
rg -n "unreadCount \+ 12" third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart
```

→ no matches (or only in comments explaining removal).

### Step 4: Rewrite first-unread jump to around-window

In `tim_uikit_chat_history_message_list.dart` (`_scrollToFirstUnreadFromTongue`
and helpers):

1. Resolve target via `FirstUnreadJumpTarget` from
   `widget.conversation` (read `groupReadSequence` / `c2cReadTimestamp` /
   `lastMessage` / locked unread count).
2. **Fast path**: if first unread already in memory (`_firstUnreadGlobalIndex`
   or identity/seq match), center + release memory-window suppress (same as
   009).
3. **Group slow path**: `loadListForSpecificMessage(seq: targetSeq)` then
   center on first message with `seq > groupReadSequence` (or exact seq if
   that message exists). Prefer centering the **oldest unread in the loaded
   window that is still ≥ first unread** — i.e. the first unread row.
4. **C2C slow path**: if model/API only supports seq/msgID around-load today,
   STOP options:
   - Prefer: find a message via local/cloud older pages **bounded** using
     timestamp filter if `getHistoryMessageList` time range is already used
     elsewhere in-repo; **or**
   - Load around `lastMessage` by walking older with **max 8 rounds × 80**
     only when unreadCount ≤ 200; for larger C2C without usable cursor, toast
     and keep tip.
   - Do **not** silently fall back to loading 10k messages.
5. On success: set position `awayTwoScreen` / rely on
   `loadListForSpecificMessage`’s `notShowLatest`; call
   `_releaseSearchJumpMemoryWindowSuppress` with landed msgID/seq; clear
   loading indicator; single-flight lock.
6. On failure: toast existing style (`无法定位到原消息` or a dedicated
  「无法定位到首条未读」); **keep** entry tip.
7. Remove/disable unbounded `_ensureFirstUnreadAnchor` count chase for
   unreadCount &gt; 200. Grep gate:

```bash
rg -n "unreadMessageCount / 80" third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart
```

Expect either removed or strictly gated behind `unreadMessageCount <= 200`.

**Verify**: `dart analyze` on touched list/model files; @me tests still pass.

### Step 5: Tip copy + count format

In `tim_uikit_tongue_item.dart` (minimal):

- For `showPrevious` (entry-at-bottom unread capsule), use「{{n}}条未读」
  (i18n `TIM_t_para`). Keep `showUnread` as「新消息」**or** also「未读」 if
  both are entry-driven — prefer consistency for entry types only.
- Change `_formatCount` for entry types: show full integer while `count <=
  9999`, else `9999+`. Do **not** break tiny counts.

Add unit-testable pure formatter in `first_unread_jump.dart` if easier than
widget tests.

**Verify**: formatter tests pass.

### Step 6: Contiguity + return-to-bottom checklist (code assert)

After jump success, confirm (read + minimal glue):

| Concern | Required |
|---------|----------|
| Up | `haveMoreData` / previous `onLoadMore` works |
| Down | `notShowLatest` or `haveMoreLatestData` so latest direction allowed |
| Memory | suppress released with first-unread anchor |
| Bottom | existing tongue `_scrollToLatestAndDismissUnreadCapsule` → `reloadNewestMessageWindow` untouched |

**Verify**: manual smoke list in Done criteria (may be NOT RUN).

### Step 7: Index

Mark plan 010 DONE in `plans/README.md` when Done criteria pass.

## Test plan

| Case | File |
|------|------|
| groupReadSequence+1 resolution | `unread_entry_jump_test.dart` |
| fully-read cursor → null | same |
| C2C timestamp target | same |
| count_fallback only when ≤200 | same |
| format 10000 → `9999+`; 10000? wait 10000 > 9999 → `9999+`; 10000 user example → `9999+` OK; 5000 → `5000` | same |
| policy C2C/group ≥15 | same |
| chat_message_window + at_me regression | existing tests |

Manual smoke (NOT RUN allowed with reason):

1. Group unread 20 → tip shows; tap → first unread; scroll both ways; return bottom.
2. Group unread ≥1000 (or mock locked count) → open is fast (no multi-minute hydrate); tap jumps without loading entire unread stack.
3. C2C unread ≥15 with `c2cReadTimestamp` → tip + jump or documented soft-fail.
4. @me tip still works (009).

## Done criteria

- [ ] `UnreadTonguePolicy.entryUnreadTongueEnabled == true`
- [ ] Entry policy enables **C2C and group** for unread ≥ 15
- [ ] Open path no longer requires loading `unreadCount + 12` messages
- [ ] First-unread jump primary path uses read cursor + `loadListForSpecificMessage` (group) or documented C2C strategy — **not** unbounded count chase
- [ ] `flutter test` for `unread_entry_jump_test.dart`, `chat_message_window_test.dart`, `at_me_jump_window_test.dart` → all pass
- [ ] No files outside Scope modified
- [ ] `plans/README.md` 010 status updated

## STOP conditions

- `groupReadSequence` / `c2cReadTimestamp` always 0 in this app’s conversation
  objects at open time (cursor never hydrated) — STOP and report; do not ship
  count-chase for 10k as a “fix.”
- C2C around-by-timestamp requires APIs not present in-repo — implement group
  path first, leave C2C tip visible with toast on tap, and report; **or** ask
  before inventing hopping RPC.
- Fix seems to require changing mark-read / conversation-list unread SSOT —
  STOP.
- Drift vs excerpts.
- Verification fails twice.

## Maintenance notes

- Keep entry-unread jump and @me jump on the **same** around-window primitive.
- If IM SDK adds official “get first unread message” API later, replace the
  resolver only.
- Reviewers: watch open-path hydrate, 10k RAM, tip cleared on failed jump,
  and 99+ format regression.
- Deferred: unread divider redesign; auto-jump on open; per-mute tip policy.
