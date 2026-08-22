import 'package:flutter/material.dart';
import 'package:tencent_cloud_chat_demo/src/api/platform_api.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/utils/app_version.dart';
import 'package:tencent_cloud_chat_demo/src/widgets/app_dialog.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';
import 'package:url_launcher/url_launcher.dart';

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  bool _checking = false;
  bool _automaticCheckCompleted = false;

  List<int> _versionParts(String value) {
    return value
        .trim()
        .replaceFirst(RegExp(r'^[vV]'), '')
        .split('.')
        .map((part) => int.tryParse(RegExp(r'\d+').stringMatch(part) ?? '') ?? 0)
        .toList();
  }

  int _compareVersion(String left, String right) {
    final leftParts = _versionParts(left);
    final rightParts = _versionParts(right);
    final length =
        leftParts.length > rightParts.length ? leftParts.length : rightParts.length;
    for (var i = 0; i < length; i++) {
      final leftValue = i < leftParts.length ? leftParts[i] : 0;
      final rightValue = i < rightParts.length ? rightParts[i] : 0;
      if (leftValue != rightValue) {
        return leftValue.compareTo(rightValue);
      }
    }
    return 0;
  }

  Future<void> check(
    BuildContext context, {
    required bool manual,
  }) async {
    if (_checking || (!manual && _automaticCheckCompleted)) {
      return;
    }
    _checking = true;
    try {
      final info = await PlatformApi.instance.fetchContact();
      final clientVersion = await AppVersion.getClientVersion();
      final clientParts = clientVersion.split('+');
      final localVersion = clientParts.first.trim();
      final localBuild =
          clientParts.length > 1 ? int.tryParse(clientParts[1].trim()) ?? 0 : 0;
      final remoteVersion = info.version.trim();
      final remoteBuild = int.tryParse(info.build.trim()) ?? 0;
      if (remoteVersion.isEmpty) {
        throw const FormatException('Missing remote version');
      }

      final versionComparison = _compareVersion(remoteVersion, localVersion);
      final hasNewVersion = versionComparison > 0 ||
          (versionComparison == 0 && remoteBuild > localBuild);
      if (!manual) {
        _automaticCheckCompleted = true;
      }
      if (!context.mounted) {
        return;
      }

      final i18n = AppI18n.of(context);
      if (!hasNewVersion) {
        if (manual) {
          ToastUtils.toast(i18n.t(
            zhHans: '当前已是最新版本',
            zhHant: '目前已是最新版本',
            en: 'You are using the latest version.',
            ja: '最新バージョンを使用しています。',
            ko: '현재 최신 버전을 사용 중입니다.',
          ));
        }
        return;
      }

      if (!manual && AppDialog.isShowing) {
        _automaticCheckCompleted = false;
        Future<void>.delayed(const Duration(seconds: 2), () {
          if (context.mounted) {
            check(context, manual: false);
          }
        });
        return;
      }
      final confirmed = await AppDialog.confirm(
        title: i18n.t(
          zhHans: '发现新版本',
          zhHant: '發現新版本',
          en: 'Update Available',
          ja: '新しいバージョン',
          ko: '새 버전 발견',
        ),
        message: i18n.t(
          zhHans: '发现新版本 v$remoteVersion，是否立即更新？',
          zhHant: '發現新版本 v$remoteVersion，是否立即更新？',
          en: 'Version $remoteVersion is available. Update now?',
          ja: 'バージョン $remoteVersion が利用可能です。更新しますか？',
          ko: '새 버전 $remoteVersion이 있습니다. 지금 업데이트하시겠습니까?',
        ),
        cancelText: i18n.t(
          zhHans: '取消',
          zhHant: '取消',
          en: 'Cancel',
          ja: 'キャンセル',
          ko: '취소',
        ),
        confirmText: i18n.t(
          zhHans: '更新',
          zhHant: '更新',
          en: 'Update',
          ja: '更新',
          ko: '업데이트',
        ),
      );
      if (!confirmed || !context.mounted) {
        return;
      }

      final uri = Uri.tryParse(info.downloadUrl.trim());
      if (uri == null ||
          !uri.hasScheme ||
          !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (!context.mounted) {
          return;
        }
        ToastUtils.toast(i18n.t(
          zhHans: '无法打开下载页面',
          zhHant: '無法開啟下載頁面',
          en: 'Unable to open the download page.',
          ja: 'ダウンロードページを開けません。',
          ko: '다운로드 페이지를 열 수 없습니다.',
        ));
      }
    } catch (_) {
      if (manual && context.mounted) {
        final i18n = AppI18n.of(context);
        ToastUtils.toast(i18n.t(
          zhHans: '检查更新失败，请稍后重试',
          zhHant: '檢查更新失敗，請稍後再試',
          en: 'Unable to check for updates. Please try again later.',
          ja: '更新を確認できません。しばらくしてから再試行してください。',
          ko: '업데이트를 확인할 수 없습니다. 잠시 후 다시 시도해 주세요.',
        ));
      }
    } finally {
      _checking = false;
    }
  }
}
