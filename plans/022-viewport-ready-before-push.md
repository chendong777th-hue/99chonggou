# Plan 022: Ready-gated chat open (ViewportReady before Push)

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> the "Current state" excerpts to live files. If any in-scope symbol already
> matches the target behavior (explicit `ChatOpenViewportPhase` +
> `EntrySnapshot` + push only after Ready or documented fallback), STOP and
> report — do not duplicate.

## Status

- **Priority**: P0
- **Effort**: L (ship in 3 verifiable slices; do not big-bang)
- **Risk**: MED–HIGH (changes open timing; wrong Ready definition reintroduces
  blank first frame or tap lag)
- **Depends on**: 020 (DONE — warm count 20, light shell, ensureCompleteOpenWindow),
  017 (DONE — image decode bounds), 019 (DONE — instant pin)
- **Category**: direction / perf
- **Planned at**: working tree 2026-08-22 (`NO_GIT`)
- **Issue**: omit

- **Execution**: DONE (2026-08-22) — `ChatEntrySnapshot` +
  `ChatOpenViewportCoordinator`; tap `prepareForOpen` then push; Ready
  mounts heavy immediately; miss keeps 020 shell. Covered by
  `test/chat_open_viewport_ready_contract_test.dart`.

## Why this matters

Product intent (operator design doc): **correct viewport content must be Ready
before Push/POP starts** — not “shell slides in, then content becomes correct.”

Today (post-020) the app still does:

```text
Tap → ensureCompleteOpenWindow(≤220ms) → Push → light shell → settle → mount TIMUIKitChat + gate
```

That reduces hitch but violates the design’s binding of **correct first paint ↔
transition start**. Fast scroll + tap on a cold cell still often times out
prewarm and enters on a chrome-only shell.

This plan lands a **ViewportReady gate** on top of existing warm/gate/shell
machinery, without inventing a second history store or prefetching all
conversations.

## Product decisions (locked for this plan)

| Decision | Choice |
|----------|--------|
| Consistency | **Snapshot Consistency** (13.2): use local/warm EntrySnapshot for first paint; server/SDK validate **after** transition |
| Strong Consistency (13.1) | **Out of scope** — do not block Push on network round-trip |
| Light shell (020) | **Timeout / failure fallback only** — when Ready before Push, first frame should mount heavy chat (or shell that is already content-ready), not empty message area |
| Warm window count | Keep **20** (`HistoryMessageDartConstant.initialOpenFetchCount`) as Snapshot message budget |
| List architecture | Honor `docs/conversation_list_scheme_a.md`: IM SDK is list truth; Snapshot is **enter-chat cache**, not a new SQLite truth source |

## Tradeoffs vs warm / gate / light shell

```text
                    ┌─────────────────────┐
                    │  Warm scheduler     │  fills messageListMap (≤20)
                    │  (keep as engine)   │
                    └──────────┬──────────┘
                               │ derives
                               ▼
                    ┌─────────────────────┐
                    │  EntrySnapshot      │  typed view of “can paint viewport”
                    └──────────┬──────────┘
                               │ Ready?
                    ┌──────────┴──────────┐
                    ▼                     ▼
              Push immediately      Fallback path
              + skip/thin gate      (shell OK)
                    │
                    ▼
         history_gate_content_ready_skip
         (preferred when Snapshot complete)
```

| Mechanism | Role after 022 | Do not |
|-----------|----------------|--------|
| **Warm** (`ConversationHistoryWarmScheduler`) | Continues to fill memory; `ensureCompleteOpenWindow` becomes the Prepare step | Replace with “prefetch all chats” |
| **Open history gate** (`_startOpenHistoryGate`) | Prefer `history_gate_content_ready_skip` when open was Ready-gated; keep absorb gate only for fallback opens | Delete gate entirely |
| **Light shell** (`_heavyChatBodyMounted`) | Only when open entered **without** ViewportReady (timeout / cold) | Use empty shell on the happy Ready path |
| **Image decode defer (017)** | Keep; Snapshot may add **layout size hints** later (Slice C optional) | Block Ready on full bitmap decode |

## Current state

Relevant files:

- `lib/src/conversation.dart` — `_handleOnConvItemTaped`; prewarm then `Navigator.push`
- `lib/src/services/conversation_history_warm_scheduler.dart` —
  `ensureCompleteOpenWindow` / `warmCount`
- `lib/src/utils/conversation_preview_history_sync.dart` —
  `isCompleteOpenHistoryWindow` / `canSkipOpenRebootstrap`
- `lib/src/chat.dart` — `_heavyChatBodyMounted`, `_startOpenHistoryGate`,
  `_buildChatTransitionShell` / `_buildChatAppBar`
- `lib/src/navigation/app_chat_route.dart` — `allowSnapshotting: false`
- `lib/src/services/chat_open_perf_log.dart` — open marks
- `third_party/.../history_message_constant.dart` — `initialOpenFetchCount = 20`
- `docs/conversation_list_scheme_a.md` — SDK-primary list (do not regress)

### Excerpt A — tap still pushes after timed prewarm

```dart
// lib/src/conversation.dart (~2971–2986)
ChatOpenPerfLog.mark('open_prewarm_begin');
final prewarmComplete = await ConversationHistoryWarmScheduler.instance
    .ensureCompleteOpenWindow(conversation: selectedConv);
ChatOpenPerfLog.mark('open_prewarm_end', extras: {... 'complete': prewarmComplete });
ChatOpenPerfLog.mark('navigator_push_begin');
await Navigator.push(context, appChatRoute(...));
```

### Excerpt B — gate skip when complete window already in memory

```dart
// lib/src/chat.dart (~3817–3835)
final completeWindow =
    ConversationPreviewHistorySync.isCompleteOpenHistoryWindow(...);
if (completeWindow || emptyConfirmed) {
  ChatOpenPerfLog.mark('history_gate_content_ready_skip', ...);
  _openLifecycle.openHistoryGate = null;
  ...
  return;
}
```

### Excerpt C — light shell until route settle

```dart
// lib/src/chat.dart — `_heavyChatBodyMounted` false → `_buildChatTransitionShell`
// mount heavy after `_scheduleAfterRouteTransition` / 360ms timeout
```

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Contract tests | `flutter test test/chat_open_viewport_ready_contract_test.dart test/chat_open_warm_window_count_contract_test.dart test/chat_open_gate_visual_contract_test.dart test/conversation_preview_history_sync_test.dart` | all pass |
| Analyze (touched) | `dart analyze lib/src/services/chat_open_viewport_coordinator.dart lib/src/models/chat_entry_snapshot.dart lib/src/conversation.dart lib/src/chat.dart` | no errors |

## Scope

**In scope**:

- New: `lib/src/models/chat_entry_snapshot.dart`
- New: `lib/src/services/chat_open_viewport_coordinator.dart` (phase + requestId)
- `lib/src/conversation.dart` — tap path uses coordinator before push
- `lib/src/chat.dart` — honor Ready vs fallback for shell / heavy mount timing
- `lib/src/services/chat_open_perf_log.dart` — marks for phase transitions
- Tests under `test/chat_open_viewport_ready_contract_test.dart` (+ extend sync tests if needed)
- `plans/README.md` status row

**Out of scope**:

- Rewriting conversation list virtualization / SDK-primary Store
- Persisting EntrySnapshot to SQLite as list truth
- Blocking Push on cloud fetch / Strong Consistency
- Changing `initialOpenFetchCount` again
- Wallet, calls, search-jump entry, desktop embedded chat redesign
- Full off-main-thread Flutter layout of message rows (not feasible 1:1 with UIKit; Ready = data + skip-gate eligibility)

## Git workflow

- Workspace often has **no `.git`** — do not `git init`. If git appears, branch
  `advisor/022-viewport-ready-open`; do not push unless asked.

## Architecture (target)

### State machine

```text
idle
  → preparing     (Tap; requestId = ++seq; chatId bound)
  → prepared      (EntrySnapshot built from memory/warm result)
  → viewportReady (Snapshot satisfies Ready predicate)
  → transitioning (Navigator.push started)
  → visible       (Chat first frame / heavy mounted)
  → idle          (pop / leave)

Any phase may → cancelled if requestId != current or user opens another chat.
```

Enum name suggestion: `ChatOpenViewportPhase`.

### EntrySnapshot fields (v1 — derive, don’t duplicate store)

```dart
@immutable
class ChatEntrySnapshot {
  final String conversationKey;      // c2c_* / group_* cache key
  final String conversationID;       // raw conversationID
  final int requestId;
  final int messageCount;            // rawMessageCount at capture
  final bool initialHistoryLoaded;
  final bool mayHaveOlderHistory;
  final bool completeOpenWindow;     // isCompleteOpenHistoryWindow
  final bool emptyConfirmed;         // loaded && count==0
  final String? tipMsgID;            // lastMessage.msgID if any
  final int? tipTimestamp;
  final int capturedAtMs;
  // v1 optional / nullable — fill when cheap:
  final int? layoutSizedImageCount;  // messages with known w/h meta
  final int? imageMessageCount;      // IMAGE elems in window
}
```

**Ready predicate (v1)**:

```text
emptyConfirmed
  OR completeOpenWindow
  OR (initialHistoryLoaded && messageCount > 0 && !mayHaveOlderHistory
      && messageCount < initialOpenFetchCount)  // short chat already exhausted
```

Reuse `ConversationPreviewHistorySync.isCompleteOpenHistoryWindow` + empty
logic from `_startOpenHistoryGate` — do **not** invent a second completeness
definition.

### Coordinator API (sketch)

```dart
class ChatOpenViewportCoordinator {
  static final instance = ChatOpenViewportCoordinator._();

  int get currentRequestId;
  ChatOpenViewportPhase phaseFor(String conversationKey);

  /// Prepare + wait until Ready or [timeout]. Returns snapshot; may be !ready.
  Future<ChatEntrySnapshot> prepareForOpen({
    required V2TimConversation conversation,
    Duration timeout = const Duration(milliseconds: 220),
  });

  bool isCurrent(int requestId, String conversationKey);
}
```

Internally call existing `ensureCompleteOpenWindow` then build Snapshot from
`TUIChatGlobalModel`.

## Steps

### Step 1: Add EntrySnapshot + Ready predicate + contracts

1. Create `lib/src/models/chat_entry_snapshot.dart` with fields above.
2. Add `ChatEntrySnapshot.capture(...)` factory that reads
   `TUIChatGlobalModel` + optional `V2TimConversation.lastMessage`.
3. Add `bool get isViewportReady` implementing the Ready predicate.
4. Unit/contract tests: complete window → ready; empty confirmed → ready;
   thin non-exhausted window → not ready.

**Verify**: `flutter test test/chat_open_viewport_ready_contract_test.dart` →
pass for Snapshot cases.

### Step 2: Add ChatOpenViewportCoordinator + wire tap path

1. Create `lib/src/services/chat_open_viewport_coordinator.dart`.
2. `prepareForOpen`:
   - bump `requestId`, set phase `preparing`
   - `await ensureCompleteOpenWindow` (existing)
   - capture Snapshot → `prepared` → if `isViewportReady` then `viewportReady`
   - on timeout still return Snapshot (possibly not ready)
3. In `conversation.dart` `_handleOnConvItemTaped` (push route branch):
   - replace raw `ensureCompleteOpenWindow` + push with:
     - `final snap = await coordinator.prepareForOpen(...)`
     - if `!coordinator.isCurrent(...)` return (race)
     - mark phase `transitioning`, then `Navigator.push`
   - Pass readiness into Chat via a **small, explicit** channel (pick one;
     do not invent two):
     - **Preferred**: static/thread-local on coordinator
       `bool takeOpenWasViewportReady(String key)` consumed once in Chat
       `initState`, **or**
     - optional ctor flag on `Chat` / `appChatRoute` (`openViewportReady: bool`)
4. Perf logs: `viewport_preparing`, `viewport_ready`, `viewport_ready_miss`,
   `navigator_push_begin` (keep), include `requestId`, `ready`, `rawCount`.

**Verify**: existing warm/open contracts still pass; new coordinator tests for
requestId invalidation (prepare A, start prepare B, A result ignored).

### Step 3: Chat open path — Ready vs fallback shell

1. When `openViewportReady == true` (from Step 2 channel):
   - Set `_heavyChatBodyMounted = true` **immediately** (or after first
     post-frame at latest) — **do not** wait for route animation to show empty
     message area.
   - Still call `_startOpenHistoryGate` — expect
     `history_gate_content_ready_skip` (assert via log mark in debug/tests).
2. When `openViewportReady == false` (timeout / cold):
   - Keep 020 behavior: light shell during transition, mount heavy on settle /
     360ms timeout.
3. Do **not** remove `_buildChatAppBar` sharing / GlobalKey header fix.
4. Document in a short comment at `_scheduleHeavyChatBodyMount`: Ready path
   bypasses shell delay.

**Verify**:

- Contract: source contains both Ready bypass and fallback shell path.
- Manual / log: warm chat open → `viewport_ready` then
  `history_gate_content_ready_skip` without long empty shell.
- Cold chat open → may see shell; list becomes scrollable after mount.

### Step 4 (optional in same PR if time): Snapshot image meta counters

If Step 1–3 green and time remains:

- When capturing Snapshot, count IMAGE messages and how many already have
  layout width/height (SDK image elem or local meta).
- Do **not** fail Ready solely on missing image sizes in v1.
- Log counters on `viewport_ready` for 017 follow-up.

**Verify**: extras present in perf log mark; no behavior change required.

## Test plan

New file: `test/chat_open_viewport_ready_contract_test.dart`

| Case | Expect |
|------|--------|
| Snapshot complete window | `isViewportReady == true` |
| Snapshot empty confirmed | `isViewportReady == true` |
| Thin loaded window with mayHaveOlder | `isViewportReady == false` |
| Coordinator requestId supersede | stale prepare does not mark current ready |
| `conversation.dart` / `chat.dart` source contracts | prepare → push ordering; Ready bypasses shell delay; fallback keeps shell |

Pattern after: `test/chat_open_warm_window_count_contract_test.dart`,
`test/media_preview_chat_scroll_lock_contract_test.dart`.

## Done criteria

- [ ] `ChatEntrySnapshot` + Ready predicate exist and are tested
- [ ] Tap path goes through `ChatOpenViewportCoordinator.prepareForOpen`
- [ ] Push only after prepare returns (still ≤ ~220ms timeout; never infinite wait)
- [ ] Ready opens skip empty-shell delay; fallback opens keep 020 shell
- [ ] Warm count remains 20; no new “prefetch all conversations”
- [ ] `flutter test` commands in table pass
- [ ] `dart analyze` on in-scope files: no errors
- [ ] `plans/README.md` row 022 → DONE

## STOP conditions

Stop and report if:

- Live code no longer has `ensureCompleteOpenWindow` or gate skip path (020
  reverted) — re-baseline before coding.
- Making Ready require cloud round-trip appears necessary for product — that
  is Strong Consistency; out of scope; ask operator.
- Embedding Ready flag requires rewriting `TIMUIKitChat` / Provider scope in
  ways that break embedded desktop chat — keep mobile push path only and
  report.
- Snapshot threatens to become a second message store (copying full
  `V2TimMessage` lists into Cell models for thousands of rows) — **reject**;
  Snapshot must be captured at tap from existing `messageListMap`, not
  duplicated per Cell in the feed.

## Maintenance notes

- Ready definition must stay shared with
  `ConversationPreviewHistorySync.isCompleteOpenHistoryWindow` — single source.
- If operators later want Strong Consistency, add a flag
  `ChatOpenConsistency.strong` that extends prepare timeout and awaits cloud
  peek — do not silently change default.
- Light shell remains valuable as **degraded** UX; do not delete until Ready
  hit rate is measured high in production logs (`viewport_ready` vs
  `viewport_ready_miss`).

## Rollback

1. Conversation tap: call `ensureCompleteOpenWindow` + push directly (020).
2. Chat: always use shell delay mount (ignore Ready flag).
3. Delete coordinator/snapshot files if unused.

## Executor report-back

- Files changed
- Ready hit vs miss behavior observed in logs/tests
- Any STOP hit
- `plans/README.md` updated
