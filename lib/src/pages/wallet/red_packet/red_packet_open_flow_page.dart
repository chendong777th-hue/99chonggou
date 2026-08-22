import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_amount.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/full_screen_back_route.dart';
import 'package:tencent_cloud_chat_demo/src/services/android_performance_profile.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/wallet_page_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';

import 'lucky_red_packet_detail_page.dart';
import 'widgets/red_packet_detail_app_bar.dart';

const Color _kRedPacketAmountGold = Color(0xFFB08A4A);

enum RedPacketResultType {
  normal,
  lucky,
}

class RedPacketOpenPreviewData {
  const RedPacketOpenPreviewData({
    required this.orderId,
    required this.packetType,
    this.senderName = '',
    this.senderAvatar = '',
    this.greeting = '',
    this.amountText = '',
    this.currency = '99',
    this.autoClaim = true,
    this.luckyDetailData,
    this.resultBuilder,
    this.closeWhenResultPopped = false,
  });

  static const emptyNormal = RedPacketOpenPreviewData(
    orderId: '',
    packetType: 'NORMAL_C2C',
  );

  static const emptyLucky = RedPacketOpenPreviewData(
    orderId: '',
    packetType: 'LUCKY_GROUP',
  );

  final String orderId;
  final String packetType;
  final String senderName;
  final String senderAvatar;
  final String greeting;
  final String amountText;

  /// 红包币种代码（如 `99` / `USDT`）。
  final String currency;
  final bool autoClaim;
  final LuckyRedPacketDetailData? luckyDetailData;
  final WidgetBuilder? resultBuilder;
  final bool closeWhenResultPopped;

  bool get isLucky => packetType.trim().toUpperCase() == 'LUCKY_GROUP';
  bool get isExclusive => packetType.trim().toUpperCase() == 'EXCLUSIVE';

  RedPacketResultType get resultType {
    return isLucky ? RedPacketResultType.lucky : RedPacketResultType.normal;
  }

  String get displaySenderName {
    return senderName.trim();
  }

  String get displayGreeting {
    return greeting.trim();
  }

  String get displayAmount {
    return amountText.trim();
  }

  /// 展示用币种单位：平台币为「元」，USDT 为 `USDT`。
  String get coinUnit => walletDisplayCoin(currency);
}

class RedPacketPreviewPage extends StatefulWidget {
  const RedPacketPreviewPage({
    super.key,
    required this.data,
  });

  final RedPacketOpenPreviewData data;

  @override
  State<RedPacketPreviewPage> createState() => _RedPacketPreviewPageState();
}

class _RedPacketPreviewPageState extends State<RedPacketPreviewPage>
    with TickerProviderStateMixin {
  late final AnimationController _openCtrl;
  AnimationController? _splitCtrl;
  bool _opening = false;
  bool _opened = false;
  bool _showOpenedDetail = false;
  bool _showCoverLayer = true;

  AnimationController get _splitController {
    return _splitCtrl ??= AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
  }

  @override
  void initState() {
    super.initState();
    _openCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
  }

  @override
  void dispose() {
    _openCtrl.dispose();
    _splitCtrl?.dispose();
    super.dispose();
  }

  Future<void> _openRedPacket() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _opened = false;
      _showOpenedDetail = false;
      _showCoverLayer = true;
    });
    await _openCtrl.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _opening = false;
      _opened = true;
      _showOpenedDetail = true;
    });
    await _splitController.forward(from: 0);
    if (!mounted) return;
    setState(() {
      _showCoverLayer = false;
      _showOpenedDetail = false;
    });
    final openedResult = await Navigator.of(context).push<dynamic>(
      FullScreenBackPageRoute<dynamic>(
        settings: const RouteSettings(name: 'red_packet_opened_preview'),
        transitionDuration: Duration.zero,
        reverseTransitionDuration: const Duration(milliseconds: 300),
        builder: (_) => _buildResultPage(),
      ),
    );
    if (mounted) {
      if (widget.data.closeWhenResultPopped) {
        Navigator.of(context).pop(openedResult);
        return;
      }
      _reset();
    }
  }

  void _reset() {
    _openCtrl.stop();
    _splitCtrl?.stop();
    _openCtrl.value = 0;
    _splitCtrl?.value = 0;
    setState(() {
      _opening = false;
      _opened = false;
      _showOpenedDetail = false;
      _showCoverLayer = true;
    });
  }

  void _closePreview() {
    Navigator.of(context).maybePop();
  }

  Widget _buildResultPage() {
    final builder = widget.data.resultBuilder;
    if (builder != null) {
      return builder(context);
    }
    return switch (_resultType) {
      RedPacketResultType.normal =>
        RedPacketOpenedPreviewPage(data: widget.data),
      RedPacketResultType.lucky => LuckyRedPacketDetailPage(
          data: widget.data.luckyDetailData ??
              LuckyRedPacketDetailData(
                orderId: widget.data.orderId,
                packetType: widget.data.packetType,
                senderName: widget.data.displaySenderName,
                senderAvatar: widget.data.senderAvatar,
                greeting: widget.data.displayGreeting,
                amountText: widget.data.displayAmount,
                claimedCount: 0,
                totalCount: 0,
                claimedAmountText: '0.00',
                totalAmountText: '0.00',
                allClaimed: false,
                claims: const [],
              ),
        ),
    };
  }

  RedPacketResultType get _resultType => widget.data.resultType;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: Stack(
          children: [
            if (_showOpenedDetail)
              Positioned.fill(
                child: _buildResultPage(),
              ),
            if (_showCoverLayer)
              AnimatedBuilder(
                animation: _splitController,
                builder: (context, _) {
                  final split =
                      Curves.easeInCubic.transform(_splitController.value);
                  final opacity = (1.0 - split).clamp(0.0, 1.0);

                  return Opacity(
                    opacity: opacity,
                    child: const _PreviewMaskLayer(),
                  );
                },
              ),
            if (_showCoverLayer)
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _closePreview,
                child: LayoutBuilder(
                  builder: (context, viewport) {
                    final shortestSide =
                        math.min(viewport.maxWidth, viewport.maxHeight);
                    final horizontalPadding = shortestSide * 0.045;
                    final topGap = viewport.maxHeight * 0.026;
                    final cardWidthFactor =
                        viewport.maxWidth > 720 ? 0.38 : 0.94;

                    return Padding(
                      padding: EdgeInsets.fromLTRB(
                        horizontalPadding,
                        topGap,
                        horizontalPadding,
                        viewport.maxHeight * 0.035,
                      ),
                      child: Column(
                        children: [
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, body) {
                                final closeSize = (shortestSide * 0.13)
                                    .clamp(46.0, 64.0)
                                    .toDouble();
                                final gap = shortestSide * 0.075;
                                final maxByWidth =
                                    body.maxWidth * cardWidthFactor;
                                final maxByHeight = math.max(
                                  0.0,
                                  (body.maxHeight - gap - closeSize) * 3 / 4,
                                );
                                final cardWidth =
                                    math.min(maxByWidth, maxByHeight);

                                return Center(
                                  child: SizedBox(
                                    width: cardWidth,
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: () {},
                                          child: AspectRatio(
                                            aspectRatio: 3 / 4,
                                            child: _RedPacketCover(
                                              data: widget.data,
                                              controller: _openCtrl,
                                              splitController: _splitController,
                                              opening: _opening,
                                              opened: _opened,
                                              onOpen: _openRedPacket,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: gap),
                                        GestureDetector(
                                          behavior: HitTestBehavior.opaque,
                                          onTap: _closePreview,
                                          child: _CloseButton(size: closeSize),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PreviewMaskLayer extends StatelessWidget {
  const _PreviewMaskLayer();

  @override
  Widget build(BuildContext context) {
    if (AndroidPerformanceProfile.instance.reduceHeavyVisualEffects) {
      return SizedBox.expand(
        child: ColoredBox(
          color: Colors.white.withValues(alpha: 0.82),
        ),
      );
    }
    return SizedBox.expand(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          color: Colors.white.withValues(alpha: 0.42),
        ),
      ),
    );
  }
}

class _RedPacketCover extends StatelessWidget {
  const _RedPacketCover({
    required this.data,
    required this.controller,
    required this.splitController,
    required this.opening,
    required this.opened,
    required this.onOpen,
  });

  final RedPacketOpenPreviewData data;
  final AnimationController controller;
  final AnimationController splitController;
  final bool opening;
  final bool opened;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, card) {
        final buttonSize = card.maxWidth * 0.25;
        final flapHeight = card.maxHeight * 0.255;
        final buttonBottom =
            math.max(0.0, flapHeight * 0.56 - buttonSize * 0.50);

        Widget buildCoverStack() {
          return Stack(
            fit: StackFit.expand,
            children: [
              Image.asset(
                'assets/img/red_packet_preview_cover.webp',
                fit: BoxFit.cover,
              ),
              _WechatTitleOverlay(
                data: data,
                cardWidth: card.maxWidth,
                cardHeight: card.maxHeight,
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: flapHeight,
                child: const CustomPaint(
                  painter: _RedPocketFlapPainter(),
                ),
              ),
              Positioned(
                left: 0,
                right: 0,
                bottom: buttonBottom,
                child: Center(
                  child: _OpenCoinButton(
                    controller: controller,
                    opening: opening,
                    opened: opened,
                    size: buttonSize,
                    onTap: onOpen,
                  ),
                ),
              ),
            ],
          );
        }

        return ClipRRect(
          borderRadius: BorderRadius.circular(card.maxWidth * 0.022),
          child: AnimatedBuilder(
            animation: splitController,
            builder: (context, _) {
              final split = Curves.easeInCubic.transform(splitController.value);
              if (split <= 0) {
                return buildCoverStack();
              }

              final travel = card.maxHeight * 1.08 * split;
              final opacity = (1.0 - split * 0.18).clamp(0.0, 1.0);
              return Stack(
                fit: StackFit.expand,
                children: [
                  Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, -travel),
                      child: ClipRect(
                        child: ClipPath(
                          clipper: const _TopSplitClipper(),
                          child: SizedBox(
                            width: card.maxWidth,
                            height: card.maxHeight,
                            child: buildCoverStack(),
                          ),
                        ),
                      ),
                    ),
                  ),
                  Opacity(
                    opacity: opacity,
                    child: Transform.translate(
                      offset: Offset(0, travel),
                      child: ClipRect(
                        child: ClipPath(
                          clipper: const _BottomSplitClipper(),
                          child: SizedBox(
                            width: card.maxWidth,
                            height: card.maxHeight,
                            child: buildCoverStack(),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }
}

class _WechatTitleOverlay extends StatelessWidget {
  const _WechatTitleOverlay({
    required this.data,
    required this.cardWidth,
    required this.cardHeight,
  });

  final RedPacketOpenPreviewData data;
  final double cardWidth;
  final double cardHeight;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: cardWidth * 0.06,
      right: cardWidth * 0.06,
      top: cardHeight * 0.255,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _WechatMark(size: cardWidth * 0.064),
              SizedBox(width: cardWidth * 0.016),
              Flexible(
                child: Text(
                  data.isLucky
                      ? '拼手气红包'
                      : data.isExclusive
                          ? '专属红包'
                          : '预览红包封面',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: const Color(0xFFFFE6A8),
                    fontSize: cardWidth * 0.041,
                    fontWeight: FontWeight.w600,
                    shadows: const [
                      Shadow(
                        color: Color(0x52000000),
                        blurRadius: 4,
                        offset: Offset(0, 1.5),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: cardHeight * 0.018),
          Text(
            data.displayGreeting,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: const Color(0xFFFFE6A8),
              fontSize: cardWidth * 0.058,
              fontWeight: FontWeight.w600,
              shadows: const [
                Shadow(
                  color: Color(0x66000000),
                  blurRadius: 5,
                  offset: Offset(0, 2),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TopSplitClipper extends CustomClipper<Path> {
  const _TopSplitClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.43,
        0,
        size.height * 0.55,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _BottomSplitClipper extends CustomClipper<Path> {
  const _BottomSplitClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, size.height * 0.55)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.43,
        size.width,
        size.height * 0.55,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}

class _WechatMark extends StatelessWidget {
  const _WechatMark({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: const Color(0xFF21C35E),
        borderRadius: BorderRadius.circular(size * 0.18),
      ),
      alignment: Alignment.center,
      child: Icon(
        Icons.chat_bubble,
        color: Colors.white,
        size: size * 0.62,
      ),
    );
  }
}

class _OpenCoinButton extends StatelessWidget {
  const _OpenCoinButton({
    required this.controller,
    required this.opening,
    required this.opened,
    required this.size,
    required this.onTap,
  });

  final AnimationController controller;
  final bool opening;
  final bool opened;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: opening || opened ? null : onTap,
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, _) {
          final eased = Curves.easeInOutCubic.transform(controller.value);
          final turns = opening ? eased * math.pi * 3.0 : 0.0;
          final pulse =
              opening ? math.sin(controller.value * math.pi) * 0.035 : 0.0;
          final showCoin = opening || opened;

          return Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.0012)
              ..rotateY(turns),
            child: Transform.scale(
              scale: 1 + pulse,
              child:
                  showCoin ? _GoldCoinFace(size: size) : _OpenFace(size: size),
            ),
          );
        },
      ),
    );
  }
}

class _OpenFace extends StatelessWidget {
  const _OpenFace({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.35),
          radius: 0.95,
          colors: [
            Color(0xFFFFE79B),
            Color(0xFFF4B63C),
            Color(0xFFC97918),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.16),
            blurRadius: size * 0.075,
            offset: Offset(0, size * 0.035),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: Text(
        '開',
        style: TextStyle(
          color: const Color(0xFF6E3D24),
          fontSize: size * 0.39,
          fontWeight: FontWeight.w400,
          height: 1,
        ),
      ),
    );
  }
}

class _GoldCoinFace extends StatelessWidget {
  const _GoldCoinFace({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: size,
      width: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: const RadialGradient(
          center: Alignment(-0.35, -0.35),
          radius: 0.95,
          colors: [
            Color(0xFFFFE79B),
            Color(0xFFF4B63C),
            Color(0xFFC97918),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.18),
            blurRadius: size * 0.13,
            offset: Offset(0, size * 0.045),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: Size.square(size * 0.72),
        painter: const _CoinHolePainter(),
      ),
    );
  }
}

class _CoinHolePainter extends CustomPainter {
  const _CoinHolePainter();

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);

    final holeSize = size.shortestSide * 0.34;
    final hole = RRect.fromRectAndRadius(
      Rect.fromCenter(center: center, width: holeSize, height: holeSize),
      Radius.circular(size.shortestSide * 0.04),
    );
    final shadowPaint = Paint()
      ..color = const Color(0xFF8A470E).withOpacity(0.28)
      ..maskFilter =
          MaskFilter.blur(BlurStyle.normal, size.shortestSide * 0.03);
    canvas.drawRRect(
        hole.shift(Offset(0, size.shortestSide * 0.025)), shadowPaint);

    final holePaint = Paint()..color = const Color(0xFF8E4510);
    canvas.drawRRect(hole, holePaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RedPocketFlapPainter extends CustomPainter {
  const _RedPocketFlapPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE52B1F), Color(0xFFD91F18)],
      ).createShader(Offset.zero & size);
    canvas.drawPath(_buildPath(size), paint);

    final highlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.006
      ..color = const Color(0xFFFF8D68).withOpacity(0.7);
    final curve = Path()
      ..moveTo(0, size.height * 0.22)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.56,
        size.width,
        size.height * 0.22,
      );
    canvas.drawPath(curve, highlight);
  }

  Path _buildPath(Size size) {
    return Path()
      ..moveTo(0, size.height * 0.20)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 0.58,
        size.width,
        size.height * 0.20,
      )
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _CloseButton extends StatelessWidget {
  const _CloseButton({required this.size});

  final double size;

  @override
  Widget build(BuildContext context) {
    final actualSize = size.clamp(46.0, 64.0).toDouble();

    return Container(
      width: actualSize,
      height: actualSize,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
          color: const Color(0xFFD7A852),
          width: actualSize * 0.035,
        ),
      ),
      alignment: Alignment.center,
      child: Text(
        '×',
        style: TextStyle(
          color: const Color(0xFFD7A852),
          fontSize: (actualSize * 0.62),
          height: 0.95,
          fontWeight: FontWeight.w300,
        ),
      ),
    );
  }
}

class RedPacketOpenedPreviewPage extends StatefulWidget {
  const RedPacketOpenedPreviewPage({
    super.key,
    required this.data,
    this.onBack,
  });

  final RedPacketOpenPreviewData data;
  final VoidCallback? onBack;

  @override
  State<RedPacketOpenedPreviewPage> createState() =>
      _RedPacketOpenedPreviewPageState();
}

class _RedPacketOpenedPreviewPageState extends State<RedPacketOpenedPreviewPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _introCtrl;
  late final Animation<double> _contentScale;

  @override
  void initState() {
    super.initState();
    _introCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _contentScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.94, end: 1.10)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 52,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.10, end: 1.0)
            .chain(CurveTween(curve: Curves.easeOutBack)),
        weight: 48,
      ),
    ]).animate(_introCtrl);
    _introCtrl.forward();
  }

  @override
  void dispose() {
    _introCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: redPacketImmersiveOverlayStyle(context),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        backgroundColor: cs.bg,
        appBar: buildRedPacketDetailAppBar(
          context,
          immersive: true,
          onBack: widget.onBack,
        ),
        body: LayoutBuilder(
          builder: (context, viewport) {
            final width = viewport.maxWidth;
            final height = viewport.maxHeight;
            final navHeight = redPacketDetailNavHeight(context);
            final imageHeight = height * (width > 720 ? 0.21 : 0.18);
            final totalHeaderHeight = navHeight + imageHeight;

            return Column(
              children: [
                SizedBox(
                  height: totalHeaderHeight,
                  width: double.infinity,
                  child: IgnorePointer(
                    child: ClipPath(
                      clipper: const _OpenedCoverClipper(),
                      child: Image.asset(
                        'assets/img/red_packet_preview_cover.webp',
                        fit: BoxFit.cover,
                        alignment: const Alignment(0, -0.08),
                      ),
                    ),
                  ),
                ),
                Expanded(
                  child: ColoredBox(
                    color: cs.bg,
                    child: _OpenedResultContent(
                      maxWidth: width > 720 ? width * 0.38 : width,
                      contentScale: _contentScale,
                      data: widget.data,
                    ),
                  ),
                ),
                buildRedPacketDetailFooter(context),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _OpenedResultContent extends StatelessWidget {
  const _OpenedResultContent({
    required this.maxWidth,
    required this.contentScale,
    required this.data,
  });

  final double maxWidth;
  final Animation<double> contentScale;
  final RedPacketOpenPreviewData data;

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);

    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: EdgeInsets.fromLTRB(34.w, 48.h, 34.w, 40.h),
          child: AnimatedBuilder(
            animation: contentScale,
            builder: (context, child) {
              return Transform.scale(
                scale: contentScale.value,
                alignment: Alignment.center,
                child: child,
              );
            },
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    AppUserAvatar(
                      faceUrl: data.senderAvatar,
                      showName: data.displaySenderName,
                      size: 40.w,
                    ),
                    SizedBox(width: 14.w),
                    Flexible(
                      child: Text(
                        '${data.displaySenderName}发出的红包',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.text,
                          fontSize: 31.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 18.h),
                Text(
                  data.displayGreeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: cs.subText,
                    fontSize: 27.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 48.h),
                if (data.displayAmount.isNotEmpty)
                  RichText(
                    textAlign: TextAlign.center,
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: data.displayAmount,
                          style: TextStyle(
                            color: _kRedPacketAmountGold,
                            fontSize: 51.sp,
                            fontWeight: FontWeight.w500,
                            height: 1.0,
                          ),
                        ),
                        TextSpan(
                          text: ' ${data.coinUnit}',
                          style: TextStyle(
                            color: _kRedPacketAmountGold,
                            fontSize: 24.sp,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _OpenedCoverClipper extends CustomClipper<Path> {
  const _OpenedCoverClipper();

  @override
  Path getClip(Size size) {
    return Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.89)
      ..quadraticBezierTo(
        size.width * 0.50,
        size.height * 1.08,
        0,
        size.height * 0.89,
      )
      ..close();
  }

  @override
  bool shouldReclip(covariant CustomClipper<Path> oldClipper) => false;
}
