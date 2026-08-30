import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/platform/listener_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/account_session_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_local/conversation_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/conversation_unread_clear_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_contact_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/friend_local/friend_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_entity_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_member_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_local/group_membership_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_notice_incremental_sync_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_session_cache.dart';
import 'package:tencent_cloud_chat_demo/src/services/local_account_data_purge.dart';
import 'package:tencent_cloud_chat_demo/src/services/local_message_overlay_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/native_post_home_bootstrap_queue.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/display_name_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/services/group_member_store.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_conversation_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_friendship_view_model.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_search_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';

/// 登录态写入与登录流程保护（verify / 直接 OK 共用）。
class AuthSessionService {
  AuthSessionService._();

  static final AuthSessionService instance = AuthSessionService._();

  int _authFlowDepth = 0;

  bool get isInAuthFlow => _authFlowDepth > 0;

  void enterAuthFlow() {
    _authFlowDepth++;
    ApiClient.instance.setSuppressAuthExpired(true);
  }

  void leaveAuthFlow() {
    if (_authFlowDepth > 0) {
      _authFlowDepth--;
    }
    if (_authFlowDepth == 0) {
      ApiClient.instance.setSuppressAuthExpired(false);
    }
  }

  void resetAuthFlow() {
    _authFlowDepth = 0;
    ApiClient.instance.setSuppressAuthExpired(false);
  }

  /// 开始密码/短信登录前：清内存 token，避免拦截器带过期 JWT。
  /// 同时关闭旧 IM 实例并清理旧的 ImSessionCache，避免账号切换后误复用旧 userSig。
  /// 并清空全局搜索 / UIKit 会话通讯录缓存，避免串号本地结果。
  /// 登录成功后由调用方重新初始化 IM，并重新拉取当前账号数据。
  Future<void> beginLogin() async {
    await AccountSessionService.instance.waitForPendingClear();
    // Invalidate callbacks before resolving the old owner. The resolver may
    // need an async SDK/cache fallback, and account B must not inherit work
    // that completes during that interval.
    final previousOwnerFuture =
        SessionIdentityService.instance.resolveCurrentOwnerUserId();
    SessionIdentityService.instance.invalidate(reason: 'begin_login');
    ConversationUnreadClearService.clearSession();
    LocalMessageOverlayStore.instance.invalidateScope();
    final previousOwner = await previousOwnerFuture;
    NativePostHomeBootstrapQueue.instance.reset(reason: 'begin_login');
    await ApiClient.instance.ensureDeviceIdReady();
    await ListenerStore.beforeLogout();
    await AuthBootstrapService.instance
        .uninitializeImSdkForAccountBoundary(reason: 'begin_login');
    // A login switch can enter here without going through the explicit logout
    // button. Invalidate old projections first, then remove only that owner's
    // local rows before the new token/userSig is installed.
    await ConversationSyncService.instance.clearSession(
      ownerUserId: previousOwner,
    );
    await FriendSyncService.instance.clearSession();
    await FriendContactIncrementalSyncService.instance.clearSession();
    await GroupMembershipSyncService.instance.clearSession();
    await GroupEntityIncrementalSyncService.instance.clearSession();
    await GroupNoticeIncrementalSyncService.instance.clearSession();
    await GroupMemberIncrementalSyncService.instance.clearSession();
    if (previousOwner.isNotEmpty) {
      await LocalAccountDataPurge.instance.purgeOwnerDisk(previousOwner);
    }
    await ApiClient.instance.clearToken();
    if (previousOwner.isNotEmpty) {
      await ImSessionCache.instance.clearForUser(previousOwner);
    } else {
      await ImSessionCache.instance.clear();
    }
    DisplayNameStore.instance.clear(notify: false);
    GroupMemberStore.instance.clear(notify: false);
    LoginUserInfo.clearAllSessions();
    try {
      serviceLocator<TUISearchViewModel>().clearSession(notify: false);
    } catch (_) {}
    try {
      serviceLocator<TUIConversationViewModel>().clearData();
    } catch (_) {}
    try {
      serviceLocator<TUIFriendShipViewModel>().clearData();
    } catch (_) {}
  }

  /// verify 或直接 password OK 后：先同步更新内存 token，再持久化。
  static String normalizeToken(String raw) {
    var token = raw.trim();
    if (token.toLowerCase().startsWith('bearer ')) {
      token = token.substring(7).trim();
    }
    return token;
  }

  Future<void> applyTokenResult(TokenResult result) async {
    final token = normalizeToken(result.token);
    if (normalizeAuthNextStep(result.nextStep) != 'OK') {
      throw AuthSessionException('登录未完成，请重试');
    }
    if (!ApiClient.isValidJwt(token)) {
      throw AuthSessionException('登录令牌无效，请重新登录');
    }
    await ApiClient.instance.saveToken(token, userId: result.userId);
  }

  Future<void> applyPasswordLoginOk(PasswordLoginResult result) async {
    if (!result.isLoginOk) {
      throw AuthSessionException('登录未完成，请重试');
    }
    final token = normalizeToken(result.token ?? '');
    if (!ApiClient.isValidJwt(token)) {
      throw AuthSessionException('登录令牌无效，请重新登录');
    }
    await ApiClient.instance.saveToken(
      token,
      userId: result.userId,
    );
  }

  /// 保存 token 后拉取 /me 与 userSig（登录成功必经）。
  Future<UserSigResult> bootstrapAuthenticatedSession() async {
    final generation = SessionIdentityService.instance.generation;
    final results = await Future.wait<Object>([
      AuthApi.instance.fetchMe(),
      AuthApi.instance.fetchUserSig(),
    ]);
    final me = results[0] as MeResult;
    final sig = results[1] as UserSigResult;
    if (!SessionIdentityService.instance.isGenerationCurrent(generation)) {
      throw AuthSessionException('登录账号已切换，请重试');
    }
    if (sig.userId.trim().isEmpty ||
        sig.userSig.trim().isEmpty ||
        sig.sdkAppId <= 0) {
      throw AuthSessionException('获取 IM 凭证失败，请重试');
    }
    final currentToken = ApiClient.instance.token;
    final savedOwner =
        await ApiClient.instance.saveAuthenticatedUserIdIfCurrent(
      expectedToken: currentToken,
      userId: sig.userId.trim().isNotEmpty ? sig.userId : me.userId,
    );
    if (!savedOwner) {
      throw AuthSessionException('登录账号已切换，请重试');
    }
    if (!SessionIdentityService.instance.isGenerationCurrent(generation)) {
      throw AuthSessionException('登录账号已切换，请重试');
    }
    final cacheSaved = await ImSessionCache.instance.saveIfCurrent(
      sig,
      () => SessionIdentityService.instance.isGenerationCurrent(generation),
    );
    if (!cacheSaved) {
      throw AuthSessionException('登录账号已切换，请重试');
    }
    if (!SessionIdentityService.instance.isGenerationCurrent(generation)) {
      throw AuthSessionException('登录账号已切换，请重试');
    }
    return sig;
  }
}

class AuthSessionException implements Exception {
  AuthSessionException(this.message);
  final String message;

  @override
  String toString() => message;
}
