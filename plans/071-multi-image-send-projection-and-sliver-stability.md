# Plan 071: 保证多图发送数量与聊天页气泡数量一致

> **Executor instructions**: 先执行漂移检查，逐步完成每个验证门。仅修改本计划 Scope 中的文件；遇到 STOP 条件立即报告，不要扩大范围。

## Status

- **Priority**: P0
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: plans/058-060（保持其发送占位/SDK 接管语义）
- **Category**: bug
- **Planned at**: commit `9f7c46e`, 2026-08-23

## Why this matters

现场日志显示相册选择 4 张、每张 `resolve_file_end` 成功，但 `image_send_queue_start count=1`；另一轮显示发送队列 3 张而聊天页仅 2 个气泡。与此同时 Flutter 反复报告 `RenderSliverMultiBoxAdaptor.childMainAxisPosition` 的 null check 异常。腾讯 IM 云端历史中存在连续、不同 msgID/seq 的图片，故问题位于 optimistic 占位合并、SDK 回执接管或 Flutter 列表投影，而非上传数量。修复后，N 张成功导出的图片必须产生 N 个唯一 SDK/本地投影行，且批量刷新不能触发 Sliver 子项失配。

## Current state

- `tui_chat_separate_view_model.dart:6174-6242` 批量创建 optimistic 图片，给消息写 `random: optimisticId.hashCode`，再调用 `setMessageList`；日志只记录批量总数和 rawAfter。
- 同文件的 `hydrateOptimisticImagePlaceholder` 通过 clientId/stableId 在 `rawMessageList` 查找 pending 行；任一查找失败会取消该行，发送队列因此小于选择数。
- `tui_chat_global_model.dart:6276-6395` 的 `setMessageList` 始终执行 `dedupeMessages`、排序和内存窗口处理；必须证明多条 pending 图片的 dedup key、stable id、local seq 均不同。
- `tim_uikit_chat_history_message_list.dart:6575-6607` 为列表行计算稳定 key，优先 outgoingStableId/id/msgID，再回退 sender/timestamp/seq/random/elemType；任何重复 key 都可能造成 Sliver 回收错位。
- 日志错误 `RenderSliverMultiBoxAdaptor.childMainAxisPosition` 表明列表在异步 hydrate/替换/取消期间出现 child 与 index 映射失配；不得只吞异常，必须保证批量提交和 key 稳定。

## Commands you will need

| Purpose | Command | Expected |
|---|---|---|
| Drift | `git diff --stat 9f7c46e..HEAD -- third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart` | Review any drift before editing |
| Static check | `git diff --check -- <in-scope files>` | No whitespace errors |
| Flutter tests | `flutter test <focused tests>` | Exit 0; if engine permission fails, record BLOCKED |

## Scope

**In scope**

- `third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart`
- `third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/tui_chat_global_model.dart`
- `third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKItMessageList/tim_uikit_chat_history_message_list.dart`
- Focused regression tests under `test/` for multi-image identity, hydrate count, and list-key uniqueness.

**Out of scope**

- Tencent IM SDK payload/API changes.
- PhotoKit export, compression, or picker UI.
- Memory-window size changes, pagination semantics, or unrelated call/chat features.
- Suppressing Sliver exceptions without fixing the identity/index invariant.

## Steps

### Step 1: Add a deterministic batch identity audit

Log (without file paths or message content) each selected index, optimisticId, stableId, random, localSeq, and the raw list count before/after `setMessageList`. In `hydrateOptimisticImagePlaceholder`, log target id, raw count, match count, found/pending booleans, and the resulting raw count. Add a debug-only assertion/test helper that all IDs and list keys in one batch are unique.

**Verify**: focused test reproduces a 4-item batch and asserts 4 unique IDs/keys and 4 hydrate successes.

### Step 2: Fix canonical pending-message identity and dedupe

Trace `messageDedupKey`, `_outgoingCorrelationKey`, group sequence handling, and `setMessageList` merge order. Ensure pre-SDK messages cannot share a group seq, random, stable id, or fallback key. Preserve the existing rule that optimistic and its SDK replacement collapse to one row, while two different optimistic images never collapse. If identity cannot be proven, STOP rather than adding FIFO/time-based guessing.

**Verify**: unit tests cover two same-second images, four identical-byte images, and optimistic→SDK replacement; expected canonical count remains 4 then 4.

### Step 3: Make hydrate/adopt atomic with the list projection

Ensure each successful hydrate updates exactly its matched row and does not rebuild from a stale snapshot that can erase sibling pending rows. Ensure SDK send completion replaces by a unique stable/client/msgID identity and records matchedCount; `matchedCount != 1` must emit a diagnostic and use a safe full merge that preserves all unrelated rows. Do not remove a row merely because a callback arrived out of order.

**Verify**: a three-image send with serial SDK completions in reverse order leaves three canonical rows and three display rows.

### Step 4: Enforce Sliver-safe stable keys and refresh timing

Audit `_stableMessageListKey`, `findChildIndexCallback`, and any `VisibilityDetector`/`AutoScrollTag` key used for message rows. Keys must be non-null and unique for every canonical row before and after SDK adoption. Batch list mutations must occur in one committed projection update; do not remove children during the same frame in which the sliver is laying out. Add a regression test or instrumentation for duplicate keys and row-count changes.

**Verify**: profile/debug reproduction emits no `childMainAxisPosition` null-check stack and list row count remains equal to canonical count through hydrate and send completion.

## Test plan

- Add focused tests following existing message projection/dedupe test style.
- Cases: 1/3/4/9 selected images; same timestamps; identical file sizes/bytes; reverse completion order; one failed send; restart/history rebuild from SDK messages.
- Assert selected → placeholder → hydrate → queue → SDK adopt → display counts, unique keys, and no sibling loss.
- Run the narrow tests first, then the package test command available in the repository. If Flutter engine cache permission fails, mark the plan BLOCKED with the exact command/error.

## Done criteria

- [ ] For N successfully resolved images, queue and canonical/display counts are N.
- [ ] Distinct images never share dedup identity; optimistic/SDK pair still collapses to one.
- [ ] No `RenderSliverMultiBoxAdaptor.childMainAxisPosition` null-check error in the focused reproduction.
- [ ] Regression tests cover out-of-order completion and same-second multi-image sends.
- [ ] `git diff --check` passes and no out-of-scope files change.
- [ ] Update `plans/README.md` status row.

## STOP conditions

- The live identity or list code differs materially from the excerpts.
- Fix requires changing SDK payload/history behavior or picker export.
- A row cannot be assigned a unique identity without inventing time/FIFO correlation.
- Flutter tests remain blocked after one reasonable attempt; report instead of weakening assertions.

## Maintenance notes

Future changes to dedupe, memory-window trimming, message row keys, or optimistic→SDK adoption must preserve the invariant: canonical SDK messages and pending rows have unique identities, and one projection commit cannot erase unrelated siblings. Reviewers should inspect count/key assertions and reverse-completion behavior first.
