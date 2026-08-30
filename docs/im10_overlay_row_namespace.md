# IM-10 Overlay/Row namespace 迁移计划

更新时间：2026-08-30 (phase C 收口)
工作包：IM-10（基于 `docs/腾讯IM模式一_专用消息服务架构设计_重梳版.md` 第 18 节 Overlay/Row 命名空间 + 第 29 节 ADR-008）
状态：`Draft` → 等产品/技术共同验收 → 转 `Adopted`
前置：IM-04 / IM-07 / IM-08 / IM-09 phase 1+2 / IM-10 phase A/B 已推送（`2555fe9c` / `deae4f3c` / `d3ab34be` / `c8975a30`）

本文是 IM-10 的静态扫描结果 + 迁移策略文档。
不做实现，不改写代码，只登记现状、目标、约束和后续 PR 顺序。

---

## 0. IM-10 目标

页面只能消费 `MessageWindowSnapshot + MessageRowDelta`，不直接修改正式消息列表。

具体 6 类组件必须迁到各自的 Overlay/Row namespace：

| 组件 | 当前实现 | 目标位置 |
| --- | --- | --- |
| 通话气泡 | `LocalMessageOverlayStore.upsert` + `chat.dart:messageListProjectionBuilder` | Overlay（已就位） |
| 群提示 | `LocalMessageOverlayStore.upsert` + `group_local_tips_service.dart` | Overlay（已就位） |
| 群提示补丁 | `group_tips_operator_patch_service.dart::setMessageList` (已迁至 writer) | Writer 已就位 |
| 通话气泡去重 | `utils/call_bubble_dedupe.dart::setMessageList` (已迁至 writer) | Writer 已就位 |
| 历史 bootstrap | `chat.dart:8070/8439/9885 (已迁至 writer)` | Writer 已就位 |
| 归档写入 | `archive_im_local_persist_service.dart:344/766` (已迁至 writer) | Writer 已就位 |
| 静默归档 | `silent_archive_service.dart:235` | 必须改走 Writer |
| 时间线 / 未读线 / 加载行 | chat list 内嵌渲染 | Row namespace（待设计） |
| 发送中（pending） | chat list 内嵌渲染 | Overlay（待设计） |

---

## 1. 当前事实（2026-08-30 静态扫描）

### 1.1 Overlay 部分（已就位）

`lib/src/services/local_message_overlay_store.dart` 已经提供完整 Overlay API：
- `configureScope({ownerUserId, domainGeneration})` — IM domain fence
- `invalidateScope()` — 切账号/会话边界立即清空
- `messagesFor(conversationID)` — 拉取 overlay 消息
- `upsert/removeWhere/clearConversation/clearAll` — CRUD
- 已绑定 `chat.dart:10304` 的 `messageListProjectionListenable`
- 已绑定 `chat.dart:10307` 的 `messageListProjectionBuilder`（合并 formal + overlays）

实际写入方：
- `lib/src/services/call_bubble_insert_service.dart:40/66` — 通话气泡
- `lib/src/services/group_local/group_local_tips_service.dart:1062/1070/191` — 群提示

### 1.2 直接 `setMessageList` 路径（必须收紧）

`rg 'setMessageList\s*\(' lib third_party` 命中 25 处：

`lib/src/` 内（11 处）：

```
lib/src/services/silent_archive_service.dart:235
```

`third_party/` 内（14 处）：
- `tui_chat_global_model.dart` 6 处 + `tui_chat_separate_view_model.dart` 7 处 + `tim_uikit_chat.dart` 1 处

`third_party/` 是 UIKit 受控代码，本阶段**不修**；只登记让 IM-11 静态门禁验证不漏报。

### 1.3 `messageListMap` 读路径（18 处，全部读不写）

仅作登记，不需改：
- `lib/utils/chat_image_message_prefetch.dart:381`
- `lib/src/chat.dart` 14 处
- `lib/src/utils/call_bubble_dedupe.dart:244`
- `lib/src/utils/c2c_blocked_outgoing_message_sync.dart:54`

---

## 2. 迁移策略

### 2.1 阶段切分

| 阶段 | 子阶段 | 范围 | PR 编号 |
| --- | --- | --- | --- |
| **IM-10 phase A**（本阶段） | ADR + 静态扫描脚本 + 1 个静态门禁测试 | 文档 + 脚本 | `im10: ADR + 静态扫描 + 门禁` |
| IM-10 phase B | `chat.dart:3853/3862` 历史 bootstrap 改为 `commitMessageDelta` | 生产代码 done | `im10: chat history bootstrap -> writer` |
| IM-10 phase C | `chat.dart:8070/8439/9885` 预览合并/全局去重/通话占位删除改为 `commitMessageDelta` | 生产代码 done | `im10: chat preview/dedupe/call placeholder -> writer` |
| IM-10 phase D | `archive_im_local_persist_service` 归档写改为 `commitMessageDelta`（_stripMemoryIds/_rewriteMemoryIdentity 走 delete/edit + replace） | 生产代码 done | `im10: archive write -> writer` |
| IM-10 phase E | `group_tips_operator_patch_service` 群提示补丁改为 `commitMessageDelta`（_patchVisibleMessages/_decorateVisibleMessageList 走 localMetadata + replace） | 生产代码 done | `im10: group tips patch -> writer` |
| IM-10 phase F | `call_bubble_dedupe` 通话气泡去重视图合并改为 `commitMessageDelta`（apply() 走 localMetadata/delete 双模式） | 生产代码 done | `im10: call bubble dedupe -> writer` |
| IM-10 phase G | `silent_archive_service` 静默归档改为 `commitMessageDelta` | 生产代码 | `im10: silent archive -> writer` |
| IM-10 phase H | Row namespace（时间线 / 未读线 / 加载行） | 新组件 | `im10: row namespace design` |
| IM-10 phase I | 发送中 Overlay | 新组件 | `im10: pending overlay` |
| IM-10 phase J | IM-11 静态门禁收口 | 自动化 | `im11: gate` |

### 2.2 单阶段约束

- 单阶段通过 `dart format` / `dart analyze` / `flutter test` 后单独 commit。
- 阶段报告按交接 MD §10 模板（实际改动 / 生产问题 / 验证 / 未完成 / 边界）。
- 不放宽现有测试断言。
- 不修改 `third_party/` UIKit 代码（除非同步给上游）。
- 不删除 `setMessageList` 入口，只收紧调用点。

### 2.3 行级（Row）namespace 设计要点

- 时间线：派生自现有消息列表（timestamp 聚合），不需要单独 Row
- 未读线：`firstUnreadMessageID` 锚点；渲染时叠加在消息流中，不进入正式列表
- 加载行：状态机（loading / loading-more / no-more / error），不进正式列表
- 发送中：optical bubble，由 `Outbox` 状态机驱动；不进正式列表，只走 overlay

### 2.4 Writer 适配

- `commitMessageDelta(MessageDelta<V2TimMessage>)` 是现有 Writer 入口
- `MessageDeltaKind` 已有：`optimisticAdoption / edit / realtimeUpsert / revoke / delete`
- 历史 bootstrap 用 `MessageDeltaKind.optimisticAdoption` 或新增 `MessageDeltaKind.bootstrap`（待 PR 决定）
- 整段 replace 用 `delta.replace = true`

---

## 3. 静态门禁（IM-11 收口）

设计文档 23.1 + 交接 MD §9 要求以下命令必须只剩白名单命中：

```powershell
rg -n --glob '*.dart' 'setMessageList\s*\(' lib third_party
rg -n --glob '*.dart' 'messageListMap\s*\[.*\]\s*=' lib third_party
rg -n --glob '*.dart' 'messageListMap\s*\[\s*[a-z]' lib third_party
```

### 3.1 临时白名单（IM-10 收口前）

`lib/src/` 内允许的 `setMessageList` 调用方：

```
lib/src/services/silent_archive_service.dart:235
```

每收口一个 → 从白名单移除。

### 3.2 门禁脚本

`tool/im10_migration_scan.ps1`：

1. 扫描 `setMessageList` 调用方
2. 对比白名单
3. 任何白名单外的命中 → exit 1

预期 IM-10 phase J 跑时白名单为空。

---

## 4. 已验证证据

- `dart analyze lib/src/services/local_message_overlay_store.dart` → 0 errors
- `LocalMessageOverlayStore` 已绑定 chat page overlay 渲染（`chat.dart:10304/10307`）
- 通话气泡和群提示 insert 服务已用 `LocalMessageOverlayStore.upsert`（`call_bubble_insert_service.dart:40/66`、`group_local_tips_service.dart:1062/1070/191`）
- **IM-10 phase B（`c8975a30`）**：`_hydrateOfficialAccountMessageList` 历史 bootstrap（`chat.dart:3853/3862`）→ `commitMessageDelta`（`optimisticAdoption` + `historyEnvelope` + `replace: true`）；白名单 -2 → 9 条；79/79 回归通过（`im05/im08/im09/im10/im_contracts`）。
- **IM-10 phase C（pending push）**：`_mergePreviewMessageIfMissing` / `_onChatGlobalModelChanged` / `_removeLocalCallBubblePlaceholder`（`chat.dart:8070/8439/9885`）→ `commitMessageDelta`：
  - 8070：`optimisticAdoption` + `historyEnvelope` + `replace: true`（preview 折进现有列表）
  - 8439：`compatibilitySnapshot` + `compatibilityProjection` + `replace: true`（dedupe 后合成稳定快照）
  - 9885：`delete` + `userAction` + `explicitDeletes`（按 `callId` 删除 local call bubble placeholder）
  - 白名单 -3 → 6 条；ADR §0/§1.2/§2.1/§3.1 已同步；`dart analyze lib/src/chat.dart` 0 新增 issue（37 全部为旧 `use_build_context_synchronously` 等 info/warning，与改动无关）。
- **IM-10 phase D（pending push）**：`archive_im_local_persist_service.dart` 2 处归档写 → `commitMessageDelta`：
  - 344 `_stripMemoryIds`：`delete` + `compatibilityProjection` + `replace:true` + `upserts: next`（按 msgID 集合剥除内存中 spurious 记录，跨 alias key 多卷同步）
  - 766 `_rewriteMemoryIdentity`：`edit` + `compatibilityProjection` + `replace:true` + `upserts: next`（archive → cloud 提升时把本地 msgID 改写成 cloud msgID）
  - 白名单 6 → 4 条；ADR §0/§1.2/§2.1/§3.1 同步；`dart analyze archive_im_local_persist_service.dart` 0 issues。
- **IM-10 phase E（pending push）**：`group_tips_operator_patch_service.dart` 2 处群提示补丁 → `commitMessageDelta`：
  - 207 `_patchVisibleMessages`：`localMetadata` + `userAction` + `replace:true` + `upserts: filtered`（管理员群提示元数据修复,跨 alias key 同步）
  - 255 `_decorateVisibleMessageList`：`localMetadata` + `userAction` + `replace:true` + `upserts: newestFirst`（群提示装饰排序,最新优先）
  - 白名单 4 → 2 条;ADR §0/§1.2/§2.1/§3.1 同步;im05/im08/im09/im10/im_contracts 79/79 回归通过;dart analyze 1 unused_element 警告(预先存在,与本次改动无关)。

- **IM-10 phase F（pending push）**：`call_bubble_dedupe.dart` 1 处通话气泡去重视图合并 → `commitMessageDelta`：
  - 283 `CallBubbleDedupe.apply`：applyCallOnly=true 走 `localMetadata` + `compatibilityProjection` + `replace:true` + `upserts: deduped`；applyCallOnly=false 走 `delete`（保留 isDeleteMsg 语义）+ `replace:true` + `upserts: deduped`
  - 白名单 2 → 1 条;ADR §0/§2.1/§3.1 同步;im05/im08/im09/im10/im_contracts 79/79 回归通过;dart analyze 0 issues。

## 5. 未完成

- 真机验证：6 类组件迁到 Overlay/Row 后的渲染顺序、滚动不跳底、撤回/删除前后锚点稳定、双 View 各自维护 anchor
- 多设备验证：A 设备插入通话气泡后 B 设备的渲染延迟
- 性能验证：单条消息插入不触发无界全表排序
- 产品答复 Q1-Q10（IM-09 ADR §6）：草稿/置顶/免打扰/已读 跨设备语义

## 6. 静态扫描结果（本阶段固定入档）

执行 `tool/im10_migration_scan.ps1` 后的结果（详见 §1.2 表格）。

任何后续修改必须更新本表格或迁移到白名单外 → 立刻触发 PR 评审。
