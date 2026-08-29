# Plan 057: Stabilize the back-to-bottom capsule against stale latest-state and viewport changes

> **Executor instructions**: Follow this plan independently after reading it
> fully. This plan addresses the blue “回到底部” capsule being shown after a
> latest window has settled or after keyboard/asynchronous layout changes. Do
> not change unread semantics, pagination ordering, or the meaning of an
> explicit user scroll.

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: 056-dedupe-inbound-pending-batches.md (soft; use the same
  diagnostic vocabulary, but the capsule fix can be developed independently)
- **Category**: bug
- **Planned at**: commit `363b315`, 2026-08-23

## Why this matters

The screenshot shows the conversation near the newest visible messages while
the blue “回到底部” capsule remains visible. The capsule is driven by both
physical `ScrollPosition` and independent state (`_showScrollToBottomCapsule`,
`_userLeftBottomIntentionally`, `haveMoreLatestData`, and
`memoryWindowMissingNewer`). Keyboard insets, image/text height measurement,
and latest-window reloads can change the viewport without clearing every one of
those states, producing a stale affordance and confusing the user.

## Current state

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/tim_uikit_chat_history_message_list_tongue_container.dart`
  owns the capsule state and rendering.
- `_computeScrollToBottomCapsuleVisible` around lines 515–561 requires the
  user-left-bottom latch and a distance greater than roughly one viewport.
- `_buildTongueSelector` around lines 920–936 combines that latch with
  `physicallyAtBottom`, `selectorData.haveMoreLatestData`,
  `presentationBottomLocked`, and programmatic-scroll state.
- `back_to_bottom_capsule_policy.dart` defines the final visibility policy;
  preserve its explicit-user-scroll behavior.
- `tui_chat_separate_view_model.dart` exposes `haveMoreLatestData` and also
  considers `globalModel.memoryWindowMissingNewer(conversationID)`.
- The message list uses a reversed `CustomScrollView`; its physical bottom is
  `ScrollPosition.minScrollExtent`, not `maxScrollExtent`.
- Existing diagnostics already emit a `tongue_state` event containing
  `bottomVisible`, `pixels`, `minExtent`, logical position, and presentation
  lock. Extend that event only with the missing source booleans needed to
  distinguish “more latest data” from stale viewport/latch state.

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| Policy tests | `flutter test test/back_to_bottom_capsule_policy_test.dart` | All tests pass |
| Targeted static check | `flutter analyze --no-fatal-warnings --no-fatal-infos third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/tim_uikit_chat_history_message_list_tongue_container.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/back_to_bottom_capsule_policy.dart` | No analyzer errors |
| Formatting/diff check | `dart format --output=none --set-exit-if-changed <touched Dart files>` | Exit 0 |
| Whitespace check | `git diff --check` | Exit 0 |

## Scope

**In scope:**

- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/tim_uikit_chat_history_message_list_tongue_container.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/TIMUIKitTongue/back_to_bottom_capsule_policy.dart` only if a policy-level helper is required
- `test/back_to_bottom_capsule_policy_test.dart`
- A new focused state/contract test under `test/` if the current policy test cannot exercise the stale-state transition

**Out of scope:**

- changing unread counts or read receipts;
- changing `haveMoreLatestData`/SDK `isFinished` semantics;
- changing pagination page size or memory-window limits;
- changing reversed-list orientation;
- automatically forcing the user to the latest position without an explicit
  user action or an existing presentation-bottom lock.

## Steps

### Step 1: Characterize the three visibility cases

Add tests for:

1. physically at bottom + no missing newer data → capsule hidden;
2. physically at bottom + `haveMoreLatestData`/missing-newer true → preserve
   the existing product decision, but make the source explicit in diagnostics;
3. physically away from bottom by more than one viewport after an intentional
   drag → capsule visible;
4. keyboard/viewport change settles at bottom → stale `_userLeft...` state is
   cleared or ignored for visibility;
5. programmatic return-to-bottom lock → capsule hidden until the lock settles.

Model the tests after `test/back_to_bottom_capsule_policy_test.dart`; do not
use golden screenshots as the only assertion.

**Verify:** `flutter test test/back_to_bottom_capsule_policy_test.dart` → all
existing and new policy tests pass (the stale-state test should fail before the
fix if the current state is reproducible in the test seam).

### Step 2: Separate “missing newer data” from stale physical/latch state

Refine the capsule decision so a true “more latest data” signal is preserved,
while a viewport-only transition cannot leave `_showScrollToBottomCapsule` or
`_userLeftBottomIntentionally` latched after the list is physically settled.
Use the existing `presentationBottomLocked` and programmatic-scroll guards.
Do not clear a capsule that represents an intentional user scroll away from the
bottom when the list is genuinely more than one viewport away.

If viewport changes need a reset hook, trigger it at the existing settled
scroll/geometry boundary rather than adding a per-frame rebuild or timer.

**Verify:** targeted tests and `flutter analyze ...` → pass with no new errors.

### Step 3: Make diagnostics decisive

Extend `tongue_state` with `haveMoreLatestData`, `memoryWindowMissingNewer`,
`physicallyAtBottom`, `leftBottomByOneScreen`, and the current viewport
dimension. Keep values numeric/boolean only; do not log message content or
identifiers. This must allow production logs to distinguish a legitimate
“more latest” button from stale viewport state.

**Verify:** `git diff --check` → exit 0; targeted analyze → no errors.

## Test plan

- Policy unit tests for all five cases in Step 1.
- A regression test for a viewport change that updates `minScrollExtent` while
  the list is physically at bottom.
- A regression test proving an intentional one-screen-plus user scroll still
  shows the capsule.
- Run `flutter test test/back_to_bottom_capsule_policy_test.dart`, then
  `flutter test test` if targeted tests pass.

## Done criteria

- [ ] The capsule never remains visible solely because a keyboard/layout
  transition left a stale latch.
- [ ] A genuine `haveMoreLatestData`/missing-newer state remains visible per
  existing product behavior.
- [ ] Intentional user scrolling away from bottom still shows the capsule.
- [ ] Programmatic return-to-bottom and presentation locks hide it during
  settling.
- [ ] Diagnostics identify which branch caused visibility.
- [ ] Targeted tests, analyze, formatting, and diff checks pass.

## STOP conditions

- The current code no longer uses the named latch/policy structure.
- The proposed fix requires changing pagination completion or unread semantics.
- A test cannot distinguish a true missing-newer condition from stale viewport
  state.
- Fixing the capsule requires changing `ScrollView(reverse: true)` or global
  scroll physics.

## Maintenance notes

Keep the policy pure where possible and keep geometry sampling at settled
boundaries. Any future keyboard, media-preview, or dynamic-height change must
preserve the invariant that physical bottom, logical history position, and
missing-newer state are separately observable rather than inferred from one
boolean.
