import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/auth_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/settings/change_phone_page.dart';
import 'package:tencent_cloud_chat_demo/utils/navigation_routes.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

/// 判断用户是否已绑定手机号，并在未绑定时引导进入 [ChangePhonePage]。
class PhoneBindingGuard {
  PhoneBindingGuard._();

  static bool isBound(MeResult me) {
    final masked = me.phoneMasked.trim();
    if (masked.isNotEmpty) {
      return true;
    }
    final phone = me.phone.trim();
    if (phone.isEmpty) {
      return false;
    }
    final digits = phone.replaceAll(RegExp(r'\D'), '');
    return digits.length >= 7;
  }

  static Future<bool> fetchIsBound() async {
    final me = await AuthApi.instance.fetchMe();
    return isBound(me);
  }

  /// 已绑定返回 true；未绑定则打开绑定/修改手机号页，绑定成功后返回 true。
  static Future<bool> ensureBound(BuildContext context) async {
    try {
      if (await fetchIsBound()) {
        return true;
      }
    } catch (_) {
      if (!context.mounted) {
        return false;
      }
      ToastUtils.toast(AppI18n.of(context).t(
        zhHans: '无法获取账号信息，请稍后重试',
        zhHant: '無法取得帳號資訊，請稍後再試',
        en: 'Unable to load account info. Please try again later.',
        ja: 'アカウント情報を取得できません。しばらくしてからもう一度お試しください。',
        ko: '계정 정보를 가져올 수 없습니다. 잠시 후 다시 시도해 주세요.',
      ));
      return false;
    }

    if (!context.mounted) {
      return false;
    }

    ToastUtils.toast(AppI18n.of(context).t(
      zhHans: '请先绑定手机号',
      zhHant: '請先綁定手機號',
      en: 'Please bind a phone number first.',
      ja: '先に電話番号を登録してください。',
      ko: '먼저 휴대전화 번호를 등록해 주세요.',
    ));

    final result = await Navigator.push<bool>(
      context,
      NavigationRoutes.cupertino(
        builder: (_) => const ChangePhonePage(),
      ),
    );
    if (result == true) {
      return true;
    }

    try {
      return await fetchIsBound();
    } catch (_) {
      return false;
    }
  }
}
