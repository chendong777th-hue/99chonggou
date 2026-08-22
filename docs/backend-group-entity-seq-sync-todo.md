# 群 Entity 增量 Sync — 状态说明

> 客户端对接正文见：[group-entity-incremental-sync-client.md](./group-entity-incremental-sync-client.md)

本文件曾误被「群治理 REST」文档覆盖。治理能力见产品侧其它文档；**群资料游标增量**以 `group-entity-incremental-sync-client.md` 为准。

> **成员人数/名单**：勿把成员变更当作 Entity changes 的唯一手段。在线已由客户端「成员首屏 REST」对齐；断线补偿见 [backend-group-member-seq-sync-todo.md](./backend-group-member-seq-sync-todo.md)。

## 后端需保证

1. `GET /me/groups/changes?since_seq=&limit=` 可用  
2. 响应含 `next_seq` / `has_more` / `events[]`（或 camelCase 等价）  
3. 游标失效返回可识别错误码（`CURSOR_EXPIRED` 等）  
4. TCP `group_changed.detail` 尽量带 `seq` 与完整 `groupName` / `avatarUrl`

## 客户端已做

- 游标读写、分页拉取、写 Group Entity、冷启 / TCP / syncFull 挂接  
- tip 实时写入（同会话更早提交）
