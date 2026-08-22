# 99chat Flutter 客户端

99chat 是基于 Flutter 的 IM 客户端，底层集成腾讯云 Chat SDK / TUIKit，并在其上扩展了自建账号体系、好友关系、群治理、朋友圈、钱包红包、音视频通话、推送和本地缓存能力。

本文档是项目入口文档，面向日常开发、联调、测试和发布。腾讯云原始 Demo 说明仅作为上游参考，不再作为本项目主文档。

## 支持平台

- Android
- iOS
- Web
- macOS / Windows：保留多端兼容能力，发布前必须单独做平台冒烟

## 技术栈

- Flutter：`>=3.19.0`
- Dart：`>=3.0.0 <4.0.0`
- Tencent Cloud Chat SDK：见 `pubspec.yaml`
- Tencent Cloud Chat UIKit：本地 fork，见 `third_party/tencent_cloud_chat_uikit`
- 本地存储：`sqflite`、`sqflite_common_ffi`、`shared_preferences`、`flutter_secure_storage`
- 网络：`dio`
- 推送：APNs、JPush、自建 `/me/push-token`

推荐开发基线：

- Flutter `3.32.x`
- Xcode 15 或更高
- Android Studio 最新稳定版
- iOS 真机用于 APNs、VoIP、相册、推送权限验证

## 目录结构

| 路径 | 说明 |
| --- | --- |
| `lib/main.dart` | 应用入口 |
| `lib/config.dart` | 产品配置、环境变量和灰度开关 |
| `lib/src/pages/app.dart` | 启动、登录态恢复、IM SDK 初始化入口 |
| `lib/src/chat.dart` | 聊天页主实现 |
| `lib/src/conversation.dart` | 会话列表主实现 |
| `lib/src/api/` | 自建后端 API 封装 |
| `lib/src/services/` | 登录、会话、本地缓存、推送、朋友圈等服务 |
| `lib/src/pages/moments/` | 朋友圈页面 |
| `lib/src/pages/wallet/` | 钱包、红包、转账、记录 |
| `docs/` | 业务设计、后端契约、运维和治理文档 |
| `third_party/` | 本地 fork / 受控依赖 |
| `test/` | 单元测试与轻量集成测试 |

## 快速开始

```bash
flutter pub get
flutter run
```

Web 端首次运行前：

```bash
cd web
npm install
cd ..
flutter run -d chrome
```

常用检查：

```bash
flutter test
flutter analyze
```

说明：当前全量 `flutter analyze` 仍包含历史遗留 warning/error。新增改动应至少保证相关文件 `ReadLints` 无错误，并运行对应测试。

## 环境变量

运行时使用 `--dart-define` 注入环境变量。生产构建不得依赖源码里的开发默认值。

| Key | 用途 | 默认值 | 发布要求 |
| --- | --- | --- | --- |
| `API_BASE_URL` | 主业务后端地址，`ApiClient` 会优先使用非 loopback 值 | 见 `IMDemoConfig.smsLoginHttpBase` | 生产必须为 HTTPS |
| `SANGONG_HTTP_BASE` | 三公代理地址（可选） | 默认 `${主服务}/sangong` | 禁止直连公网 8088 |
| `SANGONG_SETTINGS_HTTP_BASE` | 遗留覆盖 Base（可选） | 空 | 非空时覆盖默认 `/sangong` |
| `REALTIME_TCP_PORT` | 自建 TCP 实时通道端口 | `8082` | 与后端部署一致 |
| `JPUSH_APPKEY` | Android JPush AppKey | 空 | Android 推送发布必须配置 |
| `JPUSH_CHANNEL` | Android JPush 渠道 | `developer-default` | 按渠道包配置 |
| `ANDROID_JPUSH_ENABLED` | Android JPush 总开关 | `true` | 灰度时显式声明 |
| `ANDROID_JPUSH_WAKE_ENABLED` | JPush 唤醒能力 | `true` | 合规评审后启用 |
| `ANDROID_JPUSH_AUTO_WAKEUP_ENABLED` | JPush 自动唤醒 | `true` | 合规评审后启用 |
| `ANDROID_KEEP_ALIVE_ENABLED` | Android 前台服务保活引导 | `true` | 合规评审后启用 |
| `ANDROID_BATTERY_OPT_GUIDE_ENABLED` | 电池优化引导 | `true` | 按渠道策略配置 |
| `SELF_HOSTED_PUSH_ENABLED` | 自建 Push token 注册 | `true` | 生产推荐开启 |
| `USE_GALLERY_VIDEO_PLAYER_POOL` | 图集视频 Player 池灰度 | `false` | 灰度验证后开启 |

示例：

```bash
flutter run \
  --dart-define=API_BASE_URL=https://api.example.com \
  --dart-define=JPUSH_APPKEY=your-jpush-appkey
```

## 后端契约

主要契约文档：

- 朋友圈后端接口：`docs/moments-backend-api-implementation.md`
- 朋友圈自建服务设计：`docs/moments-self-hosted-server.md`
- 好友自建客户端：`docs/friend-self-hosted-client.md`
- 群自建客户端：`docs/group-self-hosted-client.md`
- 群后端 TODO：`docs/group-self-hosted-backend-todo.md`
- 群治理客户端：`docs/group-governance-client.md`
- 群公告客户端：`docs/group-notice-self-hosted-client.md`
- 群成员 tips：`docs/group-member-tips-tcp-client.md`
- 贴纸自建服务：`docs/sticker-self-hosted-server.md`
- VoIP Push 自建服务：`docs/voip-push-self-hosted-server.md`
- IM 三条关键链路：`docs/im-three-flows.md`
- 朋友圈企业级加固：`docs/moments-enterprise-hardening.md`
- 朋友圈评论删除客户端：`docs/moments-comment-delete-client.md`

## 发布流程

发布前必须完成：

1. 确认 `lib/config.dart` 中所有生产敏感项已通过 `--dart-define` 或原生构建配置覆盖。
2. 执行相关测试，至少覆盖本次改动模块。
3. 执行 `flutter analyze`，新增代码不得引入新的 analyzer error。
4. Android 检查包名、签名、JPush AppKey、渠道、通知权限和前台服务合规说明。
5. iOS 检查 Bundle ID、APNs 证书 ID、VoIP 证书 ID、Signing & Capabilities、通知权限。
6. Web 发布前检查 CORS、API_BASE_URL、文件上传、媒体预览和登录态恢复。
7. 回归登录、会话、聊天、推送、朋友圈、钱包红包、音视频通话。

当前仓库未发现 `.github/workflows` 或 fastlane 配置。正式发布前应补 CI/CD 门禁。

## 排障手册

### 登录后被踢回登录页

检查：

- `API_BASE_URL` 是否指向正确后端。
- `/me` 与 `/auth/user-sig` 是否返回同一个业务用户。
- 本地 token 是否过期。
- `ApiClient` 是否触发 auth expired。

相关文件：

- `lib/src/api/api_client.dart`
- `lib/src/services/auth_session_service.dart`
- `lib/src/services/auth_bootstrap_service.dart`
- `lib/src/services/login_coordinator.dart`

### 会话未读或列表顺序异常

检查：

- `ConversationLocalStore` 是否写入正确账号。
- SDK 会话同步是否完成。
- 前台聊天 guard 是否压回过期未读。

相关文件：

- `lib/src/services/conversation_local/conversation_local_store.dart`
- `lib/src/services/conversation_local/conversation_sync_service.dart`
- `lib/src/services/conversation_local/conversation_list_notifier.dart`

### 朋友圈加载失败

检查：

- `/moments/feed` 或 `/moments/users/{userId}` 是否返回统一分页结构。
- 是否命中 `MomentsErrorMapper` 的权限、登录过期或网络错误。
- `MomentsLocalStore` 是否有当前账号缓存。

相关文件：

- `lib/src/api/moments_api.dart`
- `lib/src/services/moments/moments_store.dart`
- `lib/src/services/moments/moments_local_store.dart`
- `lib/src/services/moments/moments_feed_controller.dart`

### Android 收不到推送

检查：

- `JPUSH_APPKEY` 是否注入。
- `ANDROID_JPUSH_ENABLED` 是否开启。
- 设备是否关闭通知权限或电池优化。
- `/me/push-token` 是否注册成功。

相关文件：

- `lib/src/services/android_jpush_service.dart`
- `lib/src/services/notification_settings_service.dart`
- `lib/src/services/push_notification_router.dart`

### 钱包或红包状态异常

检查：

- 后端订单是否返回稳定 `orderId` / `clientOrderId`。
- 网络异常后 pending recovery 是否恢复订单。
- 页面是否读取 `WalletController.lastError` 或订单结果错误。

相关文件：

- `lib/src/pages/wallet/api_wallet_repository.dart`
- `lib/src/pages/wallet/wallet_controller.dart`
- `lib/src/pages/wallet/order/wallet_order_service.dart`
- `lib/src/pages/wallet/order/wallet_pending_recovery_service.dart`

## 模块 Owner

| 模块 | Owner | 主要文件 |
| --- | --- | --- |
| 登录与账号 | 99chat Mobile / Auth | `lib/src/services/auth_*`、`lib/src/pages/login.dart` |
| IM SDK 初始化 | 99chat Mobile / IM Platform | `lib/src/pages/app.dart`、`lib/src/services/auth_bootstrap_service.dart` |
| 会话与未读 | 99chat Mobile / Conversation | `lib/src/conversation.dart`、`lib/src/services/conversation_local/` |
| 聊天页 | 99chat Mobile / Chat | `lib/src/chat.dart`、`lib/utils/custom_message/` |
| 朋友圈 | 99chat Mobile / Moments | `lib/src/pages/moments/`、`lib/src/services/moments/` |
| 钱包红包 | 99chat Mobile / Wallet | `lib/src/pages/wallet/` |
| 推送与通知 | 99chat Mobile / Push | `lib/src/services/*push*`、`lib/src/services/notification_settings_service.dart` |
| 音视频通话 | 99chat Mobile / Call | `lib/src/services/call_*`、`third_party/tencent_calls_uikit` |
| 本地 fork 依赖 | 99chat Mobile / Dependency | `third_party/`、`docs/dependency-governance.md` |

## 依赖治理

本项目使用多个本地 fork 和 `dependency_overrides`。任何升级 Flutter、腾讯云 SDK、视频播放器、录音、扫码、贴纸能力前，先阅读：

- `docs/dependency-governance.md`

## 已知限制

- `flutter analyze` 当前仍有历史遗留问题，CI 接入前需要分批清理。
- `lib/config.dart` 仍存在开发默认后端地址和开发 key，生产发布必须用构建参数覆盖。
- 部分 `third_party` fork 与上游版本存在差异，升级必须经过模块 owner 审查。
