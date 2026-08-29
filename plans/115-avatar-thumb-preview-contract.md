# Plan 115: 全局头像 Thumb 展示与全屏 Preview 双变体契约

> **Executor instructions**: 本计划是 Plan 114 的前置架构变更。先完成后端契约、历史回填和客户端变体语义迁移，再迁移 UI 消费面。任何普通页面、列表、卡片、推送或通知主动请求 preview/origin 都视为验收失败。当前仓库只有 Flutter 客户端，后端迁移必须在对应后端仓库独立实施和评审。

## Status

- **Priority**: P0
- **Effort**: L
- **Risk**: HIGH（跨后端 API、腾讯 IM 投影、本地 SQLite、实时事件、推送、Flutter/UIKit/Web/native 通知）
- **Depends on**: 后端可以持久化并回填 `thumb_url`、`preview_url` 和 `avatar_version`
- **Category**: architecture / API contract / performance / UX
- **Planned at**: commit `9f7c46e`, 2026-08-26
- **Status**: TODO

## Product invariant

1. 页面内普通展示无论尺寸、位置和业务类型，网络源只允许 `thumb`。
2. 用户明确进入全屏头像预览后，才允许请求 `preview`。
3. `_origin.jpg` 不进入头像 UI；如果未来需要原图下载，必须是另一个明确授权的操作和接口。
4. 普通展示缺少或加载失败的 thumb 时显示默认头像并上报，禁止静默回退 preview。
5. thumb 可以作为全屏 preview 的首帧占位，但全屏打开后应独立解析并加载 preview。

本规则覆盖用户、群、群成员、好友、会话、聊天消息、资料页页内头像、搜索、申请、通话、朋友圈、钱包卡片、二维码、推送和系统通知。头像在页面上显示得较大，不等于全屏预览。

## Root cause

当前头像链路在上传响应之后立即丢失变体语义：

- `UserAvatarUploadResult` 和 `GroupAvatarUploadResult` 能拿到 origin/preview/thumb，但资料模型只保留一个 `avatarUrl/faceUrl`。
- `/me`、用户资料/搜索、好友、群、群成员和实时事件客户端模型只解析单 URL。
- `UserProfileRecord`、`MeFriendRecord`、`MeGroupRecord`、`GroupMemberRecord` 及对应 SQLite 都只有一个头像字段。
- `ConversationFaceUrl`、`UserDisplayProfile`、`PushIdentityCache` 只能选择单 URL，无法表达展示目的。
- UIKit `Avatar` 的普通渲染和 `_openBigAvatar()` 复用同一个 `faceUrl`。把它改为 thumb 会让全屏也只有 thumb；继续传 preview 又会让所有页内头像下载 preview。

因此这不是若干页面的 URL 替换，而是后端到渲染边界的双变体数据迁移。

## Verified current data paths

当前工作区只包含 Flutter 客户端、vendored Tencent SDK/UIKit 和 Android/iOS 通知代码，不包含用户提到的后端 `GroupProfileView`、`GroupAccessService`、`GroupMemberEnrichmentService` 或 `PushAvatarResolver`。以下链路是从当前工作区源码直接核对的；后端类的实际实现仍需在后端仓库复核。

### User / C2C avatar path

- `UploadApi.uploadUserAvatar()` 能解析 origin/preview/thumb，但兼容字段 `avatarUrl` 优先选择 thumb；`MyProfileDetail` 随后只传这一个值给 `UserAvatarHelper.applySelfAvatarUpdate()`。
- `applySelfAvatarUpdate()` 把同一个 URL 写入腾讯 IM `V2TimUserFullInfo.faceUrl`、当前用户 view model 和 `UserProfileLocalService`，上传响应里的 preview 语义在此丢失。
- `/me`、用户搜索/公开资料、好友列表、好友变化事件、好友申请、朋友圈和通话记录模型都只保留一个 `avatarUrl/faceUrl`。
- `user_profiles.avatar_url`、`friends.friend_avatar_url`、conversation `face_url/raw_json` 也都是单字段。好友全量/增量同步会继续把这个单值投影到用户资料、会话和群成员内存。
- 单聊会话行优先本地用户资料，再回退 conversation/好友 IM face；聊天打开的 live-profile 路径又会优先读取腾讯 IM 并回写本地。因此历史 IM preview 可以重新覆盖一次上传后已经保存的 thumb。

### Group and group-member avatar path

- 群上传响应已经同时解析 `thumbUrl` 和 `previewUrl`；修改群头像和建群流程明确把 thumb 写进群资料、腾讯 IM/会话和群资料变更消息，但没有保存 preview sidecar。
- `/me/groups`、`GET /group/{id}`、群搜索/加群 lookup 和成员分页最终都落到 `MeGroupRecord.avatarUrl` 或 `GroupMemberRecord.avatarUrl` 单字段。
- `GroupLocalStore` 和 `GroupMemberLocalStore` 的 SQLite schema 分别只保存 `avatar_url`；群资料/成员变化事件也只解析一个 URL。`GroupEntityChangeEvent.avatarVersion` 虽已存在，但尚未绑定 thumb/preview 双变体。
- `MeGroupRecord.toV2TimGroupInfo()` 和成员转换把单字段继续写入 `V2TimGroupInfo.faceUrl` / `V2TimGroupMemberFullInfo.faceUrl`；群资料同步又把群头像双写到 conversation `faceUrl`。
- 群会话头像的实际优先级是 `GroupLocalStore` → REST/群列表 → Tencent conversation；群成员展示又可能被 `UserProfileLocalService` 的用户单字段覆盖。任一来源是 preview 都会扩散到普通页面。
- 群资料、群详情、入群页的可点击头像与 UIKit `_openBigAvatar()` 共用这个单字段：若当前值为 thumb，全屏只能看 thumb；若当前值为 preview，页内 40/56/96px 也会先下载 preview。

### Native notification path

- Dart push/local-notification 代码从 message、conversation、`GroupLocalStore` 或当前用户资料选出单个 `avatarUrl`。
- iOS `NotificationAvatarDecorator` 与 Android `NotificationAvatarLoader` 直接下载 payload URL 并裁剪/缩放，不做可靠的 variant 选择。因此 payload 本身必须是 thumb，native 端不得猜文件名。

## Canonical contract

新增不可变头像描述符，字段至少包括：

```text
ownerType: user | group
ownerId: stable user/group id
avatarVersion: monotonic revision or immutable object revision
thumbUrl: 200x200 display source
previewUrl: full-screen preview source
```

可选保留 `originUrl` 供非头像 UI 的明确下载业务使用，但普通 descriptor selector 不暴露它。

选择 API 必须表达意图：

```text
displaySource() -> thumbUrl or placeholder
fullscreenSource() -> previewUrl, with thumbUrl as visual placeholder only
```

不得提供一个模糊的 `bestUrl()`，否则调用方会再次把 preview 带回普通页面。

首选网络契约是惰性 preview：普通列表、资料页首屏、会话、消息和推送响应只需要返回 `thumbUrl + avatarVersion`；用户点击头像进入全屏后，客户端再按 `ownerType + ownerId + avatarVersion` 调用专用 preview resolver/endpoint。上传响应可以同时返回 preview，客户端可保存其描述信息，但点击前不得创建 preview 的 image provider、发起下载或加入预热队列。若现有详情 API 为兼容而已经返回 `previewUrl`，同样只能由全屏 selector 在点击后读取。

## Backend work

1. 在用户和群头像记录中持久化 `thumb_url`、`preview_url`、`avatar_version`。上传事务必须同时提交三者，版本在换头像时变化。
2. 历史 `_preview.jpg` 记录离线回填对应 thumb；生成/对象不存在要留下可观测迁移状态，不能让客户端猜 URL 后缀。
3. 普通投影统一返回 `thumbUrl`、`avatarVersion`：`/me`、用户 profile/search/contact match、好友列表和变化流、群列表/详情、群成员分页和变化流、群申请/通知、会话 projection、资料实时事件。需要全屏预览的用户/群必须能通过专用 endpoint 按 owner/version 惰性获取 `previewUrl`。
4. 上传响应返回 `originUrl`、`previewUrl`、`thumbUrl`、`avatarVersion`，但业务资料写入和 IM 投影仍以 thumb 为普通展示值。
5. 推送 payload 只发送 `avatarThumbUrl`；兼容期可保留旧 `avatarUrl`，但其值必须是 thumb。native 端不推导后缀。
6. 腾讯 IM 的单值 `faceUrl` 统一投影 thumb，保证 SDK conversation/message/group/member 旁路也不会把 preview 带进普通 UI。preview 始终从业务 sidecar 或全屏专用 API 获取。
7. 契约测试覆盖上传后重新登录、另一设备读取、换头像版本、旧记录回填、好友/群成员实时变更、离线推送，以及点击全屏前 preview endpoint 调用次数为 0。

## Client data migration

1. 新增 `AvatarDescriptor`/`AvatarVariants` value object，集中做 URL 规范化、版本身份和 display/fullscreen 选择。
2. 为用户资料、好友、群、群成员本地模型增加 `avatarThumbUrl`、可选 `avatarPreviewUrl`、`avatarVersion`。SQLite 只做 additive migration，保留旧字段作为迁移输入，不清库；采用全屏惰性 resolver 时普通 conversation/friend/member 快照不必复制 preview URL。
3. conversation snapshot、friend/group/member store、实时 event 和 custom message 中携带 thumb；需要进入头像全屏的 owner 额外保存或按需查询 preview descriptor。
4. 将腾讯 IM `faceUrl` 视为 thumb-only compatibility projection，不再作为 full-screen preview authority。
5. 旧单 URL 的分类只能依赖后端明确的 variant metadata。无法证明是 thumb 的旧 URL不得用于普通展示；记录 missing 并显示默认头像。

## Renderer split

### `AppUserAvatar`

- 输入改为 descriptor 或明确 `thumbUrl`，删除普通渲染传 preview 的能力。
- 继续按逻辑尺寸 × DPR 限制 decode 和磁盘派生尺寸。
- cache identity 包含 owner、avatarVersion、`thumb`、目标像素 bucket；签名 URL 不能作为唯一资源身份。

### UIKit `Avatar`

- 普通层只使用 `thumbUrl`。
- `isShowBigWhenClick` 只声明存在全屏入口，不再暗示普通层使用大图。
- `_openBigAvatar()` 在点击后调用 `previewResolver` 或读取 `previewUrl`；Web lightbox、ImageScreen 和保存操作都使用 preview。
- 全屏可以先复用已解码 thumb 保持首帧稳定，preview 到达后无闪白替换。

### Push/native

- `PushPayloadNormalizer` 优先读取 `avatarThumbUrl`，旧 `avatarUrl` 仅兼容且后端保证为 thumb。
- Android/iOS 通知装饰器只下载 thumb，并继续做边界尺寸 decode；不在 native 层替换文件名。

## Consumer migration matrix

### Must use thumb

- 首页会话行、归档/选择/分享会话行、聊天顶栏、消息气泡发送者头像、消息预热。
- 好友/联系人/黑名单、新联系人和好友申请、搜索结果、转发/名片/成员选择器。
- 群列表、共同群、群申请和通知、群资料页内头像、群详情页内头像、群成员/管理/@/回执/Reaction。
- 自己和他人的资料页页内头像、二维码头像、宽屏侧栏和设置页。
- 通话页、最近通话、悬浮通话窗、群直播横幅；大背景仍不是头像全屏预览，按本规则使用 thumb。
- 朋友圈、钱包/红包/转账、联系人卡片、平台通知和所有业务列表/卡片。
- App 内消息横幅、离线 push、本地系统通知、iOS Communication Notification、Android notification large icon。

### May use preview after explicit full-screen entry

- 对方用户资料头像点击后的 UIKit `_openBigAvatar()`。
- 自己资料的“查看头像”全屏页。
- 群资料/群详情头像点击后的全屏页。
- 加好友页和入群申请页头像点击后的全屏页。
- UIKit narrow/wide profile card 在真正打开全屏头像查看器后的路径。

普通页面中的 72px、96px 甚至铺满背景头像都不属于上述允许范围。

## Raw renderer cleanup

下列绕过统一头像组件的路径必须迁移，否则无法保证 thumb、尺寸 cache 和失败策略一致：

- `lib/src/pages/wallet/red_packet/widgets/red_packet_member_sheet.dart` 的 `Image.network(item.avatar)`。
- `lib/src/pages/wallet/red_packet/red_packet_screen.dart` 的直接网络图像。
- `lib/src/create_group.dart` 和 `lib/src/avatar_select_page.dart` 中实际表示头像的裸 `Image.network`。
- Web HTML `<img>` 分支必须接受同一个 display/fullscreen selector 结果。

实施时重新运行全仓 `rg`，禁止新增 raw `faceUrl/avatarUrl` 直接进入头像网络组件的调用。

## Rollout order

### Phase 0: Contract and observability

- 固化普通投影与全屏 resolver 的响应 fixtures 和后端 schema；记录 variant、version、owner，不记录完整私有 URL/token。
- 增加普通展示 preview/origin 请求计数器，先观测当前违规面。

### Phase 1: Backend and history backfill

- 写入双 URL 和版本；普通读接口/事件/推送补齐 thumb/version，全屏 resolver 返回 preview；完成历史 thumb 回填。
- 验证跨设备和重登录仍能稳定显示 thumb，并且只在进入全屏后取得同版本 preview。

### Phase 2: Client models and stores

- 解析 descriptor，迁移 user/friend/group/member/conversation stores。
- IM `faceUrl` 改为 thumb projection；旧 preview 单值不得继续流入展示 resolver。

### Phase 3: Renderers and full-screen boundary

- 先拆 `Avatar` 的 display/fullscreen 图源，再迁移 `AppUserAvatar`。
- 确保全屏 save/download 与 Web lightbox 使用 preview，普通 widget tree 只使用 thumb。

### Phase 4: Consumer migration

- 按 must-use-thumb 清单逐模块迁移，清理 raw renderers。
- 推送和 native 通知单独做端到端验证。

### Phase 5: Plan 114 cache and scroll prediction

- descriptor 已稳定后再统一 provider/key/目标尺寸派生缓存并接入会话滚动预热。
- 不允许预热 preview；全屏 preview 只在点击后启动。

## Verification

### Contract tests

- 上传后 `/me`、他人 profile、好友、群、群成员普通投影均返回同一版本的 thumb；按 owner/version 打开的全屏 resolver 返回同版本 preview。
- 换头像生成新版本，旧 thumb/preview 不与新资源共享 cache key。
- 历史记录完成回填；未完成记录普通 UI 显示默认头像，不请求 preview。

### Widget/integration tests

- 普通 `Avatar/AppUserAvatar` 只解析 thumb；传入 descriptor 含 preview 也不产生 preview provider。
- 点击全屏前 preview 请求数为 0；点击后恰好解析一次 preview。
- 全屏先显示 thumb，再无闪白升级 preview；保存使用 preview。
- 会话、资料页页内、群成员、消息、通话、朋友圈、钱包、推送 fixture 都断言 thumb。
- Web、Android 和 iOS notification 断言 URL variant 为 thumb。

### Repository gates

```sh
rg -n "Image\\.network|NetworkImage|CachedNetworkImageProvider|AppNetworkImage" lib third_party/tencent_cloud_chat_uikit
flutter analyze <touched files>
flutter test <avatar contract and focused suites>
```

人工真机矩阵覆盖冷启动、重登录、另一设备换头像、弱网、离线、快速滚动、全屏打开/关闭/保存，以及用户/群两种 owner。

## Done criteria

- [ ] 后端所有普通读取和事件路径返回 thumb+version，全屏 resolver 按 owner/version 返回 preview；历史记录已回填或有明确 missing 状态。
- [ ] 普通 UI、推送和 native 通知的 preview/origin 网络请求为 0。
- [ ] 腾讯 IM `faceUrl` 只承载 thumb；preview 由业务 descriptor/API 提供。
- [ ] 用户/好友/群/群成员普通存储明确保留 thumb+version，preview 只存在 owner sidecar 或全屏 resolver；merge 不会把不明单 URL 重新写入 display 字段。
- [ ] 所有全屏入口在点击后才请求 preview；退出普通页面不会预热 preview。
- [ ] raw avatar renderers 已迁移到统一组件/provider。
- [ ] Focused tests、analyzer、Android/iOS/Web 端到端验证通过。
- [ ] Plan 114 随后只预热 thumb，并记录 first-visible-frame 指标改善。

## STOP conditions

- 后端只继续提供一个含义不明的 `avatar_url`，或要求客户端永久猜 `_preview`/`_thumb` 后缀。
- 为了兼容历史数据而允许普通页面回退 preview。
- `Avatar` 仍用同一 URL 同时承担页内显示和全屏预览。
- preview 在路由打开前被预取，或 origin 进入普通头像 cache。
- SQLite migration 需要清库、账号间 cache identity 会碰撞、头像更新版本会串图。
- 推送/native 仍直接下载 preview，或 Web 路径绕过 selector。

## Maintenance notes

- 新增头像场景默认只能调用 display selector；只有命名明确的 full-screen preview route 可以调用 fullscreen selector。
- Code review 增加检查：禁止业务代码直接把 `faceUrl/avatarUrl` 传给网络头像组件。
- 监控 thumb missing、thumb error、preview-before-fullscreen 和 origin-avatar-request 四类指标。
- CDN 尺寸、格式或文件名规则变化只应影响后端 descriptor，不应要求客户端字符串替换。
