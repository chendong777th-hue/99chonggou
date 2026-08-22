import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/platform/listener_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_session_cache.dart';
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
  /// 同时清理旧的 ImSessionCache，避免账号切换后误复用旧 userSig。
  /// 并清空全局搜索 / UIKit 会话通讯录缓存，避免串号本地结果。
  /// 不在此处 IM logout，否则会把已在线会话踢下线并拖慢/阻断进首页。
  Future<void> beginLogin() async {
    await ApiClient.instance.ensureDeviceIdReady();
    await ListenerStore.beforeLogout();
    await ApiClient.instance.clearToken();
    await ImSessionCache.instance.clear();
    DisplayNameStore.instance.clear(notify: false);
    GroupMemberStore.instance.clear(notify: false);
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
    await ApiClient.instance.saveToken(token);
  }

  Future<void> applyPasswordLoginOk(PasswordLoginResult result) async {
    if (!result.isLoginOk) {
      throw AuthSessionException('登录未完成，请重试');
    }
    final token = normalizeToken(result.token ?? '');
    if (!ApiClient.isValidJwt(token)) {
      throw AuthSessionException('登录令牌无效，请重新登录');
    }
    await ApiClient.instance.saveToken(token);
  }

  /// 保存 token 后拉取 /me 与 userSig（登录成功必经）。
  Future<UserSigResult> bootstrapAuthenticatedSession() async {
    await AuthApi.instance.fetchMe();
    final sig = await AuthApi.instance.fetchUserSig();
    if (sig.userSig.trim().isEmpty || sig.sdkAppId <= 0) {
      throw AuthSessionException('获取 IM 凭证失败，请重试');
    }
    await ImSessionCache.instance.save(sig);
    return sig;
  }
}

class AuthSessionException implements Exception {
  AuthSessionException(this.message);
  final String message;

  @override
  String toString() => message;
}
