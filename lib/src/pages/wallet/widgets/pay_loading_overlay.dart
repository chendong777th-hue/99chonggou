import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

/// 支付请求中的全屏加载遮罩。
/// 第一阶段：圆环点阵旋转 +「请求支付...」
/// 约 1 秒后切换至第二阶段：品牌 Logo + 三点脉冲。
class PayLoadingOverlay extends StatefulWidget {
  final bool show;
  final String logoAsset;
  final String brandText;
  final String loadingText;

  const PayLoadingOverlay({
    super.key,
    required this.show,
    this.logoAsset = 'assets/img/99chat_logo.png',
    this.brandText = '',
    this.loadingText = '',
  });

  static OverlayEntry? _entry;

  /// 在根 Overlay 上展示支付加载动画。
  static void present(
    BuildContext context, {
    String logoAsset = 'assets/img/99chat_logo.png',
    String? brandText,
    String? loadingText,
  }) {
    // 进入支付流程即收起键盘，避免后续弹层/成功动画与键盘叠层。
    FocusManager.instance.primaryFocus?.unfocus();

    final i18n = AppI18n.of(context);
    final resolvedBrand = brandText ??
        i18n.t(
          zhHans: '99chat支付',
          zhHant: '99chat支付',
          en: '99chat Pay',
          ja: '99chat Pay',
          ko: '99chat Pay',
        );
    final resolvedLoading = loadingText ??
        i18n.t(
          zhHans: '请求支付...',
          zhHant: '請求支付...',
          en: 'Processing payment...',
          ja: '支払い処理中...',
          ko: '결제 요청 중...',
        );
    dismiss(immediate: true);
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (_) => PayLoadingOverlay(
        show: true,
        logoAsset: logoAsset,
        brandText: resolvedBrand,
        loadingText: resolvedLoading,
      ),
    );
    overlay.insert(_entry!);
  }

  /// 关闭支付加载动画。
  static void dismiss({bool immediate = false}) {
    final current = _entry;
    if (current == null) {
      return;
    }
    _entry = null;

    void removeEntry() {
      try {
        current.remove();
      } catch (_) {}
    }

    if (immediate || SchedulerBinding.instance.schedulerPhase == SchedulerPhase.idle) {
      removeEntry();
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future<void>.delayed(Duration.zero, removeEntry);
    });
  }

  /// 第一阶段停留 + 切换动画 + 第二阶段停留（合计 1.5 秒）。
  static const Duration stage1Hold = Duration(milliseconds: 700);
  static const Duration switchDuration = Duration(milliseconds: 400);
  static const Duration stage2Hold = Duration(milliseconds: 400);

  static Duration get animationMinDuration =>
      stage1Hold + switchDuration + stage2Hold;

  /// 弹出支付密码弹窗前展示加载动画。
  /// [prepare] 可在此阶段做下单准备；动画至少展示 [minDuration]。
  static Future<void> runBeforePayPrompt(
    BuildContext context, {
    Future<void> Function()? prepare,
    Duration? minDuration,
    String logoAsset = 'assets/img/99chat_logo.png',
    String? brandText,
    String? loadingText,
  }) async {
    final i18n = AppI18n.of(context);
    present(
      context,
      logoAsset: logoAsset,
      loadingText: loadingText ??
          i18n.t(
            zhHans: '请求支付...',
            zhHant: '請求支付...',
            en: 'Processing payment...',
            ja: '支払い処理中...',
            ko: '결제 요청 중...',
          ),
      brandText: brandText ??
          i18n.t(
            zhHans: '99chat支付',
            zhHant: '99chat支付',
            en: '99chat Pay',
            ja: '99chat Pay',
            ko: '99chat Pay',
          ),
    );
    final hold = minDuration ?? animationMinDuration;
    try {
      await Future.wait([
        if (prepare != null) prepare() else Future<void>.value(),
        Future<void>.delayed(hold),
      ]);
    } finally {
      dismiss();
    }
  }

  @override
  State<PayLoadingOverlay> createState() => _PayLoadingOverlayState();
}

class _PayLoadingOverlayState extends State<PayLoadingOverlay> {
  int _stageIndex = 0;
  Timer? _switchTimer;

  @override
  void initState() {
    super.initState();
    if (widget.show) {
      _startSequence();
    }
  }

  @override
  void didUpdateWidget(covariant PayLoadingOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!oldWidget.show && widget.show) {
      _startSequence();
    }

    if (oldWidget.show && !widget.show) {
      _switchTimer?.cancel();
      _stageIndex = 0;
    }
  }

  void _startSequence() {
    _switchTimer?.cancel();
    if (mounted) {
      setState(() => _stageIndex = 0);
    } else {
      _stageIndex = 0;
    }
    _switchTimer = Timer(PayLoadingOverlay.stage1Hold, () {
      if (mounted && widget.show) {
        setState(() => _stageIndex = 1);
      }
    });
  }

  @override
  void dispose() {
    _switchTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.show) return const SizedBox.shrink();

    final i18n = AppI18n.of(context);
    final loadingText = widget.loadingText.isEmpty
        ? i18n.t(
            zhHans: '请求支付...',
            zhHant: '請求支付...',
            en: 'Processing payment...',
            ja: '支払い処理中...',
            ko: '결제 요청 중...',
          )
        : widget.loadingText;
    final brandText = widget.brandText.isEmpty
        ? i18n.t(
            zhHans: '99chat支付',
            zhHant: '99chat支付',
            en: '99chat Pay',
            ja: '99chat Pay',
            ko: '99chat Pay',
          )
        : widget.brandText;

    return Material(
      type: MaterialType.transparency,
      child: AbsorbPointer(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withValues(alpha: 0.28),
          alignment: Alignment.center,
          child: ClipRRect(
            borderRadius: BorderRadius.circular(22),
            child: Container(
              width: 172,
              padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
              decoration: BoxDecoration(
                color: const Color(0xFF2A2A2E).withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(22),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 18,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: AnimatedSwitcher(
                duration: PayLoadingOverlay.switchDuration,
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeOut,
                transitionBuilder: (child, animation) {
                  final scale = Tween<double>(begin: 0.96, end: 1).animate(
                    CurvedAnimation(parent: animation, curve: Curves.easeOut),
                  );
                  return FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(scale: scale, child: child),
                  );
                },
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                child: _stageIndex == 0
                    ? _StageOne(
                        key: const ValueKey('pay_loading_stage1'),
                        loadingText: loadingText,
                      )
                    : _StageTwo(
                        key: const ValueKey('pay_loading_stage2'),
                        logoAsset: widget.logoAsset,
                        brandText: brandText,
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StageOne extends StatefulWidget {
  final String loadingText;

  const _StageOne({super.key, required this.loadingText});

  @override
  State<_StageOne> createState() => _StageOneState();
}

class _StageOneState extends State<_StageOne>
    with SingleTickerProviderStateMixin {
  late final AnimationController _spinCtrl;

  @override
  void initState() {
    super.initState();
    _spinCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _spinCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        AnimatedBuilder(
          animation: _spinCtrl,
          builder: (_, __) {
            return CustomPaint(
              size: const Size(68, 68),
              painter: _RingDotPainter(progress: _spinCtrl.value),
            );
          },
        ),
        const SizedBox(height: 10),
        Text(
          widget.loadingText,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.none,
          ),
        ),
      ],
    );
  }
}

class _StageTwo extends StatelessWidget {
  final String logoAsset;
  final String brandText;

  const _StageTwo({
    super.key,
    required this.logoAsset,
    required this.brandText,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 52,
            height: 52,
            child: Image.asset(
              logoAsset,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) {
                return Image.asset(
                  'assets/img/platform_99.webp',
                  fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) {
                    return Container(
                      color: const Color(0xFF2B72FF),
                      alignment: Alignment.center,
                      child: const Text(
                        '99',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          decoration: TextDecoration.none,
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          brandText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 14,
            color: Colors.white,
            fontWeight: FontWeight.w400,
            decoration: TextDecoration.none,
          ),
        ),
        const SizedBox(height: 10),
        const _ThreeDotPulse(),
      ],
    );
  }
}

class _RingDotPainter extends CustomPainter {
  final double progress;

  _RingDotPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    const count = 12;

    final center = Offset(size.width / 2, size.height / 2);
    final ringRadius = size.width * 0.33;

    for (int i = 0; i < count; i++) {
      final angle = (math.pi * 2 / count) * i - math.pi / 2;

      final x = center.dx + math.cos(angle) * ringRadius;
      final y = center.dy + math.sin(angle) * ringRadius;

      final phase = ((i - progress * count) % count + count) % count;
      final t = 1 - (phase / count);

      final radius = lerpDouble(1.5, 6.0, t)!;
      final opacity = lerpDouble(0.18, 1.0, t)!;

      final paint = Paint()
        ..isAntiAlias = true
        ..style = PaintingStyle.fill
        ..color = Colors.white.withValues(alpha: opacity);

      canvas.drawCircle(Offset(x, y), radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _RingDotPainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _ThreeDotPulse extends StatefulWidget {
  const _ThreeDotPulse();

  @override
  State<_ThreeDotPulse> createState() => _ThreeDotPulseState();
}

class _ThreeDotPulseState extends State<_ThreeDotPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  double _calcScale(int index) {
    final value = _ctrl.value;
    final delay = index * 0.2;
    double t = (value - delay) % 1.0;
    if (t < 0) t += 1.0;

    if (t < 0.25) {
      return 1.0 + (t / 0.25) * 0.45;
    } else if (t < 0.5) {
      return 1.45 - ((t - 0.25) / 0.25) * 0.45;
    }
    return 1.0;
  }

  double _calcOpacity(int index) {
    final scale = _calcScale(index);
    return 0.55 + (scale - 1.0) / 0.45 * 0.45;
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (index) {
            final scale = _calcScale(index);
            final opacity = _calcOpacity(index);

            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 5),
              child: Transform.scale(
                scale: scale,
                child: Container(
                  width: 9,
                  height: 9,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: opacity),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
