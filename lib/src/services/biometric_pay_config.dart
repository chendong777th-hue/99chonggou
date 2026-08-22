/// 面容 / 指纹支付配置。
class BiometricPayConfig {
  BiometricPayConfig._();

  /// 支付成功引导冷却期。
  static const Duration promptCooldown = Duration(days: 7);

  /// 是否启用支付成功后的开启引导。
  static const bool enablePostPayPrompt = true;
}
