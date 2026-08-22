import 'dart:async';

import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';

/// 支付成功提示遮罩。
class PaySuccessOverlay extends StatelessWidget {
  final bool show;
  final String logoAsset;
  final String title;
  final String message;

  const PaySuccessOverlay({
    super.key,
    required this.show,
    this.logoAsset = 'assets/img/99chat_logo.png',
    this.title = '',
    this.message = '',
  });

  static OverlayEntry? _entry;
  static Timer? _timer;

  static const Duration defaultDuration = Duration(milliseconds: 1100);

  static void present(
    BuildContext context, {
    String logoAsset = 'assets/img/99chat_logo.png',
    String? title,
    String? message,
    Duration? duration,
  }) {
    // 先收起键盘，避免成功动画与软键盘叠在一起。
    FocusManager.instance.primaryFocus?.unfocus();

    final i18n = AppI18n.of(context);
    final resolvedTitle = title ??
        i18n.t(
          zhHans: '支付成功',
          zhHant: '支付成功',
          en: 'Payment successful',
          ja: '支払いが完了しました',
          ko: '결제가 완료되었습니다',
        );
    final resolvedMessage = message ??
        i18n.t(
          zhHans: '支付已完成',
          zhHant: '支付已完成',
          en: 'Payment completed',
          ja: '決済が完了しました',
          ko: '결제가 완료되었습니다',
        );

    dismiss();
    final overlay = Overlay.of(context, rootOverlay: true);
    _entry = OverlayEntry(
      builder: (_) => PaySuccessOverlay(
        show: true,
        logoAsset: logoAsset,
        title: resolvedTitle,
        message: resolvedMessage,
      ),
    );
    overlay.insert(_entry!);

    final hold = duration ?? defaultDuration;
    if (hold > Duration.zero) {
      _timer = Timer(hold, dismiss);
    }
  }

  static Future<void> showFor(
    BuildContext context, {
    String logoAsset = 'assets/img/99chat_logo.png',
    String? title,
    String? message,
    Duration? duration,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    // 若键盘仍占位，等收起后再播成功动画，避免叠层。
    if (context.mounted && MediaQuery.viewInsetsOf(context).bottom > 0) {
      await Future<void>.delayed(const Duration(milliseconds: 280));
    }
    if (!context.mounted) return;

    final hold = duration ?? defaultDuration;
    present(
      context,
      logoAsset: logoAsset,
      title: title,
      message: message,
      duration: hold,
    );
    await Future<void>.delayed(hold);
  }

  static void dismiss() {
    _timer?.cancel();
    _timer = null;
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    if (!show) return const SizedBox.shrink();

    final i18n = AppI18n.of(context);
    final resolvedTitle = title.isEmpty
        ? i18n.t(
            zhHans: '支付成功',
            zhHant: '支付成功',
            en: 'Payment successful',
            ja: '支払いが完了しました',
            ko: '결제가 완료되었습니다',
          )
        : title;
    final resolvedMessage = message.isEmpty
        ? i18n.t(
            zhHans: '支付已完成',
            zhHant: '支付已完成',
            en: 'Payment completed',
            ja: '決済が完了しました',
            ko: '결제가 완료되었습니다',
          )
        : message;

    return Material(
      type: MaterialType.transparency,
      child: AbsorbPointer(
        child: Container(
          width: double.infinity,
          height: double.infinity,
          color: Colors.black.withOpacity(0.28),
          alignment: Alignment.center,
          child: SafeArea(
            minimum: const EdgeInsets.symmetric(horizontal: 24),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(22),
              child: Container(
                width: 172,
                padding: const EdgeInsets.fromLTRB(14, 18, 14, 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2A2A2E).withOpacity(0.86),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.22),
                      blurRadius: 18,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: _SuccessBody(
                  logoAsset: logoAsset,
                  title: resolvedTitle,
                  message: resolvedMessage,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SuccessBody extends StatelessWidget {
  final String logoAsset;
  final String title;
  final String message;

  const _SuccessBody({
    required this.logoAsset,
    required this.title,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _SuccessIcon(logoAsset: logoAsset),
        const SizedBox(height: 12),
        Text(
          title,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          textAlign: TextAlign.center,
          style: const TextStyle(
            fontSize: 15,
            color: Colors.white,
            fontWeight: FontWeight.w600,
            decoration: TextDecoration.none,
          ),
        ),
        if (message.isNotEmpty) ...[
          const SizedBox(height: 6),
          Text(
            message,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.25,
              color: Colors.white.withOpacity(0.72),
              fontWeight: FontWeight.w400,
              decoration: TextDecoration.none,
            ),
          ),
        ],
      ],
    );
  }
}

class _SuccessIcon extends StatelessWidget {
  final String logoAsset;

  const _SuccessIcon({required this.logoAsset});

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
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
        Positioned(
          right: -5,
          bottom: -5,
          child: Container(
            width: 23,
            height: 23,
            decoration: BoxDecoration(
              color: const Color(0xFF31D158),
              shape: BoxShape.circle,
              border: Border.all(
                color: const Color(0xFF2A2A2E),
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.check,
              size: 15,
              color: Colors.white,
            ),
          ),
        ),
      ],
    );
  }
}
