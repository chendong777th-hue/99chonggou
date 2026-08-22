import 'dart:io';

import 'package:flutter/foundation.dart';

import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class OfflinePushInfo {
  String? title;
  String? desc;
  String? ext;
  String? vendorParams;
  bool? disablePush = false;
  String? iOSSound;
  String? iOSImage;
  bool? ignoreIOSBadge;
  int? iOSPushType = 0; // 1 is voip
  String? iOSInterruptionLevel;
  bool? enableIOSBackgroundNotification;
  String? androidSound;
  String? androidOPPOChannelID;
  String? androidOPPOCategory;
  int? androidOPPONotifyLevel;
  String? androidVIVOCategory;
  int? androidVIVOClassification = 1;
  String? androidFCMChannelID;
  String? androidFCMImage;
  String? androidXiaoMiChannelID;
  String? androidHuaWeiCategory;
  String? androidHuaWeiImage;
  String? androidHonorImage;
  String? androidHonorImportance;
  String? harmonyImage;
  String? harmonyCategory;
  bool? ignoreHarmonyBadge;
  int? androidMeizuNotifyType;
  OfflinePushInfo({
    this.title,
    this.desc,
    this.ext,
    this.vendorParams,
    this.disablePush,
    this.iOSSound,
    this.iOSImage,
    this.ignoreIOSBadge,
    this.iOSPushType,
    this.iOSInterruptionLevel,
    this.enableIOSBackgroundNotification,
    this.androidSound,
    this.androidOPPOChannelID,
    this.androidOPPOCategory,
    this.androidOPPONotifyLevel,
    this.androidVIVOCategory,
    this.androidVIVOClassification,
    this.androidFCMChannelID,
    this.androidFCMImage,
    this.androidXiaoMiChannelID,
    this.androidHuaWeiCategory,
    this.androidHuaWeiImage,
    this.androidHonorImage,
    this.androidHonorImportance,
    this.harmonyImage,
    this.harmonyCategory,
    this.ignoreHarmonyBadge,
    this.androidMeizuNotifyType,
  });

  factory OfflinePushInfo.fromJson(Map json) {
    if (kIsWeb) {
      return _OfflinePushInfoFromJsonWeb(json);
    }
    return _OfflinePushInfoFromJsonNative(json);
  }

  Map<String, dynamic> toJson() {
    if (kIsWeb) {
      return _toJsonWeb();
    }
    return _toJsonNative();
  }


  Map<String, dynamic> _toJsonNative() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['offline_push_config_title'] = title;
    data['offline_push_config_desc'] = desc;
    data['offline_push_config_ext'] = ext;
    data['offline_push_config_vendor_params'] = vendorParams;
    data['offline_push_config_flag'] = disablePush == true ? 1 : 0;

    data['offline_push_config_ios_config'] = _toIOSConfigJson();
    data['offline_push_config_android_config'] = _toAndroidConfigJson();
    data['offline_push_config_harmony_config'] = _toHarmonyConfigJson();
    return data;
  }

  Map<String, dynamic> _toIOSConfigJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['ios_offline_push_config_title'] = title;
    data['ios_offline_push_config_sound'] = iOSSound;
    data['ios_offline_push_config_ignore_badge'] = ignoreIOSBadge;
    data['ios_offline_push_config_push_type'] = iOSPushType;
    data['ios_offline_push_config_image'] = iOSImage;
    data['ios_offline_push_config_interruption_level'] = iOSInterruptionLevel;
    data['ios_offline_push_config_enable_background_notification'] = enableIOSBackgroundNotification;
    return data;
  }

  Map<String, dynamic> _toAndroidConfigJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['android_offline_push_config_title'] = title;
    data['android_offline_push_config_sound'] = androidSound;
    data['android_offline_push_config_vivo_classification'] = androidVIVOClassification;
    data['android_offline_push_config_vivo_category'] = androidVIVOCategory;
    data['android_offline_push_config_oppo_channel_id'] = androidOPPOChannelID;
    data['android_offline_push_config_oppo_category'] = androidOPPOCategory;
    data['android_offline_push_config_oppo_notify_level'] = androidOPPONotifyLevel;
    data['android_offline_push_config_fcm_channel_id'] = androidFCMChannelID;
    data['android_offline_push_config_fcm_image'] = androidFCMImage;
    data['android_offline_push_config_xiaomi_channel_id'] = androidXiaoMiChannelID;
    data['android_offline_push_config_huawei_category'] = androidHuaWeiCategory;
    data['android_offline_push_config_huawei_image'] = androidHuaWeiImage;
    data['android_offline_push_config_honor_image'] = androidHonorImage;
    data['android_offline_push_config_honor_importance'] = androidHonorImportance;
    data['android_offline_push_config_meizu_notify_type'] = androidMeizuNotifyType;
    return data;
  }

  Map<String, dynamic> _toHarmonyConfigJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['harmony_offline_push_config_title'] = title;
    data['harmony_offline_push_config_image'] = harmonyImage;
    data['harmony_offline_push_config_category'] = harmonyCategory;
    data['harmony_offline_push_config_ignore_badge'] = ignoreHarmonyBadge;
    return data;
  }

  Map<String, dynamic> _toJsonWeb() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['title'] = title;
    data['desc'] = desc;
    data['ext'] = ext;
    data['vendorParams'] = vendorParams;
    data['disablePush'] = disablePush;
    data['iOSSound'] = iOSSound;
    data['ignoreIOSBadge'] = ignoreIOSBadge;
    data["iOSImage"] = iOSImage ?? "";
    data['iOSPushType'] = iOSPushType;
    data['iOSInterruptionLevel'] = iOSInterruptionLevel;
    data['enableIOSBackgroundNotification'] = enableIOSBackgroundNotification;
    data['androidSound'] = androidSound;
    data['androidOPPOChannelID'] = androidOPPOChannelID;
    data['androidOPPOCategory'] = androidOPPOCategory;
    data['androidOPPONotifyLevel'] = androidOPPONotifyLevel;
    data["androidVIVOCategory"] = androidVIVOCategory;
    data['androidVIVOClassification'] = androidVIVOClassification;
    data['androidFCMChannelID'] = androidFCMChannelID;
    data["androidFCMImage"] = androidFCMImage ?? "";
    data['androidXiaoMiChannelID'] = androidXiaoMiChannelID;
    data['androidHuaWeiCategory'] = androidHuaWeiCategory;
    data["androidHuaWeiImage"] = androidHuaWeiImage ?? "";
    data["androidHonorImage"] = androidHonorImage ?? "";
    data["androidHonorImportance"] = androidHonorImportance;
    data["harmonyImage"] = harmonyImage ?? "";
    data["harmonyCategory"] = harmonyCategory ?? "";
    data["ignoreHarmonyBadge"] = ignoreHarmonyBadge;
    return data;
  }

  String toLogString() {
    var res = "|title:$title|desc:$desc|ext:$ext";
    return res;
  }
}

class _OfflinePushInfoFromJsonWeb extends OfflinePushInfo {
  _OfflinePushInfoFromJsonWeb(Map json) : super() {
    json = Utils.formatJson(json);
    title = json['title'];
    desc = json['desc'];
    ext = json['ext'];
    vendorParams = json['vendorParams'];
    disablePush = json['disablePush'] ?? false;
    iOSSound = json['iOSSound'];
    iOSImage = json["iOSImage"] ?? "";
    ignoreIOSBadge = json['ignoreIOSBadge'];
    iOSPushType = json["iOSPushType"] ?? 0;
    iOSInterruptionLevel = json["iOSInterruptionLevel"] ?? "";
    enableIOSBackgroundNotification = json["enableIOSBackgroundNotification"] ?? false;
    androidSound = (json['androidSound'] ?? "").toString();
    androidOPPOChannelID = (json['androidOPPOChannelID'] ?? "").toString();
    androidOPPOCategory = json["androidOPPOCategory"] ?? "";
    androidOPPONotifyLevel = json["androidOPPONotifyLevel"] ?? 0;
    androidVIVOCategory = json["androidVIVOCategory"] ?? "";
    androidVIVOClassification = (json['androidVIVOClassification'] ?? 1);
    androidFCMChannelID = json["androidFCMChannelID"] ?? "";
    androidFCMImage = json["androidFCMImage"] ?? "";
    androidXiaoMiChannelID = json["androidXiaoMiChannelID"] ?? "";
    androidHuaWeiCategory = json["androidHuaWeiCategory"] ?? "";
    androidHuaWeiImage = json["androidHuaWeiImage"] ?? "";
    androidHonorImage = json["androidHonorImage"] ?? "";
    androidHonorImportance = json["androidHonorImportance"] ?? "";
    harmonyImage = json["harmonyImage"] ?? "";
    harmonyCategory = json["harmonyCategory"] ?? "";
    ignoreHarmonyBadge = json["ignoreHarmonyBadge"] ?? false;
  }
}

class _OfflinePushInfoFromJsonNative extends OfflinePushInfo {
  _OfflinePushInfoFromJsonNative(Map json) : super() {
    json = Utils.formatJson(json);
    title = json['offline_push_config_title'];
    desc = json['offline_push_config_desc'];
    ext = json['offline_push_config_ext'];
    vendorParams = json['offline_push_config_vendor_params'];
    int flag = json['offline_push_config_flag'] ?? 0;
    disablePush = flag != 0;

    Map<String, dynamic> iOSConfig = json['offline_push_config_ios_config'] ?? {};
    if (iOSConfig.isNotEmpty) {
      String iOSTitle = iOSConfig['ios_offline_push_config_title'] ?? "";
      if (iOSTitle.isNotEmpty && Platform.isIOS) {
        title = iOSTitle;
      }

      iOSSound = iOSConfig['ios_offline_push_config_sound'];
      iOSPushType = iOSConfig['ios_offline_push_config_push_type'] ?? 0;
      iOSImage = iOSConfig['ios_offline_push_config_image'];
      ignoreIOSBadge = iOSConfig['ios_offline_push_config_ignore_badge'];
      iOSInterruptionLevel = iOSConfig['ios_offline_push_config_interruption_level'];
      enableIOSBackgroundNotification = iOSConfig['ios_offline_push_config_enable_background_notification'];
    }

    Map<String, dynamic> androidConfig = json['offline_push_config_android_config'] ?? {};
    if (androidConfig.isNotEmpty) {
      String androidTitle = androidConfig['android_offline_push_config_title'] ?? "";
      if (androidTitle.isNotEmpty && Platform.isAndroid) {
        title = androidTitle;
      }

      androidSound = androidConfig['android_offline_push_config_sound'];
      androidVIVOClassification = androidConfig['android_offline_push_config_vivo_classification'];
      androidVIVOCategory = androidConfig['android_offline_push_config_vivo_category'];
      androidOPPOChannelID = androidConfig['android_offline_push_config_oppo_channel_id'];
      androidOPPOCategory = androidConfig['android_offline_push_config_oppo_category'];
      androidOPPONotifyLevel = androidConfig['android_offline_push_config_oppo_notify_level'];
      androidFCMChannelID = androidConfig['android_offline_push_config_fcm_channel_id'];
      androidFCMImage = androidConfig['android_offline_push_config_fcm_image'];
      androidXiaoMiChannelID = androidConfig['android_offline_push_config_xiaomi_channel_id'];
      androidHuaWeiCategory = androidConfig['android_offline_push_config_huawei_category'];
      androidHuaWeiImage = androidConfig['android_offline_push_config_huawei_image'];
      androidHonorImage = androidConfig['android_offline_push_config_honor_image'];
      androidHonorImportance = androidConfig['android_offline_push_config_honor_importance'];
      androidMeizuNotifyType = androidConfig['android_offline_push_config_meizu_notify_type'];
    }

    Map<String, dynamic> harmonyConfig = json['offline_push_config_harmony_config'] ?? {};
    if (harmonyConfig.isNotEmpty) {
      harmonyImage = harmonyConfig['harmony_offline_push_config_image'];
      harmonyCategory = harmonyConfig['harmony_offline_push_config_category'];
      var badgeValue = harmonyConfig['harmony_offline_push_config_ignore_badge'];
      if (badgeValue == true || badgeValue == 1) {
        ignoreHarmonyBadge = true;
      } else {
        ignoreHarmonyBadge = false;
      }
    }
  }
}
