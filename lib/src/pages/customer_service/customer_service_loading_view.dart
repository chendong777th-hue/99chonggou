import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';

/// 客服 H5 加载骨架：顶部/底部用 shimmer；中间内容区留白。
class CustomerServiceLoadingView extends StatefulWidget {
  const CustomerServiceLoadingView({super.key});

  @override
  State<CustomerServiceLoadingView> createState() =>
      _CustomerServiceLoadingViewState();
}

class _CustomerServiceLoadingViewState extends State<CustomerServiceLoadingView>
    with SingleTickerProviderStateMixin {
  static const Color _headerBlue = Color(0xFF2B7FE0);
  static const Color _panelBg = Color(0xFFF7F7F7);

  late final AnimationController _shimmerController;

  @override
  void initState() {
    super.initState();
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat();
  }

  @override
  void dispose() {
    _shimmerController.dispose();
    super.dispose();
  }

  Widget _shimmer({
    required double height,
    double? width,
    BorderRadius borderRadius = const BorderRadius.all(Radius.circular(8)),
    List<Color>? colors,
  }) {
    return AnimatedBuilder(
      animation: _shimmerController,
      builder: (context, child) {
        final slide = -1.2 + 2.4 * _shimmerController.value;
        final palette = colors ??
            const [
              Color(0xFFE6EDF6),
              Color(0xFFF7FAFD),
              Color(0xFFE6EDF6),
            ];
        return Container(
          height: height,
          width: width,
          decoration: BoxDecoration(
            borderRadius: borderRadius,
            gradient: LinearGradient(
              begin: Alignment(slide, 0),
              end: Alignment(slide + 1, 0),
              colors: palette,
            ),
          ),
        );
      },
    );
  }

  List<Color> _chipColors(double alpha) {
    return [
      Colors.white.withValues(alpha: alpha),
      Colors.white.withValues(alpha: alpha * 0.55),
      Colors.white.withValues(alpha: alpha),
    ];
  }

  Widget _categorySkeletonGrid() {
    return Column(
      children: [
        for (var row = 0; row < 2; row++) ...[
          if (row > 0) const SizedBox(height: 8),
          Row(
            children: [
              for (var col = 0; col < 4; col++) ...[
                if (col > 0) const SizedBox(width: 6),
                Expanded(
                  child: _shimmer(
                    height: 32,
                    borderRadius: BorderRadius.circular(8),
                    colors: _chipColors(row == 0 && col == 0 ? 0.9 : 0.45),
                  ),
                ),
              ],
            ],
          ),
        ],
      ],
    );
  }

  Widget _bottomInputSkeleton() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
      child: Row(
        children: [
          _shimmer(
            height: 28,
            width: 28,
            borderRadius: BorderRadius.circular(6),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _shimmer(
              height: 40,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
          const SizedBox(width: 10),
          _shimmer(
            height: 40,
            width: 40,
            borderRadius: BorderRadius.circular(20),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final dark = Theme.of(context).brightness == Brightness.dark;

    return ColoredBox(
      color: _panelBg,
      child: Column(
        children: [
          ColoredBox(
            color: _headerBlue,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
              child: _categorySkeletonGrid(),
            ),
          ),
          Expanded(
            child: ColoredBox(
              color: _panelBg,
              child: Center(
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primaryBlue.withValues(alpha: 0.85),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      i18n.t(
                        zhHans: '正在加载客服页面…',
                        zhHant: '正在載入客服頁面…',
                        en: 'Loading customer service…',
                        ja: 'カスタマーサポートを読み込み中…',
                        ko: '고객센터 페이지를 불러오는 중…',
                      ),
                      style: TextStyle(
                        color: AppColors.subText(dark: dark),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ColoredBox(
            color: _panelBg,
            child: _bottomInputSkeleton(),
          ),
        ],
      ),
    );
  }
}
