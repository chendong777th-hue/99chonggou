# 好友通讯录 Versioned Sync 联调说明

> **状态**：后端 P1 已实现 · 客户端 P1 已接入  
> **目标**：一端加/删好友、改备注、资料变更后，其它在线端靠 TCP 秒级同步；离线端上线后用 Difference 补齐，无需整表重拉（正常窗口内）。

关联：快照 `GET /me/friends` · TCP `friend_list_changed` · 旧待办归档见本文末尾「历史待办」。

## 模型

- 全局单调 `seq`（表 `friend_contact_sync_seq`）
- 事件表 `friend_contact_change`：按 `account_id`（通讯录 owner）过滤
- Contact（备注/关系）落在 `user_friend`；User（昵称/头像）落在 `users`，事件里带展示快照

## API

### Snapshot（现有，增强）

```http
GET /me/friends?limit=100&cursor=
```

响应新增：

| 字段 | 说明 |
|------|------|
| `syncSeq` | 当前账号通讯录事件流最大 `seq`；无事件为 `0` |

首次装机 / `SNAPSHOT_REQUIRED` 回退：分页拉完快照后，本地游标设为响应里的 `syncSeq`。

### Difference

```http
GET /me/friends/changes?since_seq={lastSeq}&limit=100
```

| 参数 | 说明 |
|------|------|
| `since_seq` | 上次拿到的最大 `seq`；首次用 `0` |
| `limit` | 默认 100，上限 1000 |

需登录 JWT。

#### 成功响应

见产品文档示例：`nextSeq` / `hasMore` / `events[]`（含 `type`、`tcpAction`、展示字段）。

| `type` | 含义 | 对应 TCP `action` |
|--------|------|-------------------|
| `CONTACT_CREATED` | 成友 / 恢复 | `added` |
| `CONTACT_DELETED` | 单向删除 | `removed` |
| `CONTACT_UPDATED` | 关系态变化（如对方删我） | `updated` |
| `CONTACT_REMARK_UPDATED` | 本人改备注 | `remark_updated` |
| `CONTACT_PROFILE_UPDATED` | 对方昵称/头像/可见性 | `profile_updated` |

空页：`events=[]`，`nextSeq = max(since_seq, 本账号 max seq)`。

#### 游标过期

`since_seq > 0` 且小于本账号库内最小 `seq` → **HTTP 410**，reason **`SNAPSHOT_REQUIRED`**。  
客户端：`GET /me/friends` 分页重建后，用快照 `syncSeq` 重置游标。

## TCP

`friend_list_changed` payload **新增同源 `seq`**：

| 字段 | 说明 |
|------|------|
| `seq` | 本事件在 owner 通讯录流中的序号 |
| `action` | `added` / `removed` / `updated` / `remark_updated` / `profile_updated` |

多 Session：同一 `userId` 全部在线 TCP 连接均收。  
重连成功 **不**视为已同步；必须再打 `GET /me/friends/changes?since_seq=`。

## 客户端实现（本仓库）

| 组件 | 职责 |
|------|------|
| `FriendContactIncrementalSyncService` | 持久化 `last_friend_contact_seq_<owner>`；Difference 拉页应用；410→Snapshot |
| `MeFriendApi.fetchFriendsSnapshotFromNetwork` | 分页 Snapshot + `syncSeq` |
| `MeFriendApi.fetchFriendsChanges` | Difference；410/`SNAPSHOT_REQUIRED` → 异常 |
| `FriendSyncService.syncFull` | Snapshot 落库后 `resetCursorFromSnapshot(syncSeq)` |
| `FriendSyncService.applyListChanged` | TCP/`Difference` 共用；按 `seq` 去重；TCP 仅**连续**推进游标 |
| 冷启 / 重连 | `auth_bootstrap` / `native_post_home` / `_onTcpAuthOk` 挂 Difference |

行为要点：

1. 本地秒开 → Difference → upsert/删除 → UI 刷新  
2. TCP 与 Difference 按 `seq` 去重（`seq <= cursor` 跳过写入）  
3. TCP 跳号不推进游标，留给 Difference 补洞  
4. 成友乐观写入保留；Difference / `CONTACT_CREATED` 收敛  
5. 勿再依赖「只拉 `/me/friends` 首页」判断新人是否存在  

单测：`test/friend_contact_incremental_sync_test.dart`

## 写路径（服务端已挂钩）

| 动作 | 事件 |
|------|------|
| accept / auto_accepted / restored → `bindMutualFriends` | 双方 `CONTACT_CREATED` |
| `PUT /me/friends/{id}/remark` | owner `CONTACT_REMARK_UPDATED` |
| `DELETE /me/friends/{id}` | owner `CONTACT_DELETED`；对方若仍保留则 `CONTACT_UPDATED` |
| 昵称/头像变更 | 所有仍保留该 peer 的 owner → `CONTACT_PROFILE_UPDATED` |

DDL：`scripts/migrate-friend-contact-sync.sql`

---

## 历史待办（P0 止血 / 早期草案）

以下条目多为早期客户端止血与抽象 API 草案，**P1 契约以本文上方为准**。

- 成友乐观 retain + `syncFull` 后刷通讯录 UI + 自动通过写「新的朋友」本地历史：**已完成**
- 旧草案中的 `/api/contacts/snapshot`、`/api/sync/difference` 命名已收敛为 `/me/friends` + `/me/friends/changes`

*文档版本：2026-08-12 · 客户端 P1 接入*
