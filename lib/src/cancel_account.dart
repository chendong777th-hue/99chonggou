// ignore_for_file: use_key_in_widget_constructors, unused_import

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/utils/constant.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/view_models/tui_self_info_view_model.dart';
import 'package:tencent_cloud_chat_uikit/data_services/services_locatar.dart';
import 'package:tencent_cloud_chat_uikit/tencent_cloud_chat_uikit.dart';
import 'package:tencent_cloud_chat_uikit/theme/color.dart';
import 'package:tencent_cloud_chat_uikit/ui/widgets/avatar.dart';
import 'package:tencent_cloud_chat_demo/src/pages/login.dart';
import 'package:tencent_cloud_chat_demo/src/provider/theme.dart';
import 'package:provider/provider.dart';
import 'package:tencent_cloud_chat_demo/src/routes.dart';
import 'package:tencent_cloud_chat_demo/utils/init_step.dart';
import 'package:tencent_cloud_chat_demo/utils/request.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:tencent_cloud_chat_demo/src/platform/listener_store.dart';
import 'package:tencent_cloud_chat_demo/src/services/platform_official_account_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/im_session_cache.dart';
import 'package:tencent_cloud_chat_demo/src/services/auth_bootstrap_service.dart';
import 'package:tencent_cloud_chat_demo/src/services/account_session_service.dart';
import 'package:tencent_cloud_chat_demo/src/api/api_client.dart';
import '../config.dart';
import 'package:dio/dio.dart';

class CancelAccount extends StatelessWidget {
  final TUISelfInfoViewModel _selfInfoViewModel =
      serviceLocator<TUISelfInfoViewModel>();
  final CoreServicesImpl _coreServices = TIMUIKitCore.getInstance();

  _handleLogout(BuildContext context) async {
    await AccountSessionService.instance.clearForLogout(
      reason: 'cancel_account_logout',
      purgeOwnerDisk: true,
    );
    if (context.mounted) {
      InitStep.directToLogin(context);
    }
  }

  CupertinoActionSheet mapAppSheet(BuildContext context) {
    final i18n = AppI18n.of(context);
    return CupertinoActionSheet(
      title: Text(
        i18n.t(
          zhHans: '确认注销账户',
          zhHant: '確認註銷帳戶',
          en: 'Confirm account deletion',
          ja: 'アカウント削除の確認',
          ko: '계정 삭제 확인',
        ),
      ),
      actions: [
        CupertinoActionSheetAction(
          onPressed: () async {
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
              ToastUtils.toast(
                AppI18n.current.t(
                  zhHans: '账户注销成功！',
                  zhHant: '帳戶註銷成功！',
                  en: 'Account deleted successfully',
                  ja: 'アカウントを削除しました',
                  ko: '계정이 삭제되었습니다',
                ),
              );
              _handleLogout(context);
            } else {
              ToastUtils.log(codeStr);
              ToastUtils.toast(codeStr ?? "");
            }
          },
          child: Text(
            i18n.t(
              zhHans: '注销',
              zhHant: '註銷',
              en: 'Delete',
              ja: '削除',
              ko: '삭제',
            ),
            style: TextStyle(
              fontSize: 17.0,
              color: hexToColor("FF584C"),
            ),
          ),
        )
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final i18n = AppI18n.of(context);
    final theme = Provider.of<DefaultThemeData>(context).theme;
    final option1 = _selfInfoViewModel.loginInfo?.userID;
    return Scaffold(
      appBar: AppBar(
        iconTheme: IconThemeData(
          color: theme.primaryColor ?? const Color(0xFF1E90FF),
        ),
        shadowColor: theme.weakDividerColor,
        elevation: 1,
        title: Text(
          i18n.t(
            zhHans: '注销账户',
            zhHant: '註銷帳戶',
            en: 'Delete account',
            ja: 'アカウント削除',
            ko: '계정 삭제',
          ),
          style: const TextStyle(fontSize: IMDemoConfig.appBarTitleFontSize),
        ),
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [
              theme.lightPrimaryColor ?? CommonColor.lightPrimaryColor,
              theme.primaryColor ?? CommonColor.primaryColor
            ]),
          ),
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          color: theme.weakBackgroundColor,
        ),
        child: Center(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Container(
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                    ),
                    height: 80,
                    width: 80,
                    child: Avatar(
                      borderRadius: BorderRadius.circular(40),
                        showName: _selfInfoViewModel.loginInfo?.userID ?? "",
                        faceUrl: _selfInfoViewModel.loginInfo?.faceUrl ?? ""),
                  ),
                  Positioned(
                    right: -10,
                    bottom: -10,
                    child: Icon(
                      Icons.do_not_disturb_on,
                      color: hexToColor('FA5151'),
                      size: 34,
                    ),
                  ),
                ],
              ),
              Container(
                margin: const EdgeInsets.only(top: 40, bottom: 80),
                padding: const EdgeInsets.only(right: 40, left: 40),
                child: Text(
                  i18n.format(
                    zhHans:
                        '注销后，您将无法使用当前账号，相关数据也将删除且无法找回。当前账号ID: {option1}',
                    zhHant:
                        '註銷後，您將無法使用目前帳號，相關資料也將刪除且無法找回。目前帳號ID: {option1}',
                    en:
                        'After deletion, you will no longer be able to use this account. Related data will be removed and cannot be recovered. Account ID: {option1}',
                    ja:
                        '削除後、このアカウントは使用できなくなり、関連データは復元できません。アカウントID: {option1}',
                    ko:
                        '삭제 후 이 계정을 사용할 수 없으며 관련 데이터는 복구할 수 없습니다. 계정 ID: {option1}',
                    vars: {'option1': option1 ?? ''},
                  ),
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    color: theme.darkTextColor,
                    fontSize: 14,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(right: 40, left: 40),
                child: MaterialButton(
                  elevation: 0,
                  highlightElevation: 0,
                  minWidth: double.infinity,
                  color: Colors.white,
                  textColor: hexToColor("FA5151"),
                  height: 46,
                  child: Text(
                    i18n.t(
                      zhHans: '注销账号',
                      zhHant: '註銷帳號',
                      en: 'Delete account',
                      ja: 'アカウントを削除',
                      ko: '계정 삭제',
                    ),
                    style: const TextStyle(
                      fontSize: 18,
                    ),
                  ),
                  onPressed: () {
                    showCupertinoModalPopup(
                        context: context,
                        builder: (BuildContext context) =>
                            mapAppSheet(context)).then((value) => null);
                  },
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
