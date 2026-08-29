// ignore_for_file: file_names

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/services/contact_social_cache_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/session_identity.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

class LoginUserInfo with ChangeNotifier {
  LoginUserInfo() {
    _instances.add(this);
  }

  static final Set<LoginUserInfo> _instances = <LoginUserInfo>{};
  V2TimUserFullInfo _loginUserInfo = V2TimUserFullInfo();
  final CoreServicesImpl _coreServices = TIMUIKitCore.getInstance();
  static final Set<String> _defaultAvatarSyncAttempted = <String>{};
  bool _settingDefaultAvatar = false;

  V2TimUserFullInfo get loginUserInfo {
    return _loginUserInfo;
  }

  static void clearAllSessions() {
    for (final instance in List<LoginUserInfo>.from(_instances)) {
      instance.clearSession();
    }
  }

  void clearSession() {
    _loginUserInfo = V2TimUserFullInfo();
    _settingDefaultAvatar = false;
    notifyListeners();
  }

  @override
  void dispose() {
    _instances.remove(this);
    super.dispose();
  }

  void setLoginUserInfo(V2TimUserFullInfo info) {
    final currentUserId = ContactSocialCacheStore.safeLoginUserId();
    final incomingUserId = (info.userID ?? '').trim();
    if (currentUserId.isNotEmpty &&
        incomingUserId.isNotEmpty &&
        currentUserId != incomingUserId) {
      return;
    }
    _loginUserInfo = info;
    if ((_loginUserInfo.faceUrl ?? '').trim().isEmpty) {
      setRandomAvatar();
    }
    notifyListeners();
  }

  Future<void> setRandomAvatar() async {
    if (_settingDefaultAvatar) {
      return;
    }
    final userId = (_loginUserInfo.userID ?? '').trim();
    final identity = SessionIdentityService.instance.capture(
      ownerUserId: userId,
    );
    if (userId.isEmpty ||
        !SessionIdentityService.instance.isCurrent(
          identity,
          currentOwnerUserId: userId,
        )) {
      return;
    }
    final key = userId.isNotEmpty ? userId : 'current_user';
    if (_defaultAvatarSyncAttempted.contains(key)) {
      return;
    }

    _settingDefaultAvatar = true;
    _defaultAvatarSyncAttempted.add(key);
    try {
      if (!SessionIdentityService.instance.isCurrent(identity)) {
        return;
      }
      const faceUrl = IMDemoConfig.defaultRegisterAvatarUrl;
      final userFullInfo = V2TimUserFullInfo(faceUrl: faceUrl);
      await _coreServices.setSelfInfo(userFullInfo: userFullInfo);
      if (!SessionIdentityService.instance.isCurrent(identity)) {
        return;
      }
      _loginUserInfo.faceUrl = faceUrl;
      notifyListeners();
    } catch (e) {
      if (kDebugMode) {
        debugPrint('LoginUserInfo: set default avatar skipped ($e)');
      }
    } finally {
      _settingDefaultAvatar = false;
    }
  }
}
