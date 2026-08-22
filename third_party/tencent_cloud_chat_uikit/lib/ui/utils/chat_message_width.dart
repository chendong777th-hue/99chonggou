import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/platform.dart';

/// Width limits used by message body widgets on wide screens.
///
/// This keeps bubble content inside the chat panel without changing the
/// outer message row layout.
double chatMessageMaxWidth(
  BuildContext context, {
  double desktopMaxWidth = 360,
  double desktopMinWidth = 220,
  double desktopFactor = 0.42,
  double mobileFactor = 0.70,
}) {
  final screenWidth = MediaQuery.sizeOf(context).width;
  final isWide = PlatformUtils().isWeb || screenWidth >= 900;
  if (!isWide) {
    return math.max(160, screenWidth * mobileFactor);
  }

  final minWidth = math.min(desktopMinWidth, screenWidth * mobileFactor);
  final preferredWidth = math.max(minWidth, screenWidth * desktopFactor);
  return math.min(desktopMaxWidth, preferredWidth);
}
