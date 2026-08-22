// ignore_for_file: deprecated_member_use

import 'package:dio/dio.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/platform/listener_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_session_cache.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/account_session_service.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_chat_i18n_tool/tools/i18n_tool.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/about_us.dart';
import 'package:tencent_cloud_chat_demo/src/pages/cross_platform/wide_screen/contact_us.dart';
import 'package:tencent_cloud_chat_demo/src/pages/skin/skin_page.dart';
import 'package:tencent_cloud_chat_demo/src/provider/local_setting.dart';
import 'package:tencent_cloud_chat_demo/src/provider/login_user_Info.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:tencent_cloud_chat_demo/src/routes.dart';
import 'package:tencent_cloud_chat_demo/utils/init_step.dart';
import 'package:tencent_cloud_chat_demo/utils/constant.dart';
import 'package:tencent_cloud_chat_demo/utils/request.dart';
import 'package:tencent_cloud_chat_demo/utils/theme.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart'
    if (dart.library.html) 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_uikit/data_services/core/tim_uikit_wide_modal_operation_key.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/wide_popup.dart';
import 'package:url_launcher/url_launcher.dart';

class Settings extends StatefulWidget {
  final VoidCallback closeFunc;

  const Settings({Key? key, required this.closeFunc}) : super(key: key);

  @override
  State<StatefulWidget> createState() => SettingsState();
}

class SettingsState extends State<Settings> {
  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final loginUserInfoModel = Provider.of<LoginUserInfo>(context);
    final LocalSetting localSetting = Provider.of<LocalSetting>(context);
    final V2TimUserFullInfo loginUserInfo = loginUserInfoModel.loginUserInfo;
    final readStatus = localSetting.isShowReadingStatus;
    final onlineStatus = localSetting.isShowOnlineStatus;
    final language = localSetting.language;
    final CoreServicesImpl _coreServices = TIMUIKitCore.getInstance();
    final option1 = loginUserInfo.userID;
    final themeData = Provider.of<DefaultThemeData>(context);
    final isDarkTheme = themeData.currentThemeType == ThemeType.dark;

    Widget title(String item, bool isNeedDivider) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isNeedDivider)
            const SizedBox(
              height: 30,
            ),
          if (isNeedDivider)
            SizedBox(
              height: 1,
              child: Container(
                color: theme.weakDividerColor,
              ),
            ),
          const SizedBox(
            height: 30,
          ),
          Text(
            item,
            style: TextStyle(fontSize: 18, color: theme.darkTextColor),
          ),
          const SizedBox(
            height: 30,
          ),
        ],
      );
    }

    Widget secondTitle(String item, bool isTheFirst) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isTheFirst)
            const SizedBox(
              height: 20,
            ),
          Text(
            item,
            style: TextStyle(fontSize: 16, color: theme.darkTextColor),
          ),
          const SizedBox(
            height: 16,
          ),
        ],
      );
    }

    Widget languageRadio(String item) {
      return Radio(
          value: item,
          groupValue: language,
          onChanged: (_) {
            I18nUtils(null, item);
            localSetting.language = item;
          });
    }

    _handleLogout(BuildContext context) async {
      await AccountSessionService.instance.clearForLogout(
        reason: 'wide_settings_logout',
      );
      if (context.mounted) {
        InitStep.directToLogin(context);
      }
      widget.closeFunc();
    }

    _handleDeregister() async {
      Future<SharedPreferences> _prefs = SharedPreferences.getInstance();
      SharedPreferences prefs = await _prefs;
      String token = prefs.getString("smsLoginToken") ?? "";
      String userID = prefs.getString("smsLoginUserID") ?? "";
      String appID = prefs.getString("sdkAppId") ?? "";

      Response<Map<String, dynamic>> data = await appRequest(
          path:
              "/base/v1/auth_users/user_delete?apaasUserId=$userID&userId=$userID&token=$token&apaasAppId=$appID",
          method: "get",
          data: <String, dynamic>{
            "apaasUserId": userID,
            "userId": userID,
            "token": token,
            "apaasAppId": appID
          });

      Map<String, dynamic> res = data.data!;
      int errorCode = res['errorCode'];
      String? codeStr = res['codeStr'];

      if (errorCode == 0) {
        ToastUtils.toast((AppI18n.of(context).t(
        zhHans: '账户注销成功！',
        zhHant: '帳戶註銷成功！',
        en: 'Account deleted successfully',
        ja: 'アカウントを削除しました',
        ko: '계정 삭제 완료',
      )));
        _handleLogout(context);
      } else {
        ToastUtils.log(codeStr);
        ToastUtils.toast(codeStr ?? "");
      }
    }

    _confirmIfDeregister() {
      widget.closeFunc();
      TUIKitWidePopup.showSecondaryConfirmDialog(
          operationKey: TUIKitWideModalOperationKey.confirmGeneral,
          context: context,
          text: AppI18n.of(context).t(
        zhHans: '确认注销账户',
        zhHant: '確認註銷帳戶',
        en: 'Confirm Account Deletion',
        ja: 'アカウント削除の確認',
        ko: '계정 삭제 확인',
      ),
          theme: theme,
          onCancel: () {},
          onConfirm: () {
            _handleDeregister();
          });
    }

    Widget switchCheckBox(bool value, String name, String description, ValueChanged<bool> onChange) {
      return Row(
        children: [
          Checkbox(
              fillColor: WidgetStateProperty.all(theme.primaryColor),
              value: value,
              onChanged: (bool? newItem) {
                onChange(newItem ?? false);
              }),
          Expanded(
              child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(name, style: TextStyle(color: theme.darkTextColor)),
              const SizedBox(
                height: 4,
              ),
              Text(
                description,
                style: TextStyle(color: theme.weakTextColor, fontSize: 12),
              )
            ],
          ))
        ],
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Scrollbar(
        child: ListView(
          children: [
            title(AppI18n.of(context).t(
        zhHans: '我的账户',
        zhHant: '我的帳戶',
        en: 'My Account',
        ja: 'マイアカウント',
        ko: '내 계정',
      ), false),
            Row(
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: Avatar(faceUrl: loginUserInfo.faceUrl ?? "", showName: ""),
                ),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (loginUserInfo.nickName != null)
                      SelectableText(
                        loginUserInfo.nickName!,
                        style: TextStyle(color: theme.darkTextColor, fontSize: 16),
                      ),
                    const SizedBox(
                      height: 4,
                    ),
                    SelectableText("ID: ${loginUserInfo.userID ?? " "}", style: TextStyle(color: theme.weakTextColor, fontSize: 14)),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                OutlinedButton(
                    onPressed: () {
                      _handleLogout(context);
                    },
                    child: Text(
                      AppI18n.of(context).t(
        zhHans: '退出登录',
        zhHant: '登出',
        en: 'Log Out',
        ja: 'ログアウト',
        ko: '로그아웃',
      ),
                      style: TextStyle(color: theme.cautionColor),
                    )),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                OutlinedButton(
                    onPressed: () {
                      _confirmIfDeregister();
                    },
                    child: Text(AppI18n.of(context).t(
        zhHans: '注销账户',
        zhHant: '註銷帳戶',
        en: 'Delete Account',
        ja: 'アカウント削除',
        ko: '계정 삭제',
      ), style: TextStyle(color: theme.darkTextColor))),
              ],
            ),
            Text(
              AppI18n.of(context).format(
        zhHans: '注销后，您将无法使用当前账号，相关数据也将删除且无法找回。当前账号ID: {option1}',
        zhHant: '註銷後，您將無法使用目前帳號，相關資料也將刪除且無法找回。目前帳號ID: {option1}',
        en: 'After deletion, you cannot use this account and data cannot be recovered. Account ID: {option1}',
        ja: '削除後、このアカウントは使用できず、データは復元できません。アカウントID: {option1}',
        ko: '삭제 후 이 계정을 사용할 수 없으며 데이터는 복구할 수 없습니다. 계정 ID: {option1}',
        vars: {'option1': option1 ?? ''},
      ),
              style: TextStyle(color: theme.weakTextColor, fontSize: 12),
            ),
            title(AppI18n.of(context).t(
        zhHans: '界面',
        zhHant: '介面',
        en: 'Interface',
        ja: 'インターフェース',
        ko: '인터페이스',
      ), true),
            secondTitle(AppI18n.of(context).t(
        zhHans: '外观',
        zhHant: '外觀',
        en: 'Appearance',
        ja: '外観',
        ko: '외관',
      ), true),
            Row(
              children: [
                Radio(
                  value: false,
                  groupValue: isDarkTheme,
                  onChanged: (_) {
                    themeData.currentThemeType = ThemeType.blue;
                  },
                ),
                Text(AppI18n.of(context).t(
        zhHans: '浅色模式',
        zhHant: '淺色模式',
        en: 'Light Mode',
        ja: 'ライトモード',
        ko: '라이트 모드',
      )),
                const SizedBox(
                  width: 30,
                ),
                Radio(
                  value: true,
                  groupValue: isDarkTheme,
                  onChanged: (_) {
                    themeData.currentThemeType = ThemeType.dark;
                  },
                ),
                Text(
                  AppI18n.of(context).t(
        zhHans: '深色模式',
        zhHant: '深色模式',
        en: 'Dark Mode',
        ja: 'ダークモード',
        ko: '다크 모드',
      ),
                )
              ],
            ),
            secondTitle(AppI18n.of(context).t(
        zhHans: '主题',
        zhHant: '主題',
        en: 'Theme',
        ja: 'テーマ',
        ko: '테마',
      ), false),
            SkinPage(key: widget.key),
            secondTitle(AppI18n.of(context).t(
        zhHans: '语言',
        zhHant: '語言',
        en: 'Language',
        ja: '言語',
        ko: '언어',
      ), false),
            Row(
              children: [
                languageRadio("en"),
                Text(AppI18n.of(context).t(
        zhHans: '英语',
        zhHant: '英語',
        en: 'English',
        ja: '英語',
        ko: '영어',
      )),
                const SizedBox(
                  width: 30,
                ),
                languageRadio("zh-Hant"),
                Text(AppI18n.of(context).t(
        zhHans: '繁体中文',
        zhHant: '繁體中文',
        en: 'Traditional Chinese',
        ja: '繁体字中国語',
        ko: '번체 중국어',
      )),
                const SizedBox(
                  width: 30,
                ),
                languageRadio("zh-Hans"),
                Text(AppI18n.of(context).t(
        zhHans: '简体中文',
        zhHant: '簡體中文',
        en: 'Simplified Chinese',
        ja: '簡体字中国語',
        ko: '간체 중국어',
      )),
                const SizedBox(
                  width: 30,
                ),
                languageRadio("ja"),
                Text(AppI18n.of(context).t(
        zhHans: '日语',
        zhHant: '日語',
        en: 'Japanese',
        ja: '日本語',
        ko: '일본어',
      )),
                const SizedBox(
                  width: 30,
                ),
                languageRadio("ko"),
                Text(AppI18n.of(context).t(
        zhHans: '韩语',
        zhHant: '韓語',
        en: 'Korean',
        ja: '韓国語',
        ko: '한국어',
      ))
              ],
            ),
            title(AppI18n.of(context).t(
        zhHans: '通用',
        zhHant: '通用',
        en: 'General',
        ja: '一般',
        ko: '일반',
      ), true),
            secondTitle(AppI18n.of(context).t(
        zhHans: '消息',
        zhHant: '訊息',
        en: 'Messages',
        ja: 'メッセージ',
        ko: '메시지',
      ), true),
            switchCheckBox(readStatus, AppI18n.of(context).t(
        zhHans: '消息阅读状态',
        zhHant: '訊息閱讀狀態',
        en: 'Read Receipts',
        ja: '既読表示',
        ko: '읽음 표시',
      ), AppI18n.of(context).t(
        zhHans: '关闭后，您收发的消息均不带消息阅读状态，您将无法看到对方是否已读，同时对方也无法看到你是否已读。',
        zhHant: '關閉後，您收發的訊息均不帶訊息閱讀狀態，您將無法看到對方是否已讀，同時對方也無法看到你是否已讀。',
        en: 'When off, messages will not show read status for you or others.',
        ja: 'オフにすると、既読状態は表示されません。',
        ko: '끄면 읽음 상태가 표시되지 않습니다.',
      ), (value) {
              localSetting.isShowReadingStatus = value;
            }),
            secondTitle(AppI18n.of(context).t(
        zhHans: '联系人',
        zhHant: '聯絡人',
        en: 'Contacts',
        ja: '連絡先',
        ko: '연락처',
      ), false),
            switchCheckBox(onlineStatus, AppI18n.of(context).t(
        zhHans: '显示在线状态',
        zhHant: '顯示在線狀態',
        en: 'Show Online Status',
        ja: 'オンライン状態を表示',
        ko: '온라인 상태 표시',
      ), AppI18n.of(context).t(
        zhHans: '关闭后，您将不可以在会话列表和通讯录中看到好友在线或离线的状态提示。',
        zhHant: '關閉後，您將不可以在會話列表和通訊錄中看到好友在線或離線的狀態提示。',
        en: 'When off, online/offline status will not appear in chats or contacts.',
        ja: 'オフにすると、オンライン/オフライン状態は表示されません。',
        ko: '끄면 채팅 목록과 연락처에서 온라인 상태가 표시되지 않습니다.',
      ), (value) {
              localSetting.isShowOnlineStatus = value;
            }),
            title(AppI18n.of(context).t(
        zhHans: '关于',
        zhHant: '關於',
        en: 'About',
        ja: 'について',
        ko: '정보',
      ), true),
            secondTitle(AppI18n.of(context).t(
        zhHans: '关于腾讯云 · IM',
        zhHant: '關於騰訊雲 · IM',
        en: 'About Tencent Cloud · IM',
        ja: 'Tencent Cloud · IM について',
        ko: 'Tencent Cloud · IM 정보',
      ), true),
            Row(
              children: [
                OutlinedButton(
                    onPressed: () {
                      widget.closeFunc();
                      TUIKitWidePopup.showPopupWindow(
                          operationKey: TUIKitWideModalOperationKey.aboutUs,
                          context: context,
                          theme: theme,
                          title: AppI18n.of(context).t(
        zhHans: '关于我们',
        zhHant: '關於我們',
        en: 'About Us',
        ja: 'このアプリについて',
        ko: '앱 정보',
      ),
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: (closeFunc) => AboutUs(closeFunc: closeFunc));
                    },
                    child: Text(AppI18n.of(context).t(
        zhHans: '查看详情',
        zhHant: '查看詳情',
        en: 'View Details',
        ja: '詳細を見る',
        ko: '자세히 보기',
      ), style: TextStyle(color: theme.darkTextColor))),
                const SizedBox(
                  width: 20,
                ),
                OutlinedButton(
                    onPressed: () {
                      widget.closeFunc();
                      TUIKitWidePopup.showPopupWindow(
                          operationKey: TUIKitWideModalOperationKey.contactUs,
                          context: context,
                          theme: theme,
                          title: AppI18n.of(context).t(
        zhHans: '联系我们',
        zhHant: '聯繫我們',
        en: 'Contact Us',
        ja: 'お問い合わせ',
        ko: '문의하기',
      ),
                          width: MediaQuery.of(context).size.width * 0.6,
                          height: MediaQuery.of(context).size.height * 0.6,
                          child: (closeFunc) => ContactUs(closeFunc: closeFunc));
                    },
                    child: Text(AppI18n.of(context).t(
        zhHans: '联系我们',
        zhHant: '聯繫我們',
        en: 'Contact Us',
        ja: 'お問い合わせ',
        ko: '문의하기',
      ), style: TextStyle(color: theme.darkTextColor))),
              ],
            ),
            secondTitle(AppI18n.of(context).t(
        zhHans: '相关网站',
        zhHant: '相關網站',
        en: 'Related Links',
        ja: '関連サイト',
        ko: '관련 사이트',
      ), false),
            Row(
              children: [
                OutlinedButton(
                    onPressed: () {
                      launchUrl(
                        Uri.parse("https://www.tencentcloud.com/products/im?from=pub"),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: Text(AppI18n.of(context).t(
        zhHans: '官方网站',
        zhHant: '官方網站',
        en: 'Official Website',
        ja: '公式サイト',
        ko: '공식 웹사이트',
      ), style: TextStyle(color: theme.darkTextColor))),
                const SizedBox(
                  width: 20,
                ),
                OutlinedButton(
                    onPressed: () {
                      launchUrl(
                        Uri.parse("https://pub.dev/publishers/comm.qq.com/packages"),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: Text(AppI18n.of(context).t(
        zhHans: '所有 SDK',
        zhHant: '所有 SDK',
        en: 'All SDKs',
        ja: 'すべてのSDK',
        ko: '모든 SDK',
      ), style: TextStyle(color: theme.darkTextColor))),
                const SizedBox(
                  width: 20,
                ),
                OutlinedButton(
                    onPressed: () {
                      launchUrl(
                        Uri.parse("https://github.com/TencentCloud/chat-demo-flutter"),
                        mode: LaunchMode.externalApplication,
                      );
                    },
                    child: Text(AppI18n.of(context).t(
        zhHans: '源代码',
        zhHant: '原始碼',
        en: 'Source Code',
        ja: 'ソースコード',
        ko: '소스 코드',
      ), style: TextStyle(color: theme.darkTextColor))),
              ],
            ),
            const SizedBox(
              height: 30,
            )
          ],
        ),
      ),
    );
  }
}
