import 'package:tencent_calls_uikit/src/call_define.dart';
import 'package:tencent_calls_uikit/src/extensions/trtc_logger.dart';
import 'package:tencent_calls_uikit/src/platform/call_kit_platform_interface.dart';
import 'package:tencent_calls_uikit/src/utils/permission.dart';

class MethodChannelTUICallKit extends TUICallKitPlatform {
  @override
  Future<void> startForegroundService(bool isVideo) async {}

  @override
  Future<void> stopForegroundService() async {}

  @override
  Future<void> startRing(String filePath) async {}

  @override
  Future<void> stopRing() async {}

  @override
  Future<void> updateCallStateToNative() async {}

  @override
  Future<void> startFloatWindow() async {}

  @override
  Future<void> stopFloatWindow() async {}

  @override
  Future<bool> hasFloatPermission() async => false;

  @override
  Future<bool> isAndroidPictureInPictureSupported() async => false;

  @override
  Future<void> enterMobilePictureInPicture() async {}

  @override
  Future<bool> isAppInForeground() async => true;

  @override
  Future<bool> showIncomingBanner() async => false;

  @override
  Future<bool> initResources(Map resources) async => true;

  @override
  Future<void> openMicrophone() async {}

  @override
  Future<void> closeMicrophone() async {}

  @override
  Future<void> apiLog(TRTCLoggerLevel level, String logString) async {}

  @override
  Future<bool> hasPermissions({required List<PermissionType> permissions}) async =>
      true;

  @override
  Future<PermissionResult> requestPermissions({
    required List<PermissionType> permissions,
    String title = '',
    String description = '',
    String settingsTip = '',
  }) async =>
      PermissionResult.granted;

  @override
  Future<bool> isNotificationEnabled() async => false;

  @override
  Future<void> pullBackgroundApp() async {}

  @override
  Future<void> openLockScreenApp() async {}

  @override
  Future<void> enableWakeLock(bool enable) async {}

  @override
  Future<void> setScreenPowerPolicy(CallScreenPowerPolicy policy) async {}

  @override
  Future<bool> isScreenLocked() async => false;

  @override
  Future<void> imSDKInitSuccessEvent() async {}

  @override
  Future<void> loginNativeTUICore(int sdkAppId, String userId, String userSig) async {}

  @override
  Future<void> logoutNativeTUICore() async {}

  @override
  Future<bool> checkUsbCameraService() async => false;

  @override
  Future<void> openUsbCamera(int viewId) async {}

  @override
  Future<void> closeUsbCamera() async {}

  @override
  Future<bool> isSamsungDevice() async => false;
}
