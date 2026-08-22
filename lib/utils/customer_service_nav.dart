import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/platform_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/pages/customer_service/customer_service_sheet.dart';
import 'package:tencent_cloud_chat_demo/utils/customer_service_url_builder.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:url_launcher/url_launcher.dart';

class CustomerServiceNav {
  CustomerServiceNav._();

  static Future<void> open(BuildContext context, {bool guest = false}) async {
    if (kIsWeb) {
      final i18n = AppI18n.of(context);
      try {
        final baseUrl = await PlatformApi.instance.fetchCustomerServiceUrl();
        if (baseUrl.trim().isEmpty) {
          ToastUtils.toast(i18n.t(
            zhHans: '暂未配置在线客服',
            zhHant: '暫未設定線上客服',
            en: 'Customer service is not configured yet.',
            ja: 'オンラインサポートはまだ設定されていません。',
            ko: '온라인 고객센터가 아직 설정되지 않았습니다.',
          ));
          return;
        }
        final visitor = guest
            ? CustomerServiceUrlBuilder.guestVisitor()
            : await CustomerServiceUrlBuilder.resolveVisitor();
        final url = CustomerServiceUrlBuilder.build(
          baseUrl: baseUrl,
          visiterId: visitor.id,
          visiterName: visitor.name,
          avatar: visitor.avatar,
        );
        final uri = CustomerServiceUrlBuilder.parseLoadableUri(url);
        if (uri == null) {
          ToastUtils.toast(i18n.t(
            zhHans: '客服链接无效',
            zhHant: '客服連結無效',
            en: 'Invalid customer service link.',
            ja: 'カスタマーサポートのリンクが無効です。',
            ko: '고객센터 링크가 올바르지 않습니다.',
          ));
          return;
        }
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } catch (_) {
        ToastUtils.toast(i18n.t(
          zhHans: '客服页面加载失败，请稍后重试',
          zhHant: '客服頁面載入失敗，請稍後重試',
          en: 'Failed to load customer service. Please try again later.',
          ja: 'カスタマーサポートページの読み込みに失敗しました。しばらくしてから再度お試しください。',
          ko: '고객센터 페이지를 불러오지 못했습니다. 잠시 후 다시 시도해 주세요.',
        ));
      }
      return;
    }

    await CustomerServiceSheet.show(context, guest: guest);
  }
}
