import 'package:flutter/material.dart';

/// 官方账号不可输入，但仍保留普通聊天单行输入栏的视觉占位和底部安全区。
class OfficialAccountInputSpacer extends StatelessWidget {
  const OfficialAccountInputSpacer({
    super.key,
    required this.backgroundColor,
  });

  /// 普通窄屏输入栏：36px 控件高度 + 上下各 5px。
  static const double inputBarHeight = 46;

  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: backgroundColor,
      child: const SafeArea(
        top: false,
        left: false,
        right: false,
        minimum: EdgeInsets.zero,
        child: SizedBox(height: inputBarHeight),
      ),
    );
  }
}
