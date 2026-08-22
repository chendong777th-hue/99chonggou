import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/chat_cards/chat_wallet_card_metrics.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';

class RedPacketCard extends StatelessWidget {
  final String msg;
  final String status;
  final String? title;
  final String? typeLabel;
  final String? iconUrl;
  final bool useReceiverAvatar;
  final String? receiverUserId;
  final String? receiverName;
  final String? groupId;
  final String? receiverFaceUrl;
  final String? amountText;
  final String? packetCountText;
  final String? progressText;
  final String timeText;
  final bool isSelf;
  final String? packetType;
  /// 本地记录：用户已点击/拆开过该红包（服务端仍为 pending 时也做视觉区分）。
  final bool openedLocally;
  final VoidCallback? onTap;

  const RedPacketCard({
    super.key,
    required this.msg,
    required this.status,
    this.title,
    this.typeLabel,
    this.iconUrl,
    this.useReceiverAvatar = false,
    this.receiverUserId,
    this.receiverName,
    this.groupId,
    this.receiverFaceUrl,
    this.packetType,
    this.amountText,
    this.packetCountText,
    this.progressText,
    required this.timeText,
    this.isSelf = false,
    this.openedLocally = false,
    this.onTap,
  });

  String _state() {
    final value = status.trim().toLowerCase();
    if (value == 'empty' ||
        value == 'finished' ||
        value == 'fully_claimed' ||
        value == 'claimed_all' ||
        value == '已抢完') {
      return 'empty';
    }
    if (value == 'claimed' || value == 'received' || value == '已领取') {
      return 'claimed';
    }
    if (value == 'viewed' || value == '已查看') {
      return 'viewed';
    }
    if (value == 'refunded' || value == '已退款') {
      return 'refunded';
    }
    if (value == 'expired' || value == '已过期') {
      return 'expired';
    }
    if (value == 'failed' || value == 'failure' || value == 'error') {
      return 'failed';
    }
    if (value == 'success') {
      return 'available';
    }
    return 'available';
  }

  String _headlineText(bool isExclusive) {
    if (isExclusive && (title?.trim().isNotEmpty ?? false)) {
      return title!.trim();
    }
    final greeting = msg.trim();
    if (greeting.isNotEmpty) return greeting;
    return '恭喜发财，大吉大利';
  }

  String? _statusLine(String state) {
    switch (state) {
      case 'empty':
        return '已被领完';
      case 'claimed':
        return '已领取';
      case 'viewed':
        return '已查看';
      case 'refunded':
        return '已退款';
      case 'expired':
        return '已过期';
      case 'failed':
        return '红包异常';
      default:
        return null;
    }
  }

  String? _packetCountLine() {
    final count = packetCountText?.trim();
    if (count == null || count.isEmpty || count == '0') {
      return null;
    }
    return '共$count个红包';
  }

  @override
  Widget build(BuildContext context) {
    double w(num value) => ChatWalletCardMetrics.w(value);
    double h(num value) => ChatWalletCardMetrics.h(value);
    double cardSp(num value) => ChatWalletCardMetrics.cardSp(value);
    double r(num value) => ChatWalletCardMetrics.r(value);

    var state = _state();
    if (openedLocally && state == 'available') {
      state = 'viewed';
    }
    final isExclusive = useReceiverAvatar;
    final headline = _headlineText(isExclusive);
    final amount = amountText?.trim();
    final packetCountLine = _packetCountLine();
    final statusLine = _statusLine(state);
    final label = typeLabel?.trim() ?? '';
    final isUnopened = state == 'available';
    final isInactive = !isUnopened;
    final radius = BorderRadius.all(Radius.circular(r(AppTokens.rLg)));
    final baseTheme = _RedPacketCardTheme.fromPacketType(packetType);
    final theme = isUnopened ? baseTheme : baseTheme.opened();

    return LayoutBuilder(
      builder: (context, constraints) {
        final cardWidth = ChatWalletCardMetrics.clampCardWidth(
          constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : ChatWalletCardMetrics.maxWidth,
        );
        final tailOverhang = w(9);

        return SizedBox(
          width: cardWidth,
          child: Stack(
            clipBehavior: Clip.hardEdge,
            children: [
              if (!isSelf)
                Positioned(
                  left: 0,
                  top: h(22),
                  child: Transform.flip(
                    flipX: true,
                    child: CustomPaint(
                      size: Size(w(14), h(24)),
                      painter: _RedPacketTailPainter(color: theme.body),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(
                  left: isSelf ? 0 : tailOverhang,
                  right: isSelf ? tailOverhang : 0,
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    onTap: onTap,
                    borderRadius: radius,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [theme.bodyHighlight, theme.body],
                        ),
                        borderRadius: radius,
                        boxShadow: isUnopened
                            ? [
                                BoxShadow(
                                  color: theme.body.withValues(alpha: 0.18),
                                  blurRadius: 10,
                                  offset: Offset(0, h(3)),
                                ),
                              ]
                            : null,
                      ),
                      child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              ConstrainedBox(
                                constraints: BoxConstraints(
                                  minHeight: ChatWalletCardMetrics.minBodyHeight,
                                ),
                                child: Align(
                                  alignment: Alignment.topLeft,
                                  child: Padding(
                                    padding: EdgeInsets.fromLTRB(
                                      w(16),
                                      h(12),
                                      w(16),
                                      h(8),
                                    ),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.only(top: h(2)),
                                          child: _RedPacketLeading(
                                            iconUrl: iconUrl,
                                            size: ChatWalletCardMetrics
                                                .iconSize(),
                                            iconBg: theme.iconBg,
                                            useReceiverAvatar:
                                                useReceiverAvatar,
                                            receiverUserId: receiverUserId,
                                            receiverName: receiverName ?? '',
                                            groupId: groupId,
                                            receiverFaceUrl: receiverFaceUrl,
                                            dimmed: isInactive,
                                            dimStrength:
                                                isInactive ? 0.72 : 1,
                                          ),
                                        ),
                                        SizedBox(width: w(12)),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Text(
                                                headline,
                                                maxLines: 1,
                                                overflow: TextOverflow.ellipsis,
                                                style: TextStyle(
                                                  color: theme.title,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  height: 1.12,
                                                ),
                                              ),
                                              if (state == 'available' &&
                                                  ((amount != null &&
                                                          amount.isNotEmpty) ||
                                                      packetCountLine !=
                                                          null)) ...[
                                                SizedBox(height: h(8)),
                                                Text.rich(
                                                  TextSpan(
                                                    children: [
                                                      if (amount != null &&
                                                          amount.isNotEmpty)
                                                        TextSpan(
                                                          text: amount,
                                                          style: TextStyle(
                                                            color: theme.title,
                                                            fontSize:
                                                                cardSp(32),
                                                            fontWeight:
                                                                FontWeight.w700,
                                                            height: 1.1,
                                                            letterSpacing: 0.4,
                                                          ),
                                                        ),
                                                      if (amount != null &&
                                                          amount.isNotEmpty &&
                                                          packetCountLine !=
                                                              null)
                                                        TextSpan(
                                                          text: ' · ',
                                                          style: TextStyle(
                                                            color:
                                                                theme.subtitle,
                                                            fontSize:
                                                                cardSp(22),
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            height: 1.1,
                                                          ),
                                                        ),
                                                      if (packetCountLine !=
                                                          null)
                                                        TextSpan(
                                                          text: packetCountLine,
                                                          style: TextStyle(
                                                            color:
                                                                theme.subtitle,
                                                            fontSize:
                                                                cardSp(22),
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            height: 1.1,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                ),
                                              ] else if (statusLine !=
                                                  null) ...[
                                                SizedBox(height: h(10)),
                                                Text(
                                                  statusLine,
                                                  maxLines: 1,
                                                  overflow:
                                                      TextOverflow.ellipsis,
                                                  style: TextStyle(
                                                    color: theme.subtitle,
                                                    fontSize: cardSp(22),
                                                    fontWeight: FontWeight.w500,
                                                    height: 1.12,
                                                  ),
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: w(16),
                                  vertical: h(8),
                                ),
                                decoration: BoxDecoration(
                                  color: theme.footer.withValues(alpha: 0.92),
                                  borderRadius: BorderRadius.only(
                                    bottomLeft: Radius.circular(r(14)),
                                    bottomRight: Radius.circular(r(14)),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        label.isNotEmpty
                                            ? label
                                            : '99Chat红包',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: theme.footerText,
                                          fontSize: ChatWalletCardMetrics
                                              .footerSp(20),
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      timeText,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: theme.footerText,
                                        fontSize: ChatWalletCardMetrics
                                            .footerSp(20),
                                        fontWeight: FontWeight.w500,
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
                  ),
              if (isSelf)
                Positioned(
                  right: 0,
                  top: h(22),
                  child: CustomPaint(
                    size: Size(w(14), h(24)),
                    painter: _RedPacketTailPainter(color: theme.body),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// 聊天红包卡片配色：专属 / 拼手气 / 普通 统一用普通红包橙色。
class _RedPacketCardTheme {
  final Color body;
  final Color bodyHighlight;
  final Color footer;
  final Color iconBg;
  final Color title;
  final Color subtitle;
  final Color meta;
  final Color footerText;

  const _RedPacketCardTheme({
    required this.body,
    required this.bodyHighlight,
    required this.footer,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.meta,
    required this.footerText,
  });

  static const _normal = _RedPacketCardTheme(
    body: Color(0xFFF55E44),
    bodyHighlight: Color(0xFFFA6A4E),
    footer: Color(0xFFE8553C),
    iconBg: Color(0xFFFFF4E8),
    title: Color(0xFFFFFBF5),
    subtitle: Color(0xFFFFE8C4),
    meta: Color(0xFFFFDDB8),
    footerText: Color(0xFFFFD4B0),
  );

  /// 已点击 / 已领取：同色系明显变亮偏白，并略降饱和。
  _RedPacketCardTheme opened() {
    return _RedPacketCardTheme(
      body: _openedTone(body, towardWhite: 0.34, saturation: 0.72),
      bodyHighlight: _openedTone(bodyHighlight, towardWhite: 0.40, saturation: 0.76),
      footer: _openedTone(footer, towardWhite: 0.30, saturation: 0.70),
      iconBg: _openedTone(iconBg, towardWhite: 0.22, saturation: 0.85),
      title: _openedTone(title, towardWhite: 0.10, saturation: 0.92),
      subtitle: _openedTone(subtitle, towardWhite: 0.18, saturation: 0.80),
      meta: _openedTone(meta, towardWhite: 0.20, saturation: 0.78),
      footerText: _openedTone(footerText, towardWhite: 0.24, saturation: 0.75),
    );
  }

  static Color _openedTone(
    Color color, {
    required double towardWhite,
    required double saturation,
  }) {
    final lightened =
        Color.lerp(color, Colors.white, towardWhite.clamp(0.0, 1.0))!;
    final hsl = HSLColor.fromColor(lightened);
    return hsl
        .withSaturation((hsl.saturation * saturation).clamp(0.0, 1.0))
        .toColor();
  }

  factory _RedPacketCardTheme.fromPacketType(String? packetType) {
    return _normal;
  }
}

class _RedPacketTailPainter extends CustomPainter {
  final Color color;

  const _RedPacketTailPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    final path = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(
        size.width * 0.88,
        size.height * 0.14,
        size.width * 0.92,
        size.height * 0.46,
      )
      ..quadraticBezierTo(
        size.width * 0.96,
        size.height * 0.78,
        0,
        size.height,
      )
      ..close();
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _RedPacketTailPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class _RedPacketLeading extends StatelessWidget {
  final String? iconUrl;
  final double size;
  final Color iconBg;
  final bool useReceiverAvatar;
  final String? receiverUserId;
  final String receiverName;
  final String? groupId;
  final String? receiverFaceUrl;
  final bool dimmed;
  final double dimStrength;

  const _RedPacketLeading({
    required this.iconUrl,
    required this.size,
    required this.iconBg,
    this.useReceiverAvatar = false,
    this.receiverUserId,
    this.receiverName = '',
    this.groupId,
    this.receiverFaceUrl,
    this.dimmed = false,
    this.dimStrength = 1,
  });

  Widget _wrapDimmed(Widget child) {
    if (!dimmed) return child;
    return Opacity(opacity: dimStrength.clamp(0.0, 1.0), child: child);
  }

  @override
  Widget build(BuildContext context) {
    if (useReceiverAvatar) {
      var faceUrl = UserAvatarHelper.usableAvatarOrEmpty(receiverFaceUrl);
      if (faceUrl.isEmpty) {
        faceUrl = UserAvatarHelper.usableAvatarOrEmpty(iconUrl);
      }
      if (faceUrl.isEmpty) {
        faceUrl = UserAvatarHelper.groupMemberFaceUrl(groupId, receiverUserId);
      }
      return _wrapDimmed(
        SizedBox(
          width: size,
          height: size,
          child: AppUserAvatar(
            faceUrl: faceUrl,
            showName: receiverName.trim().isNotEmpty
                ? receiverName.trim()
                : (receiverUserId?.trim() ?? ''),
            size: size,
          ),
        ),
      );
    }

    return _wrapDimmed(
      ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.asset(
          'assets/img/red_packet_icon.png',
          width: size,
          height: size,
          fit: BoxFit.cover,
        ),
      ),
    );
  }
}
