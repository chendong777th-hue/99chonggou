import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_uikit/ui/utils/screen_utils.dart';

/// 桌面用居中 Dialog，移动端保留 BottomSheet；互不影响。
Future<T?> showAdaptiveModalSheet<T>({
  required BuildContext context,
  required WidgetBuilder builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
  bool enableDrag = true,
  Color? backgroundColor,
  Color? barrierColor,
  BorderRadius? desktopBorderRadius,
  double? desktopMaxWidth,
  double? desktopMaxHeightFactor,
}) {
  final isDesktop =
      TUIKitScreenUtils.getFormFactor(context) == DeviceType.Desktop;
  if (!isDesktop) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: isScrollControlled,
      isDismissible: isDismissible,
      enableDrag: enableDrag,
      backgroundColor: backgroundColor ?? Colors.transparent,
      barrierColor: barrierColor,
      builder: builder,
    );
  }

  final size = MediaQuery.sizeOf(context);
  final maxW = desktopMaxWidth ?? size.width.clamp(360.0, 480.0);
  final maxH = size.height * (desktopMaxHeightFactor ?? 0.82);

  return showDialog<T>(
    context: context,
    barrierDismissible: isDismissible,
    barrierColor: barrierColor ?? Colors.black.withValues(alpha: 0.28),
    builder: (dialogContext) {
      return Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW, maxHeight: maxH),
          child: ClipRRect(
            borderRadius: desktopBorderRadius ?? BorderRadius.circular(16),
            child: Material(
              color: backgroundColor ?? Colors.transparent,
              child: builder(dialogContext),
            ),
          ),
        ),
      );
    },
  );
}
