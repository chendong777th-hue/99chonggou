import 'package:flutter/widgets.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';

class AppI18n {
  final AppLocale locale;

  const AppI18n._(this.locale);

  static AppI18n of(BuildContext context) {
    return AppI18n._(_fromLocale(Localizations.localeOf(context)));
  }

  static AppI18n get current => AppI18n._(LocaleSettings.currentLocale);

  static AppLocale _fromLocale(Locale locale) {
    if (locale.languageCode == 'zh') {
      final scriptCode = locale.scriptCode?.toLowerCase();
      final countryCode = locale.countryCode?.toUpperCase();
      if (scriptCode == 'hant' ||
          countryCode == 'TW' ||
          countryCode == 'HK' ||
          countryCode == 'MO') {
        return AppLocale.zhHant;
      }
      return AppLocale.zhHans;
    }
    switch (locale.languageCode) {
      case 'en':
        return AppLocale.en;
      case 'ja':
        return AppLocale.ja;
      case 'ko':
        return AppLocale.ko;
      default:
        return LocaleSettings.currentLocale;
    }
  }

  String t({
    required String zhHans,
    String? zhHant,
    String? en,
    String? ja,
    String? ko,
  }) {
    final traditional = zhHant ?? zhHans;
    final english = en ?? zhHans;
    final japanese = ja ?? english;
    final korean = ko ?? english;
    switch (locale) {
      case AppLocale.zhHant:
        return traditional;
      case AppLocale.en:
        return english;
      case AppLocale.ja:
        return japanese;
      case AppLocale.ko:
        return korean;
      case AppLocale.zhHans:
        return zhHans;
    }
  }

  String format({
    required String zhHans,
    String? zhHant,
    String? en,
    String? ja,
    String? ko,
    required Map<String, String> vars,
  }) {
    var text = t(
      zhHans: zhHans,
      zhHant: zhHant,
      en: en,
      ja: ja,
      ko: ko,
    );
    vars.forEach((key, value) {
      text = text.replaceAll('{$key}', value);
    });
    return text;
  }
}
