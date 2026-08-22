import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/config.dart';
import 'package:tencent_cloud_chat_demo/src/api/platform_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/privacy/privacy_policy_page.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/settings_widgets.dart';
import 'package:tencent_cloud_chat_demo/src/theme/app_colors.dart';
import 'package:tencent_cloud_chat_demo/src/pages/privacy/terms_of_service_page.dart';
import 'package:tencent_cloud_chat_demo/src/utils/app_version.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:url_launcher/url_launcher.dart';

class AboutUsPage extends StatefulWidget {
  /// 外层已有标题栏（如桌面弹窗）时隐藏自身 AppBar。
  final bool embedded;

  const AboutUsPage({super.key, this.embedded = false});

  @override
  State<AboutUsPage> createState() => _AboutUsPageState();
}

class _AboutUsPageState extends State<AboutUsPage> {
  String _website = '';
  String _email = '';
  bool _loadingContact = true;
  String _displayVersion = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _loadContact();
      _loadVersion();
    });
  }

  Future<void> _loadContact() async {
    try {
      final info = await PlatformApi.instance.fetchContact();
      if (!mounted) return;
      setState(() {
        _website = _resolveWebsite(info.website);
        _email = info.email;
        _loadingContact = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _website = '';
        _loadingContact = false;
      });
    }
  }

  String _resolveWebsite(String apiWebsite) {
    return apiWebsite.trim();
  }

  Future<void> _loadVersion() async {
    final version = await AppVersion.getDisplayVersion();
    if (!mounted) return;
    setState(() {
      _displayVersion = version;
    });
  }

  void _openPage(BuildContext context, Widget page) {
    Navigator.push(
      context,
      NavigationRoutes.cupertino(
        builder: (_) => page,
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
  }

  Future<void> _sendEmail() async {
    final targetEmail = _email.isNotEmpty ? _email : 'support@99chat.app';
    final i18n = AppI18n.of(context);
    await launchUrl(
      Uri.parse(
        'mailto:$targetEmail?subject=${Uri.encodeComponent(i18n.t(
          zhHans: '${IMDemoConfig.appName} 反馈',
          zhHant: '${IMDemoConfig.appName} 回饋',
          en: '${IMDemoConfig.appName} Feedback',
          ja: '${IMDemoConfig.appName} フィードバック',
          ko: '${IMDemoConfig.appName} 피드백',
        ))}',
      ),
      mode: LaunchMode.externalApplication,
    );
  }

  @override
  Widget build(BuildContext context) {
    final dark = settingsIsDark(context);
    final muted = AppColors.subText(dark: dark);
    final i18n = AppI18n.of(context);

    return SettingsScaffold(
      embedded: widget.embedded,
      title: i18n.t(
        zhHans: '关于我们',
        zhHant: '關於我們',
        en: 'About Us',
        ja: 'このアプリについて',
        ko: '앱 정보',
      ),
      children: [
        Container(
          width: double.infinity,
          color: AppColors.card(dark: dark),
          padding: const EdgeInsets.fromLTRB(16, 34, 16, 34),
          child: Column(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(26),
                child: Image.asset(
                  'assets/im_new_logo.jpg',
                  width: 96,
                  height: 96,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                IMDemoConfig.appName,
                style: TextStyle(
                  color: AppColors.text(dark: dark),
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                i18n.t(
                  zhHans:
                      '专业版 v${_displayVersion.isEmpty ? IMDemoConfig.appVersion : _displayVersion}',
                  zhHant:
                      '專業版 v${_displayVersion.isEmpty ? IMDemoConfig.appVersion : _displayVersion}',
                  en: 'Pro v${_displayVersion.isEmpty ? IMDemoConfig.appVersion : _displayVersion}',
                  ja: 'Pro版 v${_displayVersion.isEmpty ? IMDemoConfig.appVersion : _displayVersion}',
                  ko: 'Pro 버전 v${_displayVersion.isEmpty ? IMDemoConfig.appVersion : _displayVersion}',
                ),
                style: TextStyle(
                  color: muted,
                  fontSize: 15,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SettingsGroup(
          margin: EdgeInsets.zero,
          children: [
            SettingsCell(
              title: i18n.t(
                zhHans: '服务条款',
                zhHant: '服務條款',
                en: 'Terms of Service',
                ja: '利用規約',
                ko: '서비스 이용약관',
              ),
              onTap: () => _openPage(context, const TermsOfServicePage()),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '隐私政策',
                zhHant: '隱私政策',
                en: 'Privacy Policy',
                ja: 'プライバシーポリシー',
                ko: '개인정보 처리방침',
              ),
              showDivider: false,
              onTap: () => _openPage(context, const PrivacyPolicyPage()),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SettingsGroup(
          margin: EdgeInsets.zero,
          children: [
            SettingsCell(
              title: i18n.t(
                zhHans: '官方网站',
                zhHant: '官方網站',
                en: 'Official Website',
                ja: '公式サイト',
                ko: '공식 웹사이트',
              ),
              value: _loadingContact
                  ? i18n.t(
                      zhHans: '获取中',
                      zhHant: '讀取中',
                      en: 'Loading',
                      ja: '読み込み中',
                      ko: '불러오는 중',
                    )
                  : (_website.isNotEmpty
                      ? _website
                      : i18n.t(
                          zhHans: '未配置',
                          zhHant: '未設定',
                          en: 'Not configured',
                          ja: '未設定',
                          ko: '설정되지 않음',
                        )),
              onTap: _website.isEmpty ? null : () => _openExternal(_website),
            ),
            SettingsCell(
              title: i18n.t(
                zhHans: '邮件反馈',
                zhHant: '郵件回饋',
                en: 'Email Feedback',
                ja: 'メールでフィードバック',
                ko: '이메일 문의',
              ),
              value: _loadingContact
                  ? i18n.t(
                      zhHans: '获取中',
                      zhHant: '讀取中',
                      en: 'Loading',
                      ja: '読み込み中',
                      ko: '불러오는 중',
                    )
                  : (_email.isNotEmpty
                      ? _email
                      : i18n.t(
                          zhHans: '未配置',
                          zhHant: '未設定',
                          en: 'Not configured',
                          ja: '未設定',
                          ko: '설정되지 않음',
                        )),
              showDivider: false,
              onTap: _email.isEmpty ? null : _sendEmail,
            ),
          ],
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 42, 16, 0),
          child: Center(
            child: Text(
              '© 2026 ${IMDemoConfig.appName}',
              style: TextStyle(
                color: muted,
                fontSize: 14,
              ),
            ),
          ),
        ),
      ],
    );
  }
}
