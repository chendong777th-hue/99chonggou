// ignore_for_file: file_names

import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:tencent_cloud_chat_demo/src/services/call_kit_bridge.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';

class CommonUtils {
  static double adaptHeight(double height) {
    return height.h;
  }

  static AppOfflinePushInfo convertTUIOfflinePushInfo(OfflinePushInfo offlinePush) {
    AppOfflinePushInfo tuiOfflinePushInfo = AppOfflinePushInfo();
    tuiOfflinePushInfo.title = offlinePush.title ?? '';
    tuiOfflinePushInfo.desc = offlinePush.desc ?? '';
    tuiOfflinePushInfo.ignoreIOSBadge = offlinePush.ignoreIOSBadge ?? false;
    tuiOfflinePushInfo.iOSSound = offlinePush.iOSSound ?? '';
    tuiOfflinePushInfo.androidSound = offlinePush.androidSound ?? '';
    tuiOfflinePushInfo.androidOPPOChannelID =
        offlinePush.androidOPPOChannelID ?? '';
    return tuiOfflinePushInfo;
  }

  static double adaptWidth(double width) {
    return width.w;
  }

  static double adaptFontSize(double fontSize) {
    return fontSize.sp;
  }
}
