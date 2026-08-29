# Plan 111: 用统一恢复状态机收口登录、前台、重连和云端追赶

> **Executor instructions**: 复用 092/103–106 的 reconciliation state，不得新增重复 pull
> 或页面级强制 reload。完成后更新计划索引。
>
> **Drift check**: `git diff --stat 9f7c46e..HEAD -- lib/src/pages/app.dart lib/src/services/auth_bootstrap_service.dart lib/src/services/chat_history_recovery_coordinator.dart lib/src/services/im_snapshot_bootstrap_service.dart lib/src/services/conversation_local third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models test`

## Status

- **Priority**: P1
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: 092、103–106、108、110
- **Category**: architecture / correctness
- **Planned at**: commit `9f7c46e`, 2026-08-25

## Goal

将登录 snapshot、App resume、socket reconnect、conversation page、群 gap repair 和 C2C
catch-up 收口为可持久化、可续跑的状态机。页面先服务本地数据，后台恢复只产生 typed
updates，不直接 reload UI。

## State model

```text
idle → loadingLocal → servingLocal → reconcilingRemote
                                  ↘ incomplete → retryScheduled
                                  ↘ consistent
                                  ↘ failedRetryable / failedTerminal
```

每个 owner/conversation 记录 generation、reason、source、attempt、budget、last confirmed
anchor、missing group seq ranges、C2C continuation 和 completeness。

## Steps

1. 建立 owner-level recovery session，合并同次 `app_resumed`、`connect_success`、
   `im_reconnected`，禁止三条链路重复拉取。
2. 本地 projection 成功后立即进入 servingLocal；网络恢复不能阻塞首屏。
3. conversation snapshot、群 gap 和 C2C catch-up 作为子任务，统一 generation/cancel/budget。
4. 子任务输出 typed mutation，经 Coordinator/SQLite；不得直接清空 messageListMap 或 reload
   会话页面。
5. incomplete 状态持久化，下一次前台/重连继续；consistent 只有在腾讯可观察契约满足时
   设置，不能把非空响应当完整。
6. 多账号切换使旧 generation 全部失效，迟到 completion 不得写新账号。

## Verification

- 同次前台+重连只启动一个 recovery session。
- 离线首屏正常展示；恢复后增量更新，不闪空。
- 群 gap、C2C 三页以上追赶、timeout、切账号、杀进程续跑测试通过。
- 无重复 unread、重复摘要 notify 或重复消息 commit。

## STOP conditions

- 腾讯 SDK 无法区分 cloud/local provenance，却被要求标记 consistent。
- 需要无限重试或无限历史拉取。
- 状态机必须直接持有 Widget/BuildContext 才能工作。

