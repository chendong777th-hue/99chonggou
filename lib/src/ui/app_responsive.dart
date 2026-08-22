import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

class AppResponsive {
  AppResponsive._();

  static bool isDesktop(BuildContext context) =>
      TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;

  static double textScale(BuildContext context) =>
      MediaQuery.textScalerOf(context).scale(1.0);

  static double screenWidth(BuildContext context) =>
      MediaQuery.sizeOf(context).width;

  static double screenHeight(BuildContext context) =>
      MediaQuery.sizeOf(context).height;

  static double _extraForScale(
    BuildContext context, {
    required double mobileStep,
    required double desktopStep,
    double maxExtra = 10,
  }) {
    final delta = math.max(0.0, textScale(context) - 1.0);
    final step = isDesktop(context) ? desktopStep : mobileStep;
    return math.min(maxExtra, delta * step);
  }

  static double listRowMinHeight(
    BuildContext context, {
    double mobile = 56,
    double desktop = 52,
  }) {
    return (isDesktop(context) ? desktop : mobile) +
        _extraForScale(
          context,
          mobileStep: 8,
          desktopStep: 4,
          maxExtra: 12,
        );
  }

  static EdgeInsetsGeometry listRowPadding(
    BuildContext context, {
    double mobileHorizontal = 16,
    double desktopHorizontal = 20,
    double mobileVertical = 12,
    double desktopVertical = 10,
  }) {
    return EdgeInsets.symmetric(
      horizontal: isDesktop(context) ? desktopHorizontal : mobileHorizontal,
      vertical: (isDesktop(context) ? desktopVertical : mobileVertical) +
          _extraForScale(
            context,
            mobileStep: 4,
            desktopStep: 2,
            maxExtra: 6,
          ),
    );
  }

  static double controlHeight(
    BuildContext context, {
    double mobile = 48,
    double desktop = 44,
  }) {
    return (isDesktop(context) ? desktop : mobile) +
        _extraForScale(
          context,
          mobileStep: 6,
          desktopStep: 4,
          maxExtra: 10,
        );
  }

  static double labelColumnWidth(
    BuildContext context, {
    double mobile = 88,
    double desktop = 104,
  }) {
    return (isDesktop(context) ? desktop : mobile) +
        _extraForScale(
          context,
          mobileStep: 10,
          desktopStep: 6,
          maxExtra: 20,
        );
  }

  static EdgeInsetsGeometry modalEdgeInsets(
    BuildContext context, {
    double mobile = 24,
    double desktop = 28,
  }) {
    return EdgeInsets.symmetric(
      horizontal: isDesktop(context) ? desktop : mobile,
      vertical: isDesktop(context) ? desktop : mobile,
    );
  }

  static double modalCardMaxWidth(
    BuildContext context, {
    double mobile = 340,
    double desktop = 380,
  }) {
    return isDesktop(context) ? desktop : mobile;
  }

  static double dialogButtonHeight(BuildContext context) =>
      controlHeight(context, mobile: 48, desktop: 44);

  static double dialogButtonFontSize(BuildContext context) =>
      isDesktop(context) ? 15 : 16;
}

extension AppResponsiveContextX on BuildContext {
  bool get isDesktopFormFactor => AppResponsive.isDesktop(this);

  double get appTextScale => AppResponsive.textScale(this);

  double get appScreenWidth => AppResponsive.screenWidth(this);

  double get appScreenHeight => AppResponsive.screenHeight(this);
}
