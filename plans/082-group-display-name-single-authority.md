# Plan 082: 收敛群聊昵称为单一资料快照权威

## Status

- Priority: P0
- Effort: M
- Risk: HIGH
- Depends on: 055, 072, 079
- Category: correctness / perf
- Planned at: commit `9f7c46e`, 2026-08-24

## Why this matters

群聊名称当前可能在 SDK `conversation.showName`、SQLite、GroupLocalStore、DisplayNameStore、REST 群列表和群资料事件之间来回覆盖，导致列表昵称反复跳变。目标是让所有来源只生成或投影到一个带 generation/revision 的 `GroupMetadataSnapshot`，UI 只消费快照。

## Current state

- `conversation_local_store.dart:5955-6004` 会在读取会话时用本地群资料重新水合 `showName`。
- `conversation_sync_service.dart:442-488` 会把 REST 群列表名称 patch 到会话和 DisplayNameStore。
- `conversation.dart:4463` 渲染列表时再次读取 GroupLocalStore。
- SDK `onConversationChanged` 仍会把会话 `showName` 送入同步链路。

## Scope

In scope:

- `lib/src/services/group_local/group_metadata_refresh_coordinator.dart`
- `lib/src/services/conversation_local/conversation_local_store.dart`
- `lib/src/services/conversation_local/conversation_sync_service.dart`
- `lib/src/conversation.dart`
- 群资料 revision、快照和行 fingerprint 测试

Out of scope: 群人数/公告业务字段、SDK 历史消息、会话列表布局。

## Steps

1. 定义快照权威等级：明确用户/SDK 群资料变更 > 远程详情 > 本地 SQLite 首次占位 > SDK `showName` 兜底。
2. 所有写入集中到 coordinator，拒绝旧 generation 和低权威来源覆盖已确认快照。
3. SQLite、DisplayNameStore 和会话对象改为快照投影；读取和渲染不得再次从 GroupLocalStore 旁路覆盖。
4. 将 `groupMetadataRevision` 纳入会话行 fingerprint，资料变化只失效对应群聊行，不触发消息列表整表刷新。
5. 账号切换、退出群、解散群时清理 generation 和旧快照。

## Verification

- SDK 旧名、REST 新名、本地旧缓存并发到达时最终稳定显示远程确认值。
- 同一群资料请求只提交一次快照，旧 generation 不得回写。
- 列表群名只发生一次局部行刷新，不触发全量会话或消息列表重建。
- 新增来源优先级、revision、generation 和账号隔离测试全部通过。

## STOP conditions

- 无法区分用户明确修改与 SDK 普通会话快照；
- 需要保留多个 UI 读取旁路；
- 群名变更会影响消息排序或未读语义。
