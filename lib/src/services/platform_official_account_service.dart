import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_pin_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_demo/utils/chat_id_format.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_conversation.dart';
import 'package:tencent_cloud_chat_sdk/enum/history_msg_get_type_enum.dart';
import 'package:tencent_cloud_chat_sdk/enum/receive_message_opt_enum.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/tencent_im_sdk_plugin.dart';

class _OfficialAccountDef {
  const _OfficialAccountDef({
    required this.userId,
    required this.defaultName,
    required this.fallbackFaceUrl,
  });

  final String userId;
  final String defaultName;
  final String fallbackFaceUrl;
}

class _CachedOfficialProfile {
  String? displayName;
  String? faceUrl;
  String? introduction;
}

/// 平台公众号（含伪装 IM 用户与腾讯云 @TOA#_ 运营号）。
class PlatformOfficialAccountService {
  PlatformOfficialAccountService._();

  static final Map<String, _CachedOfficialProfile> _profileByUserId = {};
  static String? _boundImUserId;
  static final Set<String> _dismissedOfficialIds = {};
  static bool _dismissedLoaded = false;
  static SessionIdentity? _ensureSubscribedIdentity;
  static Future<bool>? _ensureSubscribedFuture;
  static DateTime? _lastEnsureSubscribedAt;

  /// 资料拉取成功后递增，供会话列表刷新标题。
  static final ValueNotifier<int> infoRevision = ValueNotifier(0);

  static String _legacyDismissedPrefsKey(String imUserId) =>
      'platform_official_account_dismissed_$imUserId';

  static String _dismissedIdsPrefsKey(String imUserId) =>
      'platform_official_dismissed_ids_$imUserId';

  static List<_OfficialAccountDef> get _accountDefs {
    final list = <_OfficialAccountDef>[];
    final seen = <String>{};

    void addDef({
      required String userId,
      required String defaultName,
      required String fallbackFaceUrl,
    }) {
      final id = userId.trim();
      if (id.isEmpty || seen.contains(id)) {
        return;
      }
      seen.add(id);
      list.add(
        _OfficialAccountDef(
          userId: id,
          defaultName: defaultName.trim(),
          fallbackFaceUrl: fallbackFaceUrl.trim(),
        ),
      );
    }

    addDef(
      userId: IMDemoConfig.platformOfficialAccountId,
      defaultName: IMDemoConfig.platformOfficialAccountName,
      fallbackFaceUrl: IMDemoConfig.platformOfficialAccountFaceUrl,
    );
    addDef(
      userId: IMDemoConfig.systemWelcomeAccountId,
      defaultName: IMDemoConfig.systemWelcomeAccountName,
      fallbackFaceUrl: IMDemoConfig.systemWelcomeAccountFaceUrl,
    );
    addDef(
      userId: IMDemoConfig.cloudOfficialAccountId,
      defaultName: IMDemoConfig.cloudOfficialAccountName,
      fallbackFaceUrl: IMDemoConfig.cloudOfficialAccountFaceUrl,
    );
    return list;
  }

  /// `platform_wallet_notice` 发件 IM 账号（支付助手会话）。
  static String get walletNoticeAccountId =>
      IMDemoConfig.platformOfficialAccountId.trim();

  static bool isWalletNoticeOfficialAccount(String? userId) {
    final id = userId?.trim() ?? '';
    return id.isNotEmpty && id == walletNoticeAccountId;
  }

  /// 普通 IM 用户伪装的公众号（非腾讯云 `@TOA#_` 运营号）。
  static bool isPseudoOfficialAccount(String? userId) {
    final def = _defFor(userId);
    if (def == null) {
      return false;
    }
    return !def.userId.startsWith('@TOA#_');
  }

  static _OfficialAccountDef? _defFor(String? userId) {
    if (userId == null || userId.isEmpty) {
      return null;
    }
    final id = userId.trim();
    for (final def in _accountDefs) {
      if (def.userId == id) {
        return def;
      }
    }
    return null;
  }

  static _CachedOfficialProfile _profileFor(String userId) {
    return _profileByUserId.putIfAbsent(userId, _CachedOfficialProfile.new);
  }

  static Future<String?> _resolveImUserId() async {
    final res = await TencentImSDKPlugin.v2TIMManager.getLoginUser();
    final id = res.data?.trim() ?? '';
    return id.isNotEmpty ? id : null;
  }

  /// IM 已登录才允许 getUsersInfo / 好友库相关调用。
  static Future<bool> _isImLoggedIn() async {
    return (await _resolveImUserId()) != null;
  }

  /// 可安全传给 getUsersInfo 的 IM userID（排除「99Pay支付助手」这类昵称兼容项）。
  static bool _isFetchableImUserId(String? raw) {
    final id = raw?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    // 含汉字的是展示名兼容匹配项，不是 IM userID。
    if (RegExp(r'[\u4e00-\u9fff]').hasMatch(id)) {
      return false;
    }
    return true;
  }

  static List<String> _fetchableProfileUserIds([List<String>? userIds]) {
    final source = userIds ?? displayProfileUserIds;
    return source
        .map((e) => e.trim())
        .where(_isFetchableImUserId)
        .toList(growable: false);
  }

  static void resetSessionState() {
    _boundImUserId = null;
    _dismissedLoaded = false;
    _dismissedOfficialIds.clear();
    _profileByUserId.clear();
    _ensureSubscribedFuture = null;
    _ensureSubscribedIdentity = null;
    _lastEnsureSubscribedAt = null;
  }

  static Future<void> loadDismissedState({
    bool force = false,
    SessionIdentity? expectedIdentity,
  }) async {
    final identity =
        expectedIdentity ?? SessionIdentityService.instance.capture();
    if (!_isCurrent(identity)) return;
    final imUserId = await _resolveImUserId();
    if (!_isCurrent(identity) || !_sameOwner(imUserId, identity.ownerUserId)) {
      return;
    }
    if (imUserId == null) {
      _dismissedOfficialIds.clear();
      _dismissedLoaded = true;
      return;
    }
    if (!force && _dismissedLoaded && _boundImUserId == imUserId) {
      return;
    }
    _boundImUserId = imUserId;
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrent(identity) || !_sameOwner(imUserId, identity.ownerUserId)) {
      return;
    }
    _dismissedOfficialIds.clear();

    final legacyDismissed =
        prefs.getBool(_legacyDismissedPrefsKey(imUserId)) ?? false;
    if (legacyDismissed &&
        IMDemoConfig.platformOfficialAccountId.trim().isNotEmpty) {
      _dismissedOfficialIds.add(IMDemoConfig.platformOfficialAccountId.trim());
    }
    final stored = prefs.getStringList(_dismissedIdsPrefsKey(imUserId));
    if (stored != null) {
      _dismissedOfficialIds
          .addAll(stored.map((e) => e.trim()).where((e) => e.isNotEmpty));
    }

    _dismissedLoaded = true;
  }

  static Future<void> _persistDismissedState({
    SessionIdentity? expectedIdentity,
  }) async {
    final identity =
        expectedIdentity ?? SessionIdentityService.instance.capture();
    if (!_isCurrent(identity)) return;
    final imUserId = identity.ownerUserId;
    if (!_sameOwner(imUserId, identity.ownerUserId)) return;
    _boundImUserId = imUserId;
    final dismissed = _dismissedOfficialIds.toList(growable: false);
    final prefs = await SharedPreferences.getInstance();
    if (!_isCurrent(identity)) return;
    await prefs.setStringList(
      _dismissedIdsPrefsKey(imUserId),
      dismissed,
    );
    await prefs.setBool(_legacyDismissedPrefsKey(imUserId), false);
  }

  static bool isDismissedFromList(String? userId) {
    final id = userId?.trim() ?? '';
    return id.isNotEmpty && _dismissedOfficialIds.contains(id);
  }

  static bool shouldHideInConversationList(String? userId) {
    return isDismissedFromList(userId) && isPlatformOfficialAccount(userId);
  }

  static bool shouldHideConversation(V2TimConversation conversation) {
    final userId = _userIdFromConversation(conversation);
    return userId != null && shouldHideInConversationList(userId);
  }

  static String? _userIdFromConversation(V2TimConversation conversation) {
    final userId = conversation.userID?.trim() ?? '';
    if (userId.isNotEmpty) {
      return userId;
    }
    final conversationId = conversation.conversationID.trim();
    if (conversationId.startsWith('c2c_')) {
      return conversationId.substring(4);
    }
    return null;
  }

  static void reconcileDismissedWithSdkConversations(
    List<V2TimConversation> conversations,
  ) {
    if (_dismissedOfficialIds.isEmpty) {
      return;
    }
    var changed = false;
    for (final accountId in _dismissedOfficialIds.toList()) {
      V2TimConversation? match;
      for (final c in conversations) {
        if (_matchesAccount(c, accountId)) {
          match = c;
          break;
        }
      }
      if (match == null) {
        continue;
      }
      if (match.lastMessage != null || (match.unreadCount ?? 0) > 0) {
        _dismissedOfficialIds.remove(accountId);
        changed = true;
      }
    }
    if (changed) {
      infoRevision.value++;
    }
  }

  static Future<void> _undismissAccount(
    String accountId, {
    required SessionIdentity identity,
  }) async {
    if (!_dismissedOfficialIds.remove(accountId)) {
      return;
    }
    _dismissedLoaded = true;
    await _persistDismissedState(expectedIdentity: identity);
  }

  static Future<String?> ensureReadyForChat({String? userId}) async {
    final identity = SessionIdentityService.instance.capture();
    if (!_isCurrent(identity)) return null;
    final def = _defFor(userId);
    if (def == null) {
      return null;
    }
    await loadDismissedState(force: true, expectedIdentity: identity);
    if (!_isCurrent(identity)) return null;
    await _undismissAccount(def.userId, identity: identity);
    await _refreshCachedProfileWithRetry(
      attempts: 2,
      userIds: [def.userId],
      identity: identity,
    );
    if (!_isCurrent(identity)) return null;
    await _ensureNormalReceiveOpt(userIds: [def.userId], identity: identity);
    await _ensureNotPinned(userIds: [def.userId], identity: identity);
    return null;
  }

  static Future<void> dismissFromConversationList({String? userId}) async {
    final identity = SessionIdentityService.instance.capture();
    if (!_isCurrent(identity)) return;
    final def = _defFor(userId);
    if (def == null) {
      return;
    }
    _dismissedOfficialIds.add(def.userId);
    _dismissedLoaded = true;
    final imUserId = identity.ownerUserId;
    _boundImUserId = imUserId;
    await _persistDismissedState(expectedIdentity: identity);
    if (!_isCurrent(identity)) return;
    await TencentImSDKPlugin.v2TIMManager
        .getConversationManager()
        .deleteConversation(conversationID: 'c2c_${def.userId}');
    infoRevision.value++;
  }

  static bool get isConfigured => _accountDefs.isNotEmpty;

  /// 主通知号（兼容旧调用）。
  static String get officialAccountId =>
      _accountDefs.isNotEmpty ? _accountDefs.first.userId : '';

  static List<String> get officialAccountIds =>
      _accountDefs.map((e) => e.userId).toList(growable: false);

  static bool isPlatformOfficialAccount(String? userId) {
    return _defFor(userId) != null;
  }

  /// 含配置列表与 @TOA#_ 前缀腾讯云运营公众号。
  static bool isOfficialAccountUserId(String? userId) {
    if (isPlatformOfficialAccount(userId)) {
      return true;
    }
    final trimmed = userId?.trim() ?? '';
    return trimmed.startsWith('@TOA#_');
  }

  /// 认证账号（消息列表/聊天页恒在线 + V 徽章）。
  /// 优先匹配 IM userID；也可匹配会话展示名（兼容昵称与 userID 不一致）。
  static bool isVerifiedBadgeAccount(String? userId, {String? showName}) {
    final id = userId?.trim() ?? '';
    final name = showName?.trim() ?? '';
    for (final entry in IMDemoConfig.verifiedBadgeUserIds) {
      final key = entry.trim();
      if (key.isEmpty) {
        continue;
      }
      if (id.isNotEmpty && id == key) {
        return true;
      }
      if (name.isNotEmpty && name == key) {
        return true;
      }
    }
    return false;
  }

  /// 是否展示认证 V 徽章并按「认证」处理在线态：平台公众号 或 认证账号。
  static bool showsVerifiedBadge(String? userId, {String? showName}) {
    return isPlatformOfficialAccount(userId) ||
        isVerifiedBadgeAccount(userId, showName: showName);
  }

  static bool shouldHideFromContactAndPickers(String? userId) {
    if (isPlatformOfficialAccount(userId)) {
      return true;
    }
    final id = userId?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    return IMDemoConfig.hiddenPickerUserIds.contains(id);
  }

  static bool shouldHideConversationFromPickers(
    V2TimConversation? conversation,
  ) {
    if (conversation == null) {
      return false;
    }
    final userId = _userIdFromConversation(conversation);
    return userId != null && shouldHideFromContactAndPickers(userId);
  }

  static bool _matchesAccount(
      V2TimConversation conversation, String accountId) {
    if (conversation.userID?.trim() == accountId) {
      return true;
    }
    final conversationId = conversation.conversationID.trim();
    return conversationId == 'c2c_$accountId';
  }

  static bool matchesOfficialConversation(V2TimConversation conversation) {
    if (!isConfigured) {
      return false;
    }
    for (final def in _accountDefs) {
      if (_matchesAccount(conversation, def.userId)) {
        return true;
      }
    }
    return false;
  }

  static Future<List<V2TimMessage>> fetchChatHistoryMessages({
    String? userId,
    int count = 50,
  }) async {
    final def = _defFor(userId) ??
        (_accountDefs.isNotEmpty ? _accountDefs.first : null);
    if (def == null) {
      return const [];
    }
    final id = def.userId;
    final seen = <String>{};
    final merged = <V2TimMessage>[];

    void append(List<V2TimMessage>? list) {
      if (list == null) {
        return;
      }
      for (final msg in list) {
        final msgId = msg.msgID;
        if (msgId == null || msgId.isEmpty) {
          merged.add(msg);
          continue;
        }
        if (seen.add(msgId)) {
          merged.add(msg);
        }
      }
    }

    for (final getType in const [
      HistoryMsgGetTypeEnum.V2TIM_GET_LOCAL_OLDER_MSG,
      HistoryMsgGetTypeEnum.V2TIM_GET_CLOUD_OLDER_MSG,
    ]) {
      final res = await TencentImSDKPlugin.v2TIMManager
          .getMessageManager()
          .getHistoryMessageListV2(
            count: count,
            getType: getType,
            userID: id,
          );
      if (res.code == 0 && res.data != null) {
        append(res.data!.messageList);
      }
    }

    merged.sort((a, b) => (b.timestamp ?? 0).compareTo(a.timestamp ?? 0));
    return merged;
  }

  static bool shouldSuppressTUIKitError(int? code, String? message) {
    return false;
  }

  static String? introductionFor(String? userId) {
    final def = _defFor(userId);
    if (def == null) {
      return null;
    }
    final intro = _profileFor(def.userId).introduction?.trim() ?? '';
    return intro.isNotEmpty ? intro : null;
  }

  /// 兼容旧调用。
  static String? get messengerIntroduction =>
      introductionFor(officialAccountId);

  static String? get messengerFaceUrl => _profileFor(officialAccountId).faceUrl;

  static bool _isUsableFaceUrl(String? url) {
    final trimmed = url?.trim() ?? '';
    return trimmed.isNotEmpty &&
        !UserAvatarHelper.isDefaultPlaceholder(trimmed);
  }

  static String resolveFaceUrl({
    String? userId,
    String? conversationFaceUrl,
  }) {
    final def = _defFor(userId);
    if (def == null) {
      return conversationFaceUrl?.trim() ?? '';
    }
    if (isPseudoOfficialAccount(userId) && def.fallbackFaceUrl.isNotEmpty) {
      return def.fallbackFaceUrl;
    }
    final cache = _profileFor(def.userId);
    if (_isUsableFaceUrl(cache.faceUrl)) {
      return cache.faceUrl!.trim();
    }
    if (_isUsableFaceUrl(conversationFaceUrl)) {
      return conversationFaceUrl!.trim();
    }
    if (def.fallbackFaceUrl.isNotEmpty) {
      return def.fallbackFaceUrl;
    }
    return '';
  }

  /// 需要拉真实 IM 昵称/头像的账号：配置公众号 + 认证号 + 选人隐藏系统号。
  static List<String> get displayProfileUserIds {
    final out = <String>{};
    for (final id in officialAccountIds) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty) {
        out.add(trimmed);
      }
    }
    for (final id in IMDemoConfig.verifiedBadgeUserIds) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty) {
        out.add(trimmed);
      }
    }
    for (final id in IMDemoConfig.hiddenPickerUserIds) {
      final trimmed = id.trim();
      if (trimmed.isNotEmpty) {
        out.add(trimmed);
      }
    }
    return out.toList(growable: false);
  }

  /// 会话/标题展示优先走 IM 资料，不使用前端写死昵称。
  static bool prefersImProfileDisplayName(String? userId) {
    return isPlatformOfficialAccount(userId) ||
        isVerifiedBadgeAccount(userId) ||
        _isHiddenPickerSystemAccount(userId);
  }

  static bool _isHiddenPickerSystemAccount(String? userId) {
    final id = userId?.trim() ?? '';
    if (id.isEmpty) {
      return false;
    }
    return IMDemoConfig.hiddenPickerUserIds.contains(id);
  }

  static Future<bool> ensureSubscribed({bool force = false}) async {
    final identity = SessionIdentityService.instance.capture();
    if (!_isCurrent(identity)) return false;
    // 冷启动 / 会话页 init 可能早于 IM Login；未登录绝不打 getUsersInfo。
    if (!await _isImLoggedIn() || !_isCurrent(identity)) {
      return false;
    }

    final ids = _fetchableProfileUserIds();
    if (ids.isEmpty) {
      return false;
    }

    final running = _ensureSubscribedFuture;
    if (!force && running != null && _ensureSubscribedIdentity == identity) {
      return running;
    }

    final last = _lastEnsureSubscribedAt;
    if (!force &&
        last != null &&
        DateTime.now().difference(last) < const Duration(seconds: 30)) {
      return true;
    }

    late final Future<bool> task;
    task = _doEnsureSubscribed(ids, identity).whenComplete(() {
      if (identical(_ensureSubscribedFuture, task)) {
        _ensureSubscribedFuture = null;
        _ensureSubscribedIdentity = null;
      }
    });
    _ensureSubscribedIdentity = identity;
    _ensureSubscribedFuture = task;
    return task;
  }

  static Future<bool> _doEnsureSubscribed(
    List<String> ids,
    SessionIdentity identity,
  ) async {
    if (!await _isImLoggedIn() || !_isCurrent(identity)) {
      return false;
    }
    await loadDismissedState(force: true, expectedIdentity: identity);
    try {
      await _refreshCachedProfileWithRetry(
        attempts: 3,
        userIds: ids,
        identity: identity,
      );
      if (!_isCurrent(identity)) return false;
      // 免打扰/取消置顶仅对配置的平台公众号生效。
      final officialIds = officialAccountIds;
      if (officialIds.isNotEmpty) {
        await _ensureNormalReceiveOpt(
          userIds: officialIds,
          identity: identity,
        );
        await _ensureNotPinned(userIds: officialIds, identity: identity);
      }
      if (!_isCurrent(identity)) return false;
      _lastEnsureSubscribedAt = DateTime.now();
      return true;
    } finally {
      if (_isCurrent(identity)) infoRevision.value++;
    }
  }

  static Future<void> _ensureNormalReceiveOpt({
    required List<String> userIds,
    required SessionIdentity identity,
  }) async {
    if (userIds.isEmpty || !_isCurrent(identity)) {
      return;
    }
    final res = await TencentImSDKPlugin.v2TIMManager
        .getMessageManager()
        .setC2CReceiveMessageOpt(
          userIDList: userIds,
          opt: ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE,
        );
    if (res.code != 0) {
      return;
    }
  }

  static Future<void> _ensureNotPinned({
    required List<String> userIds,
    required SessionIdentity identity,
  }) async {
    for (final id in userIds) {
      if (!_isCurrent(identity)) return;
      final uid = id.trim();
      if (uid.isEmpty) {
        continue;
      }
      try {
        final snapshot = ConversationPinService.c2cConversationSnapshot(
          userID: uid,
        );
        await ConversationPinSyncService.instance.setPinned(
          conversation: snapshot,
          pinned: false,
          source: 'official_account_ensure_not_pinned',
        );
      } catch (e) {
        debugPrint(
          'PlatformOfficialAccount: ensureNotPinned failed user=$uid error=$e',
        );
      }
    }
  }

  static String _listInjectionDisplayName(_OfficialAccountDef def) {
    return resolveShowName(userId: def.userId);
  }

  static Future<void> _refreshCachedProfile({
    List<String>? userIds,
    required SessionIdentity identity,
  }) async {
    if (!await _isImLoggedIn() || !_isCurrent(identity)) {
      return;
    }
    final ids = _fetchableProfileUserIds(userIds);
    if (ids.isEmpty) {
      return;
    }
    final res = await TencentImSDKPlugin.v2TIMManager.getUsersInfo(
      userIDList: ids,
    );
    if (!_isCurrent(identity)) return;
    if (res.code != 0 || res.data == null || res.data!.isEmpty) {
      return;
    }
    for (final user in res.data!) {
      final id = user.userID?.trim() ?? '';
      if (id.isEmpty || !prefersImProfileDisplayName(id)) {
        continue;
      }
      final cache = _profileFor(id);
      // 只用 IM 真实 nickName，不用 config 默认名。
      final name = user.nickName?.trim() ?? '';
      final face = user.faceUrl?.trim() ?? '';
      final intro = user.selfSignature?.trim() ?? '';
      var changed = false;
      if (cache.displayName != name) {
        cache.displayName = name;
        changed = true;
      }
      if (cache.faceUrl != face) {
        cache.faceUrl = face;
        changed = true;
      }
      if (cache.introduction != intro) {
        cache.introduction = intro;
        changed = true;
      }
      if (changed) {
        infoRevision.value++;
      }
    }
  }

  static bool _hasUsableCachedProfile(String userId) {
    final cache = _profileFor(userId);
    final name = cache.displayName?.trim() ?? '';
    return name.isNotEmpty && _isUsableFaceUrl(cache.faceUrl);
  }

  static Future<void> _refreshCachedProfileWithRetry({
    int attempts = 5,
    List<String>? userIds,
    required SessionIdentity identity,
  }) async {
    final ids = _fetchableProfileUserIds(userIds ?? officialAccountIds);
    if (ids.isEmpty) {
      return;
    }
    for (var i = 0; i < attempts; i++) {
      if (!await _isImLoggedIn() || !_isCurrent(identity)) {
        return;
      }
      await _refreshCachedProfile(userIds: ids, identity: identity);
      final allReady = ids.every(_hasUsableCachedProfile);
      if (allReady) {
        return;
      }
      if (i < attempts - 1) {
        await Future<void>.delayed(Duration(milliseconds: 250 * (i + 1)));
      }
    }
  }

  static bool _isCurrent(SessionIdentity identity) {
    return identity.ownerUserId.isNotEmpty &&
        SessionIdentityService.instance.isCurrent(identity);
  }

  static bool _sameOwner(String? left, String? right) {
    final a = ChatIdFormat.rawUserUid(left);
    final b = ChatIdFormat.rawUserUid(right);
    return a.isNotEmpty && a == b;
  }

  /// 展示名：IM 昵称缓存 > 会话 showName（SDK）> userID。
  /// 不使用 [IMDemoConfig] 里的默认昵称字符串。
  static String resolveShowName({
    String? userId,
    String? conversationShowName,
  }) {
    final id = userId?.trim() ?? '';
    if (id.isNotEmpty) {
      final cached = _profileFor(id).displayName?.trim() ?? '';
      if (cached.isNotEmpty) {
        return cached;
      }
    }
    final fromConversation = conversationShowName?.trim() ?? '';
    if (fromConversation.isNotEmpty) {
      return fromConversation;
    }
    return id;
  }

  static V2TimConversation buildConversation({
    required String userId,
    String? showName,
    String? faceUrl,
  }) {
    final def = _defFor(userId);
    if (def == null) {
      throw ArgumentError('Not a platform official account: $userId');
    }
    final resolvedName = resolveShowName(
      userId: def.userId,
      conversationShowName: showName,
    );
    return V2TimConversation(
      conversationID: 'c2c_${def.userId}',
      userID: def.userId,
      type: 1,
      showName: resolvedName,
      faceUrl: resolveFaceUrl(userId: def.userId, conversationFaceUrl: faceUrl),
      isPinned: false,
      recvOpt: ReceiveMsgOptEnum.V2TIM_RECEIVE_MESSAGE.index,
    );
  }

  static List<V2TimConversation> conversationsIfMissingFrom(
    List<V2TimConversation> conversations,
  ) {
    if (!isConfigured) {
      return const [];
    }
    final injected = <V2TimConversation>[];
    for (final def in _accountDefs) {
      if (_dismissedOfficialIds.contains(def.userId)) {
        continue;
      }
      final exists = conversations.any((c) => _matchesAccount(c, def.userId));
      if (exists) {
        continue;
      }
      injected.add(
        buildConversation(
          userId: def.userId,
          showName: _listInjectionDisplayName(def),
          faceUrl: resolveFaceUrl(userId: def.userId),
        ),
      );
    }
    return injected;
  }

  /// 兼容旧调用：返回第一个缺失的公众号会话。
  static V2TimConversation? conversationIfMissingFrom(
    List<V2TimConversation> conversations,
  ) {
    final list = conversationsIfMissingFrom(conversations);
    return list.isEmpty ? null : list.first;
  }
}
