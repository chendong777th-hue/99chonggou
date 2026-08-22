import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/record/wallet_record_screen.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/wallet_page_colors.dart';
import 'package:tencent_cloud_chat_demo/src/utils/immersive_app_system_ui.dart';

/// 红包头图区域主色，用于沉浸式状态栏图标明暗估算。
const Color kRedPacketHeaderTone = Color(0xFFD4382A);

double redPacketDetailNavHeight(BuildContext context) {
  return MediaQuery.paddingOf(context).top + kToolbarHeight;
}

SystemUiOverlayStyle redPacketImmersiveOverlayStyle(BuildContext context) {
  final cs = WalletPageColors.of(context);
  return immersiveOverlayForColors(
    statusBarBackground: kRedPacketHeaderTone,
    navigationBarBackground: cs.bg,
  );
}

PreferredSizeWidget buildRedPacketDetailAppBar(
  BuildContext context, {
  VoidCallback? onBack,
  bool immersive = false,
}) {
  final i18n = AppI18n.of(context);
  final appBar = WalletAppBarColors.of(context);
  final titleColor = immersive ? Colors.white : appBar.title;
  final iconColor = immersive ? Colors.white : appBar.icon;

  return AppBar(
    iconTheme: IconThemeData(color: iconColor),
    centerTitle: true,
    elevation: 0,
    shadowColor: Colors.transparent,
    surfaceTintColor: Colors.transparent,
    backgroundColor: immersive ? Colors.transparent : appBar.background,
    foregroundColor: titleColor,
    systemOverlayStyle: immersive
        ? redPacketImmersiveOverlayStyle(context)
        : walletPageOverlayStyle(context),
    leading: onBack == null
        ? null
        : BackButton(
            color: iconColor,
            onPressed: onBack,
          ),
    automaticallyImplyLeading: onBack == null,
    title: Text(
      i18n.t(
        zhHans: '红包详情',
        zhHant: '紅包詳情',
        en: 'Red Packet Details',
        ja: '紅包詳細',
        ko: '레드패킷 상세',
      ),
      style: TextStyle(
        fontSize: 17,
        fontWeight: FontWeight.w600,
        color: titleColor,
      ),
    ),
    actions: [
      IconButton(
        tooltip: i18n.t(
          zhHans: '更多',
          zhHant: '更多',
          en: 'More',
          ja: 'その他',
          ko: '더보기',
        ),
        onPressed: () => _showRedPacketMoreMenu(context),
        icon: Icon(
          Icons.more_horiz_rounded,
          color: iconColor,
          size: 28,
        ),
      ),
      const SizedBox(width: 4),
    ],
  );
}

enum _RedPacketMoreAction { records }

Future<void> _showRedPacketMoreMenu(BuildContext context) async {
  final i18n = AppI18n.of(context);
  final cs = WalletPageColors.of(context);
  final action = await showModalBottomSheet<_RedPacketMoreAction>(
    context: context,
    backgroundColor: Colors.transparent,
    barrierColor: Colors.black.withValues(alpha: 0.42),
    useSafeArea: true,
    builder: (sheetContext) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Material(
              color: cs.card,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(sheetContext).pop(
                  _RedPacketMoreAction.records,
                ),
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: Text(
                      i18n.t(
                        zhHans: '红包记录',
                        zhHant: '紅包記錄',
                        en: 'Red Packet History',
                        ja: '紅包履歴',
                        ko: '레드패킷 기록',
                      ),
                      style: TextStyle(
                        color: cs.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Material(
              color: cs.card,
              borderRadius: BorderRadius.circular(14),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => Navigator.of(sheetContext).pop(),
                child: SizedBox(
                  height: 56,
                  child: Center(
                    child: Text(
                      i18n.t(
                        zhHans: '取消',
                        zhHant: '取消',
                        en: 'Cancel',
                        ja: 'キャンセル',
                        ko: '취소',
                      ),
                      style: TextStyle(
                        color: cs.text,
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
  if (action != _RedPacketMoreAction.records || !context.mounted) {
    return;
  }
  await Navigator.of(context).push(
    AppMaterialPageRoute(
      builder: (_) => const WalletRecordScreen(),
    ),
  );
}

Widget buildRedPacketDetailFooter(BuildContext context) {
  final cs = WalletPageColors.of(context);
  final i18n = AppI18n.of(context);
  final bottomInset = MediaQuery.paddingOf(context).bottom;

  return Padding(
    padding: EdgeInsets.fromLTRB(24, 12, 24, 12 + bottomInset),
    child: Text(
      i18n.t(
        zhHans: '超过24小时未领取红包将自动退回。',
        zhHant: '超過24小時未領取紅包將自動退回。',
        en: 'Unclaimed red packets will be refunded after 24 hours.',
        ja: '24時間以内に受け取られなかった紅包は自動返金されます。',
        ko: '24시간 내에 수령하지 않은 홍바오는 자동 환불됩니다.',
      ),
      textAlign: TextAlign.center,
      style: TextStyle(
        color: cs.subText,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        height: 1.4,
      ),
    ),
  );
}
