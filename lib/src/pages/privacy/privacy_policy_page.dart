import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_chat_i18n_tool/language_json/strings.g.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/privacy_policy_localizations.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';

class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    final locale = LocaleSettings.currentLocale;
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return Scaffold(
      backgroundColor: theme.weakBackgroundColor ?? AppTokens.surface,
      appBar: AppBar(
        backgroundColor: theme.appbarBgColor ?? AppTokens.surface,
        foregroundColor: theme.primaryColor ?? const Color(0xFF1E90FF),
        elevation: 0,
        centerTitle: true,
        title: Text(
          PrivacyPolicyLocalizations.title(locale),
          style: AppTokens.label.copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w700,
            color: theme.appbarTextColor ?? AppTokens.ink800,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
        child: SelectableText(
          PrivacyPolicyLocalizations.body(locale),
          style: AppTokens.body.copyWith(
            fontSize: 16,
            height: 1.85,
            color: theme.darkTextColor ?? AppTokens.ink700,
          ),
        ),
      ),
    );
  }
}
