# Plan 087: 收敛移动端生命周期、前后台恢复和退出回写

> **Executor instructions**: 本计划依赖 086 的仲裁协议，只处理生命周期和恢复调度，不改变业务数据内容。

## Status

- **Priority**: P0
- **Effort**: L
- **Risk**: HIGH
- **Depends on**: 086
- **Category**: bug / performance / tests
- **Planned at**: commit `9f7c46e`, 2026-08-24

## Goal

把前后台恢复、断线重连、页面退出和账号切换从多个并行入口收敛为有界调度：同一阶段只执行一次，恢复任务可取消，旧结果不能回写新页面或新账号。正常使用的消息、未读、草稿、通话、群资料和会话列表语义必须保持不变。

## Scope

- `lib/src/pages/app.dart`
- `lib/src/chat.dart`
- `lib/src/services/device_sync_service.dart`
- `lib/src/services/conversation_local/conversation_sync_service.dart`
- `lib/src/services/chat_history_recovery_coordinator.dart`
- 相关测试

不修改 SDK 历史 API、会话列表布局、通话 UI 和服务端接口。

## Rules

- 恢复顺序固定：认证/SDK 就绪 → 会话同步 → 当前聊天历史 → 未读/已读 → 低优先级资料富化。
- 同一阶段单飞；新的触发只设置 pending，不并行开第二份。
- 页面退出立即取消未开始任务；已开始任务必须通过 086 guard。
- 前台恢复不得清空当前列表再重建，必须增量合并。

## Verification

增加冷启动、后台 30 秒/长时间、断网恢复、快速退出登录、快速切会话测试；执行 `flutter test` 定向用例和真机 Profile。出现恢复后消息减少、未读倒灌、草稿恢复或旧群资料回写时 STOP。
