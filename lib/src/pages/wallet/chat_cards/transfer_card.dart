import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/chat_cards/chat_wallet_card_metrics.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/transfer_party_name_resolver.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_user_avatar.dart';
import 'package:tencent_cloud_chat_demo/utils/user_avatar.dart';

const String _transferArrowIconSvg = '''
<svg viewBox="0 0 1024 1024" xmlns="http://www.w3.org/2000/svg">
  <path d="M512 993.28C245.76 993.28 30.72 778.24 30.72 512S245.76 30.72 512 30.72s481.28 215.04 481.28 481.28-215.04 481.28-481.28 481.28z m0-880.64c-220.16 0-399.36 179.2-399.36 399.36s179.2 399.36 399.36 399.36 399.36-179.2 399.36-399.36-179.2-399.36-399.36-399.36z"></path>
  <path d="M281.6 491.52h450.56c5.12 0 10.24 0 15.36-5.12 10.24-5.12 15.36-10.24 20.48-20.48 5.12-10.24 5.12-20.48 0-30.72 0-5.12-5.12-10.24-10.24-15.36l-148.48-148.48c-15.36-15.36-40.96-15.36-56.32 0s-15.36 40.96 0 56.32L634.88 409.6H281.6c-20.48 0-40.96 20.48-40.96 40.96s20.48 40.96 40.96 40.96zM742.4 532.48H291.84c-5.12 0-10.24 0-15.36 5.12-10.24 5.12-15.36 10.24-20.48 20.48-5.12 10.24-5.12 20.48 0 30.72 0 5.12 5.12 10.24 10.24 15.36l148.48 148.48c10.24 10.24 20.48 10.24 30.72 10.24 10.24 0 20.48-5.12 30.72-10.24 15.36-15.36 15.36-40.96 0-56.32L389.12 614.4h353.28c20.48 0 40.96-20.48 40.96-40.96s-20.48-40.96-40.96-40.96z"></path>
</svg>
''';

/// 转账卡片配色：偏珊瑚红，饱和度低于红包卡片，避免刺眼。
abstract final class _TransferCardColors {
  static const Color body = Color(0xFFD47166);
  static const Color footer = Color(0xFFC06258);
  static const Color iconBg = Color(0xFFFFF1EE);
  static const Color icon = Color(0xFFA85A52);
  static const Color title = Color(0xFFFFF9F7);
  static const Color subtitle = Color(0xFFFFECE8);
  static const Color footerText = Color(0xFFFFDED8);
}

class TransferCard extends StatelessWidget {
  final String amount;
  final String coin;
  final String status;
  final String? memo;
  final bool isSelf;
  final String timeText;
  final VoidCallback? onTap;

  /// 群转账：左侧显示收款人头像，主标题「转账给{name}」，下一行金额。
  final bool isGroupTransfer;
  final String? receiverUserId;
  final String? receiverName;
  final String? receiverFaceUrl;
  final String? groupId;

  const TransferCard({
    super.key,
    required this.amount,
    required this.coin,
    required this.status,
    this.memo,
    this.isSelf = false,
    this.timeText = '--:--',
    this.onTap,
    this.isGroupTransfer = false,
    this.receiverUserId,
    this.receiverName,
    this.receiverFaceUrl,
    this.groupId,
  });

  String _normalizedStatus() {
    final value = status.trim().toLowerCase();
    switch (value) {
      case 'success':
      case 'completed':
      case '已完成':
      case '成功':
        return 'success';
      case 'failed':
      case 'failure':
      case 'cancelled':
      case 'canceled':
      case '失败':
        return 'failed';
      case 'expired':
      case '已过期':
        return 'expired';
      case 'refunded':
      case '已退款':
        return 'refunded';
      case 'pending':
      case 'accepted':
      case 'unknown':
      case 'processing':
      case '处理中':
        return 'pending';
      default:
        return 'pending';
    }
  }

  String _amountPart() {
    final amountText = amount.trim();
    final coinText = coin.trim();
    if (amountText.isEmpty) {
      return '';
    }
    return coinText.isEmpty ? amountText : '$amountText $coinText';
  }

  String _groupReceiverLabel(AppI18n i18n) {
    final cleaned = TransferPartyNameResolver.sanitizeDisplayName(
      receiverName,
      userId: receiverUserId,
      groupId: groupId,
    );
    if (cleaned.isNotEmpty) {
      return cleaned;
    }
    return i18n.t(
      zhHans: '对方',
      zhHant: '對方',
      en: 'recipient',
      ja: '相手',
      ko: '상대',
    );
  }

  String _titleText(AppI18n i18n) {
    final amountPart = _amountPart();
    if (isGroupTransfer) {
      final name = _groupReceiverLabel(i18n);
      return i18n.format(
        zhHans: '转账给{name}',
        zhHant: '轉帳給{name}',
        en: 'Transfer to {name}',
        ja: '{name}へ送金',
        ko: '{name}님에게 이체',
        vars: {'name': name},
      );
    }
    if (amountPart.isEmpty) {
      return i18n.t(
        zhHans: '转账',
        zhHant: '轉帳',
        en: 'Transfer',
        ja: '送金',
        ko: '이체',
      );
    }
    return i18n.format(
      zhHans: '转账 {amount}',
      zhHant: '轉帳 {amount}',
      en: 'Transfer {amount}',
      ja: '送金 {amount}',
      ko: '이체 {amount}',
      vars: {'amount': amountPart},
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    double w(num value) => ChatWalletCardMetrics.w(value);
    double h(num value) => ChatWalletCardMetrics.h(value);
    double sp(num value) => ChatWalletCardMetrics.sp(value);
    double r(num value) => ChatWalletCardMetrics.r(value);
    final borderRadius = BorderRadius.circular(r(AppTokens.rLg));
    final title = _titleText(i18n);
    final groupAmount = isGroupTransfer ? _amountPart() : '';
    final cleanedReceiverName = isGroupTransfer
        ? TransferPartyNameResolver.sanitizeDisplayName(
            receiverName,
            userId: receiverUserId,
            groupId: groupId,
          )
        : (receiverName ?? '');
    final normalizedStatus = _normalizedStatus();
    final memoText = memo?.trim() ?? '';
    final actionText = switch (normalizedStatus) {
      'failed' => i18n.t(
          zhHans: '转账失败',
          zhHant: '轉帳失敗',
          en: 'Transfer failed',
          ja: '送金に失敗しました',
          ko: '이체 실패',
        ),
      'expired' => i18n.t(
          zhHans: '转账已过期',
          zhHant: '轉帳已過期',
          en: 'Transfer expired',
          ja: '送金の有効期限が切れました',
          ko: '이체가 만료되었습니다',
        ),
      'refunded' => i18n.t(
          zhHans: '转账已退款',
          zhHant: '轉帳已退款',
          en: 'Transfer refunded',
          ja: '送金は返金されました',
          ko: '이체가 환불되었습니다',
        ),
      _ when memoText.isNotEmpty && !isGroupTransfer => memoText,
      _ when isGroupTransfer => '',
      _ => isSelf
          ? i18n.t(
              zhHans: '你发起一笔转账',
              zhHant: '你發起一筆轉帳',
              en: 'You initiated a transfer',
              ja: '送金を開始しました',
              ko: '이체를 시작했습니다',
            )
          : i18n.t(
              zhHans: '您有一笔转账',
              zhHant: '您有一筆轉帳',
              en: 'You received a transfer',
              ja: '送金が届きました',
              ko: '이체가 도착했습니다',
            ),
    };

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
                      painter: _TransferTailPainter(),
                    ),
                  ),
                ),
              Padding(
                padding: EdgeInsets.only(
                  left: isSelf ? 0 : tailOverhang,
                  right: isSelf ? tailOverhang : 0,
                ),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: borderRadius,
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      color: _TransferCardColors.body,
                      borderRadius: borderRadius,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: ChatWalletCardMetrics.minBodyHeight,
                          ),
                          child: Align(
                            alignment: Alignment.topLeft,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(
                                  w(16), h(12), w(16), h(8)),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: EdgeInsets.only(top: h(2)),
                                    child: _TransferLeading(
                                      size: ChatWalletCardMetrics.iconSize(),
                                      useReceiverAvatar: isGroupTransfer,
                                      receiverUserId: receiverUserId,
                                      receiverName: cleanedReceiverName,
                                      groupId: groupId,
                                      receiverFaceUrl: receiverFaceUrl,
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
                                          title,
                                          maxLines: isGroupTransfer ? 1 : 2,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: _TransferCardColors.title,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w500,
                                            height: 1.12,
                                          ),
                                        ),
                                        if (groupAmount.isNotEmpty) ...[
                                          SizedBox(height: h(2)),
                                          Text(
                                            groupAmount,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: _TransferCardColors.title,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w500,
                                              height: 1.12,
                                            ),
                                          ),
                                        ],
                                        if (actionText.isNotEmpty) ...[
                                          SizedBox(height: h(6)),
                                          Text(
                                            actionText,
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              color: _TransferCardColors.subtitle,
                                              fontSize: sp(22),
                                              fontWeight: FontWeight.w500,
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
                              horizontal: w(16), vertical: h(8)),
                          decoration: BoxDecoration(
                            color: _TransferCardColors.footer,
                            borderRadius: BorderRadius.only(
                              bottomLeft: Radius.circular(r(14)),
                              bottomRight: Radius.circular(r(14)),
                            ),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  '99Chat',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    color: _TransferCardColors.footerText,
                                    fontSize:
                                        ChatWalletCardMetrics.footerSp(18),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                              Text(
                                timeText,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: _TransferCardColors.footerText,
                                  fontSize: ChatWalletCardMetrics.footerSp(18),
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
              if (isSelf)
                Positioned(
                  right: 0,
                  top: h(22),
                  child: CustomPaint(
                    size: Size(w(14), h(24)),
                    painter: _TransferTailPainter(),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _TransferLeading extends StatelessWidget {
  final double size;
  final bool useReceiverAvatar;
  final String? receiverUserId;
  final String receiverName;
  final String? groupId;
  final String? receiverFaceUrl;

  const _TransferLeading({
    required this.size,
    this.useReceiverAvatar = false,
    this.receiverUserId,
    this.receiverName = '',
    this.groupId,
    this.receiverFaceUrl,
  });

  @override
  Widget build(BuildContext context) {
    if (useReceiverAvatar) {
      var faceUrl = UserAvatarHelper.usableAvatarOrEmpty(receiverFaceUrl);
      if (faceUrl.isEmpty) {
        faceUrl = UserAvatarHelper.groupMemberFaceUrl(groupId, receiverUserId);
      }
      return SizedBox(
        width: size,
        height: size,
        child: AppUserAvatar(
          faceUrl: faceUrl,
          showName: receiverName.trim().isNotEmpty
              ? receiverName.trim()
              : (receiverUserId?.trim() ?? ''),
          size: size,
        ),
      );
    }

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(size * 0.18),
      decoration: BoxDecoration(
        color: _TransferCardColors.iconBg,
        borderRadius: BorderRadius.circular(AppTokens.rMd),
      ),
      child: SvgPicture.string(
        _transferArrowIconSvg,
        fit: BoxFit.contain,
        colorFilter: const ColorFilter.mode(
          _TransferCardColors.icon,
          BlendMode.srcIn,
        ),
      ),
    );
  }
}

class _TransferTailPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = _TransferCardColors.body;
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
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
