# Plan 081: 统一会话多端操作权威与可靠对账

## Status

- Priority: P0
- Effort: L
- Risk: HIGH
- Depends on: 072, 080
- Category: correctness / tech-debt
- Planned at: commit `9f7c46e`, 2026-08-24

## Why this matters

置顶、归档、免打扰、删除目前分别走腾讯 SDK、本地 SQLite、自建 REST 和 FriendRealtimeService。当前进程内 RefreshBus 只能刷新本机，不能保证其他设备收到操作；删除还主要是本地删除。目标是为四类操作建立统一的云端 mutation、版本/tombstone、实时事件和重连对账链路。

## Current state

- 置顶默认腾讯为主，但本地 PinSync 有 optimistic 写入和 stale/echo 忽略窗口。
- 归档依赖 `conversation_archive_changed` 自建事件。
- 免打扰依赖 SDK `recvOpt`，同时存在本地 optimistic projection。
- 删除入口调用 SDK `deleteConversation` 后触发本地刷新，不等价于云端多端删除。

## Scope

In scope:

- `lib/src/services/conversation_local/conversation_sync_service.dart`
- `lib/src/services/conversation_pin_sync_service.dart`
- `lib/src/services/archived_conversation_sync_service.dart`
- `lib/src/services/conversation_refresh_bus.dart`
- 删除/免打扰/归档/置顶相关 API 和契约测试

Out of scope: 会话列表布局、消息历史来源、聊天消息 payload、群资料字段。

## Steps

1. 定义统一 `ConversationMutation`：canonical conversation ID、operation、desired value、origin device、monotonic version、generation、tombstone（删除）。
2. 所有本端操作先写云端权威，再写本地 projection；失败只回滚同一 mutation token，不覆盖后续操作。
3. 所有设备接收同一 mutation 事件；事件缺失或版本落后时，前台恢复/登录执行一次权威对账。
4. 将 Pin、Archive、Mute、Delete 接入同一 ConversationMutationCoordinator；RefreshBus 只负责本机 UI 通知，不再承担跨端同步语义。
5. 删除必须区分“本机清理历史”和“多端删除会话”；若产品要求多端删除，增加云端 tombstone，阻止旧分页重新 upsert。

## Verification

- 两台设备交叉执行四类操作，另一台在在线、断线重连、冷启动三种状态均最终一致。
- 操作 A→B→A 的快速切换不被旧 echo 或 stale version 覆盖。
- 删除 tombstone 阻止旧 SDK 分页和本地缓存回灌。
- 新增多端 mutation、版本冲突、重连对账契约测试全部通过。

## STOP conditions

- 后端无法提供版本号、可靠事件或对账接口；
- 删除语义未明确是本机还是多端；
- 需要通过定时 reload 替代权威 mutation/对账；
- 未读、草稿、置顶排序语义发生变化。
