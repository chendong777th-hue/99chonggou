import 'package:flutter/material.dart';

/// UIKit 宽屏弹窗尺寸约定（与 demo 的 DesktopModalLayout 对齐）。
class WidePopupLayout {
  WidePopupLayout._();

  static Size medium(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Size(
      size.width.clamp(420, 520).toDouble(),
      (size.height * 0.72).clamp(480, 640).toDouble(),
    );
  }

  static Size large(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Size(
      size.width.clamp(560, 720).toDouble(),
      (size.height * 0.78).clamp(520, 720).toDouble(),
    );
  }

  static Size searchDetail(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Size(
      size.width.clamp(520, 720).toDouble(),
      (size.height * 0.72).clamp(480, 680).toDouble(),
    );
  }
}
