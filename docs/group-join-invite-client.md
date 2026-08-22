# 群成员邀请与加群审批 — 客户端对接文档

> 版本：v1.0  
> 适用：Public / Meeting / Community 群  
> 原则：**邀请入群、申请加群、审批、加群方式设置全部走 99chat-server**，不再使用 IM SDK `inviteUserToGroup` / `getGroupApplicationList`。

---

## 1. 总览

| 能力 | 接口 | 说明 |
|------|------|------|
| 读取加群方式 | `GET /group/{groupId}/join-options` | 群成员可读 |
| 修改加群方式 | `PUT /group/{groupId}/join-options` | 仅群主/管理员 |
| 邀请好友入群 | `POST /group/{groupId}/members` | 群成员；须双向好友 |
| 申请加群 | `POST /group/{groupId}/join` | 非群成员 |
| 待审批列表 | `GET /group/{groupId}/join-applications` | 群主/管理员 |
| 待审被邀请人 ID | `GET /group/{groupId}/pending-invitees` | 群成员（含普通成员） |
| 同意 / 拒绝 | `POST .../approve` / `reject` | 群主/管理员 |
| 成员列表 | `GET /group/{groupId}/members` | 群成员；含入群时间 / 邀请人 / 渠道（**全员可见**） |

### 加群方式枚举 `GroupJoinOption`

| 值 | 含义 | 对应 UI |
|----|------|---------|
| `free_access` | 自动通过 | 自动审批 |
| `need_permission` | 需管理员审批 | 管理员审批（默认） |
| `disabled` | 禁止 | 禁止加群 / 禁止邀请 |

- **申请加群** 受 `applyJoinOption` 控制  
- **成员邀请好友** 受 `inviteJoinOption` 控制（群主/管理员邀请始终直接入群）

服务端会同步写入腾讯 IM `ApplyJoinOption` / `InviteJoinOption`。

---

## 2. 邀请好友入群

### `POST /group/{groupId}/members`

**请求**

```json
{
  "userIds": ["friend01", "friend02"],
  "message": "一起来聊"
}
```

`userIds` 单次最多 **100** 人，超出返回 `400 BATCH_TOO_LARGE`。

**逻辑**

| 邀请人身份 | 行为 |
|-----------|------|
| 群主 / 管理员 | 校验双向好友 → IM 管理员 `add_group_member` **直接入群** |
| 普通成员 + `inviteJoinOption=free_access` | 直接入群 |
| 普通成员 + `inviteJoinOption=need_permission` | 创建待审批记录，`status=pending` |
| 普通成员 + `inviteJoinOption=disabled` | 返回 `INVITE_DISABLED` |

**响应**

```json
{
  "results": [
    { "userId": "friend01", "status": "added", "imResult": 1 },
    { "userId": "friend02", "status": "pending", "applicationId": 123 },
    { "userId": "friend03", "status": "failed", "code": "NOT_FRIEND" }
  ]
}
```

| status | 说明 |
|--------|------|
| `added` | 已入群 |
| `already_member` | 已在群内 |
| `pending` | 待管理员审批 |
| `failed` | 失败，见 `code` |

常见 `code`：`NOT_FRIEND` · `USER_NOT_FOUND` · `INVITE_DISABLED` · `APPLICATION_PENDING`

---

## 3. 申请加群

### `POST /group/{groupId}/join`

```json
{ "message": "申请加入" }
```

| applyJoinOption | 行为 |
|-----------------|------|
| `disabled` | 403 `JOIN_DISABLED` |
| `free_access` | 直接入群 |
| `need_permission` | 创建待审批，`status=pending` |

---

## 4. 审批

### `GET /group/{groupId}/pending-invitees`

返回本群 **邀请待审**（`type=invite` 且 `status=pending`）的被邀请人用户 ID 列表（去重、按 ID 升序）。**任意群成员**可读，不限于管理员。

```json
{
  "userIds": ["friend02", "friend09"]
}
```

不含主动申请加群（`type=apply`）的申请人；完整审批详情仍用下方 `join-applications`。

### `GET /group/{groupId}/join-applications`

返回当前 **pending** 列表（群主/管理员）。每条记录含 `fromUserNickName` / 头像：优先本地用户表；默认**不**同步打 IM `portrait_get`（可用 `JOIN_APPS_IM_PORTRAIT_ENABLED=true` 打开旧行为）。群通知聚合请用 `GET /me/join-applications`，勿对多群扇出本接口。

**已对你隐藏**（`DELETE /me/join-applications` dismiss）的记录不会出现在你的列表中；其他管理员仍可见。

```json
{
  "items": [
    {
      "id": 123,
      "type": "invite",
      "fromUserId": "mem0001",
      "fromUserNickName": "张三",
      "toUserId": "friend01",
      "message": "拉你进群",
      "status": "pending",
      "handledBy": null,
      "createdAt": "2026-06-18T10:00:00Z",
      "handledAt": null
    }
  ]
}
```

### `POST /group/{groupId}/join-applications/{id}/approve`

同意后服务端调 IM `add_group_member` 拉人入群。

### `POST /group/{groupId}/join-applications/{id}/reject`

拒绝后通知申请人/邀请人。

### 删除审批记录（群主/管理员）

物理删除 `group_join_application` 记录，**不会**补发 `join_application_handled` / `member_added`。待审批单建议优先走 `reject`，避免申请人无感知。

| 方法 | 路径 | 说明 |
|------|------|------|
| DELETE | `/group/{groupId}/join-applications/{id}` | 删除单条 |
| DELETE | `/group/{groupId}/join-applications` | 批量或全部（见下） |

**批量删除**（body 传 ID 列表）：

```json
{ "applicationIds": [123, 124] }
```

**全部删除**（无 body）：

| 参数 | 说明 |
|------|------|
| 无参数 | 默认删除本群全部 **已处理**（`approved` + `rejected`），保留 `pending` |
| `status=pending` / `approved` / `rejected` | 仅删除指定状态 |
| `includePending=true` | 与无 `status` 联用时，删除本群**全部**记录（含待审批） |

响应：

```json
{ "deleted": 3 }
```

### 隐藏我的群通知记录（`/me/join-applications`）

从**当前用户的群通知列表**中移除记录（仅自己不可见），**不删除**审批单本身；其他管理员、申请人、群侧待审批列表不受影响。

可见范围：与自己相关的记录（申请人 / 邀请人 / 被邀请人），以及作为群主/管理员收到的待审批。

**软删除**：`DELETE /me/join-applications/...` 仅对当前用户隐藏（`group_join_application_dismiss`），不删审批单；其他管理员不受影响。普通成员发起邀请时服务端自动为邀请人隐藏，管理员仍可见待审批。

| 方法 | 路径 | 说明 |
|------|------|------|
| DELETE | `/me/join-applications/{id}` | 隐藏单条 |
| DELETE | `/me/join-applications` | 批量或全部隐藏 |

批量 body：`{ "applicationIds": [123] }`；无 body 时隐藏当前用户可见的全部记录，可用 `status` 过滤。

响应 `{ "deleted": N }` 表示本次新隐藏条数（已隐藏过的重复调用不计入）。

对**同一管理员**，`GET /me/join-applications` 与 `GET /group/{groupId}/join-applications` 均会排除已隐藏记录；其他管理员不受影响。

> 若需从系统彻底删除审批单（全员不可见），请使用群侧 `DELETE /group/{groupId}/join-applications/...`（仅群主/管理员）。

---

## 5. TCP 事件（`group_changed`）

| action | 推送给 | 说明 |
|--------|--------|------|
| `group_join_option_changed` | 全员 | 加群方式变更 |
| `join_application_pending` | 群主/管理员 | 新待审批（本地 `role≥Admin`，空则回退 IM） |
| `join_application_handled` | **全部群主/管理员** ∪ 申请人(`fromUserId`) ∪ 邀请场景被邀请人(`toUserId`) | 审批结果；其他管理员需据此刷新待审列表，勿只推给申请人 |
| `member_added` | 全员 | 成员入群（含审批通过后） |

**`join_application_handled` detail**

```json
{
  "applicationId": 123,
  "applicationType": "invite",
  "status": "approved",
  "result": "approved",
  "fromUserId": "inviter",
  "toUserId": "invitee",
  "handledBy": "admin1",
  "handlerUserId": "admin1",
  "handledByUserId": "admin1",
  "operatorUserId": "admin1",
  "createdAt": 1710000000000,
  "updatedAt": 1710000005000,
  "handledAt": 1710000005000
}
```

- `operatorUserId` / `handledBy*`：实际操作审批的管理员
- `updatedAt`：优先 `handledAt` 毫秒；缺失时用服务端当前时间
- `join_application_pending` 亦带 `updatedAt`（与 `createdAt` 同值，便于客户端统一增量键）

---

## 6. 群通知（TCP + 离线 Push）

入群邀请/审批**不再**由客户端在 IM SDK `accept/refuse` 后发 `INVITE_RESULT` C2C；由服务端推送：

| 通道 | 说明 |
|------|------|
| TCP `group_changed` | 在线端实时刷新（见 §5）**（主通道）** |

**不再**发系统 Push / 系统号 C2C。离线用户上线后通过 `GET /me/groups` 或 TCP 重连补数据即可。

客户端监听：

1. TCP `group_changed`（在线）

勿再依赖 IM SDK `onApplicationProcessed` / 自建 `INVITE_RESULT` / 系统号会话里的审批消息。

---

## 7. 客户端改造要点

1. **Public / Meeting / Community** 邀请统一走 `POST /group/{groupId}/members`，勿再调 `inviteUserToGroup`。  
2. 选人仍用 `GET /me/friends`（自建好友库）。  
3. 审批 UI 改调 `GET/POST join-applications`，勿再调 IM `getGroupApplicationList`。  
4. 建群后建议 `PUT /group/{groupId}/join-options` 写入期望的加群方式。  
5. 监听 `join_application_pending` / `join_application_handled` 刷新红点与提示。

---

## 7.1 成员入群时间与邀请人（新数据）

`GET /group/{groupId}/members` 与角色变更等返回的 `GroupMemberView` 增加字段（**任意群成员可读**）：

| 字段 | 说明 |
|------|------|
| `joinedAt` | 入群时间毫秒；可能为 null |
| `invitedByUserId` | 邀请人业务 userId；自行入群 / 历史为 null |
| `invitedByNickname` | 邀请人昵称；无邀请人时为 null |
| `joinChannel` | `invite` \| `group_id` \| null |

客户端展示：

| `joinChannel` | 文案 |
|---------------|------|
| `invite` | 显示邀请人（`invitedByNickname` / `invitedByUserId`） |
| `group_id` | **通过群ID加入** |
| `null` | 不展示来源（切流前 / 迁移等历史成员） |

写入规则（仅新入群；不回填历史）：

- 业务直邀（群主/管理/`free_access`）：邀请人 = 操作者，`joinChannel=invite`
- 审批通过的 `invite`：邀请人 = 单上 `fromUserId`（**不是**审批人），`joinChannel=invite`
- 主动申请 / `free apply`：无邀请人，`joinChannel=group_id`
- IM 回调补洞：尽量用 `Operator_Account`；申请入群回调写 `group_id`

---

## 8. 错误码

| HTTP | code | 说明 |
|------|------|------|
| 400 | `INVALID_INPUT` | 参数错误 |
| 400 | `BATCH_TOO_LARGE` | `userIds` 超过单次 100 人上限 |
| 400 | `GROUP_TYPE_NOT_SUPPORTED` | 非 Public/Meeting/Community |
| 403 | `NOT_GROUP_MEMBER` | 非群成员 |
| 403 | `NOT_GROUP_ADMIN` | 非管理员 |
| 403 | `JOIN_DISABLED` / `INVITE_DISABLED` | 加群方式禁止 |
| 404 | `GROUP_NOT_FOUND` | 群不存在 |
| 404 | `APPLICATION_NOT_FOUND` | 审批单不存在 |
| 409 | `ALREADY_GROUP_MEMBER` | 已在群内 |
| 409 | `APPLICATION_PENDING` | 已有待审批 |
| 409 | `APPLICATION_ALREADY_HANDLED` | 已处理 |
