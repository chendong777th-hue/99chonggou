// ignore_for_file: constant_identifier_names

import 'package:flutter/cupertino.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

enum DeviceType { Desktop, Mobile }

class FormFactor {
  static double desktop = 900;
  static double handset = 300;
}

class TUIKitScreenUtils {
  static DeviceType? deviceType;

  static DeviceType _classifyBySize(
    double width,
    double height, {
    required bool allowLandscapeAsDesktop,
  }) {
    // 宽屏壳：宽度超过桌面门槛。
    if (width > FormFactor.desktop) {
      return DeviceType.Desktop;
    }
    // 仅 Web：用纵横比把宽窗判成 Desktop（修复对角线英寸误判成手机）。
    // 原生手机横屏绝不能走这条，否则会切到桌面长按菜单 / 宽屏壳。
    if (allowLandscapeAsDesktop && width > height * 1.1) {
      return DeviceType.Desktop;
    }
    return DeviceType.Mobile;
  }

  /// Although specifying the `BuildContext` is optional, providing it can prevent layout issues when this widget renders immediately after the app launch.
  /// If this widget needs to be used at the moment the app launches, it's recommended to provide the `BuildContext` here.
  static DeviceType getFormFactor([BuildContext? context]) {
    // 原生桌面 OS 始终走桌面交互（消息菜单、弹层等）。
    if (PlatformUtils().isDesktop) {
      deviceType = DeviceType.Desktop;
      return DeviceType.Desktop;
    }

    final allowLandscapeAsDesktop = PlatformUtils().isWeb;

    // 有 context 时每次按当前视口重算，避免启动时窄窗把结果永久钉死成 Mobile。
    if (context != null) {
      final size = MediaQuery.sizeOf(context);
      deviceType = _classifyBySize(
        size.width,
        size.height,
        allowLandscapeAsDesktop: allowLandscapeAsDesktop,
      );
      return deviceType!;
    }

    if (deviceType != null) {
      return deviceType!;
    }

    if (PlatformUtils().isWeb) {
      final win = WidgetsBinding.instance.platformDispatcher.views.first;
      final size = win.physicalSize;
      final screenWidth = size.width / win.devicePixelRatio;
      final screenHeight = size.height / win.devicePixelRatio;
      deviceType = _classifyBySize(
        screenWidth,
        screenHeight,
        allowLandscapeAsDesktop: true,
      );
      return deviceType!;
    }

    // 原生手机 / 平板：无 context 时保持 Mobile，不缓存错误的横屏 Desktop。
    return DeviceType.Mobile;
  }

  static Widget getDeviceWidget({
    /// Although specifying the `BuildContext` is optional, providing it can prevent layout issues when this widget renders immediately after the app launch.
    /// If this widget needs to be used at the moment the app launches, it's recommended to provide the `BuildContext` here.
    BuildContext? context,
    required Widget defaultWidget,
    Widget? desktopWidget,
    Widget? mobileWidget,
  }) {
    deviceType ??= getFormFactor(context);
    if (deviceType == DeviceType.Desktop) return desktopWidget ?? defaultWidget;
    return mobileWidget ?? defaultWidget;
  }
}
