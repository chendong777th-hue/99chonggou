# Plan 110: 持久化完整已读水位与同步状态

> **Executor instructions**: 扩展现有 102 barrier，不得新增第二套 unread guard。数据库
> migration 必须兼容当前 v10 数据。完成后更新计划索引。
>
> **Drift check**: `git diff --stat 9f7c46e..HEAD -- lib/src/services/conversation_local third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models test`

## Status

- **Priority**: P1
- **Effort**: M
- **Risk**: HIGH
- **Depends on**: 102 行为验证、109 message commit identity
- **Category**: correctness / migration
- **Planned at**: commit `9f7c46e`, 2026-08-25

## Goal

让杀进程、重连和账号切换后仍能拒绝旧 unread snapshot，并明确记录同步是否完整。当前
部分 `ConversationReadBarrier` 仍依赖进程内 Map；本计划将完整水位与状态原子持久化。

## Durable fields

- read anchor msgID
- group read seq（C2C 不使用跨发送者 seq）
- read message timestamp
- read mutation version
- recorded time
- SDK clean state: pending / confirmed / failed-retryable
- last reconciled message anchor
- sync completeness: localOnly / incomplete / consistent

## Steps

1. 选择扩展 conversation row 或现有 coordinator state；禁止新增第二张 unread 真源表。
2. migration 回填现有 `read_cleared_at` 和 `last_msg_id`，未知字段保持 unknown，不伪造 0 为
   已确认水位。
3. 批量已读在同一个 transaction 写 unread=0、完整 barrier、Coordinator unread stamp。
4. SDK clean 结果只推进 clean state，不删除 barrier。
5. 所有 SDK snapshot ingress 读取 durable barrier 后再裁决；进程内 Map 只作 cache。
6. 重启恢复、alias、community、归档和多账号均使用 canonical key。

## Verification

- 清空内存 cache、关闭并重开数据库后，同锚点/旧 snapshot 仍保持 0。
- 可证明新消息正常产生 unread=1 并推进 durable state。
- migration、Web meta、多账号和 SDK clean 失败重试测试通过。

## STOP conditions

- 需要用 orderkey 证明消息前进。
- C2C 被迫使用跨发送者 seq。
- migration 会丢失现有草稿、pin、archive 或 history-cleared 字段。

