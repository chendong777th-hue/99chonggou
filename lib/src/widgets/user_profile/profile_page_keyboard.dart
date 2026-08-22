import 'package:flutter/material.dart';

/// 资料页 / 加好友页：点击空白收起键盘，滚动时收起键盘。
class ProfilePageKeyboard {
  ProfilePageKeyboard._();

  static void dismiss() {
    FocusManager.instance.primaryFocus?.unfocus();
  }

  static Widget dismissScope({required Widget child}) {
    return TapRegion(
      onTapOutside: (_) => dismiss(),
      child: child,
    );
  }

  static Widget scrollBody({
    required BuildContext context,
    required Widget child,
    bool includeBottomInset = false,
  }) {
    final media = MediaQuery.of(context);
    final minHeight = media.size.height -
        media.padding.top -
        kToolbarHeight -
        media.padding.bottom;
    return dismissScope(
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: includeBottomInset
            ? EdgeInsets.only(bottom: media.viewInsets.bottom)
            : EdgeInsets.zero,
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: minHeight),
          child: child,
        ),
      ),
    );
  }
}
