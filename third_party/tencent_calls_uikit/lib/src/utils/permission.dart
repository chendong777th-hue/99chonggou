import 'package:tencent_calls_uikit/src/call_define.dart';
import 'package:tencent_calls_uikit/src/i18n/i18n_utils.dart';
import 'package:tencent_calls_uikit/src/platform/call_kit_platform_interface.dart';

enum PermissionResult {
  granted,
  denied,
  requesting,
}

enum PermissionType {
  camera,
  microphone,
  bluetooth,
}

class Permission {
  static String getPermissionRequestTitle(TUICallMediaType type) {
    if (TUICallMediaType.audio == type) {
      return CallKit_t("applyForMicrophonePermission");
    } else {
      return CallKit_t("applyForMicrophoneAndCameraPermissions");
    }
  }

  static String getPermissionRequestDescription(TUICallMediaType type) {
    if (TUICallMediaType.audio == type) {
      return CallKit_t("needToAccessMicrophonePermission");
    } else {
      return CallKit_t("needToAccessMicrophoneAndCameraPermissions");
    }
  }

  static String getPermissionRequestSettingsTip(TUICallMediaType type) {
    if (TUICallMediaType.audio == type) {
      return "${CallKit_t("applyForMicrophonePermission")}\n${CallKit_t("needToAccessMicrophonePermission")}";
    } else {
      return "${CallKit_t("applyForMicrophoneAndCameraPermissions")}\n${CallKit_t("needToAccessMicrophoneAndCameraPermissions")}";
    }
  }

  static List<PermissionType> permissionsForMediaType(TUICallMediaType type) {
    if (TUICallMediaType.video == type) {
      return const [PermissionType.camera, PermissionType.microphone];
    }
    return const [PermissionType.microphone];
  }

  /// 已授权则直接通过，避免重复 request 在部分 Android 机型上误判为 denied。
  static Future<PermissionResult> ensure(TUICallMediaType type) async {
    final permissions = permissionsForMediaType(type);
    if (await has(permissions: permissions)) {
      return PermissionResult.granted;
    }
    return request(type);
  }

  static Future<PermissionResult> ensureCamera() async {
    const permissions = [PermissionType.camera];
    if (await has(permissions: permissions)) {
      return PermissionResult.granted;
    }
    return request(TUICallMediaType.video);
  }

  static Future<PermissionResult> request(TUICallMediaType type) async {
    PermissionResult result = PermissionResult.denied;
    final permissions = permissionsForMediaType(type);
    result = await TUICallKitPlatform.instance.requestPermissions(
        permissions: permissions,
        title: getPermissionRequestTitle(type),
        description: getPermissionRequestDescription(type),
        settingsTip: getPermissionRequestSettingsTip(type));
    return result;
  }

  static Future<bool> has({required List<PermissionType> permissions}) async {
    return await TUICallKitPlatform.instance.hasPermissions(permissions: permissions);
  }
}
