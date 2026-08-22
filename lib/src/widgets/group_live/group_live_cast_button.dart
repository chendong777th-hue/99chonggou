import 'dart:io';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tencent_cloud_chat_demo/src/i18n/app_i18n.dart';
import 'package:tencent_cloud_chat_demo/src/services/group_live_cast_service.dart';
import 'package:tencent_cloud_chat_demo/utils/toast.dart';

/// System cast control: AirPlay route picker on iOS, cast settings on Android.
class GroupLiveCastButton extends StatelessWidget {
  const GroupLiveCastButton({
    super.key,
    this.iconColor = Colors.white,
    this.iconSize = 20,
    this.padding = const EdgeInsets.all(6),
  });

  final Color iconColor;
  final double iconSize;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    if (Platform.isIOS) {
      return SizedBox(
        width: 32,
        height: 32,
        child: UiKitView(
          viewType: 'group_live_airplay_picker',
          layoutDirection: TextDirection.ltr,
          creationParams: <String, dynamic>{
            'tint': iconColor.toARGB32(),
          },
          creationParamsCodec: const StandardMessageCodec(),
        ),
      );
    }

    return Material(
      color: Colors.transparent,
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => unawaited(_openAndroidCast(context)),
        child: Padding(
          padding: padding,
          child: Icon(
            Icons.cast_rounded,
            color: iconColor,
            size: iconSize,
          ),
        ),
      ),
    );
  }

  Future<void> _openAndroidCast(BuildContext context) async {
    final i18n = AppI18n.of(context);
    final ok = await GroupLiveCastService.openCastPicker();
    if (!ok && context.mounted) {
      ToastUtils.toast(i18n.t(
        zhHans: '无法打开投屏设置，请使用系统投屏功能',
        zhHant: '無法打開投屏設定，請使用系統投屏功能',
        en: 'Unable to open cast settings. Use system cast instead.',
        ja: 'キャスト設定を開けません。システムのキャストをご利用ください。',
        ko: '캐스트 설정을 열 수 없습니다. 시스템 캐스트를 사용해 주세요.',
      ));
    }
  }
}
