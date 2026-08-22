import 'dart:async';
import 'dart:convert';
import 'dart:ffi';

import 'package:tencent_cloud_chat_sdk/models/v2_tim_offline_push_config.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_manager.dart';
import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_library_manager.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_callback.dart';
import 'package:tencent_cloud_chat_sdk/native_im/bindings/native_imsdk_bindings_generated.dart';
import 'package:tencent_cloud_chat_sdk/native_im/tools.dart';

class TIMOfflinePushManager {
  static TIMOfflinePushManager instance = TIMOfflinePushManager();

  TIMOfflinePushManager();

  void init() {}

  Future<V2TimCallback> setOfflinePushConfig({
    required double businessID,
    required String token,
    bool isTPNSToken = false,
    bool isVoip = false,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('setOfflinePushConfig');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    String tokenResult = token;
    if (!isHexString(token)) {
      // 如果 token 不是十六进制字符串，则需要转换为十六进制字符串
      // C 接口的 token 需要传入 base16 编码的字符串，这里将 token 转换为 base16 编码的字符串
      List<int> bytes = utf8.encode(token);
      tokenResult = bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();
    }

    V2TimOfflinePushConfig config = V2TimOfflinePushConfig(businessID: businessID.toInt(), token: tokenResult, isTPNSToken: isTPNSToken, isVoip: isVoip);

    Pointer<Char> pConfig = Tools.string2PointerChar(json.encode(config.toJson()));
    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    int result = NativeLibraryManager.bindings.DartSetOfflinePushToken(pConfig, pUserData);
    if (result != TIMResult.TIM_SUCC.value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pConfig, pUserData]);
      return V2TimCallback(code: TIMErrCode.ERR_INVALID_PARAMETERS.value, desc: "invalid parameter");
    }

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointers([pConfig, pUserData]);
      return value;
    });
  }

  bool isHexString(String input) {
    if (input.isEmpty) return false;

    // 包含可选的0x前缀和大小写字母
    final hexRegex = RegExp(r'^(0x)?[0-9a-fA-F]+$');
    return hexRegex.hasMatch(input);
  }

  Future<V2TimCallback> doBackground({
    required int unreadCount,
  }) async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('doBackground');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartDoBackground(unreadCount, pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointer(pUserData);
      return value;
    });
  }

  Future<V2TimCallback> doForeground() async {
    if (!TIMManager.instance.isInitSDK()) {
      return V2TimCallback(code: TIMErrCode.ERR_SDK_NOT_INITIALIZED.value, desc: "sdk not init");
    }

    String userData = Tools.generateUserData('doForeground');
    Completer<V2TimCallback> completer = Completer();
    NativeLibraryManager.addTimCallback2Map(userData, completer);

    Pointer<Void> pUserData = Tools.string2PointerVoid(userData);
    NativeLibraryManager.bindings.DartDoForeground(pUserData);

    return completer.future.then((value) {
      NativeLibraryManager.removeTimCallbackFromMap(userData);
      Tools.freePointer(pUserData);
      return value;
    });
  }

}