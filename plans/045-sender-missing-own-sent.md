# Plan 045: Keep the sender’s own just-sent message on screen

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise. When done, update the status row for this plan
> in `plans/README.md` — unless a reviewer dispatched you and told you they
> maintain the index.
>
> **Drift check (run first)**: This workspace may have **no `.git`**. Compare
> every "Current state" excerpt below to the live files. If
> `_onPinToBottomRequested` no longer uses `convId != _conversationId()`, or
> `setMessageList(replace: true)` already splices in-flight outgoing from
> `previous`, mark those steps DONE / adjust and report — do not duplicate.

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: MED (replace-retain must not resurrect Plan 018 dual image bubbles;
  send-from-history must not skip the SDK `sendMessage` itself)
- **Depends on**: none (018 already landed; this plan must keep 018 green)
- **Category**: bug
- **Planned at**: working tree 2026-08-22 (NO_GIT)
- **Issue**: omit
- **Status**: DONE (2026-08-22) — pin alias match; replace retains in-flight outgoing; prepend reloads newest when `haveMoreLatestData`

## Why this matters

The sender sometimes cannot see a message they just sent, while the peer can.
Peer visibility means **IM send succeeded**. This app is local-first: the
sender’s bubble is prepended before `sendMessage`, and **own sends often never
echo via `onRecvNewMessage`**. If the local row is then (1) not scrolled to,
(2) wiped by a `replace` history write that does not yet contain the send, or
(3) inserted only into a mid-history memory window, the sender sees nothing
and the peer (sitting on the live tip) sees the message immediately.

Product intent: after the user taps send, **their own bubble must remain in
the visible latest list** (or they must be force-scrolled to it). Do not wait
for a self-echo.

## Current state

Chat list is **reversed**: visual bottom (newest) is `minScrollExtent`. Do not
flip this.

**Send + optimistic insert** —
`third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`

`sendTextMessage` (~6760–6785) and siblings (sound / custom / face / image)
create a local `V2TimMessage`, set `SENDING`, then:

```dart
void _prependOutgoingMessage(V2TimMessage messageInfoWithSender) {
  globalModel.markMessageEnterAnimation(messageInfoWithSender);
  globalModel.prepareForOutgoingMessage(conversationID);
  globalModel.assignOutgoingLocalSeq(conversationID, messageInfoWithSender);
  final currentHistoryMsgList = [
    messageInfoWithSender,
    ...getOriginMessageList(),
  ];
  globalModel.setMessageList(conversationID, currentHistoryMsgList);
  globalModel.requestPinToBottom(conversationID, force: true);
}
```

`_sendMessage` (~5395) runs **after** prepend. Success goes through
`globalModel.applyOutgoingSendResult` → `updateMessage`. There is often **no**
`onRecvNewMessage` for the sender (`lib/src/chat.dart` `messageDidSend`
comment: 己方发送不走通知侧回显).

**Replace drops in-flight outgoing** —
`third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
`setMessageList` (~5979–6002):

```dart
final previous = _mergedAliasMessageList(conversationID);
final mergedInput = replace || isDeleteMsg || previous.isEmpty
    ? messageList
    : <V2TimMessage>[...messageList, ...previous];
```

`replace: true` is the conversation-preview first screen, full history
write-back, and Plan 018 `_swapOutgoingMessage`. A concurrent hydrate /
`reloadNewestMessageWindow` / `forceReloadNewest` that does not yet contain
the just-sent row **wipes the optimistic bubble**. Peek merge already keeps
those rows — `mergePeekWindowWithLiveMemory` (~7724–7774) retains
`isSelf && (SENDING || live placeholder)` and rows newer than the window
newest — but **`setMessageList(replace:)` does not call that helper**.

**Pin can miss the open chat** —
`third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart`
`_onPinToBottomRequested` (~1441–1468):

```dart
final convId = globalModel.pinToBottomRequestConvId;
if (convId == null || convId != _conversationId()) {
  return;
}
```

`_conversationId()` is `widget.model.conversationID` (~2000). Pin requests
use `_safeConversationId`. `c2c_userId` vs bare `userId` (or community short
vs `@TGS#…`) fails **string `!=`** even though they are the same chat.
Public helper already exists on the global model (~2014):

```dart
static bool isSameConversationIdForHistory(String? left, String? right)
```

**Send while reading history** —
`haveMoreLatestData` is `_pagination.haveMoreLatestData ||
globalModel.memoryWindowMissingNewer(conversationID)` (view model ~179–181).
Prepend inserts into the **current window**. If that window is not the live
tip, pin only reaches the **fake** bottom. `reloadNewestMessageWindow`
(~1476–1516) already exists and is what the 「回到底部」 capsule uses
(`tim_uikit_chat_history_message_list_tongue_container.dart`). Send path
does not call it.

**Conventions to match**

- Source-scan contract tests: `test/chat_open_instant_pin_contract_test.dart`,
  `test/outgoing_image_bubble_dedupe_contract_test.dart`.
- `V2TimMessage` fixtures: `test/message_ordering_test.dart` `_msg(...)`.
- Conversation ID equality: **only**
  `TUIChatGlobalModel.isSameConversationIdForHistory` — do not invent
  `==` / hand-strip `c2c_`.
- Keep Plan 018: `_swapOutgoingMessage` still `replace: true` after collapse;
  retained previous placeholders **must** correlate away.

## Commands you will need

| Purpose | Command | Expected on success |
|---------|---------|---------------------|
| Pin + retain + send-from-history contracts | `flutter test test/sender_own_sent_visible_contract_test.dart` | all pass |
| 018 dual-bubble must stay green | `flutter test test/outgoing_image_bubble_dedupe_contract_test.dart test/chat_media_optimistic_send_contract_test.dart test/message_ordering_test.dart` | all pass |
| Analyze touched Dart (app graph) | `flutter analyze --no-fatal-infos --no-fatal-warnings <touched files>` | exit 0 (infos/warnings OK) |

This workspace may have **no `.git`**. Do not `git init`. Do not push.

## Suggested executor toolkit

- Follow existing contract-test style (read file as string **or** call a
  `@visibleForTesting` static helper). Prefer a real unit test for the retain
  helper (like `message_ordering_test.dart`), not only a source scan.
- Do not spawn SubAgents if the host cannot; implement on the main session.

## Scope

**In scope** (the only files you should modify):

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart`
  — `_onPinToBottomRequested` conversation-id match only
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
  — `setMessageList` replace retain + extracted helper next to
  `mergePeekWindowWithLiveMemory`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
  — after prepend, reload newest when the memory window is missing newer
- `test/sender_own_sent_visible_contract_test.dart` (create)
- `plans/README.md` (status row only)

**Out of scope** (do NOT touch, even though they look related):

- `_normalizeInboundC2cDirection` / `_c2cDirectionConsistencyScore` /
  flipping `isSelf` on inbound echo (separate C2C mirror issue)
- `isChatListUserScrolling` cancelling force-pin (keep: finger-down must win;
  picker leftover is already cleared in `endMediaPickerOverlay`)
- Plan 044 top-reach latch / `haveMoreData` / pagination constants
- 「回到底部」capsule policy (`BackToBottomCapsulePolicy`)
- Wallet cards, call bubbles, `messageShouldMount` filters
- `_swapOutgoingMessage` / outgoing correlation keys (018) except that
  retain must **not** reintroduce dual bubbles
- `mergePeekWindowWithLiveMemory` behavior for archive / local group tips
  (do not change those branches; you may **call** a new shared outgoing
  collector from `setMessageList` only)
- Git commit / push / PR unless the operator asks

## Git workflow

- This tree is often **not a git repo**. Do not `git init`.
- If `.git` exists: branch `advisor/045-sender-own-sent` if you need a
  branch; do not push unless asked.
- Do not commit unless the operator asks.

## Steps

### Step 1: Pin request matches alias conversation IDs

In `_onPinToBottomRequested` (`tim_uikit_chat_history_message_list.dart`),
replace the string inequality with the existing public helper:

```dart
final convId = globalModel.pinToBottomRequestConvId;
if (convId == null ||
    !TUIChatGlobalModel.isSameConversationIdForHistory(
      convId,
      _conversationId(),
    )) {
  return;
}
```

Do **not** change `_lastHandledPinSeq`, force vs soft pin, bulk-sync early
return, or `isUserScrollToBottomInProgress`.

**Verify**: `rg -n "convId != _conversationId\\(\\)" third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart`
→ no matches in `_onPinToBottomRequested`.
`rg -n "isSameConversationIdForHistory" third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart`
→ at least one hit in that function.

### Step 2: Extract retain helper; use it on `replace`

In `tui_chat_global_model.dart`, add a `@visibleForTesting` **static** helper
**next to** `mergePeekWindowWithLiveMemory` (do not rewrite the peek function
body except to optionally call the same collector if that is a one-line
dedup — if wiring peek is not a one-line swap, **leave peek as-is** and only
use the helper from `setMessageList`).

Suggested shape (names may vary; behavior must match):

```dart
@visibleForTesting
static List<V2TimMessage> collectUncorrelatedInFlightOutgoing({
  required List<V2TimMessage> previous,
  required List<V2TimMessage> incoming,
}) { ... }
```

Keep a previous row when **all** of these hold:

1. `message.isSelf == true`
2. It is in-flight **or** newer than the incoming window:
   - `status == V2TIM_MSG_STATUS_SENDING` or `_isLiveOutgoingPlaceholder(message)`, **or**
   - `status == V2TIM_MSG_STATUS_SEND_SUCC` **and** incoming is non-empty **and**
     `compareMessagesChronological(message, newestIncoming) > 0`
3. No incoming row matches it:
   - `messagesCorrelateForDedup(previousRow, incomingRow)`, **or**
   - same non-empty `id`, **or**
   - same non-empty `msgID`, **or**
   - same non-empty `readOutgoingStableId(...)` (import
     `chat_media_send_utils.dart` if not already visible)

Do **not** retain incoming-looking rows (`isSelf != true`).
Do **not** retain old `SEND_SUCC` that is older/equal than the incoming
newest (that would freeze a stale window).
Do **not** retain on `isDeleteMsg`.

In `setMessageList`, **only** when `replace && !isDeleteMsg && previous.isNotEmpty`:

```dart
final extras = collectUncorrelatedInFlightOutgoing(
  previous: previous,
  incoming: messageList,
);
final effectiveIncoming = extras.isEmpty
    ? messageList
    : <V2TimMessage>[...messageList, ...extras];
final mergedInput = effectiveIncoming;
```

Keep the existing non-replace merge (`[...messageList, ...previous]`)
unchanged. Then continue with `sortMessagesNewestFirst(dedupeMessages(...))`
and the memory window as today.

**Verify**: helper exists and `replace` path references it.
`rg -n "collectUncorrelatedInFlightOutgoing" third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
→ definition + `setMessageList` call.

### Step 3: Send from a stale window reloads the live tip

In `_prependOutgoingMessage` / `_prependOutgoingMessageForConversation`
(view model), **after** `setMessageList` + `requestPinToBottom`:

- If `haveMoreLatestData` is true (this already ORs
  `memoryWindowMissingNewer`), schedule
  `unawaited(reloadNewestMessageWindow())` then
  `globalModel.requestPinToBottom(targetConvID, force: true)` **again**
  after the future completes (success or fail — still pin).
- Do **not** `await` reload on the send call stack. `_sendMessage` must
  still start immediately after prepend (today’s order).
- Guard with a per-conversation in-flight flag so three rapid sends do not
  start three overlapping `forceReloadNewest` pulls. A bool / generation on
  the separate view model is enough; latest send wins or they share one
  in-flight (either is OK; do not queue unbounded reloads).
- If `reloadNewestMessageWindow` is only reachable from the separate view
  model, call it there — **not** from the global model.

`_prependOutgoingMessage` uses `conversationID`;
`_prependOutgoingMessageForConversation` uses `targetConvID`. Apply the
same hook to **both** (or implement only on `ForConversation` and route
the first through it — `_prependOutgoingMessage` currently duplicates
instead of calling `ForConversation`; do **not** drive a cleanup refactor
beyond adding the hook to both, unless a one-line delegate is obvious).

**Verify**:
`rg -n "reloadNewestMessageWindow" third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
→ still the existing method **plus** a call from the prepend path.

### Step 4: Tests

Create `test/sender_own_sent_visible_contract_test.dart`.

**A. Pin alias match (source scan)**  
Read `tim_uikit_chat_history_message_list.dart`. Between
`void _onPinToBottomRequested()` and `void _onGlobalRouteRestoreChanged()`:

- contains `isSameConversationIdForHistory`
- does **not** contain `convId != _conversationId()`

**B. Retain helper (real unit test)**  
Model fixtures after `test/message_ordering_test.dart` `_msg`.

1. `previous = [sending self text id=c1]`, `incoming = [old peer text]` →
   extras contains `c1`.
2. `previous = [sending self id=c1]`, `incoming = [succ self id=c1 msgID=m1]`
   (same id) → extras **empty** (018 / swap must not resurrect).
3. `previous = [SEND_SUCC self, timestamp 200]`,
   `incoming = [peer, timestamp 100]` → extras contains the newer self
   (history snapshot lost the just-acked send).
4. `previous = [SEND_SUCC self, timestamp 50]`,
   `incoming = [newest, timestamp 200]` → extras **empty**.

If the helper is `@visibleForTesting` on `TUIChatGlobalModel`, call it
directly. Do not construct `TUIChatGlobalModel()` just to hit
`setMessageList` (heavy / SDK).

**C. Prepend reload hook (source scan)**  
Read view model. Between `_prependOutgoingMessageForConversation` and the
next public send method (`sendTextAtMessage` or `sendSoundMessage` —
use the nearer unique neighbor):

- contains `haveMoreLatestData`
- contains `reloadNewestMessageWindow`

**Verify**:

```bash
flutter test \
  test/sender_own_sent_visible_contract_test.dart \
  test/outgoing_image_bubble_dedupe_contract_test.dart \
  test/chat_media_optimistic_send_contract_test.dart \
  test/message_ordering_test.dart
```

→ All tests passed.

## Test plan

- New file: `test/sender_own_sent_visible_contract_test.dart` (cases A–C above).
- Pattern: `test/outgoing_image_bubble_dedupe_contract_test.dart` (scan) +
  `test/message_ordering_test.dart` (fixtures).
- Regression: 018 suite must stay green (case B2 is the dual-bubble guard).
- Device (operator, **NOT RUN** in this plan): send text while scrolled
  into older history; send an image; send while already on the live tip.
  Sender must see the bubble without tapping 「回到底部」. Peer still receives.

## Done criteria

Machine-checkable. ALL must hold:

- [x] `_onPinToBottomRequested` uses `isSameConversationIdForHistory`; no
      `convId != _conversationId()`
- [x] `setMessageList` `replace && !isDeleteMsg` splices
      `collectUncorrelatedInFlightOutgoing` (or the chosen name)
- [x] Prepend path `unawaited`s `reloadNewestMessageWindow` when
      `haveMoreLatestData`, then force-pins; send is not awaited on reload
- [x] `flutter test test/sender_own_sent_visible_contract_test.dart` passes
- [x] 018 tests listed above still pass
- [x] No files outside the in-scope list are modified
- [x] `plans/README.md` status row for 045 updated

## STOP conditions

Stop and report back (do not improvise) if:

- Live excerpts no longer match (pin check or `replace` merge already changed).
- Making retain correct appears to require changing `_outgoingCorrelationKey`
  or `_swapOutgoingMessage` (018). Stop — that is out of scope.
- `reloadNewestMessageWindow` cannot be called from prepend without awaiting
  `sendMessage` or without a circular import.
- A step’s verification fails twice after a reasonable fix.
- You believe the bug is only C2C `isSelf` flipping — that is out of scope;
  still land pin + replace-retain + history reload.

## Maintenance notes

- Reviewers: 018 dual-bubble (same `id` / `msgID` / stable id must not be
  re-inserted on replace); send latency (reload must stay `unawaited`);
  community group IDs still go through `isSameConversationIdForHistory`.
- Future hydrate / `forceReloadNewest` writers should keep using
  `replace: true` — retain is now the safety net for in-flight outgoing.
- Deferred (not this plan): inbound `isSelf` mirror rewrite sending a self
  echo into the away-from-bottom buffer; leftover `isChatListUserScrolling`
  cancelling pin outside the picker path.
- Logs if it still happens: `send_done`, `upsert_self`,
  `recv_without_placeholder`, `history_list_shrink`, `memory_window`
  `trimmedAwayLatest`, `force_pin_bottom`,
  `reload_newest_message_window_*`.
