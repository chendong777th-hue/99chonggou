# 群系统通知 Inbox 游标增量同步 — 客户端对接

> 状态：客户端已接入（`GroupNoticeIncrementalSyncService`）  
> 原则：与群 Entity **分离**；日常用 `since_seq` 补 inbox；勿混用 `GET /me/groups/changes`。

关联后端：`GET /me/group-notices/changes?since_seq=&limit=`  
催办原稿：`backend-group-notice-seq-sync-todo.md`

---

## 1. API

```http
GET /me/group-notices/changes?since_seq={lastSeq}&limit=100
Authorization: Bearer <JWT>
```

响应（camel / snake 双读）：`nextSeq` · `hasMore` · `events[]`

| type | 客户端动作 |
|------|------------|
| `NOTICE_UPSERTED` | upsert 本地系统通知 |
| `NOTICE_DELETED` | 本地移除 + dismissed |
| `READ_WATERMARK` | 推进已读水位（不打 PUT） |

游标失效：HTTP **410** 或 reason `CURSOR_EXPIRED` 等 → 全量 `GET /me/group-notices` 快照后 `since_seq=0` 再拉。

---

## 2. 客户端落点

| 文件 | 职责 |
|------|------|
| `lib/src/models/group_notice_inbox_change.dart` | 事件 / 分页 / 游标异常 |
| `lib/src/api/group_notice_api.dart` → `fetchGroupNoticeInboxChanges` | HTTP |
| `lib/src/services/group_notice_incremental_sync_service.dart` | 游标 + 分页 + apply |
| `GroupSystemNoticeService` | `removeNoticeById` / `applyRemoteReadWatermark` |
| 挂接 | bootstrap、`native_post_home`、TCP auth（经 `GroupNoticeBootstrap`）、`syncFull` 后、会话页延迟 init |
| TCP | `group_system_notice`：UPSERT/DELETE + `noteRealtimeSeq`；**不**推进 Entity seq |

本地游标 key：`group_notice_inbox_seq_<ownerUserId>`

---

## 3. 与实时路径关系

- **实时**：TCP `group_changed` · `action=group_system_notice`（detail 含 `noticeId` + `seq`）
- **本能力**：断线 / 杀进程后的增量补偿
- **审批**：仍走 `GroupJoinApplicationService`（Bootstrap 内与增量并行）

---

## 4. 验收

1. 杀进程期间设管理员：冷启只打 changes，群通知入口出现新条  
2. `NOTICE_DELETED` / `READ_WATERMARK` 生效  
3. HTTP 410 → 快照后游标恢复  
4. 404 未部署：冷启不崩  
5. Entity 游标不被 inbox `seq` 污染  
