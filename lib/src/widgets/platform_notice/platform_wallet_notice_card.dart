import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';

/// 伪公众号钱包 / 资金类通知类型。
enum PlatformWalletNoticeType {
  withdraw,
  deposit,
  flashExchange,
  setTradePassword,
  changeTradePassword,
  redPacketRefund,
  lifePayment,
  general,
}

class PlatformWalletNoticeRow {
  final String label;
  final String value;
  final bool emphasize;

  const PlatformWalletNoticeRow({
    required this.label,
    required this.value,
    this.emphasize = false,
  });
}

/// 微信支付助手风格通知数据。
class PlatformWalletNoticeData {
  final PlatformWalletNoticeType type;
  final String title;
  /// 卡片顶栏服务名，默认「支付助手」。
  final String? serviceName;
  final String? statusLabel;
  final List<PlatformWalletNoticeRow> rows;
  final String? summary;
  final String? actionLabel;
  final String? actionUrl;
  final String? orderId;
  final VoidCallback? onAction;

  const PlatformWalletNoticeData({
    required this.type,
    required this.title,
    this.serviceName,
    this.statusLabel,
    this.rows = const [],
    this.summary,
    this.actionLabel,
    this.actionUrl,
    this.orderId,
    this.onAction,
  });

  String resolvedServiceName(BuildContext context) {
    final name = serviceName?.trim() ?? '';
    if (name.isNotEmpty) {
      return name;
    }
    return AppI18n.of(context).t(
      zhHans: '支付助手',
      zhHant: '支付助手',
      en: 'Payment Assistant',
      ja: '支払いアシスタント',
      ko: '결제 도우미',
    );
  }
}

/// 伪公众号会话内的钱包通知卡片（微信支付助手样式：白底、顶栏服务名、标题、明细行）。
class PlatformWalletNoticeCard extends StatelessWidget {
  final PlatformWalletNoticeData data;
  final double maxWidth;

  const PlatformWalletNoticeCard({
    super.key,
    required this.data,
    this.maxWidth = 300,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final dark = Provider.of<DefaultThemeData>(context, listen: false)
            .currentThemeType ==
        ThemeType.dark;
    final cardBg = dark ? const Color(0xFF1B1D22) : Colors.white;
    final textColor = theme.darkTextColor ?? const Color(0xFF191919);
    final subColor = theme.weakTextColor ?? const Color(0xFF888888);
    final lineColor = theme.weakDividerColor ?? const Color(0xFFE5E5E5);
    final serviceName = data.resolvedServiceName(context);
    final status = data.statusLabel?.trim() ?? '';

    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(2),
          topRight: Radius.circular(10),
          bottomLeft: Radius.circular(10),
          bottomRight: Radius.circular(10),
        ),
        border: Border.all(
          color: dark ? const Color(0xFF2A2D33) : const Color(0xFFE6E6E6),
          width: 0.5,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 8),
            child: Text(
              serviceName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: subColor,
                height: 1.2,
              ),
            ),
          ),
          Divider(height: 1, thickness: 0.5, color: lineColor),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 6),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Text(
                    data.title,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 1.35,
                      color: textColor,
                    ),
                  ),
                ),
                if (status.isNotEmpty) ...[
                  const SizedBox(width: 8),
                  Text(
                    status,
                    style: TextStyle(
                      fontSize: 13,
                      color: subColor,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (data.summary != null && data.summary!.trim().isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
              child: Text(
                data.summary!.trim(),
                style: TextStyle(
                  fontSize: 13,
                  height: 1.45,
                  color: subColor,
                ),
              ),
            ),
          if (data.rows.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              child: Column(
                children: [
                  for (var i = 0; i < data.rows.length; i++) ...[
                    if (i > 0) const SizedBox(height: 6),
                    _NoticeRow(
                      row: data.rows[i],
                      textColor: textColor,
                      subColor: subColor,
                    ),
                  ],
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _NoticeRow extends StatelessWidget {
  final PlatformWalletNoticeRow row;
  final Color textColor;
  final Color subColor;

  const _NoticeRow({
    required this.row,
    required this.textColor,
    required this.subColor,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 76,
          child: Text(
            row.label,
            style: TextStyle(
              fontSize: 13,
              color: subColor,
              height: 1.4,
            ),
          ),
        ),
        Expanded(
          child: Text(
            row.value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: row.emphasize ? 15 : 13,
              fontWeight: row.emphasize ? FontWeight.w600 : FontWeight.w400,
              color: textColor,
              height: 1.4,
            ),
          ),
        ),
      ],
    );
  }
}

/// 静态预览 / 联调用的示例数据。
class PlatformWalletNoticeSamples {
  PlatformWalletNoticeSamples._();

  static const _serviceName = '支付助手';
  static const _time = '2026-05-28 14:32:18';
  static const _order = 'WD20260528143218001';

  static List<PlatformWalletNoticeData> all() => [
        withdrawSuccess,
        depositSuccess,
        flashExchangeSuccess,
        setTradePassword,
        changeTradePassword,
        redPacketRefund,
        generalNotice,
      ];

  static const withdrawSuccess = PlatformWalletNoticeData(
    type: PlatformWalletNoticeType.withdraw,
    serviceName: _serviceName,
    title: '提币成功',
    statusLabel: '成功',
    summary: '您的提币申请已处理完成，资产已从平台钱包转出。',
    rows: [
      PlatformWalletNoticeRow(
        label: '提币数量',
        value: '128.50 USDT',
        emphasize: true,
      ),
      PlatformWalletNoticeRow(
        label: '到账地址',
        value: 'TXyz9k…8f2A',
      ),
      PlatformWalletNoticeRow(label: '手续费', value: '1.00 USDT'),
      PlatformWalletNoticeRow(label: '订单号', value: _order),
      PlatformWalletNoticeRow(label: '时间', value: _time),
    ],
    actionLabel: '查看详情',
    orderId: _order,
  );

  static const depositSuccess = PlatformWalletNoticeData(
    type: PlatformWalletNoticeType.deposit,
    serviceName: _serviceName,
    title: '充币到账',
    statusLabel: '已到账',
    summary: '链上充币已确认，资产已计入您的钱包余额。',
    rows: [
      PlatformWalletNoticeRow(
        label: '充币数量',
        value: '500.00 USDT',
        emphasize: true,
      ),
      PlatformWalletNoticeRow(label: '网络', value: 'TRC20'),
      PlatformWalletNoticeRow(label: '确认数', value: '19/19'),
      PlatformWalletNoticeRow(label: '时间', value: _time),
    ],
    actionLabel: '查看详情',
  );

  static const flashExchangeSuccess = PlatformWalletNoticeData(
    type: PlatformWalletNoticeType.flashExchange,
    serviceName: _serviceName,
    title: '闪兑成功',
    statusLabel: '已完成',
    rows: [
      PlatformWalletNoticeRow(
        label: '支付',
        value: '100.00 USDT',
        emphasize: true,
      ),
      PlatformWalletNoticeRow(
        label: '获得',
        value: '685.00 99',
        emphasize: true,
      ),
      PlatformWalletNoticeRow(label: '汇率', value: '1 USDT = 6.85 99'),
      PlatformWalletNoticeRow(label: '订单号', value: 'EX202605281015001'),
      PlatformWalletNoticeRow(label: '时间', value: _time),
    ],
    actionLabel: '查看详情',
  );

  static const setTradePassword = PlatformWalletNoticeData(
    type: PlatformWalletNoticeType.setTradePassword,
    serviceName: _serviceName,
    title: '资金密码设置成功',
    rows: [
      PlatformWalletNoticeRow(label: '操作类型', value: '首次设置'),
      PlatformWalletNoticeRow(label: '设备', value: 'iPhone'),
      PlatformWalletNoticeRow(label: '时间', value: _time),
    ],
    actionLabel: '查看详情',
  );

  static const changeTradePassword = PlatformWalletNoticeData(
    type: PlatformWalletNoticeType.changeTradePassword,
    serviceName: _serviceName,
    title: '资金密码已修改',
    summary: '如非本人操作，请立即联系客服。',
    rows: [
      PlatformWalletNoticeRow(label: '操作类型', value: '修改密码'),
      PlatformWalletNoticeRow(label: '验证方式', value: '短信 + 旧密码'),
      PlatformWalletNoticeRow(label: '时间', value: _time),
    ],
    actionLabel: '查看详情',
  );

  static const redPacketRefund = PlatformWalletNoticeData(
    type: PlatformWalletNoticeType.redPacketRefund,
    serviceName: _serviceName,
    title: '红包退回',
    statusLabel: '已退回',
    rows: [
      PlatformWalletNoticeRow(
        label: '退回金额',
        value: '88.00 USDT',
        emphasize: true,
      ),
      PlatformWalletNoticeRow(label: '红包类型', value: '群红包'),
      PlatformWalletNoticeRow(label: '原订单', value: 'RP20260528001'),
      PlatformWalletNoticeRow(label: '时间', value: _time),
    ],
    actionLabel: '查看详情',
  );

  static const generalNotice = PlatformWalletNoticeData(
    type: PlatformWalletNoticeType.general,
    serviceName: _serviceName,
    title: '账户通知',
    summary: '您的账户已完成实名认证，现已开通完整钱包功能。',
    rows: [
      PlatformWalletNoticeRow(label: '消息类型', value: '账户通知'),
      PlatformWalletNoticeRow(label: '时间', value: _time),
    ],
    actionLabel: '查看详情',
  );
}
