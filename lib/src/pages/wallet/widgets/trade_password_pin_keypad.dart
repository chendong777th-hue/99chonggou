import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

import 'wallet_page_colors.dart';

/// 6 位交易密码圆点输入框。
class TradePasswordPinCells extends StatelessWidget {
  const TradePasswordPinCells({
    super.key,
    required this.length,
    this.pinLength = 6,
    this.hasError = false,
    this.cellSize,
    this.spacing,
  });

  final int length;
  final int pinLength;
  final bool hasError;
  final double? cellSize;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    final size = cellSize ?? 56.w;
    final gap = spacing ?? 12.w;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pinLength, (i) {
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: gap / 2),
          child: _PinCell(
            size: size,
            filled: length > i,
            hasError: hasError,
            cs: cs,
          ),
        );
      }),
    );
  }
}

/// 无边框圆点密码指示（参考资金密码页样式）。
class TradePasswordPinDots extends StatelessWidget {
  const TradePasswordPinDots({
    super.key,
    required this.length,
    this.pinLength = 6,
    this.hasError = false,
    this.dotSize,
    this.spacing,
  });

  final int length;
  final int pinLength;
  final bool hasError;
  final double? dotSize;
  final double? spacing;

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    final size = dotSize ?? 14.w;
    final gap = spacing ?? 18.w;
    final emptyColor = cs.dark ? cs.line : const Color(0xFFE3E3E3);
    final filledColor = hasError ? cs.red : cs.text;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(pinLength, (i) {
        final filled = length > i;
        return Padding(
          padding: EdgeInsets.symmetric(horizontal: gap / 2),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: filled ? filledColor : emptyColor,
            ),
          ),
        );
      }),
    );
  }
}

class _PinCell extends StatelessWidget {
  const _PinCell({
    required this.size,
    required this.filled,
    required this.hasError,
    required this.cs,
  });

  final double size;
  final bool filled;
  final bool hasError;
  final WalletPageColors cs;

  @override
  Widget build(BuildContext context) {
    final dot = (size * 0.28).clamp(10.0, 16.0);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: cs.inputFill,
        borderRadius: BorderRadius.circular(10.r),
        border: Border.all(
          color: hasError ? cs.red : cs.line,
          width: hasError ? 1.2 : 0.6,
        ),
      ),
      child: filled
          ? Container(
              width: dot,
              height: dot,
              decoration: BoxDecoration(
                color: cs.text,
                shape: BoxShape.circle,
              ),
            )
          : null,
    );
  }
}

/// 交易密码九宫格数字键盘。
class TradePasswordKeyPad extends StatelessWidget {
  const TradePasswordKeyPad({
    super.key,
    required this.enabled,
    required this.onDigit,
    required this.onDelete,
    this.scale = 1,
    this.keyBackgroundColor,
  });

  final bool enabled;
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  final double scale;

  /// 未指定时按主题自动选择键帽背景色。
  final Color? keyBackgroundColor;

  static void hapticTap() => HapticFeedback.selectionClick();

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    final keyBg = keyBackgroundColor ??
        (cs.dark ? const Color(0xFF2A2D33) : const Color(0xFFE0E0E0));
    const keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];
    final s = scale;
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: keys.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisExtent: (72 * s).h,
        mainAxisSpacing: (16 * s).h,
        crossAxisSpacing: (20 * s).w,
      ),
      itemBuilder: (_, i) {
        final k = keys[i];
        if (k.isEmpty) return const SizedBox.shrink();
        final isDel = k == 'del';
        return _KeyButton(
          cs: cs,
          enabled: enabled,
          scale: s,
          backgroundColor: keyBg,
          label: isDel ? null : k,
          icon: isDel ? Icons.backspace_outlined : null,
          onTap: isDel
              ? () {
                  hapticTap();
                  onDelete();
                }
              : () {
                  hapticTap();
                  onDigit(k);
                },
        );
      },
    );
  }
}

class _KeyButton extends StatelessWidget {
  const _KeyButton({
    required this.cs,
    required this.enabled,
    required this.onTap,
    required this.scale,
    required this.backgroundColor,
    this.label,
    this.icon,
  });

  final WalletPageColors cs;
  final bool enabled;
  final VoidCallback onTap;
  final double scale;
  final Color backgroundColor;
  final String? label;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final radius = (16 * scale).r;
    final contentColor = enabled ? cs.text : cs.subText;
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(radius),
        child: Container(
          alignment: Alignment.center,
          child: icon != null
              ? Icon(
                  icon,
                  size: (32 * scale).sp,
                  color: contentColor,
                )
              : Text(
                  label ?? '',
                  style: TextStyle(
                    fontSize: (34 * scale).sp,
                    fontWeight: FontWeight.w400,
                    color: contentColor,
                  ),
                ),
        ),
      ),
    );
  }
}
