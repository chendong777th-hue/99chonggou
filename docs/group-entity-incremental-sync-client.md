# 群 Entity 游标增量同步 — 客户端对接

> 状态：客户端已接入（`GroupEntityIncrementalSyncService`）  
> 原则：Conversation / Entity 分离；**禁止**日常全量拉群；用 `since_seq` 只补变更。  
> 成员人数/名单：在线见 TCP+tip；断线增量见 [group-member-change-client.md](./group-member-change-client.md)，勿与本 Entity 流混管。

关联后端能力：`GET /me/groups/changes?since_seq=&limit=`

---

## 1. API

```http
GET /me/groups/changes?since_seq={last_seq}&limit=200
Authorization: Bearer <JWT>
```

响应（字段兼容 snake / camel）：

```json
{
  "next_seq": 10045,
  "has_more": false,
  "events": [
    {
      "seq": 10041,
      "type": "GROUP_INFO_UPDATED",
      "group_id": "m2225Q3N5CC",
      "group_name": "新名称",
      "avatar_url": "https://…/preview.jpg",
      "avatar_version": 8,
      "updated_at": 1786520412000,
      "notice": "可选"
    }
  ]
}
```

游标失效错误码（任一即可）：`CURSOR_EXPIRED` · `SEQ_EXPIRED` · `INVALID_CURSOR` · `CURSOR_INVALID`  
→ 客户端：`syncFull(refresh: true)` 快照后，从 `since_seq=0` 重建游标。

---

## 2. 客户端落点

| 文件 | 职责 |
|------|------|
| `lib/src/models/group_entity_change.dart` | 事件 / 分页模型 |
| `lib/src/api/me_group_api.dart` → `fetchGroupEntityChanges` | HTTP |
| `lib/src/services/group_local/group_entity_incremental_sync_service.dart` | 游标持久化 + 拉页 + 写入 GroupLocalStore |
| 挂接 | 冷启 bootstrap、`native_post_home`、TCP auth（含全量 cooldown 跳过时）、`syncFull` 成功后 |
| TCP | `group_changed.detail.seq` → `noteRealtimeSeq` 前进游标 |

本地游标 key：`group_entity_seq_<ownerUserId>`（SharedPreferences）

---

## 3. 与实时路径关系

- **实时**：`group_tip` / TCP `group_name_changed|group_avatar_changed`（已有）
- **本能力**：断线 / 杀进程后的 **增量补偿**
- **不替代**：首次登录仍可用 `/me/groups` 快照；本接口不做「进列表全员对齐」

---

## 4. 验收

1. 杀进程期间错过改名：下次启动只打 `/me/groups/changes`，列表名/头更新，无全员 `GET /group/{id}` 风暴  
2. `CURSOR_EXPIRED`：触发一次 `syncFull(refresh:true)` 后游标恢复  
3. 后端 404 / 未部署：冷启不崩（静默跳过）
