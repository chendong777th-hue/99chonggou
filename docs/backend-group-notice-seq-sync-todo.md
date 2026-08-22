# 群系统通知 Inbox 增量 Sync — 状态说明

> 后端：已实现（P0+P1）  
> 客户端对接正文：[group-notice-incremental-sync-client.md](./group-notice-incremental-sync-client.md)

## 后端已提供

1. `GET /me/group-notices/changes?since_seq=&limit=`  
2. 事件：`NOTICE_UPSERTED` / `NOTICE_DELETED` / `READ_WATERMARK`  
3. 游标失效：HTTP 410 + `CURSOR_EXPIRED`  
4. TCP `group_system_notice`：detail 含 `noticeId` + inbox `seq`（DELETE 时 `type=NOTICE_DELETED`）

## 客户端已做

- 游标读写、分页拉取、写 `GroupSystemNoticeService`  
- 冷启 / TCP auth / syncFull / Bootstrap 挂接  
- TCP UPSERT/DELETE + `noteRealtimeSeq`；Entity seq 与 inbox seq 分流  
- 404 静默跳过  

## 明确不做（本轮）

- 加群审批并入同一 changes 流  
- 与 `GET /me/groups/changes`（群 Entity）混用  
