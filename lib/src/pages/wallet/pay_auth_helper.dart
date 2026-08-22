import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/biometric_pay_enable_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/pay_password_prompt.dart';
import 'package:tencent_cloud_chat_demo/src/services/biometric_pay_service.dart';

export 'package:tencent_cloud_chat_demo/src/services/biometric_pay_service.dart'
    show PayAuthMethod;
export 'package:tencent_cloud_chat_demo/src/pages/wallet/widgets/pay_password_prompt.dart'
    show PayMethodDisplay;

class PayAuthResult {
  final bool success;
  final PayAuthMethod? method;
  final String? verifiedPayPin;

  const PayAuthResult({
    required this.success,
    this.method,
    this.verifiedPayPin,
  });

  static const cancelled = PayAuthResult(success: false);
}

/// 统一支付认证：已开启面容支付时优先生物识别，否则 / 失败后走手动密码。
class PayAuthHelper {
  PayAuthHelper._();

  static Future<PayAuthResult> collectAndSubmit({
    required BuildContext context,
    required String title,
    required String amountText,
    String? amountCoin,
    required String payText,
    String? payCoinCode,
    String? payLogoUrl,
    required Future<String?> Function(String pwd) onSubmit,
    String? receiverName,
    String? receiverId,
    String? receiverAvatar,
    String? walletSubtitle,
    Future<PayMethodDisplay?> Function()? onChangePayMethod,
    bool tryBiometricFirst = true,
  }) async {
    final bio = BiometricPayService.instance;
    final i18n = AppI18n.of(context);

    if (tryBiometricFirst &&
        bio.isAvailableOnPlatform &&
        await bio.isEnabled() &&
        await bio.isDeviceSupported()) {
      final auth = await bio.authenticate(i18n: i18n);
      if (auth.success) {
        final pin = await bio.readPayPinForCurrentUser();
        if (pin != null) {
          final err = await onSubmit(pin);
          if (!context.mounted) return PayAuthResult.cancelled;
          if (err == null || err.isEmpty) {
            return const PayAuthResult(
              success: true,
              method: PayAuthMethod.biometric,
            );
          }
          await bio.disableAndClear();
        }
      }
    }

    if (!context.mounted) return PayAuthResult.cancelled;

    String? verifiedPin;
    // 设备支持生物识别即在右上角常驻快捷支付入口：已开启则直接验证，
    // 未开启则跳转开启页；不支持的设备（如部分安卓/模拟器）不显示。
    // 文案按系统模态：仅有 BiometricType.face 时写「面容」，安卓默认「指纹支付」。
    final biometricSupported =
        bio.isAvailableOnPlatform && await bio.isDeviceSupported();
    final biometricLabel =
        biometricSupported ? (await bio.paymentLabel(i18n)).trim() : null;

    final manualOk = await PayPasswordPrompt.show(
      context,
      title: title,
      amountText: amountText,
      amountCoin: amountCoin,
      payText: payText,
      payCoinCode: payCoinCode,
      payLogoUrl: payLogoUrl,
      receiverName: receiverName,
      receiverId: receiverId,
      receiverAvatar: receiverAvatar,
      walletSubtitle: walletSubtitle,
      onChangePayMethod: onChangePayMethod,
      biometricShortcutLabel: biometricLabel,
      onBiometricShortcut: biometricSupported
          ? () => _onFacePayTap(context, onSubmit: onSubmit)
          : null,
      onSubmit: (pwd) async {
        final err = await onSubmit(pwd);
        if (err == null || err.isEmpty) {
          verifiedPin = pwd;
        }
        return err;
      },
    );

    if (!context.mounted || manualOk != true) {
      return PayAuthResult.cancelled;
    }

    return PayAuthResult(
      success: true,
      method: PayAuthMethod.manual,
      verifiedPayPin: verifiedPin,
    );
  }

  /// 点击右上角快捷支付：已开启走生物识别付款；未开启则跳转开启页，
  /// 开启成功后立即用生物识别完成本次付款。返回 true 表示已付款、可关闭密码弹窗。
  static Future<bool> _onFacePayTap(
    BuildContext context, {
    required Future<String?> Function(String pwd) onSubmit,
  }) async {
    final bio = BiometricPayService.instance;
    if (await bio.isEnabled()) {
      return _submitViaBiometric(context, onSubmit: onSubmit);
    }
    if (!context.mounted) return false;
    await BiometricPayEnablePage.open(context);
    if (!context.mounted) return false;
    if (await bio.isEnabled()) {
      return _submitViaBiometric(context, onSubmit: onSubmit);
    }
    return false;
  }

  static Future<bool> _submitViaBiometric(
    BuildContext context, {
    required Future<String?> Function(String pwd) onSubmit,
  }) async {
    final bio = BiometricPayService.instance;
    final i18n = AppI18n.of(context);

    if (!await bio.hasEnrolledBiometrics()) {
      if (!context.mounted) return false;
      await BiometricPayEnablePage.open(context);
      if (!context.mounted) return false;
      if (!await bio.isEnabled()) return false;
    }

    final auth = await bio.authenticate(i18n: i18n);
    if (!auth.success) {
      if (auth.notEnrolled && context.mounted) {
        await BiometricPayEnablePage.open(context);
      }
      return false;
    }

    final pin = await bio.readPayPinForCurrentUser();
    if (pin == null) return false;

    final err = await onSubmit(pin);
    if (err != null && err.isNotEmpty) {
      await bio.disableAndClear();
      return false;
    }
    return true;
  }
}
