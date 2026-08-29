# Plan 112: 用稳定游标和响应式页投影替代 hydrate 重裁决

> **Executor instructions**: 保留虚拟列表体验，但分页必须读取 SQLite committed view。
> 不得使用整页 reload 或关闭虚拟列表规避。完成后更新计划索引。
>
> **Drift check**: `git diff --stat 9f7c46e..HEAD -- lib/src/services/conversation_local lib/src/widgets/conversation_feed test`

## Status

- **Priority**: P2
- **Effort**: L
- **Risk**: MED
- **Depends on**: 107 canonical index、108 single local authority
- **Category**: perf / architecture
- **Planned at**: commit `9f7c46e`, 2026-08-25

## Execution record (2026-08-25)

- 新增 `ConversationTypePageCursor`，排序键固定为
  `(pinned DESC, activeTime DESC, orderKey DESC, conversationID ASC)`。
- `ConversationLocalStore.loadConvTypePageAfterCursor` 增加 SQLite keyset 查询，保留原
  `loadConvTypePage(offset:)` 作为 cursor 缺失/兼容 fallback；memory-only 分支复用同一排序
  语义过滤。
- `ConversationListNotifier` 为每个 conversation type 维护 page cursor；下滑扩窗优先从
  当前类型尾部 cursor 取页，并在吸收后推进 cursor。旧 offset consumed 仍记录用于计数和
  fallback，不再是首选分页路径。
- 当前仅迁移「下滑扩窗」主路径；hydrate window jump、prepend/newer 和 TabStore 分页仍待
  统一 cursor view。Flutter 行为测试尚未启动，仅完成静态检查。
- 修正 keyset SQL 的 pin CASE 参数绑定，并新增
  `test/conversation_pinned_type_page_order_test.dart`：验证首页 `a,b` 后使用
  `(pin, activeTime, orderKey, conversationID)` cursor 稳定续出 `c`。原 offset API 继续作为
  fallback，未改变旧分页契约。
- 继续修正 memory-only keyset 的最终 ID tie-breaker，使其与 SQL 的
  `conversation_id ASC` 一致：cursor 之后取字典序更大的 ID，避免同 pin/time/order
  的会话在 Web/内存分支漏页。`git diff --check` 已通过。
- 继续对齐三个剩余区域：`ensureTypeIndexHydrated` 随机窗口在命中 snapshot page cache
  时直接装载缓存页，避免重复 OFFSET 查询；hydrate 新页不再调用
  `_preserveHotPreviewsDuringHydrate`，已提交 Store row 只负责装载、索引和 cache；
  `ConversationTabStore` 增加相同 `(pin, activeTime, orderKey, conversationID)` 的
  `pageCursorForType` 并在 page merge/reset 时推进或清理。未开启 `conversationListSdkPrimary`，
  SDK 内存分页仍是兼容源，后续需再将其改为 committed view reader。
- 已完成生产切换：`ConversationPerfFlags.conversationListSdkPrimary` 默认开启，新增默认开启
  `tabStoreCommittedViewEnabled`；TabStore `loadFirstPage/loadMore` 直接读取
  `ConversationLocalStore` committed view（首屏 offset、续页 keyset），按 SQLite count 判断
  finished，并维护同一 `ConversationTypePageCursor`。SDK `_fetch` 仅在开关关闭时回退。
- TabStore clear/setItems、archive/delete/merge 路径会清理或推进 cursor；新增测试覆盖
  committed view 首页→keyset续页→clear 生命周期。pin/archive 精确 page invalidate 仍需
  下一步完善，但不再通过切回 SDK source 规避。
- 继续完成 pin/archive 结构失效：Notifier 新增 `invalidateConversationViewPages`，pin 变化
  时使受影响 type 的 snapshot page 和 cursor 失效；archive purge 重建 type hydrate index。
  TabStore 新增同语义 `invalidateViewPages`，delete/invalidate 会清理对应 type cursor。
  `conversationListSdkPrimary` 生产开关保持开启，SDK source 仅显式 rollback 使用。
- 随机跳转 cache miss 仍保留 offset 作为绝对 index 定位 fallback；稳定 page anchor/cache
  已优先命中，后续可再增加 anchor table。新增 TabStore invalidation 生命周期测试。
- 已增加类型级稳定 page-anchor 索引：每次 hydrate 页加载后记录「页尾绝对 index →
  `ConversationTypePageCursor`」；随机跳转 cache miss 时先选择不超过目标 start 的最近
  anchor，以 keyset 分块推进到目标页，只有无 anchor 或推进失败才使用 OFFSET。pin/archive
  结构失效会清理对应 anchors，避免旧排序边界污染。
- 已将 page anchor 持久化到 SQLite `conversation_page_anchor`（数据库 v11），键为
  `owner_user_id + conv_type + page_start`，并提供写入、按最大页起点恢复、按类型或账号删除 API。
  Notifier 在内存 anchor 为空时恢复持久化 anchor；pin/archive 结构变化及账号清理会删除磁盘锚点。
- committed UI batch 现在由 TabStore 作为单一入口消费：同一批 upsert/delete/unread delta
  合并为一次 view 通知；page directory 增加 `page_end` 元数据并支持从受影响位置起始精确失效，
  为后续彻底移除 OFFSET fallback 保留稳定目录。
- `ConversationUiSnapshotBatch` 新增显式 `ConversationUiMove` 契约；TabStore 在 committed
  batch 应用前记录旧位置、应用 committed row patch 后计算新位置，并输出精确 move 日志，
  为跨页局部 invalidate 和滚动锚点保持提供依据。
- page directory 升级到数据库 v14：新增 owner/type 级 `conversation_view_state.view_version`，
  page anchor 保存真实 `page_start/page_end`、首行 cursor、尾行 cursor 和 committed view version。
  hydrate page 首次使用 OFFSET 后立即写入目录，后续随机定位优先从目录 keyset 推进。

## Goal

让大规模会话列表像 Telegram 一样基于本地稳定排序 view 分页。当前 offset/type hydrate
加载后还需合并热投影、补 pin 和排序；本计划改为 keyset cursor，并由 committed change
batch 只失效受影响页。

## Stable cursor

`(isPinned DESC, activeTime DESC, orderKey DESC, canonicalConversationId ASC)`。
排序字段变化时产生明确 move event；canonical ID 作为稳定 tie-breaker。

## Steps

1. Store 增加 before/after keyset page API，保留旧 offset API 作为 rollback allowlist。
2. 页面模型保存稳定 ID 序列与页 cursor，不缓存第二套业务权威对象。
3. committed batch 根据 changed masks 判断 row patch、跨页 move、insert 或 delete。
4. 滚动中允许延迟结构 move，但字段内容即时 patch；settle 后一次提交新顺序。
5. pin、archive、draft active time、lastMessage order 变化覆盖 cursor invalidation。
6. 删除 hydrate 中的业务字段重裁决；它只负责装载 committed rows。

## Verification

- 10k 会话模拟下无 offset 漂移、重复行、漏行或 skeleton 长驻。
- 实时入站、pin、归档、快速 fling 每批最多一次结构 notify。
- virtual tail、scroll defer、窗口跳转和账号切换测试通过。

## STOP conditions

- canonical ID 不能作为稳定 tie-breaker。
- keyset API 会改变现有 pin/archive 产品排序。
- 必须在滚动中整窗替换才能保持正确。
