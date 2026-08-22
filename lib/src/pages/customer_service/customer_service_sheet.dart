import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/api/platform_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/customer_service/customer_service_loading_view.dart';
import 'package:tencent_cloud_chat_demo/src/pages/customer_service/customer_service_webview.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/customer_service_url_builder.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

/// 在线客服：底部固定 80% 高度面板（非可拖拽 BottomSheet），顶部圆角。
class CustomerServiceSheet extends StatefulWidget {
  const CustomerServiceSheet({super.key, this.guest = false});

  final bool guest;

  static const double sheetHeightFactor = 0.8;
  static const double sheetTopRadius = 16;
  static const BorderRadius sheetBorderRadius = BorderRadius.vertical(
    top: Radius.circular(sheetTopRadius),
  );

  static Future<void> show(BuildContext context, {bool guest = false}) {
    final i18n = AppI18n.of(context);
    final screenHeight = MediaQuery.sizeOf(context).height;
    final sheetHeight = screenHeight * sheetHeightFactor;

    return showGeneralDialog<void>(
      context: context,
      barrierDismissible: true,
      barrierLabel: i18n.t(
        zhHans: '关闭在线客服',
        zhHant: '關閉線上客服',
        en: 'Dismiss customer service',
        ja: 'オンラインサポートを閉じる',
        ko: '고객센터 닫기',
      ),
      barrierColor: Colors.black.withValues(alpha: 0.55),
      transitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (dialogContext, animation, secondaryAnimation) {
        return Align(
          alignment: Alignment.bottomCenter,
          child: Padding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(dialogContext).bottom,
            ),
            child: SizedBox(
              height: sheetHeight,
              width: double.infinity,
              child: CustomerServiceSheet(guest: guest),
            ),
          ),
        );
      },
      transitionBuilder: (context, animation, secondaryAnimation, child) {
        final curved = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 1),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        );
      },
    );
  }

  @override
  State<CustomerServiceSheet> createState() => _CustomerServiceSheetState();
}

class _CustomerServiceSheetState extends State<CustomerServiceSheet> {
  String? _url;
  bool _urlReady = false;
  bool _pageLoaded = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _prepareUrl();
    });
  }

  Future<void> _prepareUrl() async {
    final i18n = AppI18n.current;
    try {
      final baseUrl = await PlatformApi.instance.fetchCustomerServiceUrl();
      if (!mounted) return;
      if (baseUrl.trim().isEmpty) {
        Navigator.of(context).pop();
        ToastUtils.toast(i18n.t(
          zhHans: '暂未配置在线客服',
          zhHant: '暫未設定線上客服',
          en: 'Customer service is not configured yet.',
          ja: 'オンラインサポートはまだ設定されていません。',
          ko: '온라인 고객센터가 아직 설정되지 않았습니다.',
        ));
        return;
      }

      final visitor = widget.guest
          ? CustomerServiceUrlBuilder.guestVisitor()
          : await CustomerServiceUrlBuilder.resolveVisitor();
      if (!mounted) return;
      final built = CustomerServiceUrlBuilder.build(
        baseUrl: baseUrl,
        visiterId: visitor.id,
        visiterName: visitor.name,
        avatar: visitor.avatar,
      );
      final uri = CustomerServiceUrlBuilder.parseLoadableUri(built);
      if (uri == null) {
        Navigator.of(context).pop();
        ToastUtils.toast(i18n.t(
          zhHans: '客服链接无效',
          zhHant: '客服連結無效',
          en: 'Invalid customer service link.',
          ja: 'カスタマーサポートのリンクが無効です。',
          ko: '고객센터 링크가 올바르지 않습니다.',
        ));
        return;
      }

      setState(() {
        _url = uri.toString();
        _urlReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      Navigator.of(context).pop();
      ToastUtils.toast(i18n.t(
        zhHans: '客服页面加载失败，请稍后重试',
        zhHant: '客服頁面載入失敗，請稍後重試',
        en: 'Failed to load customer service. Please try again later.',
        ja: 'カスタマーサポートページの読み込みに失敗しました。しばらくしてから再度お試しください。',
        ko: '고객센터 페이지를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
      ));
    }
  }

  bool get _showLoadingOverlay => !_pageLoaded || !_urlReady;

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context, listen: false).theme;
    final background =
        theme.weakBackgroundColor ?? theme.wideBackgroundColor ?? Colors.white;
    // 面板贴屏幕底边；给 WebView 留出底部安全区，避免 H5 输入行被 Home 条遮挡。
    // 键盘弹起时外层已用 viewInsets 上推整板，此处不再叠加 padding.bottom。
    final media = MediaQuery.of(context);
    final bottomSafe = media.viewInsets.bottom > 0
        ? 0.0
        : media.padding.bottom;

    return Material(
      color: Colors.transparent,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: background,
          borderRadius: CustomerServiceSheet.sheetBorderRadius,
        ),
        child: ClipRRect(
          borderRadius: CustomerServiceSheet.sheetBorderRadius,
          clipBehavior: Clip.hardEdge,
          child: Stack(
            children: [
              if (_url != null)
                Positioned(
                  left: 0,
                  right: 0,
                  top: 0,
                  bottom: bottomSafe,
                  child: CustomerServiceWebView(
                    url: _url!,
                    onPageLoadStarted: () {
                      if (!mounted) return;
                      setState(() => _pageLoaded = false);
                    },
                    onPageLoaded: () {
                      if (!mounted) return;
                      setState(() => _pageLoaded = true);
                    },
                  ),
                ),
              if (bottomSafe > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  height: bottomSafe,
                  // 与 H5 底部输入条同色，避免安全区一条异色缝。
                  child: const ColoredBox(color: Colors.white),
                ),
              Positioned(
                left: 0,
                right: 0,
                top: 0,
                bottom: bottomSafe,
                child: AnimatedOpacity(
                  opacity: _showLoadingOverlay ? 1 : 0,
                  duration: const Duration(milliseconds: 240),
                  curve: Curves.easeOut,
                  child: IgnorePointer(
                    ignoring: !_showLoadingOverlay,
                    child: const CustomerServiceLoadingView(),
                  ),
                ),
              ),
              const Positioned(
                top: 0,
                right: 0,
                child: _SheetCloseButtonAnchor(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetCloseButtonAnchor extends StatelessWidget {
  const _SheetCloseButtonAnchor();

  @override
  Widget build(BuildContext context) {
    return _SheetCloseButton(
      onPressed: () => Navigator.of(context).pop(),
    );
  }
}

class _SheetCloseButton extends StatelessWidget {
  const _SheetCloseButton({required this.onPressed});

  final VoidCallback onPressed;

  static const double _size = 28;

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);

    // 热区略大于圆钮；圆钮本身 top/right=0 贴弹窗最边缘，
    // 外侧被面板 ClipRRect 圆角裁切，形成角上圆标。
    return Tooltip(
      message: i18n.t(
        zhHans: '关闭',
        zhHant: '關閉',
        en: 'Close',
        ja: '閉じる',
        ko: '닫기',
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          customBorder: const CircleBorder(),
          child: const SizedBox(
            width: 44,
            height: 44,
            child: Align(
              alignment: Alignment.topRight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: Color(0x8A000000),
                  shape: BoxShape.circle,
                ),
                child: SizedBox(
                  width: _size,
                  height: _size,
                  child: Center(
                    child: Icon(
                      Icons.close_rounded,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
