
import 'dart:io';

import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/common_utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_c_enum.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimSoundElem
///
/// {@category Models}
///
class V2TimSoundElem extends V2TIMElem {
  ///语音本地路径，仅在消息发送成功之前有效，用作消息发送成功前语音消息预览
  late String? path;
  // ignore: non_constant_identifier_names
  late String? UUID;

  /// 语音大小
  late int? dataSize;

  /// 语音时长
  late int? duration;

  ///  语音消息url 5.0.2之后默认不返回，通过getMessageOnlineUrl异步获取
  late String? url;

  /// 语音本地url，通过downloadMessage使用默认下载路径下载消息后此字段有值
  String? localUrl;

  V2TimSoundElem({
    this.path,
    // ignore: non_constant_identifier_names
    this.UUID,
    this.dataSize,
    this.duration,
    this.url,
    this.localUrl,
  }): super(elemType: MessageElemType.V2TIM_ELEM_TYPE_SOUND);

  String? getDefaultLocalUrl() {
    var cacheDir = CommonUtils.appFileDir;
    String filePath = UUID ?? '';

    if (Platform.isAndroid) {
      filePath = 'sound_$UUID';
    } else if (Platform.isIOS) {
      String filePathPrefix = '${CommonUtils.getSDKAppID()}/${CommonUtils.getLoginUser()}';
      filePath = '$filePathPrefix/sound_$UUID';
    } else if (Platform.isMacOS) {
      String filePathPrefix = '${CommonUtils.getSDKAppID()}/${CommonUtils.getLoginUser()}';
      filePath = '$filePathPrefix/sound_$UUID';
    } else if (Platform.isWindows) {
      String filePathPrefix = 'TencentCloudChat/DownLoad/${CommonUtils.getSDKAppID()}/${CommonUtils.getLoginUser()}';
      filePath = '$filePathPrefix/sound_$UUID';
    } else if (Platform.operatingSystem == 'ohos') {
      filePath = 'sound_$UUID';
    }

    var defaultLocalUrl = '${cacheDir.path}/$filePath';
    if (File(defaultLocalUrl).existsSync()) {
      return defaultLocalUrl;
    }

    if (Platform.isAndroid && CommonUtils.externalCacheDir != null) {
      defaultLocalUrl = '${CommonUtils.externalCacheDir!.parent.path}/cache/$filePath';
      if (File(defaultLocalUrl).existsSync()) {
        return defaultLocalUrl;
      }
    }

    return null;
  }

  V2TimSoundElem.fromJson(Map json) {
    elemType = MessageElemType.V2TIM_ELEM_TYPE_SOUND;
    json = Utils.formatJson(json);
    path = json['sound_elem_file_path'];
    UUID = json['sound_elem_file_id'];
    dataSize = json['sound_elem_file_size'];
    duration = json['sound_elem_file_time'];
    localUrl = getDefaultLocalUrl();
    url = json['sound_elem_url'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['elem_type'] = CElemType.ElemSound;
    data['sound_elem_file_path'] = path;
    data['sound_elem_file_id'] = UUID;
    data['sound_elem_file_size'] = dataSize;
    data['sound_elem_file_time'] = duration;
    data['localUrl'] = localUrl;
    data['sound_elem_url'] = url;
    return data;
  }
  String toLogString() {
    String res = "UUID:$UUID|duration:$duration|dataSize:$dataSize|localUrl:$localUrl";
    return res;
  }
}
