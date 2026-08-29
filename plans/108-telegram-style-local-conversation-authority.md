# Plan 108: 让 SQLite committed view 成为会话页面唯一读取权威

> **Executor instructions**: 按步骤执行并运行每个验证命令。不得删除腾讯 SDK 同步，
> 不得开启 `conversationListSdkPrimary`，不得让 SDK callback 直接写 UI。命中 STOP 条件
> 时停止并报告。完成后更新 `plans/README.md`。
>
> **Drift check**: `git diff --stat 9f7c46e..HEAD -- lib/src/services/conversation_local lib/src/conversation.dart test`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: 102、107 Steps 1–6 行为验证
- **Category**: architecture / correctness / perf
- **Planned at**: commit `9f7c46e`, 2026-08-25

## Goal

Telegram 式客户端的关键不是“有 SQLite”，而是页面只读取数据库提交后的同一份 view。
本计划让 SDK snapshot、Coordinator、Notifier、hydrate 和 TabStore 不再各自裁决字段：
远端输入只能产生 mutation，SQLite transaction 产生唯一 committed batch，页面投影只消费
该 batch 或从 SQLite 恢复。

## Target flow

```text
Tencent callback/page/history
→ typed mutation + source/generation
→ Coordinator
→ SQLite transaction
→ ConversationUiSnapshotBatch
→ Notifier/hydrate/aggregate
```

## Scope

- `conversation_sync_service.dart`
- `conversation_local_store.dart`
- `conversation_list_notifier.dart`
- `conversation_tab_store.dart`
- `conversation_unread_aggregate.dart`
- `conversation.dart`
- 对应测试

## Steps

1. 枚举所有生产 UI writer，建立静态 allowlist。SDK callback、UIKit page、bootstrap、resume
   只能调用 Coordinator commit；`applyCompatibilityStoreProjection` 只保留明确 rollback reason。
2. 扩展 `ConversationUiSnapshotBatch`，携带 committed rows、deleted IDs、changed masks、
   unread deltas、order changes、commit generation 和 completeness。
3. Notifier 在一个 suppression scope 内消费 batch；同步更新 `_conversations`、
   `_typeHydrate` 和 snapshot cache，最后最多 notify 一次。
4. Aggregate 只消费 batch delta；只有 completeness=unknown 才扫描 SQLite 校准。
5. TabStore 在 sdkPrimary=false 时只作兼容镜像，不参与业务裁决；未来启用时也必须消费
   同一 batch。
6. 冷启动、登录和账号切换只通过 typed `restoreStoreProjection` 读取 SQLite；禁止正常
   callback 触发整窗 reload。

## Verification

- 100 条 committed mutations：一次 Store transaction、一次 Notifier notify、一次 aggregate
  delta commit、零立即校准扫描。
- 静态 writer audit 无 SDK→Notifier 直接业务写入。
- 093、102、107、归档、pin、draft、virtual tail、账号切换测试全部通过。

## STOP conditions

- 必须复制字段裁决到 Notifier/TabStore 才能实现。
- committed batch 无法表达删除、排序或 unread delta。
- 冷启动必须等待网络才能展示本地会话。

