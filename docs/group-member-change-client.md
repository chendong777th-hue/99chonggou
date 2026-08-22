# 群成员流游标增量同步 — 客户端对接

> 状态：客户端已接入（`GroupMemberIncrementalSyncService`）  
> 目标：断线/杀进程后用游标补齐成员增减与权威人数。  
> **勿**与 `GET /me/groups/changes`（群 Entity）或 notice inbox 混用游标。

关联：快照 `GET /group/{groupId}/members` · TCP `member_added` / `member_removed` / `member_left` · 后端说明见用户契约 / [backend-group-member-seq-sync-todo.md](./backend-group-member-seq-sync-todo.md)

---

## 1. API

```http
GET /me/groups/{groupId}/members/changes?since_seq={lastSeq}&limit=100
Authorization: Bearer <JWT>
```

| 参数 | 说明 |
|------|------|
| `since_seq` | 上次拿到的最大成员流 `seq`；首次用 `0` |
| `limit` | 默认 100，上限 200 |

成功响应（camel / snake 双读）：

```json
{
  "nextSeq": 10045,
  "hasMore": false,
  "memberCount": 128,
  "events": [
    {
      "seq": 10041,
      "type": "MEMBER_UPSERTED",
      "groupId": "m2225Q3N5CC",
      "userId": "10002",
      "nickName": "李四",
      "avatarUrl": "https://…",
      "role": 200,
      "memberCount": 128
    },
    {
      "seq": 10042,
      "type": "MEMBER_REMOVED",
      "groupId": "m2225Q3N5CC",
      "userId": "10003",
      "memberCount": 127
    }
  ]
}
```

| `type` | 含义 |
|--------|------|
| `MEMBER_UPSERTED` | 入群 / 成员可见信息补齐 |
| `MEMBER_REMOVED` | 踢人 / 退群 |

- 页级 `memberCount`：当前投影权威人数  
- 事件内 `memberCount`：写入当时人数  
- 空页：`events=[]`，`nextSeq = max(since_seq, 该群最大 seq)`  

游标过期：`since_seq > 0` 且小于库内最小成员流 seq → **HTTP 410** / `CURSOR_EXPIRED`  
→ 客户端：`syncMembersAfterMembershipChange`（成员首屏快照）后从 `since_seq=0` 重建游标。

---

## 2. 客户端落点

| 文件 | 职责 |
|------|------|
| `lib/src/models/group_member_change.dart` | 事件 / 分页模型 |
| `lib/src/api/me_group_api.dart` → `fetchGroupMemberChanges` | HTTP + 410 |
| `lib/src/services/group_local/group_member_incremental_sync_service.dart` | 按群游标 + 拉页 + upsert/删除 + 写人数 |
| 挂接 | 冷启 bootstrap、`native_post_home`、TCP auth（含全量 cooldown）、`syncFull` 成功后、进群聊 `chat_init` |
| TCP | `detail.seq` / `member_seq` → `noteRealtimeSeq`（**勿**用 `groupSeq`） |
| 登出 | `clearSession` 清本账号 `group_member_seq_*` |

本地游标 key：`group_member_seq_<ownerUserId>_<groupId>`（SharedPreferences）  
与 `group_entity_seq_*`、`group_notice_inbox_seq_*` 分离。

---

## 3. 与实时路径关系

| 层 | 责任 |
|----|------|
| TCP + tip | 在线主路径：成员首屏 REST → 刷头（单飞） |
| 本能力 | 断线 / 杀进程补偿 |
| Entity `/me/groups/changes` | 仅群名/头像/公告 |

TCP 与 Sync 按成员流 `seq` 去重前进游标；与 tip 共用 `syncMembersAfterMembershipChange` 单飞。

---

## 4. 验收

1. 离线期间拉人 → 上线后 `members/changes` 出现 `MEMBER_UPSERTED` + 正确 `memberCount`，聊天头/成员列表无需杀进程对齐  
2. 踢人/退群 → `MEMBER_REMOVED` + count 下降  
3. `CURSOR_EXPIRED`：触发一次成员首屏快照后游标恢复  
4. 后端 404 / 未部署：冷启不崩（静默跳过）  
5. Entity changes 不含成员全量名单  
