import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tencent_cloud_chat_demo/src/api/wallet_amount.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/wallet_page_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';

import 'widgets/red_packet_detail_app_bar.dart';

const Color _kRedPacketAmountGold = Color(0xFFB08A4A);

class LuckyRedPacketClaimPreviewData {
  const LuckyRedPacketClaimPreviewData({
    required this.avatarUrl,
    required this.name,
    required this.time,
    required this.amountText,
    this.bestLuck = false,
  });

  final String avatarUrl;
  final String name;
  final String time;
  final String amountText;
  final bool bestLuck;
}

class LuckyRedPacketDetailData {
  const LuckyRedPacketDetailData({
    required this.orderId,
    required this.packetType,
    required this.senderName,
    required this.senderAvatar,
    required this.greeting,
    required this.amountText,
    required this.claimedCount,
    required this.totalCount,
    required this.claimedAmountText,
    required this.totalAmountText,
    required this.claims,
    this.currency = '99',
    this.allClaimed = true,
    this.statusHint = '',
    this.claimsLoaded = true,
  });

  static const empty = LuckyRedPacketDetailData(
    orderId: '',
    packetType: 'LUCKY_GROUP',
    senderName: '',
    senderAvatar: '',
    greeting: '',
    amountText: '',
    claimedCount: 0,
    totalCount: 0,
    claimedAmountText: '0.00',
    totalAmountText: '0.00',
    currency: '99',
    allClaimed: false,
    claims: [],
    statusHint: '',
    claimsLoaded: true,
  );

  final String orderId;
  final String packetType;
  final String senderName;
  final String senderAvatar;
  final String greeting;
  final String amountText;
  final int claimedCount;
  final int totalCount;
  final String claimedAmountText;
  final String totalAmountText;
  final List<LuckyRedPacketClaimPreviewData> claims;
  /// 红包币种代码（如 `99` / `USDT`）。
  final String currency;
  final bool allClaimed;
  final String statusHint;
  final bool claimsLoaded;

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

  String get progressText {
    return '已领取 $claimedCount/$totalCount 个，共 $claimedAmountText/$totalAmountText $coinUnit';
  }
}

class LuckyRedPacketDetailPage extends StatefulWidget {
  const LuckyRedPacketDetailPage({
    super.key,
    required this.data,
    this.onBack,
  });

  final LuckyRedPacketDetailData data;
  final VoidCallback? onBack;

  @override
  State<LuckyRedPacketDetailPage> createState() =>
      _LuckyRedPacketDetailPageState();
}

class _LuckyRedPacketDetailPageState extends State<LuckyRedPacketDetailPage>
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
        tween: Tween(begin: 0.94, end: 1.08)
            .chain(CurveTween(curve: Curves.easeOutCubic)),
        weight: 52,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.08, end: 1.0)
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
            final maxContentWidth = width > 720 ? width * 0.42 : width;
            final navHeight = redPacketDetailNavHeight(context);
            final decorativeHeight = height * (width > 720 ? 0.025 : 0.03);
            final totalHeaderHeight = navHeight + decorativeHeight;
            final mascotWidth = maxContentWidth * (width > 720 ? 0.20 : 0.24);

            return Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(maxWidth: maxContentWidth),
                child: Column(
                  children: [
                    SizedBox(
                      height: totalHeaderHeight,
                      width: double.infinity,
                      child: IgnorePointer(
                        child: Stack(
                          clipBehavior: Clip.hardEdge,
                          fit: StackFit.expand,
                          children: [
                            const CustomPaint(
                              painter: _LuckyHeaderPainter(),
                            ),
                            Align(
                              alignment: const Alignment(0, 0.55),
                              child: Transform.translate(
                                offset: Offset(0, 4.h),
                                child: Image.asset(
                                  'assets/img/psqtou.png',
                                  width: mascotWidth,
                                  fit: BoxFit.contain,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    Expanded(
                      child: ColoredBox(
                        color: cs.bg,
                        child: _LuckyDetailBody(
                          contentScale: _contentScale,
                          data: widget.data,
                        ),
                      ),
                    ),
                    buildRedPacketDetailFooter(context),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LuckyDetailBody extends StatelessWidget {
  const _LuckyDetailBody({
    required this.contentScale,
    required this.data,
  });

  final Animation<double> contentScale;
  final LuckyRedPacketDetailData data;

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);
    final i18n = AppI18n.of(context);

    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(34.w, 0, 34.w, 32.h),
      child: Column(
        children: [
          AnimatedBuilder(
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
                    SizedBox(width: 10.w),
                    Flexible(
                      child: Text(
                        '${data.displaySenderName}发出的红包',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: cs.text,
                          fontSize: 27.sp,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 8.h),
                Text(
                  data.displayGreeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.subText,
                    fontSize: 24.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 12.h),
                if (data.displayAmount.isNotEmpty)
                  RichText(
                    text: TextSpan(
                      children: [
                        TextSpan(
                          text: data.displayAmount,
                          style: TextStyle(
                            color: _kRedPacketAmountGold,
                            fontSize: 38.sp,
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
                  )
                else if (data.statusHint.isNotEmpty)
                  Text(
                    data.statusHint,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: cs.subText,
                      fontSize: 27.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 10.h),
          Text(
            data.progressText,
            style: TextStyle(
              color: data.allClaimed ? cs.subText : cs.text,
              fontSize: 22.sp,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 12.h),
          if (data.claims.isEmpty)
            Padding(
              padding: EdgeInsets.only(top: 80.h),
              child: Text(
                !data.claimsLoaded
                    ? i18n.t(
                        zhHans: '领取记录暂时加载失败',
                        zhHant: '領取記錄暫時載入失敗',
                        en: 'Failed to load claim records.',
                        ja: '受取記録の読み込みに失敗しました。',
                        ko: '수령 기록을 불러오지 못했습니다.',
                      )
                    : i18n.t(
                        zhHans: '还没有人领取这个红包',
                        zhHant: '還沒有人領取這個紅包',
                        en: 'No one has claimed this red packet yet.',
                        ja: 'まだ誰もこの紅包を受け取っていません。',
                        ko: '아직 이 홍바오를 받은 사람이 없습니다.',
                      ),
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: cs.subText,
                  fontSize: 24.sp,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else
            for (final claim in data.claims) ...[
            Divider(height: 1, color: cs.line),
            _ClaimRow(
              avatarUrl: claim.avatarUrl,
              name: claim.name,
              time: claim.time,
              amount: claim.amountText,
              bestLuck: claim.bestLuck,
              bestLuckLabel: i18n.t(
                zhHans: '手气最佳',
                zhHant: '手氣最佳',
                en: 'Best luck',
                ja: '運試し王',
                ko: '최고 행운',
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ClaimRow extends StatelessWidget {
  const _ClaimRow({
    required this.avatarUrl,
    required this.name,
    required this.time,
    required this.amount,
    required this.bestLuckLabel,
    this.bestLuck = false,
  });

  final String avatarUrl;
  final String name;
  final String time;
  final String amount;
  final String bestLuckLabel;
  final bool bestLuck;

  @override
  Widget build(BuildContext context) {
    final cs = WalletPageColors.of(context);

    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AppUserAvatar(
            faceUrl: avatarUrl,
            showName: name,
            size: 64.w,
          ),
          SizedBox(width: 14.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: cs.text,
                    fontSize: 29.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 8.h),
                Text(
                  time,
                  style: TextStyle(
                    color: cs.subText,
                    fontSize: 23.sp,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                amount,
                style: TextStyle(
                  color: cs.text,
                  fontSize: 31.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              if (bestLuck) ...[
                SizedBox(height: 10.h),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.emoji_events_rounded,
                      color: cs.tagTextColor,
                      size: 22.sp,
                    ),
                    SizedBox(width: 6.w),
                    Text(
                      bestLuckLabel,
                      style: TextStyle(
                        color: cs.tagTextColor,
                        fontSize: 22.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _LuckyHeaderPainter extends CustomPainter {
  const _LuckyHeaderPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFE94B3F), Color(0xFFE23D32)],
      ).createShader(Offset.zero & size);

    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height * 0.78)
      ..quadraticBezierTo(
        size.width * 0.5,
        size.height * 1.08,
        0,
        size.height * 0.78,
      )
      ..close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
