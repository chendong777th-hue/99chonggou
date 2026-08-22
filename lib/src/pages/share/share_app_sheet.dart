import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/tencent_chat_i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/src/services/share_app_service.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/conversation_share_picker_page.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/wallet_share_service.dart';
import 'package:tencent_cloud_chat_demo/src/navigation/app_page_transitions.dart';

/// 「我的 → 分享应用」底部弹窗。
class ShareAppSheet extends StatefulWidget {
  static const String logoAsset = 'assets/img/share_app_logo.png';

  const ShareAppSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      isDismissible: true,
      enableDrag: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.55),
      builder: (_) => const ShareAppSheet(),
    );
  }

  @override
  State<ShareAppSheet> createState() => _ShareAppSheetState();
}

class _ShareAppSheetState extends State<ShareAppSheet> {
  String _website = '';
  bool _loadingWebsite = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadWebsite();
    });
  }

  Future<void> _loadWebsite() async {
    final website = await ShareAppService.instance.resolveWebsite();
    if (!mounted) return;
    setState(() {
      _website = website;
      _loadingWebsite = false;
    });
  }

  bool _isDark(BuildContext context) {
    var dark = Theme.of(context).brightness == Brightness.dark;
    try {
      final themeType =
          Provider.of<DefaultThemeData>(context, listen: false).currentThemeType;
      dark = themeType == ThemeType.dark;
    } catch (_) {}
    return dark;
  }

  Future<void> _shareToFriend(BuildContext context) async {
    if (_website.isEmpty) {
      ToastUtils.toast(TIM_t('未配置'));
      return;
    }
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    Navigator.of(context).pop();
    final target = await Navigator.of(context).push<ConversationShareTarget>(
      AppFullscreenDialogRoute(
        builder: (_) => ConversationSharePickerPage(theme: theme),
      ),
    );
    if (target == null) return;
    final ok = await ShareAppService.instance.sendToTarget(target);
    if (ok) {
      ToastUtils.toast(TIM_t('已分享'));
    } else {
      ToastUtils.toast(TIM_t('分享失败'));
    }
  }

  Future<void> _copyLink(BuildContext context) async {
    if (_website.isEmpty) {
      ToastUtils.toast(TIM_t('未配置'));
      return;
    }
    final ok = await ShareAppService.instance.copyShareText();
    if (ok) {
      ToastUtils.toast(TIM_t('链接已复制'));
    } else {
      ToastUtils.toast(TIM_t('复制失败，请重试'));
    }
  }

  Future<void> _systemShare(BuildContext context) async {
    if (_website.isEmpty) {
      ToastUtils.toast(TIM_t('未配置'));
      return;
    }
    Navigator.of(context).pop();
    final ret = await ShareAppService.instance.systemShare();
    switch (ret) {
      case WalletSystemShareResult.success:
        break;
      case WalletSystemShareResult.unavailable:
        ToastUtils.toast(TIM_t('当前设备暂不支持系统分享'));
        break;
      case WalletSystemShareResult.failed:
        ToastUtils.toast(TIM_t('分享失败，请重试'));
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final dark = _isDark(context);
    final bg = AppColors.card(dark: dark);
    final text = AppColors.text(dark: dark);
    final subText = AppColors.subText(dark: dark);
    final line = AppColors.line(dark: dark);
    final shareUrlLabel = _loadingWebsite
        ? TIM_t('获取中')
        : (_website.isNotEmpty ? _website : TIM_t('未配置'));
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Stack(
      children: [
        Positioned.fill(
          child: GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            behavior: HitTestBehavior.translucent,
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: GestureDetector(
            onTap: () {},
            child: Container(
        decoration: BoxDecoration(
          color: bg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: EdgeInsets.fromLTRB(20, 8, 20, 12 + bottomInset),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 5,
                  decoration: BoxDecoration(
                    color: line,
                    borderRadius: BorderRadius.circular(99),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  TIM_t('分享应用'),
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: text,
                  ),
                ),
                const SizedBox(height: 18),
                GestureDetector(
                  onTap: () => _copyLink(context),
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: dark ? const Color(0xFF23262D) : const Color(0xFFF7F8FA),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: line),
                  ),
                  child: Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.asset(
                          ShareAppSheet.logoAsset,
                          width: 52,
                          height: 52,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => Image.asset(
                            'assets/img/platform_99.webp',
                            width: 52,
                            height: 52,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              IMDemoConfig.appName,
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w700,
                                color: text,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              TIM_t('安全、便捷的即时通讯'),
                              style: TextStyle(
                                fontSize: 13,
                                color: subText,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              shareUrlLabel,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 12,
                                color: AppColors.primaryBlue,
                                height: 1.3,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 88,
                  child: Row(
                    children: [
                      _ShareActionButton(
                        icon: Icons.person_add_alt_1_rounded,
                        label: TIM_t('发送给朋友'),
                        dark: dark,
                        onTap: () => _shareToFriend(context),
                      ),
                      _ShareActionButton(
                        icon: Icons.link_rounded,
                        label: TIM_t('复制链接'),
                        dark: dark,
                        onTap: () => _copyLink(context),
                      ),
                      _ShareActionButton(
                        icon: Icons.more_horiz_rounded,
                        label: TIM_t('更多'),
                        dark: dark,
                        onTap: () => _systemShare(context),
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
        ),
      ],
    );
  }
}

class _ShareActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool dark;
  final VoidCallback onTap;

  const _ShareActionButton({
    required this.icon,
    required this.label,
    required this.dark,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconBg = dark ? const Color(0xFF2A2D33) : const Color(0xFFF0F2F5);
    final text = AppColors.text(dark: dark);
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, size: 24, color: AppColors.primaryBlue),
              ),
              const SizedBox(height: 8),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 12, color: text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
