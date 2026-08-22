import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/platform_notice/platform_wallet_notice_card.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/official_account_name_label.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';

/// 伪公众号钱包通知样式静态预览（Debug / 设计稿对照）。
class PlatformWalletNoticePreviewPage extends StatelessWidget {
  const PlatformWalletNoticePreviewPage({super.key});

  static void openIfDebug(BuildContext context) {
    if (!kDebugMode) return;
    Navigator.of(context).push(
      AppMaterialPageRoute<void>(
        builder: (_) => const PlatformWalletNoticePreviewPage(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final dark = Provider.of<DefaultThemeData>(context).currentThemeType ==
        ThemeType.dark;
    final chatBg = dark
        ? (theme.wideBackgroundColor ?? const Color(0xFF101114))
        : const Color(0xFFEDEDED);
    final appBarBg = theme.appbarBgColor ?? Colors.white;
    final titleColor = theme.appbarTextColor ?? theme.darkTextColor;
    final samples = PlatformWalletNoticeSamples.all();
    final resolvedAccountName =
        PlatformOfficialAccountService.resolveShowName(
      userId: IMDemoConfig.platformOfficialAccountId,
    );
    final accountName =
        resolvedAccountName.isNotEmpty ? resolvedAccountName : '支付助手';

    return Scaffold(
      backgroundColor: chatBg,
      appBar: AppBar(
        centerTitle: true,
        elevation: 0,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        backgroundColor: appBarBg,
        foregroundColor: titleColor,
        title: Text(
          i18n.t(
            zhHans: '支付助手通知预览',
            zhHant: '支付助手通知預覽',
            en: 'Payment Assistant Notice Preview',
            ja: '公式アカウント通知プレビュー',
            ko: '공식 계정 알림 미리보기',
          ),
          style: TextStyle(
            fontSize: 17,
            fontWeight: FontWeight.w600,
            color: titleColor,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
        children: [
          _DateChip(
            label: i18n.t(
              zhHans: '今天 14:30',
              zhHant: '今天 14:30',
              en: 'Today 14:30',
              ja: '今日 14:30',
              ko: '오늘 14:30',
            ),
          ),
          const SizedBox(height: 8),
          for (final sample in samples) ...[
            _NoticeMessageRow(
              accountName: accountName,
              timeLabel: _timeLabelFor(sample.type),
              child: PlatformWalletNoticeCard(data: sample),
            ),
            const SizedBox(height: 14),
          ],
          _HintBanner(dark: dark),
        ],
      ),
    );
  }

  static String _timeLabelFor(PlatformWalletNoticeType type) {
    return switch (type) {
      PlatformWalletNoticeType.withdraw => '14:32',
      PlatformWalletNoticeType.deposit => '13:18',
      PlatformWalletNoticeType.flashExchange => '13:45',
      PlatformWalletNoticeType.setTradePassword => '12:05',
      PlatformWalletNoticeType.changeTradePassword => '11:42',
      PlatformWalletNoticeType.redPacketRefund => '10:20',
      PlatformWalletNoticeType.lifePayment => '09:30',
      PlatformWalletNoticeType.general => '09:00',
    };
  }
}

class _DateChip extends StatelessWidget {
  final String label;

  const _DateChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF666666),
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _NoticeMessageRow extends StatelessWidget {
  final String accountName;
  final String timeLabel;
  final Widget child;

  const _NoticeMessageRow({
    required this.accountName,
    required this.timeLabel,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Image.asset(
            'assets/img/platform_99.webp',
            width: 40,
            height: 40,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => SizedBox(
              width: 40,
              height: 40,
              child: Avatar(
                faceUrl: IMDemoConfig.platformOfficialAccountFaceUrl,
                showName: accountName,
                type: 1,
              ),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              OfficialAccountNameLabel(
                name: accountName,
                badgeSize: 14,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF888888),
                ),
              ),
              const SizedBox(height: 6),
              child,
              const SizedBox(height: 4),
              Text(
                timeLabel,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFFAAAAAA),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _HintBanner extends StatelessWidget {
  final bool dark;

  const _HintBanner({required this.dark});

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: dark ? const Color(0xFF1B1D22) : Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: dark ? const Color(0xFF2A2D33) : const Color(0xFFE3E6EB),
        ),
      ),
      child: Text(
        i18n.format(
          zhHans: '以上为「支付助手」风格静态预览（白底、顶栏服务名、标题、明细行、查看详情），共 {count} 种。联调请按 docs/backend-todo-platform-wallet-notice.md 下发 IM 自定义消息。',
          zhHant: '以上為「支付助手」風格靜態預覽，共 {count} 種。聯調請依 docs/backend-todo-platform-wallet-notice.md 下發 IM 自訂訊息。',
          en: 'Payment Assistant style static preview ({count} variants). See docs/backend-todo-platform-wallet-notice.md for IM custom message payload.',
          ja: 'これは静的プレビューです。全 {count} 種類の通知スタイルを収録しています：出金、入金、スワップ、資金パスワードの設定/変更、紅包返金、システム通知。',
          ko: '정적 미리보기이며 총 {count}가지 알림 스타일이 포함되어 있습니다: 출금, 입금, 스왑, 자금 비밀번호 설정/변경, 레드패킷 환불, 시스템 알림.',
          vars: {'count': PlatformWalletNoticeSamples.all().length.toString()},
        ),
        style: TextStyle(
          fontSize: 13,
          height: 1.5,
          color: dark ? const Color(0xFF9A9CA3) : const Color(0xFF7D7D7D),
        ),
      ),
    );
  }
}
