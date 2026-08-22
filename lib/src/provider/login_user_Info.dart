// ignore_for_file: file_names

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';

class LoginUserInfo with ChangeNotifier {
  V2TimUserFullInfo _loginUserInfo = V2TimUserFullInfo();
  final CoreServicesImpl _coreServices = TIMUIKitCore.getInstance();
  static final Set<String> _defaultAvatarSyncAttempted = <String>{};
  bool _settingDefaultAvatar = false;

  V2TimUserFullInfo get loginUserInfo {
    return _loginUserInfo;
  }

  setLoginUserInfo(V2TimUserFullInfo info) {
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
    final key = userId.isNotEmpty ? userId : 'current_user';
    if (_defaultAvatarSyncAttempted.contains(key)) {
      return;
    }

    _settingDefaultAvatar = true;
    _defaultAvatarSyncAttempted.add(key);
    try {
      const faceUrl = IMDemoConfig.defaultRegisterAvatarUrl;
      final userFullInfo = V2TimUserFullInfo(faceUrl: faceUrl);
      await _coreServices.setSelfInfo(userFullInfo: userFullInfo);
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
