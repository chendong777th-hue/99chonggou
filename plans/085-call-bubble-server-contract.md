# 客户端限制说明：不改服务端时的通话气泡去重边界

本方案不修改服务端，不新增接口、不新增服务端字段、不要求服务端支持 version/eventId/tombstone。客户端只利用现有 SDK payload、本地通话记录和已有服务端回填结果做去重。

## 1. 客户端可用身份优先级

客户端按以下顺序建立本地 alias：

```text
现有 callSessionId
→ inviteID
→ roomId + caller/callee
→ 本地通话记录的 callId
→ 受限时间窗口内的候选匹配
```

最后一级只能作为候选，不能单独决定合并。

现有记录字段示例：

```json
{
  "callSessionId": "server-generated-id",
  "conversationId": "c2c_user_or_group_id",
  "callerId": "user-id",
  "calleeId": "user-id",
  "mediaType": "audio|video",
  "status": "ringing|connected|rejected|cancelled|timeout|failed|ended",
  "durationSec": 22,
  "startedAt": 0,
  "connectedAt": 0,
  "endedAt": 0,
  "version": 7
}
```

## 2. 客户端幂等规则

同一客户端进程内和本地持久化索引中，相同 alias 只能对应一条终态气泡。后到的终态按本地状态机升级，不能回退：

```text
ringing → connected → ended
ringing → rejected/cancelled/timeout/failed
```

重复的 rejected、ended 或相同 duration 更新必须是 no-op。

## 3. 多端与重连限制

不同设备可能没有一致的通话 ID 或事件顺序。客户端只能在收到本地/SDK/已有服务端记录后做 alias 合并，不能保证未带共同身份的两台设备记录一定合并。

## 4. 本地对账

前后台恢复、登录、进入聊天页时，客户端只对本地消息列表、CallResultRepository 和 SDK 当前历史做一次合并；不新增网络对账接口。

## 5. SDK 消息关联

腾讯 IM 自定义消息的 payload 必须携带：

```json
{
  "businessID": "lk_call",
  "callSessionId": "if-present",
  "status": "ended",
  "version": 7,
  "durationSec": 22,
  "mediaType": "audio"
}
```

`inviteID`、roomId 和本地 callId 通过客户端 alias 表关联；缺少共同身份时不得仅凭时间/时长强行合并。

## 6. 客户端验收清单

- 同一设备重复 LiveKit/CallKit/SDK/恢复回调最终只有一条气泡；
- SDK 消息重发不会产生新的本地气泡；
- 本地 pending 升级到 SDK/服务端记录时原地更新；
- 不同 callId、不同 roomId、不同时间窗口的通话不会误合并；
- 前后台恢复和进入页面补偿不会重复插入；
- 无法确认身份的记录保留并输出诊断，不静默丢弃。

## 7. 已知限制

不修改服务端时，客户端无法保证不同设备生成且完全没有共同 ID 的两条记录一定合并；也无法保证跨设备事件顺序。客户端只能保证同一设备多来源回调、SDK 重发、本地恢复和已有共同 ID 的记录幂等。不得用时间戳或 duration 作为永久唯一键。
