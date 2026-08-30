# IM-00 基线记录

状态：`IM-03_PARTIAL`（2026-08-29）

本文件记录重构开始前的可重复基线。它只记录命令、版本、计数、错误码和证据引用，不记录 UserSig、管理员密钥、消息正文、手机号、银行卡、钱包数据或媒体绝对路径。

## 当前代码和依赖基线

| 项目 | 值 |
| --- | --- |
| 工作区 | `D:/99chat/zuixin/9925banben/9925banben` |
| 设计基线 | `docs/腾讯IM模式一_专用消息服务架构设计_重梳版.md`，`v2.3-review` |
| Flutter/Dart 约束 | Flutter `>=3.19.0`，当前工具链 Flutter `3.44.4` / Dart `3.12.2` |
| Tencent Flutter SDK | 根依赖 `^8.7.7201`，本地 override `third_party/tencent_cloud_chat_sdk` 版本 `8.9.7545` |
| TUIKit | 根依赖 `^5.0.1`，本地 override 版本 `5.0.1+4` |
| SDK 套餐 | 项目方确认最高套餐；文档明确能力可排期，不等于控制台/运行时已验证 |
| 账号凭据 | 不进入仓库；测试账号由项目方通过安全渠道提供 |

## 静态入口基线

执行：

```powershell
pwsh -File tool/im_migration_scan.ps1
```

输出证据：本次执行结果保留在当前任务的命令输出中；后续 CI/迁移报告应把脚本 JSON 输出保存到脱敏构建产物。脚本分类如下：

| 类别 | 说明 |
| --- | --- |
| `messageListMap` | TUIKit/App 消息内存窗口读写点 |
| `setMessageList` | 正式消息列表提交边界 |
| `history` | SDK 历史 API 调用点 |
| `advancedListener` | SDK Advanced Message Listener 注册/移除 |
| `sendMessage` | SDK 消息发送调用点 |

当前允许的结论是“入口已登记”。扫描数量不是运行时消息数量，也不能证明旧入口已经完成迁移。

2026-08-29 复扫结果：`advancedListener=23`、`history=36`、`messageListMap=158`、`sendMessage=11`、`setMessageList=34`。新增的 IM Adapter Listener 入口已进入扫描，通话信令仍按独立 namespace 保留。

## 工具链运行前置

当前 Flutter SDK 位于工作区外：`D:/flutter_windows_3.44.1-stable/flutter`。Flutter CLI 启动时会在 SDK 的 `bin/cache/lockfile` 建立进程锁，因此运行 analyzer 的 Windows 用户必须对 SDK 的 `bin/cache` 目录拥有读写权限。该锁文件不是项目文件，也不能在 Flutter/Dart 进程仍运行时手工删除。

在 Codex 沙箱或其他限制了用户缓存目录的终端中，从仓库根目录执行以下命令，把 Dart/Flutter 的用户态缓存放到工作区：

```powershell
$env:APPDATA = "$PWD\.dart-appdata"
$env:LOCALAPPDATA = "$PWD\.dart-localappdata"
flutter --version
flutter analyze --no-pub
```

如果 `flutter --version` 也无输出，先关闭 IDE、Flutter 和 Dart 进程，再确认 `D:/flutter_windows_3.44.1-stable/flutter/bin/cache` 可写；不要先删除 `lockfile`。IDE 必须从已经设置这些环境变量的终端启动，或把变量配置到 IDE 的运行环境中，否则 IDE 内的 analyzer 仍可能使用不可写的默认缓存目录。

## 运行验证基线

以下结果在契约代码落地后重新执行并填入；空白表示尚未执行，不表示通过：

| 检查 | 命令 | 结果 | 证据 |
| --- | --- | --- | --- |
| 补丁空白检查 | `git diff --check` | `PASS` | 当前任务记录 |
| IM-01/02/03 契约与基础设施单测 | `flutter test --no-pub test/im_contracts_test.dart` | `PASS: 24 tests` | 2026-08-29；含生产 SQLite 回环、Listener 生命周期、Inbox fencing 状态推进和恢复 Worker |
| 相关静态分析 | `dart analyze lib/src/services/im lib/src/services/conversation_local/conversation_sync_service.dart test/im_contracts_test.dart` | `PASS: No issues found!` | 2026-08-29；使用工作区缓存变量并允许 Flutter SDK 缓存写入 |
| Dart 格式检查 | `dart format lib/src/services/im lib/src/services/conversation_local/conversation_sync_service.dart test/im_contracts_test.dart` | `PASS` | 2026-08-29 |
| IM-00 入口复扫 | `pwsh -File tool/im_migration_scan.ps1 -OutputJson docs/im-migration/00-entry-ledger.generated.json` | `PASS: 23/36/158/11/34` | 2026-08-29；按 `advancedListener/history/messageListMap/sendMessage/setMessageList` 顺序 |
| 全量静态分析 | `flutter analyze --no-pub` | `BASELINE: exit 1；30734 issues found` | 2026-08-29；工具链已正常启动；结果包含仓库历史诊断和 `wechat_message_animation_patch*` 等拷贝目录错误，不能作为本次 IM 变更的定向失败结论 |
| 全量测试 | `flutter test` | `PENDING` | 进入灰度前必须执行 |
| 真机/Web 能力 Proof | 按设计文档 17.4.5 记录 | `NOT_AVAILABLE` | 需要测试账号、平台和控制台证据 |

## 场景基线

每个场景必须记录平台、SDK/TUIKit/Push 版本、账号类型、网络状态、请求摘要、结果码、游标、边界消息 ID 和 raw evidence 引用。消息正文和凭据只存在受控测试环境。

| 场景 | 预期不变量 |
| --- | --- |
| C2C 首屏/上拉/回底 | 不清窗、不重复；不使用群 Seq |
| 群首屏/上拉/回底 | 正式 `msgID` 去重；真实群 Seq 缺口可登记并补洞 |
| 文本/图片/视频/语音/自定义发送 | `operationId + clientCorrelationId` 一致；超时不自动重发 |
| 历史本地/云端和 Web | 实际来源写入 `HistoryProof`；Web 不伪造本地历史 |
| 搜索定位 | 搜索结果只产生定位命令；重新鉴权并经 Writer/Row 确认 |
| 已读/草稿/置顶/免打扰 | 按能力和产品 ADR 分开；旧 generation 不覆盖新状态 |
| 撤回/清空/切账号 | 旧账号和旧 generation 不得写入当前账号；正式发送终态可隔离恢复 |
| Push/前后台/通知点击 | Push 只唤醒/提示；正式消息仍来自 SDK/历史 Writer |
| 通话信令 | 仅 `call-signaling` namespace，不进入普通聊天去重/排序 |

## 本阶段退出条件

- [x] 已确认设计文档在当前 `docs/`，并作为唯一基线。
- [x] 已建立入口账本和静态扫描脚本。
- [x] 已建立无 UI 依赖的 IM-01 契约目录。
- [x] 契约单测通过并记录。
- [x] 契约代码 `dart analyze` 通过并记录。
- [ ] Flutter 全量 `analyze` 通过并记录。
- [ ] 所有正式写入口完成逐条责任归属。
- [ ] 真机/Web 基线具备可复现账号和证据。
- [x] IM-03 基础设施已接入：持久化 Inbox、入口序号、账号 WriterLease、Mailbox、普通聊天 Adapter Listener。
- [x] IM-03 fencing 状态推进已具备：`PREPARED(Inbox)` → `PROCESSING` → `METADATA_COMMITTED` → `PROJECTION_PUBLISHED` → `COMPLETED`，每步校验当前 token。
- [ ] IM-03 完整退出门禁：恢复 Worker、跨 Isolate 唤醒、Crash replay 和全部正式领域事务均接入 Lease。
- [ ] IM-04/05：唯一 Message Writer、Commit Journal、Projection Checkpoint、Outbox 和加密恢复副本。
