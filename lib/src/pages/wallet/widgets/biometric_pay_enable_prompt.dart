import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/pages/wallet/biometric_pay_enable_page.dart';
import 'package:tencent_cloud_chat_demo/src/services/biometric_pay_service.dart';

/// 支付成功后引导用户开启面容 / 指纹支付（全屏页）。
class BiometricPayEnablePrompt {
  BiometricPayEnablePrompt._();

  static Future<void> maybeShowAfterPaySuccess(
    BuildContext context, {
    required PayAuthMethod authMethod,
    String? verifiedPayPin,
  }) async {
    if (!context.mounted) return;

    final bio = BiometricPayService.instance;
    if (!await bio.shouldShowEnablePrompt(authMethod: authMethod)) {
      return;
    }
    if (!context.mounted) return;

    await BiometricPayEnablePage.open(
      context,
      verifiedPayPin: verifiedPayPin,
      isPostPayPrompt: true,
    );

    await bio.markPromptShownNow();
  }
}
