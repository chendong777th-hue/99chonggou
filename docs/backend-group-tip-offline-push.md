# 后端修改说明：群 tip 离线推送显示完整文案

> 受众：自建 Push / 消息推送服务端  
> 关联客户端：`businessID=group_tip` App Custom 灰字  
> 现象：锁屏/通知栏正文显示字面量 `group_tip`，而不是「张三将李四设置为管理员」这类完整 tip  
> 目标：离线推送 body 显示与聊天内灰字一致的完整中文 tip

---

## 1. 背景与结论

### 1.1 现状

| 端 | 行为 |
|---|---|
| 客户端发 tip | Custom 消息 `data` JSON 含 `businessID: "group_tip"`，并带完整 **`previewAbstract`** |
| 聊天内灰字 | 读 `previewAbstract` / 按 `action` 拼装 → **正常显示完整文案** |
| 离线推送 | 用户看到正文为 **`group_tip`**（即 businessID 原样） |

### 1.2 根因判断

客户端开启自建 Push（`SELF_HOSTED_PUSH_ENABLED` 默认 true）时，会对 IM `OfflinePushInfo` 设置 **`disablePush: true`**，**不走腾讯 IM 离线推送**。  
锁屏文案由 **自建 Push** 根据 IM 消息/回调组装。

当前服务端很大概率在组通知 body 时：

- 误用了 `businessID`（值为 `group_tip`），或  
- custom 无文本时回落到 businessID / 类型名，

而 **没有优先使用** payload 内已有的 `previewAbstract`。

---

## 2. 消息契约（客户端已发出）

### 2.1 识别条件

同时满足：

- IM 消息类型为 **Custom**
- `customElem.data`（或等价字段）JSON 解析后：`businessID === "group_tip"`
- `action` 为下列之一（小写）：

```
member_added
member_removed
member_left
member_muted
member_unmuted
group_mute_all_on
group_mute_all_off
member_set_admin
member_cancel_admin
group_name_changed
group_avatar_changed
group_notice_changed
owner_changed
group_apply_join_option_changed
group_invite_join_option_changed
group_qr_join_enabled
group_qr_join_disabled
group_alias_join_enabled
group_alias_join_disabled
group_privacy_enabled
group_privacy_disabled
```

### 2.2 Payload 字段（`customElem.data` JSON）

| 字段 | 类型 | 说明 |
|---|---|---|
| `businessID` | string | 固定 `"group_tip"` — **禁止作为推送正文** |
| `version` | number | 当前为 `1` |
| `action` | string | 见上表 |
| `opUserId` | string | 操作者 userId |
| `opUserName` | string | 操作者展示名 |
| `memberUserIds` | string[] | 被操作用户 id |
| `memberNames` | string[] | 被操作用户展示名 |
| **`previewAbstract`** | string | **完整 tip 文案（推送正文首选）** |
| `clientMsgId` | string | 客户端消息 id |
| `detail` | object | 可选；加群方式变更等会带枚举值 |

### 2.3 示例

```json
{
  "businessID": "group_tip",
  "version": 1,
  "action": "member_set_admin",
  "opUserId": "user_a",
  "opUserName": "张三",
  "memberUserIds": ["user_b"],
  "memberNames": ["李四"],
  "previewAbstract": "张三将李四设置为管理员",
  "clientMsgId": "uuid-..."
}
```

期望推送：

- **title**：群名称（或 App 名兜底）  
- **body / alert**：`张三将李四设置为管理员`  
- **不要**：`group_tip`

其它常见 `previewAbstract` 示例：

| action | 示例文案 |
|---|---|
| `member_added` | `张三邀请李四、王五加入群组` |
| `member_removed` | `张三将李四踢出群组` |
| `member_left` | `李四退出群聊` |
| `member_cancel_admin` | `张三将李四取消管理员` |

---

## 3. 服务端必须修改的逻辑

### 3.1 推送正文选取（硬规则）

在组装 APNs / 极光 / 厂商通道的 **alert body / notification content** 时，对 Custom 消息按以下优先级：

```
1. 若能解析 custom data 且 businessID == "group_tip"：
     a. 使用 previewAbstract（trim 后非空）→ 作为 body
     b. 否则用 §3.2 按 action 拼装 → 作为 body
     c. 仍为空 → 使用「群提示」（或产品约定的通用群提示文案）
     d. 禁止使用 businessID / action 英文枚举作为 body

2. 非 group_tip：保持现有逻辑
   但建议全局禁止：body == businessID 这类「类型名当正文」
```

伪代码：

```text
func pushBody(msg):
  data = parseCustomJson(msg)
  if data != null && data.businessID == "group_tip":
    if nonEmpty(data.previewAbstract):
      return data.previewAbstract
    text = composeGroupTip(data)   // 与客户端 groupTipDisplayText 同语义
    if nonEmpty(text):
      return text
    return "群提示"
  return existingBodyLogic(msg)    // 且不得回落成 businessID
```

### 3.2 无 `previewAbstract` 时的拼装（与客户端对齐）

用 `opUserName`（空则 `opUserId`）和 `memberNames`（空则 `memberUserIds`，多人用顿号 `、` 连接）：

| action | 文案模板 |
|---|---|
| `member_added` | `{op}邀请{members}加入群组` |
| `member_removed` | `{op}将{members}踢出群组` |
| `member_left` | `{leaver}退出群聊`（leaver 优先 members，否则 op） |
| `member_muted` | `{op}将{members}禁言` |
| `member_unmuted` | `{op}解除了{members}的禁言` |
| `group_mute_all_on` | `{op}开启了全员禁言` |
| `group_mute_all_off` | `{op}关闭了全员禁言` |
| `member_set_admin` | `{op}将{members}设置为管理员` |
| `member_cancel_admin` | `{op}将{members}取消管理员` |
| `group_name_changed` | `{op}修改了群名称` |
| `group_avatar_changed` | `{op}修改了群头像` |
| `group_notice_changed` | `{op}修改了群公告` |
| `owner_changed` | `{op}将群主转让给{members}` |
| `group_apply_join_option_changed` | `{op}将申请加群方式修改为{label}` |
| `group_invite_join_option_changed` | `{op}将邀请好友方式修改为{label}` |
| `group_qr_join_enabled` / `_disabled` | `{op}开启/关闭了二维码加群` |
| `group_alias_join_enabled` / `_disabled` | `{op}开启/关闭了群别名加群` |
| `group_privacy_enabled` / `_disabled` | `{op}开启/关闭了群成员隐私保护` |
| 其它 | `群提示` |

加群方式 `label`（`detail.applyJoinOption` / `inviteJoinOption`）：

| 存储值（示例） | 展示 |
|---|---|
| 自由加入 / freeAccess 类 | `自动审批` |
| 需审批 / needPermission 类 | `管理员审批` |
| 禁止 / disabled 类 | `禁止` |

（具体枚举字符串以现网 `detail` 为准；客户端 `GroupJoinOption` 与 tip 拼装已按上表语义。）

### 3.3 标题（title）

建议：

- 群聊：群名称（会话 showName / 群资料名）  
- 取不到：App 名（如 `99Chat`）  
- **不要**用 `group_tip` 或 action 英文名作 title

### 3.4 用户通知显示偏好（若服务端已支持）

客户端设置对应服务端枚举（`notificationDisplayContent`）：

| 服务端值 | 含义 | 对 group_tip 的 body |
|---|---|---|
| `show_all` | 显示名称与内容 | 使用完整 tip（§3.1） |
| `generic` | 仅通用提示 | `你收到了一条消息`（或现网 generic 文案） |
| `hidden` | 隐藏内容 | 按现网 hidden 策略（可无正文/不展示细节） |

**仅在 `show_all` 时**需要完整 tip；修 bug 时勿在 `show_all` 下仍输出 `group_tip`。

### 3.5 是否推送

- 群 tip 一般为群内可见操作提示；是否对免打扰群抑制，跟现网「群消息免打扰」策略一致即可。  
- 客户端发送 tip 时带 `isExcludedFromUnreadCount: true`（不计入未读）；**这不表示不要推送**。除非产品明确「灰字不推送」，否则仍应推，且 body 为完整文案。

---

## 4. 建议排查的服务端落点

请在下列逻辑中搜索并改正（名称因仓库而异）：

1. Custom 消息 → 推送 body 的映射（是否 `body = businessID` / `msgType`）  
2. 「无文本 custom」默认摘要  
3. IM 回调 / 旁路消费群消息后的 Push 组装  
4. 任何把 `data.businessID` 或整段 JSON 截断当 alert 的代码  

日志建议临时打：

- `businessID`、`action`、`previewAbstract`、最终 `title`/`body`  
- 确认修复后 body **不等于** `group_tip`

---

## 5. 验收标准

| # | 场景 | 期望 |
|---|---|---|
| 1 | 设管理员 / 取消管理员（接收方离线或杀进程） | 通知 body = 完整中文 tip，**不是** `group_tip` |
| 2 | 邀请入群 / 踢人 / 退群 | 同上 |
| 3 | 聊天内灰字 | 与推送 body 文案一致（或同语义） |
| 4 | 用户设置为「仅显示你收到了一条消息」 | body 为 generic，不出现 `group_tip` |
| 5 | 回归：普通文本消息离线推送 | 仍显示真实文本（`show_all` 下） |

---

## 6. 客户端侧说明（配合，非本单必改）

- 发 tip：`GroupTipCustomSender` → `buildGroupTipPayload` 已写入 `previewAbstract`。  
- `MessageOfflinePush.build`：`desc = NotificationPushText.summarizeMessage(...)`（可解析出完整 tip），但 **`disablePush: true`**（自建 Push 开启时），故锁屏以服务端为准。  
- 客户端可另做加固（可选）：保证 IM custom description / 旁路字段也带 `previewAbstract`，便于服务端多源取值；**不能替代**服务端禁止用 `businessID` 当正文。

---

## 7. 非目标

- 不改 tip 的 IM 投递与灰字展示协议（`businessID` / `action` 不变）  
- 不改为双通道同时开腾讯 IM 离线推送（除非产品另行决策）  
- 本单可不做「所有 custom 类型」统一摘要重构；至少先修 `group_tip`

---

## 8. 联系与对照代码（客户端仓）

| 内容 | 路径 |
|---|---|
| businessID / payload / 文案拼装 | `lib/src/utils/group_tip_custom_message.dart` |
| 发送 tip | `lib/src/services/group_local/group_tip_custom_sender.dart` |
| 离线 PushInfo 组装 | `lib/src/utils/message_offline_push.dart` |
| 推送摘要（含 group_tip） | `lib/src/utils/notification_push_text.dart` |
| 通知显示模式枚举 | `lib/src/models/notification_display_mode.dart` |

---

**文档版本**：2026-08-12  
**状态**：供后端实施；客户端仓路径 `docs/backend-group-tip-offline-push.md`
