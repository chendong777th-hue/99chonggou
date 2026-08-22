import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';

class LanguageSwitchSheet {
  const LanguageSwitchSheet._();

  static const List<String> languages = <String>[
    'zh-Hans',
    'zh-Hant',
    'en',
    'ja',
    'ko',
  ];

  static String normalize(String? language) {
    return LocalSetting.normalizeLanguage(language);
  }

  static AppLocale toAppLocale(String? language) {
    switch (normalize(language)) {
      case 'en':
        return AppLocale.en;
      case 'zh-Hant':
        return AppLocale.zhHant;
      case 'ja':
        return AppLocale.ja;
      case 'ko':
        return AppLocale.ko;
      case 'zh-Hans':
      default:
        return AppLocale.zhHans;
    }
  }

  static String languageText(String? language, AppI18n i18n) {
    switch (normalize(language)) {
      case 'en':
        return i18n.t(
          zhHans: 'English',
          zhHant: 'English',
          en: 'English',
          ja: 'English',
          ko: 'English',
        );
      case 'zh-Hant':
        return i18n.t(
          zhHans: '繁体中文',
          zhHant: '繁體中文',
          en: 'Traditional Chinese',
          ja: 'Traditional Chinese',
          ko: 'Traditional Chinese',
        );
      case 'ja':
        return i18n.t(
          zhHans: '日本語',
          zhHant: '日本語',
          en: 'Japanese',
          ja: '日本語',
          ko: 'Japanese',
        );
      case 'ko':
        if (kIsWeb) {
          // Web 简中子集不含韩文 Hangul，避免「한국어」显示为方框。
          return i18n.t(
            zhHans: '韩语',
            zhHant: '韓語',
            en: 'Korean',
            ja: '韓国語',
            ko: 'Korean',
          );
        }
        return i18n.t(
          zhHans: '한국어',
          zhHant: '한국어',
          en: 'Korean',
          ja: 'Korean',
          ko: '한국어',
        );
      case 'zh-Hans':
      default:
        return i18n.t(
          zhHans: '简体中文',
          zhHant: '簡體中文',
          en: 'Simplified Chinese',
          ja: 'Simplified Chinese',
          ko: 'Simplified Chinese',
        );
    }
  }

  static void apply(LocalSetting localSetting, String? language) {
    final next = normalize(language);
    localSetting.language = next;
    LocaleSettings.setLocale(toAppLocale(next));
  }

  static Future<void> show(
    BuildContext context,
    LocalSetting localSetting,
  ) async {
    final i18n = AppI18n.of(context);
    final title = i18n.t(
      zhHans: '选择语言',
      zhHant: '選擇語言',
      en: 'Choose Language',
      ja: '言語を選択',
      ko: '언어 선택',
    );
    final cancelText = i18n.t(
      zhHans: '取消',
      zhHant: '取消',
      en: 'Cancel',
      ja: 'キャンセル',
      ko: '취소',
    );

    final String? selected;
    if (kIsWeb) {
      selected = await showDialog<String>(
        context: context,
        barrierDismissible: true,
        builder: (dialogContext) => _WebLanguagePickerDialog(
          title: title,
          i18n: i18n,
          currentLanguage: normalize(localSetting.language),
        ),
      );
    } else {
      selected = await AppDialog.actionSheet<String>(
        title: title,
        cancelText: cancelText,
        actions: languages
            .map(
              (language) => AppActionSheetItem<String>(
                text: languageText(language, i18n),
                value: language,
              ),
            )
            .toList(growable: false),
      );
    }

    if (selected == null) return;
    apply(localSetting, selected);
  }
}

/// Web 专用居中语言选择弹窗（不用 iOS 底部 ActionSheet）。
class _WebLanguagePickerDialog extends StatelessWidget {
  const _WebLanguagePickerDialog({
    required this.title,
    required this.i18n,
    required this.currentLanguage,
  });

  final String title;
  final AppI18n i18n;
  final String currentLanguage;

  @override
  Widget build(BuildContext context) {
    final labelStyle = TextStyle(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: AppTokens.ink900,
      fontFamily: AppTokens.fontFamily,
      height: 1.35,
    );
    final selectedLabelStyle = labelStyle.copyWith(
      fontWeight: FontWeight.w700,
      color: AppTokens.brand500,
    );

    return Dialog(
      backgroundColor: AppTokens.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 8,
      insetPadding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppTokens.rCard),
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: AppTokens.title.copyWith(fontSize: 18),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppTokens.ink500,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
            const Divider(height: 1, color: AppTokens.divider),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Column(
                  children: [
                    for (var i = 0; i < LanguageSwitchSheet.languages.length; i++)
                      _WebLanguageOptionTile(
                        label: LanguageSwitchSheet.languageText(
                          LanguageSwitchSheet.languages[i],
                          i18n,
                        ),
                        selected:
                            LanguageSwitchSheet.languages[i] == currentLanguage,
                        labelStyle: labelStyle,
                        selectedLabelStyle: selectedLabelStyle,
                        onTap: () => Navigator.of(context).pop(
                          LanguageSwitchSheet.languages[i],
                        ),
                        showDivider: i < LanguageSwitchSheet.languages.length - 1,
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WebLanguageOptionTile extends StatelessWidget {
  const _WebLanguageOptionTile({
    required this.label,
    required this.selected,
    required this.labelStyle,
    required this.selectedLabelStyle,
    required this.onTap,
    required this.showDivider,
  });

  final String label;
  final bool selected;
  final TextStyle labelStyle;
  final TextStyle selectedLabelStyle;
  final VoidCallback onTap;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        hoverColor: AppTokens.brand50,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: selected ? selectedLabelStyle : labelStyle,
                    ),
                  ),
                  if (selected)
                    Icon(
                      Icons.check_rounded,
                      size: 20,
                      color: AppTokens.brand500,
                    ),
                ],
              ),
            ),
            if (showDivider)
              const Divider(
                height: 1,
                indent: 20,
                endIndent: 20,
                color: AppTokens.divider,
              ),
          ],
        ),
      ),
    );
  }
}
