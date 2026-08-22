import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';

/// 补充 [Translations] 未覆盖的短文案（随 [LocaleSettings] 切换）。
class UikitAppStrings {
  UikitAppStrings._();

  static String _pick({
    required String zhHans,
    required String zhHant,
    required String en,
    required String ja,
    required String ko,
  }) {
    switch (LocaleSettings.currentLocale) {
      case AppLocale.zhHant:
        return zhHant;
      case AppLocale.en:
        return en;
      case AppLocale.ja:
        return ja;
      case AppLocale.ko:
        return ko;
      case AppLocale.zhHans:
        return zhHans;
    }
  }

  static String genderPrivate() => _pick(
        zhHans: '保密',
        zhHant: '保密',
        en: 'Private',
        ja: '非公開',
        ko: '비공개',
      );

  static String avCall() => _pick(
        zhHans: '音视频通话',
        zhHant: '音視訊通話',
        en: 'Audio/Video Call',
        ja: '音声・ビデオ通話',
        ko: '음성/영상 통화',
      );

  static String editRemarkHint() => _pick(
        zhHans: '填写备注名',
        zhHant: '填寫備註名',
        en: 'Enter remark name',
        ja: '備考名を入力',
        ko: '비고 이름 입력',
      );
}
