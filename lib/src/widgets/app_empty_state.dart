import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';

/// 列表/记录类页面统一空状态插画。
class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    this.message,
    this.imageWidth,
    this.padding,
  });

  static const String assetPath = 'assets/img/empty.webp';

  final String? message;
  final double? imageWidth;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final w = imageWidth ?? 160;
    final textColor = AppColors.subText(dark: dark);

    return Padding(
      padding: padding ??
          const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              assetPath,
              width: w,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => Icon(
                Icons.inbox_outlined,
                size: w * 0.45,
                color: textColor.withValues(alpha: 0.45),
              ),
            ),
            if (message != null && message!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                message!,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: textColor,
                  height: 1.4,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
