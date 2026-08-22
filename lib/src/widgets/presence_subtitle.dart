import 'package:flutter/material.dart';

/// 最近上线时间副标题：加载中显示骨架，完成后显示文案。
class PresenceSubtitle extends StatelessWidget {
  const PresenceSubtitle({
    super.key,
    required this.label,
    required this.loading,
    this.imOnline = false,
    this.fontSize = 12,
    this.height = 1.2,
    this.lineHeight,
    this.onlineColor,
    this.offlineColor,
    this.skeletonColor,
    this.skeletonWidth = 64,
    this.skeletonHeight = 10,
    this.maxLines = 1,
  });

  final String label;
  final bool loading;
  final bool imOnline;
  final double fontSize;
  final double height;
  final double? lineHeight;
  final Color? onlineColor;
  final Color? offlineColor;
  final Color? skeletonColor;
  final double skeletonWidth;
  final double skeletonHeight;
  final int maxLines;

  static Widget skeleton({
    Color? color,
    double width = 64,
    double height = 10,
    double lineHeight = 12,
  }) {
    return SizedBox(
      height: lineHeight,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: width,
          height: height,
          decoration: BoxDecoration(
            color: (color ?? const Color(0xFF999999)).withValues(alpha: 0.22),
            borderRadius: BorderRadius.circular(4),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final effectiveLineHeight = lineHeight ?? (fontSize * height);
    if (loading) {
      return PresenceSubtitle.skeleton(
        color: skeletonColor,
        width: skeletonWidth,
        height: skeletonHeight,
        lineHeight: effectiveLineHeight,
      );
    }
    if (label.isEmpty) {
      return SizedBox(height: effectiveLineHeight);
    }
    return Text(
      label,
      maxLines: maxLines,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        inherit: false,
        color: imOnline
            ? (onlineColor ?? const Color(0xFF1E90FF))
            : (offlineColor ?? const Color(0xFF999999)),
        fontSize: fontSize,
        height: height,
        fontWeight: FontWeight.w400,
        leadingDistribution: TextLeadingDistribution.even,
      ),
    );
  }
}
