# Plan 094: 收口会话列表页面的旁路 reload 与 apply，统一到 Coordinator commit 入口

> **Executor instructions**: 按步骤执行，每一步运行验证命令并确认预期结果后再进入下一步。任何 "STOP conditions" 中的情况出现时，停止并报告——不要自行发挥。完成后更新 `plans/README.md` 中本计划的状态行。
>
> **漂移检查（首先执行）**：
> `git diff --stat 9f7c46e..HEAD -- lib/src/conversation.dart lib/src/services/conversation_local/conversation_sync_service.dart lib/src/services/conversation_local/conversation_list_notifier.dart lib/src/services/conversation_local/conversation_local_store.dart test`
> 若任何 in-scope 文件自本计划编写后有改动，先对照 "Current state" 摘录比对现场代码；不一致即 STOP。

## Status

- **Execution**: complete. The duplicate page cold-start reload is removed;
  chat-return hydration, unread, metadata, mute and pin projections consume
  committed Store batches. Production reload/apply compatibility calls now
  require `ConversationStoreProjectionReason`; the legacy method names are
  test-only and a source contract prevents new production callers. The sole
  direct `upsertBatch` is the documented runtime rollback kill switch.
- **Priority**: P1
- **Effort**: M
- **Risk**: MED
- **Depends on**: 093（先保证实时事件全部经过 Coordinator 字段裁决，再收口页面旁路）
- **Category**: tech-debt / bug
- **Planned at**: commit `9f7c46e`, 2026-08-24

## Why this matters

`lib/src/conversation.dart` 页面在 072 阶段 4–6 迁移后仍保留 3 个旁路写入口：`reloadFromLocal()`（:782、:1205）和 `applyConversationsFromStore`（:1783）。它们不经过 `ConversationMutationCoordinator` 的 per-ID 串行队列，与 SDK 实时事件流之间没有共享的字段权威/世代裁决。若页面 reload 与 SDK listener commit 恰好交错，整表 reload 会覆盖增量更新的窗口（如用户刚置顶的会话被 reload 结果临时打回原位）。本计划把这三个旁路收口到 Coordinator commit 入口：页面只触发"读取 Store 提交后的快照"（read-only），不再直接写 Store/Notifier。同时把 `conversation_local_store.dart:3599` 的 `upsertBatch` 通用入口降级为 `@visibleForTesting`（生产路径全部走 `commitCoordinatorPlan`），消除"新调用者误用绕过权威"的架构残留。

## Current state

- `lib/src/conversation.dart:782` — 冷启动 `_loadCachedConversationPreviews` 前直接 `reloadFromLocal()`：

```780:794:lib/src/conversation.dart
    unawaited(() async {
      ConversationListNotifier.instance.ensureTabStoreBridgeAttached();
      await ConversationListNotifier.instance.reloadFromLocal();
      if (!mounted) {
        return;
      }
      _suppressFeedPaging(const Duration(milliseconds: 800));
      _viewportFillDone = false;
      _viewportFillPagesDone = 0;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          unawaited(_maybeFillFeedViewportOnce());
        }
      });
    }());
```

- `lib/src/conversation.dart:1201-1228` — `_loadCachedConversationPreviews` 内第二次 `reloadFromLocal()`（仅当 `!hasSyncedOnce`）。
- `lib/src/conversation.dart:1770-1800` — 聊天返回后的水合路径直接 `applyConversationsFromStore`：

```1779:1799:lib/src/conversation.dart
      if (openedId.isNotEmpty) {
        final local =
            await ConversationLocalStore.instance.conversationById(openedId);
        if (local != null) {
          await notifier.applyConversationsFromStore(
            upserted: <V2TimConversation>[local],
            forceAdmitIds: <String>{openedId},
          );
        }
      }
      if (!mounted) {
        return;
      }
      unawaited(
        notifier.ensureTypeIndexHydrated(
          convType: convType,
          centerIndex: center,
          forceReload: true,
          allowWindowJump: true,
        ),
      );
```

- `lib/src/services/conversation_local/conversation_local_store.dart:3599` — `upsertBatch` 公开通用入口（当前生产 SDK 路径已改走 `commitCoordinatorPlan`，但入口仍公开）。
- `lib/src/services/conversation_local/conversation_sync_service.dart:4472-4491` — 已提供收口入口 `commitSnapshotConversations` / `commitSdkHydratedConversations` / `commitCreatedConversation`（全部走 Coordinator → Store 提交路径）。
- `lib/src/services/conversation_local/conversation_list_notifier.dart:3181` — `applyConversationsFromStore` 是 Notifier 的公开 apply 入口，被页面/服务多处直接调用。
- 相关测试：`test/conversation_list_notifier_incremental_test.dart`、`test/conversation_local_store_sort_test.dart`、`test/conversation_feed_settle_jump_contract_test.dart`。

## Commands you will need

| Purpose | Command | Expected on success |
|---|---|---|
| 差异检查 | `git diff --check` | exit 0 |
| 定向静态检查 | `flutter analyze lib/src/conversation.dart lib/src/services/conversation_local/conversation_sync_service.dart lib/src/services/conversation_local/conversation_list_notifier.dart lib/src/services/conversation_local/conversation_local_store.dart` | 无本计划新增 error |
| 静态搜索 | `rg -n "ConversationLocalStore\.instance\.upsertBatch|ConversationListNotifier\.instance\.reloadFromLocal|applyConversationsFromStore" lib/src` | 仅剩 Coordinator/启动投影恢复/本计划列明理由的 allowlist |
| 核心测试 | `flutter test test/conversation_list_notifier_incremental_test.dart test/conversation_local_store_sort_test.dart test/conversation_feed_settle_jump_contract_test.dart test/conversation_sync_reload_coalesce_test.dart` | 全部通过 |
| 全量测试 | `flutter test` | 全部通过（基线失败须记录证据） |

## Scope

**In scope**（唯一允许修改的文件）：
- `lib/src/conversation.dart`（仅 :782 / :1205 / :1783 三处旁路及其直接调用链）
- `lib/src/services/conversation_local/conversation_sync_service.dart`（如需暴露只读快照读取辅助）
- `lib/src/services/conversation_local/conversation_local_store.dart`（仅 `upsertBatch` 加 `@visibleForTesting` / 守卫）
- `lib/src/services/conversation_local/conversation_list_notifier.dart`（仅若必须为只读投影增加显式方法；预期不需要）
- 对应 `test/` 文件

**Out of scope**（禁止修改，即使看起来相关）：
- `ConversationPerfFlags.conversationListSdkPrimary` 默认值（产品边界）
- 会话列表 UI 布局、滑动交互、虚拟水合策略（`ensureTypeIndexHydrated` 的调用保留）
- 腾讯 SDK 版本、wire payload、SDK 内部实现
- 未读含义、草稿、置顶/归档/免打扰操作语义
- 钱包、通话、媒体发送和搜索链路
- `_persistDedupBuffer` 的 flush 调度（那是 Plan 093 的范围；本计划不触碰）
- 删除 `upsertBatchOverride` 测试钩子（测试契约依赖它）

## Git workflow

- 分支：`advisor/094-page-bypass-coordination`
- 每个逻辑单元一个可回滚提交；提交风格匹配仓库
- 不推送、不合并，除非操作员另行要求

## Steps

### Step 1: 先写行为契约测试（锁定当前旁路竞态）

在修改前新增测试（新建 `test/conversation_page_bypass_contract_test.dart` 或扩展 `test/conversation_list_notifier_incremental_test.dart`），锁定：

1. 页面 `reloadFromLocal` 与 SDK 实时 commit 交错时，实时事件的最新字段（unread/order/lastMessage）不被 reload 覆盖。
2. 聊天返回水合路径（:1783 场景）与 SDK listener 事件交错时，用户刚置顶/刚收到的会话不被 apply 打回。
3. 冷启动 `_loadCachedConversationPreviews` 的两次 reload 在 `hasSyncedOnce` 边界下不产生重复全表刷新。

**Verify**: `flutter test test/conversation_page_bypass_contract_test.dart` → 新增测试能暴露当前行为（记录失败原因注释）；已有核心测试保持绿色。

### Step 2: 收口 :782 冷启动 reload

把 :782 的 `reloadFromLocal()` 替换为只读投影路径：

- 若 Store 已有本地数据，走 `ConversationListNotifier.instance.reloadFromLocal()` 保留（这是**启动只读投影恢复**，属 072 完成标准允许的例外）——前提是确认它发生在 `hasSyncedOnce` 之前且不会被 SDK 后续提交重复触发；
- 若 `hasSyncedOnce` 已为 true，删除该次 reload 直接走 `_maybeFillFeedViewportOnce`（SDK 同步已完成，Store 快照由 Coordinator 提交驱动）。

以"SDK 同步状态决定是否需要本地投影"为准，而不是无条件 reload。**:782 的调用必须与 :1205 合并判定**——两次调用路径重叠，需确认不会出现"两次都执行"。

**Verify**: `flutter test test/conversation_page_bypass_contract_test.dart` 冷启动用例通过；`rg -n "reloadFromLocal" lib/src/conversation.dart` 只剩明确标注的启动投影恢复（≤1 处，含理由注释）。

### Step 3: 收口 :1205 的 `_loadCachedConversationPreviews` 分支

:1205 的 `reloadFromLocal()` 仅在 `!hasSyncedOnce` 时执行——它本身已是"冷启动本地投影"的合理场景。本步骤要求：

- 给该处加注释说明其属于 072 允许的"冷启动投影恢复"例外；
- 确认它与 :782 不会双跑（若 :782 已处理同场景，:1205 可删除）；
- 确认 `hasSyncedOnce` 翻转后该路径不会再次触发。

**Verify**: `flutter test test/conversation_page_bypass_contract_test.dart` → 通过；静态确认 `reloadFromLocal` 生产调用点符合 072 完成标准（启动投影恢复 + 账号切换 + 数据库迁移，共三类）。

### Step 4: 收口 :1783 聊天返回水合

:1783 的 `applyConversationsFromStore` 是"聊天返回后把 opened conversation 强制灌回窗口"。替换为：

- 通过 `ConversationSyncService.instance.commitSdkHydratedConversations(<V2TimConversation>[local])` 或新增的只读辅助（从 Store 读取已提交快照再 apply），确保该行**经过 Coordinator 提交后的快照**而非页面直接读 Store 再写 Notifier；
- 若 `local` 是 Coordinator 已提交的最终行（`conversationById` 读出的就是提交后快照），则 `applyConversationsFromStore` 的调用可改为走 Notifier 的 `applyCommittedBatch` 语义（消费 commit 产物），而不是直接构造 apply。

禁止：把 `conversationById` 读出的行直接当"新事实"整对象覆盖 Notifier 中可能更新的行——必须保留"仅当 Store 提交后的值比 Notifier 当前行更新才灌入"的语义（用现有 `_latestPersistSequenceById` / fingerprint 或 Coordinator generation 判断）。

**Verify**: `flutter test test/conversation_page_bypass_contract_test.dart` 聊天返回用例通过；`rg -n "applyConversationsFromStore" lib/src` 的调用点收敛到 Coordinator commit 产物消费 + 明确注释的例外。

### Step 5: `upsertBatch` 降级为测试专用

把 `conversation_local_store.dart:3599` 的 `upsertBatch` 加 `@visibleForTesting` 注解（或等价守卫），使生产代码无法静默调用。确认：

- 生产路径已全部走 `commitCoordinatorPlan`（`rg -n "upsertBatch" lib/src` 只命中 `upsertBatchOverride` 测试钩子、store 内部定义、@visibleForTesting 调用点）；
- `upsertBatchOverride`（sync_service 测试钩子）保留，因为测试契约依赖它；
- 不改变 `deleteBatch`（它有独立的生产调用路径，本计划不评估）。

**Verify**: `flutter analyze` in-scope 文件无新增 error；`rg -n "ConversationLocalStore\.instance\.upsertBatch" lib/src` 返回空或只剩测试/守卫标注调用点。

## Test plan

- 新建 `test/conversation_page_bypass_contract_test.dart`（Step 1），覆盖：reload vs 实时交错、聊天返回 vs SDK 事件交错、冷启动双 reload 边界。
- 模式参考：`test/conversation_list_notifier_incremental_test.dart`（Notifier apply 断言）、`test/conversation_sync_reload_coalesce_test.dart`（override/fakeAsync）。
- 回归：`test/conversation_local_store_sort_test.dart`、`test/conversation_feed_settle_jump_contract_test.dart` 保持绿色（:1783 收口涉及的水合/滚动语义不得回归）。
- **Verify**: `flutter test test/conversation_page_bypass_contract_test.dart test/conversation_list_notifier_incremental_test.dart test/conversation_local_store_sort_test.dart test/conversation_feed_settle_jump_contract_test.dart test/conversation_sync_reload_coalesce_test.dart` → 全部通过。

## Done criteria

机器可检查，全部成立：

- [ ] `git diff --check` exit 0
- [ ] `flutter analyze`（in-scope 文件）无本计划新增 error
- [ ] 上述核心测试全部通过
- [x] 页面冷启动只剩一次 `restoreStoreProjection(coldStart)`
- [ ] `rg -n "ConversationLocalStore\.instance\.upsertBatch" lib/src` 返回空（生产路径）
- [ ] 无 in-scope 列表之外的文件被修改（`git status`）
- [x] `plans/README.md` 状态行已更新

## STOP conditions

出现以下任一情况停止并报告（不要自行发挥）：

- 现场代码与 "Current state" 摘录不一致（自 `9f7c46e` 后漂移）。
- 某步验证连续两次失败且合理修复后仍失败。
- 修复需要触碰 out-of-scope 文件（尤其 `ConversationPerfFlags`、SDK、UI 布局、`_persistDedupBuffer` 调度）。
- 发现 `reloadFromLocal` 是某个生产路径（非冷启动/账号切换/DB 迁移）的必需语义，删除后出现"列表不显示本地预览"回退。
- 聊天返回水合收口后出现滚动位置/水合窗口回归（`conversation_feed_settle_jump_contract_test.dart` 失败即 STOP）。

## Maintenance notes

- 未来新增任何页面级会话数据写入，必须走 `commitSnapshotConversations` / `commitSdkHydratedConversations` / `commitCreatedConversation` 或 Notifier 的 commit 产物消费，禁止直接 `reloadFromLocal` / `applyConversationsFromStore`。
- 评审重点：`conversation.dart` 中是否还有隐藏的 Notifier/Store 直接写入口（`:782`/`:1205`/`:1783` 之外）；`upsertBatch` 是否仍被误用。
- 本计划完成后，072 阶段 6 的"删除旧直接写入口"清单应再核一遍：本计划收口的 3 个旁路 + 093 的 buffer 语义，应能合并到 072 的完成标准中。
- `deleteBatch` 与 `reloadFromLocal` 的账号切换/数据库迁移合法调用点不在本计划评估范围，未来清理时单独立案。
