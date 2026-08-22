import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/user_agreement_localizations.dart';
import 'package:tencent_cloud_chat_demo/src/ui/app_tokens.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';

class UserAgreementPage extends StatelessWidget {
  const UserAgreementPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    return Scaffold(
      backgroundColor: theme.weakBackgroundColor ?? AppTokens.surface,
      appBar: AppBar(
        backgroundColor: theme.appbarBgColor ?? AppTokens.surface,
        foregroundColor: theme.primaryColor ?? const Color(0xFF1E90FF),
        elevation: 0,
        centerTitle: true,
        title: Text(
          UserAgreementLocalizations.title(locale),
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
          UserAgreementLocalizations.body(locale),
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
