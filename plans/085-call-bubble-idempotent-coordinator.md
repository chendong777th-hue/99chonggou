# Plan 085：通话气泡单写入与跨来源幂等协调

## 目标

同一通话无论经过 LiveKit、CallKit、腾讯 IM 自定义消息、服务端通话记录、前后台恢复或多设备事件，聊天页最终只能有一条终态气泡。失败、拒绝、取消、超时和接通都必须保留正确终态，不因重复回调产生第二条记录。

## 当前问题

- `call_lifecycle_service.dart` 在通话结束时直接插入本地气泡。
- `call_bubble_insert_service.dart` 又会在聊天页打开和历史补偿时插入本地气泡。
- SDK `lk_call/hangup` 消息可能随后进入同一消息列表。
- `CallBubbleDedupe` 目前属于事后清理，无法阻止多个来源在同一帧分别提交。
- 本地 `local_call_bubble_<callId>` 与 SDK `msgID/inviteID/roomId` 并不总是同一稳定身份。

## 客户端统一模型（不改服务端）

新增 `CallTerminalMutation`，字段至少包括：

```text
accountId
conversationId
callSessionId
terminalStatus       connected/rejected/cancelled/timeout/failed
durationSec
mediaType            audio/video
callerId
calleeId
source               livekit/callkit/sdk/server/recovery
clientMutationId
serverVersion        // 可选；不依赖服务端提供
generation
```

### 唯一身份规则

1. 优先使用 payload 中已有的 `callSessionId`/`inviteId`；没有时使用 roomId+参与方+开始时间窗口生成客户端 alias。
2. `inviteId`、roomId、SDK msgID 只能建立 alias，不能直接创建第二条终态气泡。
3. 未拿到稳定 ID 时，允许创建一条 `pending` 本地占位，但必须记录 alias，后续只能 update/upsert。
4. 不允许只用“同秒”“同 duration”或 FIFO 猜测两条通话相同；无法确认身份时保留两条并记录诊断。

## 客户端实施步骤

1. 新增按 `conversationId + callSessionId` 单飞的 `CallTerminalMutationCoordinator`。
2. LiveKit/CallKit 结束回调只提交 mutation，不直接写 `V2TimMessage`。
3. SDK `lk_call/hangup` 消息先通过 alias resolver 查找已存在 mutation；命中则更新原行，未命中才创建终态行。
4. 服务端通话记录回填先经过客户端 alias resolver，命中已有记录则更新原行，不再插入本地 bubble。
5. `ensureConversationBubbles` 改为本地 reconcile：只补本地索引中不存在的 alias，不重复生成。
6. 通过统一消息提交协调器更新气泡；本地占位→SDK/服务端终态必须保持同一 stable identity。
7. 旧 `CallBubbleDedupe` 保留为迁移期保护和诊断，不再作为业务正确性的唯一机制。
8. 账号切换、退出登录、会话切换时清理旧 generation，但不能删除已确认的服务端终态记录。

## 客户端测试

- 同一通话同时收到 LiveKit 结束、CallKit 回调、SDK hangup 和服务端记录：最终 1 条气泡。
- 多设备 A 接听、B 拒绝、C 收到历史：最终按服务端终态只显示 1 条。
- 本地 pending 先出现，服务端 ID 后到：原地更新，不新增。
- 重连、前后台恢复、重复推送、SDK 历史分页、进入页面补偿：均保持 1 条。
- 不同通话相同秒数、相同 duration、不同 callSessionId：必须保留多条。
- 音频/视频、拒绝/取消/超时/接通状态和通话时长显示正确。

## 停止条件

- 所有客户端可用字段都无法区分不同通话；
- 必须依赖时间或 duration 猜测身份；
- 修改后会影响通话音频、CallKit 接听或 LiveKit 信令。
