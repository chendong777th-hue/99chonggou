# Plan 092: 建立腾讯云消息云端对账与 Seq 补洞

> **Executor instructions**: Follow this plan step by step. Run every
> verification command and confirm the expected result before moving to the
> next step. If anything in the "STOP conditions" section occurs, stop and
> report — do not improvise.
>
> **Drift check (run first)**: `git diff --stat 9f7c46e..HEAD -- third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart third_party/tencent_cloud_chat_sdk/lib/manager/v2_tim_message_manager.dart pubspec.yaml test`
> If any in-scope file changed since this plan was written, compare the
> Current state excerpts against live code before proceeding.

## Status

- **Execution**: in progress. Steps 1–4 are complete. The single-revision
  writer is now wired into production history pagination and realtime intake:
  realtime callbacks are held by the active generation, current history
  completion merges authority + history + pending realtime, stale completions
  consume nothing, and a failed request releases pending realtime. The former
  source-provenance blocker is resolved:
  the host app now injects network reachability + IM socket readiness, and a
  cloud response is proven only when both request boundaries are online;
  offline/unknown results remain local-only/incomplete. Pagination records this
  provenance without message bodies. Bounded reconnect/open/foreground
  catch-up now coalesces per conversation, stops after three attempts or ten
  seconds, invalidates timed-out SDK completions, uses group Seq-only cursors
  and bounded `messageSeqList` gap repair, and commits fetched rows through the
  same reconciliation writer. Step 5 deferred/hidden projection convergence
  remains. The legacy global model still contains archive/SDK
  Seq-only correlation and must not be removed until provenance distinguishes
  a real archive duplicate from a same-Seq, different-server-`msgID` conflict.
- **Priority**: P0
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: plans/072 (single-writer migration), plans/080 (explicit message synchronization result), plans/077 (message commit coordinator)
- **Category**: bug
- **Planned at**: commit `9f7c46e`, 2026-08-24

## Why this matters

Users report that a message is visible on one device but absent on another, and
leaving/re-entering the conversation makes it appear. The Tencent Chat contract
allows a cloud history request to return local messages when the network is
abnormal, and group messages have a server-assigned `seq` that can detect gaps.
The current app has a second, UI-facing deferred/hidden projection on top of the
SDK list; without an explicit cloud reconciliation state, a missing message can
be indistinguishable from a deliberately buffered message. This plan makes the
SDK/local store the only message authority, adds bounded cloud reconciliation,
and makes Seq gaps observable and recoverable without replacing newer realtime
messages.

## Current state

### Relevant code

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
  owns inbound callbacks, batching, deferred unread state, hidden projections,
  message-list commits, aliases, and the derived visible list.
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart`
  drives initial history and pagination through `loadChatRecord`.
- `third_party/tencent_cloud_chat_sdk/lib/manager/v2_tim_message_manager.dart`
  exposes `getHistoryMessageList` with local/cloud and older/newer directions,
  `lastMsg`, `lastMsgID`, and group `lastMsgSeq`.
- `third_party/tencent_cloud_chat_sdk/lib/models/v2_tim_message.dart`
  contains `msgID`, SDK-local `id`, `seq`, sender, timestamp, and status. `id`
  is not a server message identity; it is maintained by the plugin for progress
  callbacks.

### Confirmed code facts

At `tui_chat_global_model.dart:2010-2065`,
`_shouldDeferIncomingToVisibleList` intentionally routes messages to a buffer
when the active chat is away from the bottom, in a context menu, or in a
background state. `_bufferIncomingWhileReadingAway` stores the message under a
dedup key and only exposes it after an explicit flush.

At `tui_chat_global_model.dart:4845-4975`,
`_applyInboundMessageBatch` can choose between immediate upsert and buffering
for each realtime message. That decision is made from current scroll geometry
and keyboard state, so it is not a synchronization acknowledgement.

At `tui_chat_global_model.dart:6583+`, `setMessageList` can merge or replace a
history window, retain in-flight outgoing messages, apply memory-window rules,
and publish revisions. This is a high-risk write boundary and must remain the
only commit path after plans 072/077/080 land.

At `tui_chat_global_model.dart:8922-8960`, `getMessageList` constructs a derived
list, removes `_inboundHiddenKeysByConv`, applies lifecycle filters, sorts, and
caches the result. A non-empty raw list therefore does not prove that the user
can see every message.

At `tim_uikit_chat.dart:1617-1668`, history loading uses `lastMsgID` and, for
some paths, also passes `lastMsgSeq`; at `3235-3305` the preload path reads only
`V2TIM_GET_LOCAL_OLDER_MSG`. The SDK wrapper documents that when both `lastMsg`
and `lastMsgSeq` are supplied, `lastMsg` wins, and that cloud pulls can fall
back to local data when offline.

### Tencent Cloud contract to honor

- Cloud history and local history are distinct sources; a cloud request may
  return local data during a network exception: <https://trtc.io/zh/document/48000>
- Group messages are ordered by server-assigned Seq; gaps must be treated as a
  synchronization condition, not filled by sorting timestamps:
  <https://trtc.io/zh/document/34971>
- SDK interfaces requiring authentication must wait for SDK ready, and network
  state changes/reconnects must be handled by the app:
  <https://trtc.io/zh/document/48866>
- Same-platform multi-device login limits and kick-out behavior are controlled
  in the Tencent Cloud console: <https://trtc.io/zh/document/47969>
- The project pins vendored Chat SDK 8.7.7201 while the repository comment says
  it is intended to align with 8.9.x. Version migration must be validated as a
  separate compatibility step; do not silently change native SDK binaries in
  this plan.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Format check | `dart format --output=none --set-exit-if-changed <changed Dart files>` | exit 0, no files reported |
| Target tests | `flutter test test/message_ordering_test.dart test/chat_body_variable_font_test.dart` | all tests pass |
| Full tests | `flutter test` | exit 0, or only pre-existing failures documented |
| Static analysis | `flutter analyze` | no new analyzer errors in changed files |

## Scope

**In scope**

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/tim_uikit_chat.dart`
- `third_party/tencent_cloud_chat_sdk/lib/manager/v2_tim_message_manager.dart`
- A new narrowly scoped reconciliation/coordinator utility under
  `third_party/tencent_cloud_chat_uikit/lib/ui/utils/` or the existing business
  logic layer, matching current package conventions.
- Tests under `test/` and, if package-local tests are required, the corresponding
  vendored package test directory.

**Out of scope**

- Tencent Cloud server data, REST history APIs, or console settings changes.
- Changing message payloads, sending protocol, message content, read receipts,
  unread semantics, or recall/delete behavior.
- Disabling deferred scrolling, chunk reveal, or the “return to bottom” UX.
- Replacing the entire SDK or changing native iOS/Android binaries in the same
  patch.
- Any font, keyboard, media preview, call, or conversation-list work.

## Steps

### Step 1: Add an explicit reconciliation state and diagnostics

Create a typed per-conversation state owned by the post-072/077 single writer.
It must distinguish `idle`, `initialHistory`, `realtimePending`, `cloudCatchUp`,
`gapDetected`, `offlineLocalOnly`, `complete`, and `failed`. Record source
(`realtime`, `local`, `cloud`), request generation, last confirmed `msgID`,
oldest/newest numeric Seq where available, and missing Seq ranges for groups.

Do not infer cloud completeness from a non-empty result. Capture the SDK network
state and whether the result was explicitly requested from local or cloud.
Diagnostics must log IDs and counts, never message bodies or UserSig values.

**Verify**: add pure unit tests for state transitions, duplicate events, stale
request generations, empty cloud responses, and offline-local responses; run
`flutter test <new reconciliation test>`. All pass.

### Step 2: Make message identity and group continuity deterministic

Use `msgID` as the exact message identity when present. Keep SDK-local `id` only
for correlating optimistic send/progress state. For group conversations, parse
`seq` as a numeric value and maintain continuity metadata; never dedupe solely
by timestamp, body, or `id`.

When a message has no `msgID` (for example a local optimistic message), route it
through the existing outgoing stable-id correlation from plans 018/045/049 rather
than inventing a cloud identity. When two records have the same Seq but different
`msgID`, retain both and emit a diagnostic; do not silently delete either record.

**Verify**: extend `test/message_ordering_test.dart` or create a focused test
covering realtime-then-history, history-then-realtime, same Seq/different ID,
missing Seq, optimistic local ID becoming server `msgID`, and repeated retries.

### Step 3: Serialize initial history, realtime intake, and cloud catch-up

While initial history or catch-up is in flight, enqueue realtime messages in the
single writer. Commit in this order:

1. commit the fetched result into the SDK-backed authoritative store;
2. merge pending realtime messages by identity;
3. sort using the existing chronological comparator;
4. update continuity metadata;
5. publish exactly one UI projection revision.

Never call `setMessageList(replace: true)` from a late history result without
merging messages received after the request began. Every asynchronous completion
must check the request generation and discard stale results without changing the
authoritative store.

**Verify**: add a deterministic fake-clock test that interleaves history, two
realtime batches, a reconnect catch-up, and a stale completion. Assert the final
list contains every unique `msgID` exactly once and preserves chronological order.

### Step 4: Add bounded cloud catch-up and Seq-gap repair

After SDK ready, network reconnection, app foreground, and opening a conversation,
run at most one coalesced catch-up request for the active conversation. For group
chats, use the SDK advanced history API in the cloud-newer direction from the last
confirmed Seq; do not pass both a `lastMsg`/`lastMsgID` and `lastMsgSeq` cursor in
the same request because the SDK gives precedence to `lastMsg`.

If a group Seq gap is detected, request the bounded missing range using the
available `messageSeqList`/Seq cursor API. Retry with exponential backoff and a
hard attempt/time limit. If the SDK reports offline/local-only data, leave the
state as incomplete and retry after network recovery; do not mark it complete.

For C2C, use the existing last-message/time cursor semantics and do not apply
group Seq continuity rules. Preserve the existing C2C protections from plans
049–051.

**Verify**: fake the SDK for online cloud, offline local fallback, reconnect,
empty result, Seq gap, duplicate result, and timeout. Assert no unbounded loop,
no duplicate rows, no data loss, and a retry after reconnect.

### Step 5: Make deferred/hidden projection self-healing

Keep the current reading-away behavior, but attach the reconciliation generation
to buffered and hidden keys. On successful cloud catch-up, explicit return-to-
bottom, route disposal, foreground resume, or a watchdog expiry, flush/reveal
only keys belonging to the current generation. A hidden key must never survive a
completed reconciliation or remain hidden if its authoritative message is not
present in the buffered state.

Do not force `jumpTo`, disable user scrolling, or clear unread counts as a side
effect of reconciliation. Those remain controlled by the existing scroll policy.

**Verify**: add tests for keyboard viewport change, user scrolling away, chunk
reveal cancellation, route exit/re-entry, and watchdog expiry. Assert the raw,
visible, buffered, and hidden sets converge after each recovery event.

### Step 6: Gate SDK version/configuration separately

Before changing SDK binaries, record the current Flutter plugin, iOS, and Android
native SDK versions. Verify the Tencent Cloud console supports the required
multi-device policy and that all devices use the same SDKAppID/account. Then
evaluate upgrading the vendored SDK to the approved 8.9.x-compatible set in a
separate commit/plan. If the native binaries cannot be upgraded together, stop
and report rather than changing only the Dart package.

**Verify**: run the existing platform build checks for iOS and Android and a
manual two-device matrix: online/online, offline→online, app background/return,
same-platform multi-device, and forced kick-out. Capture reconciliation logs for
each case.

## Test plan

- Pure identity/Seq tests: duplicate sources, missing ranges, same Seq/different
  IDs, optimistic-to-server transition.
- Async coordinator tests: stale completion, retry generation, offline fallback,
  reconnect, and bounded timeout.
- Projection tests: buffered/hidden/revealed convergence and route re-entry.
- Integration-style fake SDK test: initial history + realtime + cloud newer in
  all completion orders.
- Manual device matrix described in Step 6, with screenshots compared by message
  IDs/Seq rather than visual position only.

Use the existing message ordering and history recovery tests as patterns; do not
rely on real network calls in unit tests.

## Done criteria

- [ ] One single writer owns history, realtime, local mutation, and reconciliation commits.
- [x] Group Seq gaps are detected and repaired through bounded cloud requests.
- [x] Cloud/local fallback is represented as incomplete, not success.
- [x] Late history results cannot overwrite newer realtime messages.
- [ ] Raw, buffered, hidden, and visible message sets converge after recovery.
- [ ] All new identity, ordering, retry, and projection tests pass.
- [ ] `flutter analyze` introduces no new analyzer errors in changed files.
- [ ] No native SDK binary is changed without a separate compatibility review.
- [ ] Only in-scope files are modified.

## STOP conditions

- The code has not completed plans 072/077/080 and there is no single writer;
  stop instead of adding another reconciliation bypass.
- The SDK/native version cannot expose cloud-newer or Seq-based history on the
  target platform; report the limitation and do not fake completeness.
- A history response cannot be distinguished from offline local fallback.
- A fix requires changing message payloads, server behavior, or deleting existing
  local messages.
- A same-Seq/different-msgID case appears in production data; preserve both and
  escalate for Tencent Cloud protocol confirmation.
- Any test shows changed message order, unread count, recall/delete state, draft,
  send status, or media content.

## Maintenance notes

Future changes to pagination, message windows, scroll buffering, optimistic send
correlation, or SDK upgrades must update the reconciliation tests first. Reviewers
should inspect generation checks on every async completion, the distinction
between cloud and local results, and the invariant that UI projection state can
never delete or permanently hide an SDK-authoritative message.
