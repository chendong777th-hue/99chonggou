# Plan 109: 让消息唯一 Writer 直接派生会话摘要

> **Executor instructions**: 保留腾讯 SDK 为网络与历史来源，但消息事实提交后必须直接
> 产生 conversation mutation。不得创建第二个实时会话 writer。完成后更新计划索引。
>
> **Drift check**: `git diff --stat 9f7c46e..HEAD -- third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models lib/src/services/conversation_local test`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: 092 Steps 1–4、103、104、106、108 committed batch contract
- **Category**: architecture / correctness
- **Planned at**: commit `9f7c46e`, 2026-08-25

## Execution record (2026-08-25)

- `MessageCommitCoordinator` 增加可选 `onCommittedBatch` callback，复用已接受的
  `MessageMutationBatch`，不改变现有 `onFlush` 和 stale-drop 语义。
- 新增 `test/message_commit_coordinator_test.dart` 回归，确认 accepted batch 同时抵达
  committed callback，且 mutation identity/generation 保持一致。
- 该 callback 目前只提供 mutation metadata，不携带已提交消息实体；会话摘要派生仍未
  切换，必须由宿主在消息事实 writer 完成后提供 accepted message facts，避免 callback
  自行成为第二消息真源。
- 增加 `CommittedMessageFacts` DTO 和可选 `onCommittedFacts` resolver 边界。该 DTO 只允许
  宿主在消息事实 writer 完成后显式提供 accepted message IDs、top message anchor、真实入站
  与 replay 标记；Coordinator 不读取消息列表、不写 SQLite、不派生 conversation。新增测试
  验证 accepted batch 才触发 facts resolver。

## Goal

消除“消息列表已经有新消息，但会话摘要等待另一条 SDK conversation callback”的双链路。
消息 reconciliation writer 成功提交后，直接派生 lastMessage、order 和 unread mutation；
SDK conversation snapshot 降级为校准输入。

## Target flow

```text
realtime/history/gap/catch-up
→ MessageCommitCoordinator single writer
→ committed message result
→ ConversationMutationEvent
→ SQLite conversation commit
→ one UI batch
```

## Steps

1. 为 `MessageCommitCoordinator` 输出 typed `CommittedMessageBatch`：conversation identity、
   accepted messages、new top message、source、generation、group seq continuity、是否真实入站。
2. 在 host bridge 中将该结果转换为 `ConversationMutationEvent`，复用 093 comparator 和 102
   watermark；禁止读取正文推断版本。
3. lastMessage 只由 accepted top message 推进；发送状态升级、撤回、peer-read、weak custom
   复用现有语义。
4. unread 仅对真实 peer inbound 且非前台活跃会话增加；history/gap replay 不重复增加。
5. SDK conversation callback 仍进入 Coordinator，但较旧 snapshot 只能校准 metadata、pin、
   mute 等字段，不能回退已提交 top message/unread。
6. 建立 operation ID 串联 message commit、conversation commit 和 UI batch。

## Verification

- 实时消息无需等待 conversation callback 即写入 SQLite 摘要。
- history/realtime 顺序反转结果相同；gap 补回不重复未读。
- 杀进程后 SQLite 摘要与消息事实一致。
- 093、102、103、104、106 和消息发送/撤回测试通过。

## STOP conditions

- 消息 writer 不能可靠区分 accepted、duplicate 和 replay。
- C2C 同秒不同消息被迫按 callback 到达顺序裁决。
- 实现需要直接从 UIKit 可见列表反推消息事实。
