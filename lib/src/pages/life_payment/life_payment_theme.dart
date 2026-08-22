import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/pages/life_payment/life_payment_models.dart';

/// 生活缴费独立视觉体系：白底清爽布局 + 实用主义配色。
class LifePaymentTheme {
  LifePaymentTheme._();

  static const Color ink = Color(0xFF2C2A26);
  static const Color inkMuted = Color(0xFF8A857C);
  static const Color inkFaint = Color(0xFFB8B2A8);

  static const Color paper = Color(0xFFFFFFFF);
  static const Color paperDeep = Color(0xFFF5F5F5);
  static const Color surface = Color(0xFFFFFFFF);

  static const Color teal = Color(0xFF2B6B5E);
  static const Color tealSoft = Color(0xFFE8F0ED);

  static const Color inkDark = Color(0xFFF0EDE8);
  static const Color inkMutedDark = Color(0xFF9A968F);
  static const Color paperDark = Color(0xFF141618);
  static const Color paperDeepDark = Color(0xFF1C1E21);
  static const Color surfaceDark = Color(0xFF222428);
  static const Color tealDark = Color(0xFF4A9A88);

  static Color background(bool dark) => dark ? paperDark : paper;
  static Color card(bool dark) => dark ? surfaceDark : surface;
  static Color text(bool dark) => dark ? inkDark : ink;
  static Color subText(bool dark) => dark ? inkMutedDark : inkMuted;
  static Color accent(bool dark) => dark ? tealDark : teal;
  static Color accentSoft(bool dark) => dark
      ? const Color(0xFF1E2E2A)
      : tealSoft;

  /// 搜索框填充、分割线、选中浅底等城市选择页共用色。
  static Color searchFill(bool dark) => dark ? paperDeepDark : paperDeep;
  static Color hairline(bool dark) =>
      dark ? const Color(0xFF3A3D44) : const Color(0xFFE4E6EA);
  static Color selectedSoft(bool dark) =>
      dark ? const Color(0xFF1A2A3D) : const Color(0xFFF0F8FF);
  static const Color brandBlue = Color(0xFF1E7BF2);

  /// 新增缴费页浅灰底、表单内文案、禁用按钮等。
  static Color pageBackground(bool dark) =>
      dark ? paperDark : const Color(0xFFF3F6FB);
  static Color formCard(bool dark) => dark ? surfaceDark : Colors.white;
  static Color formLabel(bool dark) =>
      dark ? inkMutedDark : const Color(0xFF969BA4);
  static Color formValue(bool dark) =>
      dark ? inkDark : const Color(0xFF2C3037);
  static Color formHint(bool dark) =>
      dark ? const Color(0xFF6B7078) : const Color(0xFFC9CDD3);
  static Color formChevron(bool dark) =>
      dark ? const Color(0xFF6B7078) : const Color(0xFFCCD0D6);
  static Color formDivider(bool dark) =>
      dark ? const Color(0xFF33363C) : const Color(0xFFF0F1F3);
  static Color tipBannerBg(bool dark) =>
      dark ? const Color(0xFF2A2433) : const Color(0xFFF3EEF9);
  static Color tipBannerText(bool dark) =>
      dark ? const Color(0xFFB8B0C4) : const Color(0xFF8E8A95);
  static const Color tipAmber = Color(0xFFE5A638);
  static Color disabledButton(bool dark) =>
      dark ? const Color(0xFF3A3F48) : const Color(0xFFCFD7E4);
  static Color sheetBg(bool dark) => dark ? surfaceDark : Colors.white;
  static Color amountTileBg(bool dark) =>
      dark ? paperDeepDark : const Color(0xFFF7F8FA);
  static Color amountTileBorder(bool dark) =>
      dark ? const Color(0xFF3A3D44) : const Color(0xFFE8EAED);

  static SystemUiOverlayStyle systemOverlay(bool dark) {
    final bg = background(dark);
    return (dark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark)
        .copyWith(
      statusBarColor: bg,
      systemNavigationBarColor: bg,
      systemNavigationBarIconBrightness:
          dark ? Brightness.light : Brightness.dark,
    );
  }

  static Color serviceColor(LifePaymentServiceVisual visual, bool dark) {
    switch (visual) {
      case LifePaymentServiceVisual.mobile:
        return const Color(0xFF3D6FD6);
      case LifePaymentServiceVisual.electricity:
        return const Color(0xFFD4A012);
      case LifePaymentServiceVisual.water:
        return const Color(0xFF2A8FB8);
      case LifePaymentServiceVisual.gas:
        return const Color(0xFFC45C3E);
    }
  }

  static String serviceIconAsset(LifePaymentServiceVisual visual) {
    switch (visual) {
      case LifePaymentServiceVisual.mobile:
        return 'assets/life_payment/ic_mobile.svg';
      case LifePaymentServiceVisual.electricity:
        return 'assets/life_payment/ic_electricity.svg';
      case LifePaymentServiceVisual.water:
        return 'assets/life_payment/ic_water.svg';
      case LifePaymentServiceVisual.gas:
        return 'assets/life_payment/ic_gas.svg';
    }
  }
}

enum LifePaymentServiceVisual { mobile, electricity, water, gas }

extension LifePaymentTypeVisual on LifePaymentType {
  LifePaymentServiceVisual get visual {
    switch (this) {
      case LifePaymentType.mobile:
        return LifePaymentServiceVisual.mobile;
      case LifePaymentType.electricity:
        return LifePaymentServiceVisual.electricity;
      case LifePaymentType.water:
        return LifePaymentServiceVisual.water;
      case LifePaymentType.gas:
        return LifePaymentServiceVisual.gas;
    }
  }
}
