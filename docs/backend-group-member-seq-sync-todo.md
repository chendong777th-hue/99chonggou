# 群成员人数/名单实时与增量 — 后端配合待办

> 状态：**P0 实时 + P1 断线增量均已对接**（后端 `members/changes` 已实现；客户端 `GroupMemberIncrementalSyncService` 已接）  
> 目标：停在群聊时人数与成员列表及时更新；杀进程/漏推可补偿  
> **勿**把成员变更当作 `GET /me/groups/changes`（群 Entity）的唯一手段  

客户端已实现：

- TCP `member_added` / `member_removed` / `member_left` → `syncMembersAfterMembershipChange`（首屏 + `total`）→ 再刷聊天头  
- 入站 App Custom `group_tip` / IM 原生 GroupTips（拉人踢人退群）→ 同一 sync（与 TCP 单飞去重）  
- 本端邀请/踢人：`notifyGroupMembersChanged` 同源  
- 断线补偿：`GET /me/groups/{id}/members/changes` + 按群 `last_member_seq`（见 [group-member-change-client.md](./group-member-change-client.md)）

---

## 总案（三层分工）

| 层 | 责任 | 后端 | 客户端 |
|----|------|------|--------|
| ① 实时主路径 | 秒级更新 | TCP `group_changed` | 已接：先拉成员首屏再刷头 |
| ② 实时备份 | TCP 丢包仍更新 | IM tip（Custom / 原生 GroupTips） | 已接：tip → 同一 sync |
| ③ 断线补偿 | 杀进程/离线漏推 | `members/changes` 游标增量 | 已接：`GroupMemberIncrementalSyncService` |

群名/头像/公告继续只走 Entity：`GET /me/groups/changes`。

---

## P0 — TCP（实时主路径）

拉人 / 踢人 / 退群时，对群内相关在线用户推送：

```text
event: group_changed
action: member_added | member_removed | member_left
```

`detail` **尽量**带齐：

| 字段 | 说明 |
|------|------|
| `memberUserIds` / `member_user_ids` | 变更成员 |
| `memberCount` / `member_count` | 变更后权威人数 |
| `seq` | 与成员增量游标同源（本批最大 seq）；**勿**与 `groupSeq` 混用 |
| `groupSeq` | 全局展示/审计序号（Entity 同族） |

**验收：** 仅 TCP、无 tip 时，旁观者停在群聊，人数与成员列表无需杀进程即更新。

---

## P0 — IM Tip（实时备份）

同一操作在发 TCP 之外，**必须**让群内成员能收到可见 tip：

- 优先：App Custom `businessID=group_tip`，`action` 为 `member_added` / `member_removed` / `member_left`  
- 或：IM 原生 INVITE / KICKED / QUIT GroupTips  

**验收：** 人为丢掉 TCP、仅 tip 到达时，客户端仍会拉成员首屏并更新人数（已实现）。

---

## P1 — 独立成员游标增量（断线补偿）— 已实现

```http
GET /me/groups/{groupId}/members/changes?since_seq={lastSeq}&limit=100
```

游标与以下分离：

- `GET /me/groups/changes`（Entity）  
- `GET /me/group-notices/changes`（系统通知 inbox）  

详情与客户端落点：[group-member-change-client.md](./group-member-change-client.md)

---

## P2 — 可选增强

1. Entity `groups/changes` **最多**附带 `member_count` 作校验，不替代成员流  

---

## 明确不做

- 用群公告 / Entity `notice` 冒充成员变更  
- 仅靠客户端轮询代替 TCP + tip + 增量  
- 把成员全量名单塞进 `/me/groups/changes`  

---

## 优先级一览

| 优先级 | 项 | 状态 |
|--------|-----|------|
| P0 | TCP 三 action 必推 + detail 尽量带 memberCount / memberUserIds / seq | 约定中 |
| P0 | 同操作必发 tip（Custom 或原生 GroupTips） | 约定中 |
| P1 | `GET …/members/changes` + memberCount + 游标失效 | **已实现并已接客户端** |
| P2 | Entity 可选带 member_count 校验 | 可选 |
