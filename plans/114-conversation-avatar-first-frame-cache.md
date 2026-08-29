# Plan 114: 会话列表头像滚动预测预热与 Thumb 目标尺寸缓存

> **Executor instructions**: 先执行 drift check，再按阶段实施。这个计划同时定义后端头像契约和客户端落地边界；当前仓库只包含 Flutter 客户端，后端接口/数据库变更必须由后端仓库的执行者完成并提供可验证的响应样例。每个阶段完成后运行对应的 focused tests。若头像接口仍只有 `avatar_url/faceUrl` 且无法提供稳定的 `thumbUrl`，客户端不得通过无条件字符串替换宣称已完成，必须停在契约阻塞/观测阶段并报告。

## Status

- **Priority**: P1
- **Effort**: L（后端契约 + 客户端缓存/预热 + 真机验证）
- **Risk**: MED（涉及公共资料接口、图片缓存身份、滚动热路径和账号切换；不改变会话排序、消息来源或列表虚拟化语义）
- **Depends on**: Plan 115 的全局头像双变体契约先落地；后端稳定提供 `thumbUrl`/`previewUrl`/版本，客户端普通展示不得回退到 preview
- **Category**: perf / UX / architecture / API contract
- **Planned at**: commit `9f7c46e`, 2026-08-26
- **Status**: TODO

## Why this matters

首页会话列表的虚拟行已经按滚动方向预测会话水合，但头像没有跟随同一预测窗口提前下载和解码，所以新行进入可见区时仍可能先显示默认头像。当前客户端的 `CachedNetworkImage` 已能按目标像素写入 resized 磁盘文件，但 UI 和 `AvatarImageWarm` 没有共享同一个 provider/cache key/磁盘尺寸，预热不一定命中首帧。

头像来源还存在一个后端契约缺口：`users.avatar_url`、腾讯云 IM `faceUrl` 和现有会话/好友快照主要保存 `_preview.jpg`；上传接口的 `thumbUrl` 只在上传响应中出现，后续用户资料与会话接口没有暴露它。产品规格已经明确：所有非全屏头像展示只使用 `_thumb.jpg`（200×200，约 9KB）；`_preview.jpg`（长边 ≤ 750px，约 57KB）只能在用户进入全屏头像预览后请求；`_origin.jpg`（约 69KB）不得进入普通头像 UI。完成后，滚动中预热的应是同一份 thumb/目标尺寸派生位图，首帧直接命中真实头像；thumb 缺失时显示默认头像并上报契约缺口，不得静默下载 preview。

## Current state

### Avatar source chain

- `lib/utils/conversation_face_url.dart:16-72` 是会话行的同步来源选择器。群聊优先 `GroupLocalStore.readCached().avatarUrl`，再用 REST 群资料/会话快照；单聊依次考虑官方账号覆盖、本地 `UserProfileLocalService`、会话 `faceUrl` 和好友列表 `faceUrl`。这些字段目前都是单个 URL，没有独立 thumb 字段。
- `lib/src/services/conversation_local/conversation_local_store.dart` 持久化会话 `face_url`；`lib/src/services/user_profile_local/user_profile_local_service.dart`/`user_profile_local_store.dart` 持久化单个 `avatar_url`；`lib/src/services/group_local/group_local_store.dart` 持久化单个群 `avatarUrl`。
- `lib/src/api/auth_api.dart:393-425` 的 `MeResult` 只有 `avatarUrl`；`lib/src/models/user_profile_record.dart:8-25,51-93` 只有 `avatarUrl`，没有 `thumbUrl`/版本字段。`UserApi` 的搜索/用户模型同样只暴露单个头像 URL。
- `lib/src/api/upload_api.dart:153-175` 的用户上传响应已经解析 `originUrl`、`previewUrl`、`thumbUrl`，并按 thumb/preview/avatar/url 顺序把 `avatarUrl` 设为第一可用值。`lib/src/api/upload_api.dart:178-208` 的群上传要求 `thumbUrl` 非空，并把它作为 `GroupAvatarUploadResult.thumbUrl` 返回。
- `lib/src/my_profile_detail.dart:574-581` 上传成功后只把 `result.avatarUrl` 写入用户资料/IM；这在新上传时通常已经是 thumb，但刷新资料或另一设备登录后会退回后端保存的 preview。
- `lib/src/group_info_detail.dart:74-105` 和 `lib/src/create_group.dart:305-319` 会把群上传结果的 `thumbUrl` 写回群资料/会话；同样无法补齐历史记录和跨设备获取路径。

### Rendering and cache

- `lib/src/widgets/app_user_avatar.dart:106-184` 始终挂载本地默认头像层并叠加 `AppNetworkImage`。它通过 `ImageMemCacheSize` 计算逻辑尺寸 × DPR，传入 `memCacheWidth/Height` 与 `maxWidthDiskCache/maxHeightDiskCache`，并使用零 fade 和 gapless playback。
- `lib/src/widgets/app_network_image.dart:96-117` 把 URL、cache key 和磁盘尺寸转给 `CachedNetworkImage`。
- `cached_network_image` 3.3.1 + `flutter_cache_manager` 3.3.1 已会生成 `resized_w<width>_h<height>_<key>` 形式的派生磁盘文件（`flutter_cache_manager/.../image_cache_manager.dart:11-41`）。因此当前不是“完全没有派生缓存”，而是没有头像专用 namespace、稳定资源身份和可控容量/失效策略。
- `DefaultCacheManager` 的默认配置是 30 天、最多 200 个对象；头像源文件/多尺寸派生还会与其它网络图片竞争。头像需要独立但有界的缓存，不应继续挤占同一通用对象上限。
- `lib/utils/avatar_image_warm.dart:13-96` 最多预热 24 个 resolved URL，Web 跳过，使用 `ResizeImage(CachedNetworkImageProvider(url))`；它没有传 UI 的显式 `cacheKey` 或 `maxWidthDiskCache/maxHeightDiskCache`。预热可能成功下载/解码，但可见 `AppUserAvatar` 仍查另一个 provider key。
- `lib/src/conversation.dart:1524-1585` 已从 feed pixels 得出 `scrollingDown/scrollingUp`；`:1667-1726` 在滚动中把虚拟水合中心向前偏 4–12 行，但只水合会话记录，没有头像图片预取。
- `lib/src/widgets/conversation_feed/conversation_feed_body.dart:1148-1171` 使用固定 `itemExtent` 与 `ConversationPerfFlags.conversationFeedCacheExtent`。`lib/src/services/android_performance_profile.dart:110-142` 只给 120/140/160px 行缓存范围。不要把增大 row `cacheExtent` 当头像主修复，因为它还会构建/布局行，可能回退低端机滚动性能。
- `lib/src/conversation.dart:4398-4544` 的缓存预览 fallback feed 也会构建 `AppUserAvatar`；descriptor 解析必须覆盖正常虚拟 feed 与此路径。

### Verified image-size evidence

- `lib/src/services/avatar_upload_util.dart:7-16,95-179` 已把上传输入限制到约 640px 长边和 220KB，原始上传成本已有上限。
- 仓库日志中大量头像 URL 以 `_preview.jpg` 结尾；一个头像传输样本约 18KB payload / 20KB processed bytes（`docs/控制台输出.md:42`）。这证明 preview 资产在使用，但不证明客户端能在后续资料读取中得到 thumb。
- 本计划采用用户确认的产品契约：会话行 steady-state 只使用 `_thumb.jpg` 200×200、约 9KB；`_preview.jpg` 只允许在用户明确进入全屏头像预览后请求，普通展示绝不把它作为兼容回退。代码、日志和测试不得复制私有用户 ID、完整 CDN URL 或 token。

## Backend contract (hard prerequisite)

后端/API 仓库必须先完成以下契约，才能宣称会话列表稳定使用 thumb：

1. 推荐在现有 `avatar_url` 旁新增 nullable `thumb_url`，不要原地把 profile/detail 所需的 preview 语义改掉。服务端生成 200×200 thumb（明确 square crop/fit 规则），并与同一次头像上传使用相同 revision/object identity。
2. 所有可能进入会话行的响应都返回 `thumbUrl`，并尽量返回 opaque `avatarVersion` 或稳定 object key：`/me`、用户 lookup/search/profile、好友列表、群列表/群详情、会话列表 projection、资料实时变更 payload。不能只在 `AvatarUpdateResult` 返回一次。
3. 上传返回 `originUrl`、`previewUrl`、`thumbUrl` 和稳定 revision；资料变更传播也要携带 thumb 或可查询该 thumb 的 revision。
4. 回填历史行。老对象暂时无法生成 thumb 时，明确返回 `thumbUrl: null` 并保留 preview 供全屏使用；普通展示必须回到默认头像，不得把 preview 当兼容图片，也不得把一个可能 404 的推测 URL 作为唯一头像。
5. 后端契约测试必须证明：上传后再次读取 `/me`/用户资料仍有 thumb；preview-only 历史记录按迁移状态返回 nullable thumb；群/C2C 字段名一致；头像更新会产生新 revision 并使旧 thumb 失效。

**过渡方案**：若暂时不能加数据库字段，API 可依据已验证的 object-key 规则派生并返回 `thumbUrl`。派生必须在服务端完成、验证对象存在，并有契约测试；客户端不得永久盲替换 `_preview.jpg` 为 `_thumb.jpg`。

## Product and technical decisions

| Decision | Value |
|----------|-------|
| List source priority | `thumbUrl` → 本地默认头像。会话行不得请求 preview/origin；thumb 缺失/失败必须计数。 |
| Provider identity | UI 与 prefetch 构建同一 immutable descriptor：资源身份/revision、选中的 source URL、目标像素 bucket、账号/鉴权 scope。 |
| Target size | `conversationFeedAvatarSize(context) × DPR`，复用 `ImageMemCacheSize` 的 round/cap；桌面/移动端可有不同 bucket。 |
| Prefetch window | 只做图片，按方向有界；从现有虚拟水合 lead（4–12 行）起步，再按 Profile 数据调节。 |
| Scroll scheduling | 以 center index/step 和方向变化节流，不按每个 pixel 发任务；tab/account/generation 变化时取消或 stale-drop。 |
| Cold miss | decoded cache 已 primed 时第一合成帧画真实 thumb；否则保留默认层并仅异步请求 thumb。禁止 UI isolate 同步解码或网络请求 preview。 |
| Cache ownership | 可见行和预热共用一个头像 provider/cache path；不得让同一源以不同 key 重复下载。 |
| Web | 保持 HTML `<img>`/CORS 分支，不强行在 Web 调 Flutter `precacheImage`。 |

## Scope

**In scope (client after backend contract)**

- `lib/src/api/auth_api.dart`, `lib/src/api/user_api.dart` 及相关 user/group response models：解析 optional `thumbUrl`/`avatarVersion`，兼容 preview-only payload。
- `lib/src/models/user_profile_record.dart`、conversation/group local records/stores：让离线行可持久保存 thumb/revision。
- `lib/utils/conversation_face_url.dart`, `lib/utils/user_avatar.dart`：提供 typed/immutable avatar descriptor 或等价选择结果，保持现有资料来源优先级。
- `lib/src/widgets/app_user_avatar.dart`, `lib/src/widgets/app_network_image.dart`：消费统一 descriptor/provider 和精确目标尺寸 key。
- `lib/utils/avatar_image_warm.dart` 及一个新的 avatar cache/prefetch coordinator（放 `lib/utils/` 或 `lib/src/services/`）：统一 provider、cache key、队列、generation 与指标。
- `lib/src/conversation.dart`, `lib/src/widgets/conversation_feed/conversation_feed_body.dart`, `lib/src/services/android_performance_profile.dart`, `lib/src/services/conversation_local/conversation_perf_flags.dart`：把图片预热接到现有方向/中心/step 信号并定义设备档预算。
- Focused tests under `test/`，诊断只记录脱敏/哈希身份。

**Out of scope**

- 重写 conversation virtual list、修改 `itemExtent`、移除稳定 row key，或在无 Profile 证据时增大 `conversationFeedCacheExtent`。
- 修改腾讯 IM 消息/历史来源、排序、未读、群成员关系或头像上传压缩质量。
- 把客户端无条件 suffix replacement 当正式后端契约。
- 预取 origin、把 full preview 解码进 ImageCache，或提高全局 image-cache 上限掩盖 miss。
- Web CORS 配置和后端数据库 migration 的实际代码（这是后端仓库单独变更）。

## Git workflow

- Branch: `codex/114-conversation-avatar-first-frame-cache`
- Commit style: `perf: ...` / `fix: ...`
- 本计划本身不授权 commit、push 或 PR。

## Steps

### Step 0: Drift check and contract gate

1. Run:

   ```sh
   git diff --stat 9f7c46e..HEAD -- \
     lib/src/api/auth_api.dart lib/src/api/user_api.dart \
     lib/src/api/upload_api.dart lib/src/models/user_profile_record.dart \
     lib/utils/conversation_face_url.dart lib/utils/user_avatar.dart \
     lib/src/widgets/app_user_avatar.dart lib/src/widgets/app_network_image.dart \
     lib/utils/avatar_image_warm.dart lib/src/conversation.dart \
     lib/src/widgets/conversation_feed/conversation_feed_body.dart
   ```

2. 保存脱敏 fixture：`/me`、用户 lookup、好友/群列表项、会话列表项、头像更新响应。逐项标明 `thumbUrl` 是否存在，以及实际 variant 是 thumb/preview/其它。
3. 后端没有稳定 thumb/revision 时 STOP。允许继续做 characterization/placeholder 测试，但不允许完成“steady-state thumb”验收。

**Verify**: 已审查 drift；fixture 无 token/私有 ID；每个来源都有明确 thumb/preview/missing 结论。

### Step 1: Add avatar descriptor and source selection

1. 新增小型 immutable display descriptor（或匹配现有 value-object 模式），至少包含 owner kind/id、稳定 revision/object key、`thumbUrl` 和 target pixels；preview 不进入会话行 descriptor。
2. API/local models 保存 optional thumb/revision。SQLite migration 必须 additive，旧行仍能读取，不能清空 `avatar_url`。
3. `ConversationFaceUrl`/`UserAvatarHelper` 对列表用途先选既有资料 authority，再在该 authority 内只选 thumb。保留群本地库、官方账号、本地用户资料、conversation snapshot、好友列表的原优先级。
4. preview-only 行明确走默认头像并计数。除非服务端明确提供且验证过，不在客户端猜 thumb suffix；普通展示严禁 preview fallback。

**Verify**:

```sh
flutter test \
  test/group_display_resolver_test.dart \
  test/conversation_c2c_show_name_prefer_test.dart \
  test/chat_header_avatar_stability_test.dart \
  test/user_profile_open_avatar_stability_test.dart
```

Expected: 原资料 authority/placeholder 行为保持；新增 descriptor 测试覆盖 thumb、preview-only、missing、revision change。

### Step 2: Unify visible provider and target-size derivative cache

1. 建立一个同时供 `AppUserAvatar` 和 `AvatarImageWarm` 使用的 provider factory。两边必须传同一 selected URL、stable `cacheKey`、headers、`memCacheWidth/Height`、`maxWidthDiskCache/maxHeightDiskCache`。
2. 使用 versioned key，例如 `avatar-v1|kind|resourceId|revision|variant|pixels`；对不可信 URL 材料做 hash/escape。有 stable resource/revision 时，不以易变 signed URL 作为唯一身份。
3. 复用 `flutter_cache_manager` 的 resize 能力，但给头像单独的 manager/key namespace 和有界对象/TTL（若采用自定义 byte cap，也必须可测试）。可见 widget 和 prefetch 必须共用它，不能保留同一行的旧 default-manager 旁路。
4. 网络源保持 thumb。target-size derivative 是 decode/disk reuse，不是同时下载 thumb 与 preview。thumb 失败时保留默认头像并记录失败，普通展示不得 promotion 到 preview。
5. 添加脱敏指标：provider memory hit、target-file hit、source network、fallback、decoded pixels、first-visible-frame placeholder count。

**Verify**:

```sh
flutter test \
  test/avatar_image_cache_key_test.dart \
  test/avatar_image_provider_contract_test.dart \
  test/app_user_avatar_cache_test.dart
```

Expected: 预热 descriptor 与 `AppUserAvatar` 解析为完全相同 provider key/尺寸；revision/pixel 改变会换 key；多个相同行 dedupe 一个 in-flight download。

### Step 3: Attach direction-aware scroll prediction

1. 复用 `_onFeedScroll` 的 `scrollingDown/scrollingUp` 与 `_requestVirtualHydrateForFeedScroll` 的 center/lead 计算，不新增第二个 per-pixel listener。
2. 在现有 center-step throttle 放行后，从 `ConversationListNotifier.conversationAtTypeIndex`（非虚拟/fallback feed 用当前 hydrated rows）取行进方向上的有界 descriptor。按 resource/revision 去重，不按 row index。
3. 只入队图片工作。为 low/medium/normal 定义 look-ahead rows、最大并发、目标字节和 TTL；低档可以关闭/减小预测，visible row 始终高优先级。
4. 方向反转、feed scope/tab、account/session generation、avatar revision 或 dispose 变化时取消 pending 或 stale-drop。旧任务不得给当前不同 feed `setState`。
5. scroll-end 保留一个安全 warm pass，但不 await paint，也不复用昂贵的 chat-history warm 做每个头像。

**Verify**:

```sh
flutter test \
  test/conversation_feed_avatar_prefetch_test.dart \
  test/conversation_virtual_index_cache_test.dart \
  test/conversation_feed_scroll_lifecycle_test.dart \
  test/android_performance_profile_test.dart
```

Expected: 上/下方向选择正确、队列有界、反向 stale-drop、低档预算更小；无新增滚动 listener 或无界 Future 列表。

### Step 4: First-frame and failure policy

1. 保留 `AppUserAvatar` 固定尺寸 default layer 作为真冷/失败 fallback；decoded thumb 已 primed 时必须零 fade 在第一合成帧覆盖它。
2. 不等待 disk/network，不在 UI isolate 同步 decode preview/origin。thumb miss 继续保留 default layer 并记原因；只有显式全屏预览入口可以另行请求 preview。
3. URL/revision 改变时不得短暂显示另一 owner 的旧头像。`useOldImageOnUrlChange` 只可用于同一 owner 的 revision 更新。
4. Web 保持 HTML `<img>` 分支，不进入 native prewarm/cache manager。

**Verify**:

```sh
flutter test \
  test/avatar_first_frame_contract_test.dart \
  test/chat_header_avatar_stability_test.dart \
  test/user_profile_open_avatar_stability_test.dart
```

Expected: primed cache 没有 placeholder first-frame event；cold failure 不阻塞滚动、不请求 origin；owner/revision 不串图。

### Step 5: Account/session invalidation and profile validation

1. 明确公共头像 cache 是否能跨账号复用。带账号授权的请求必须把 account scope 纳入 descriptor/cache namespace；公共 OSS thumb 可按稳定 resource identity 复用。
2. 账号注销/删除只按需清 avatar namespace，不清全局 Flutter image cache 或消息媒体；保持 `LocalAccountDataPurge` owner 语义。
3. 记录脱敏 source distribution（thumb/missing/invalid）、bytes、hit rate、decode latency、queue depth、first-visible-frame placeholder count；普通展示出现 preview/origin 请求视为契约违规。
4. 真机 Profile matrix：低/中/正常 Android + iOS；cold install、warm reopen、双向快甩、方向反转、1k+ conversations、group/C2C tab、账号切换、另一设备换头像、offline/slow network、Web。

**Verify**:

```sh
flutter analyze \
  lib/src/api/auth_api.dart lib/src/api/user_api.dart \
  lib/src/models/user_profile_record.dart lib/utils/conversation_face_url.dart \
  lib/utils/user_avatar.dart lib/src/widgets/app_user_avatar.dart \
  lib/src/widgets/app_network_image.dart lib/utils/avatar_image_warm.dart \
  lib/src/conversation.dart lib/src/widgets/conversation_feed/conversation_feed_body.dart
```

Expected: analyzer 0；Profile 显示 thumb 是 steady-state source、prefetch 有界、origin row request 为 0；first-visible placeholder 下降且 scroll FPS/decoded memory/network concurrency 不回退。

## Test plan

沿用 `test/conversation_virtual_index_cache_test.dart`、`test/conversation_feed_scroll_lifecycle_test.dart`、`test/android_performance_profile_test.dart`、`test/chat_header_avatar_stability_test.dart` 的 pure-policy/fake-provider 模式，覆盖：

- API/model 解析 optional thumb/revision 并兼容 preview-only。
- descriptor 的普通展示 thumb→placeholder，群/用户 authority 和官方账号优先级不变；preview 只由全屏入口选择。
- UI/warm cache key 完全相等；resource/revision/variant/pixel bucket 改变不碰撞。
- 重复行只一次 download；方向预测索引正确且服从 tier/并发/byte budget。
- 方向反转、tab/account、revision、dispose stale-drop。
- primed thumb 首帧真实头像；cold failure 不阻塞且永不请求 preview/origin。
- Web 不调用 Flutter prewarm；账号失效只清头像 namespace。

图片测试使用 fake cache manager/file service 或 in-memory provider；不依赖私有 CDN/完整日志 URL。

## Done criteria

- [ ] 后端契约测试证明上传后及后续 `/me`、user、friend/group、conversation、realtime profile 路径均能返回稳定 `thumbUrl`/revision；历史 preview-only 行兼容。
- [ ] Client 在 user/group/conversation local projection 中保存/传播 optional thumb/revision。
- [ ] `AppUserAvatar` 与 scroll prefetch 共用一个 provider factory、stable key 和 bounded target-size avatar namespace。
- [ ] 会话行网络源只允许 `_thumb.jpg`；`_preview.jpg`/`_origin.jpg` row request 均为 0，缺少 thumb 时显示默认头像并产生可观测契约错误。
- [ ] Direction-aware prefetch 有界、节流、可取消/stale-safe，并复用现有 virtual-feed center/step。
- [ ] Focused tests/analyzer 通过；Profile matrix 记录 placeholder、network bytes、decoded pixels、memory 和 scroll FPS。
- [ ] Backend 是独立 reviewed change；client 不修改 scope 外消息/会话语义；`plans/README.md` 状态已更新。

## STOP conditions

- 后端无法在后续资料/会话读取中返回稳定 thumb/revision，或迁移要求客户端猜 object key。
- 普通展示 descriptor 会下载 preview/origin，或 warm/UI 仍产生不同 provider key。
- 只能靠阻塞首帧、同步大图 decode、关闭 virtualization、提高全局 ImageCache 才能满足观感。
- 预测队列无界、增加滚动时 SQLite/SDK fanout，或低档机掉帧。
- revision/account switch 会串头像，或 logout 清掉无关消息媒体。
- 消息排序、未读、会话排序、群资料、Web CORS 或上传 byte 行为发生 scope 外变化。
- Focused tests/analyzer 连续两次 scoped 修复后仍失败；STOP 并报告，不弱化断言。

## Maintenance notes

- 后续头像 API 变更必须同步更新 variant/revision contract tests；不得新增绕过 descriptor 的 raw `faceUrl` 会话行消费者。
- row size/DPR bucket 改变时复核 cache object/byte budget，避免每种像素产生无限派生。
- 上线后监控 thumb missing/invalid。它升高表示后端传播/回填不完整，不应靠 preview fallback 或扩大客户端预热掩盖。
- preview 只保留在全屏预览 descriptor 中；普通展示在所有迁移阶段都不得读取它。
