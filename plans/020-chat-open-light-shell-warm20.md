# 020 — Chat open: light shell + complete warm (20)

## Goal

Reduce enter-chat transition hitch by:

1. Pushing a **light shell** during the 300ms route animation that mirrors
   real chat chrome (same AppBar / ChatHeaderTitle / divider, message-area
   background, inert narrow input bar); mount `TIMUIKitChat` + open history
   gate only after settle (or 360ms timeout).
2. **Pre-open ensure** of a complete warm window so
   `history_gate_content_ready_skip` fires more often.
3. Lower open/warm fetch count **40 → 20** (user request).

## Non-goals

- Changing transcript semantics, wallet, calls, or conversation list layout.
- Rewriting UIKit message list architecture.
- Blocking tap forever waiting for warm (hard timeout 220ms).

## Implementation sketch

| Area | Change |
|------|--------|
| `HistoryMessageDartConstant.getCount` | `40` → `20` |
| `ConversationHistoryWarmScheduler.ensureCompleteOpenWindow` | Await press-path warm with `requireCompleteWindow`; skip only if complete |
| `conversation.dart` tap → push | Await ensure before `Navigator.push` |
| `chat.dart` | `_heavyChatBodyMounted`; shell AppBar+empty; mount after `_scheduleAfterRouteTransition` |

## Risk

Short lists (< viewport) with exactly 20-fetch “complete” false positives are
less likely than at 15, but still possible on tall phones. Pagination /
`mayHaveOlderHistory` short-session path remains the safety net.

## Verify

- `test/chat_open_warm_window_count_contract_test.dart`
- Existing peek / warm / preview sync contracts
- Manual: cold open should log `open_prewarm_*` + `heavy_chat_body_mounted`
