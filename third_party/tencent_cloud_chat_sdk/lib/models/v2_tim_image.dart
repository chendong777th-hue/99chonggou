import 'dart:io';

import 'package:tencent_cloud_chat_sdk/models/common_utils.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimImage
///
/// {@category Models}
///
class V2TimImage {
  late String? uuid;

  /// 图片类型 大图 缩略图 原图
  late int? type;

  /// 图片大小
  late int? size;

  /// 图片宽度
  late int? width;

  /// 图片高度
  late int? height;

  /// 图片url
  late String? url;

  /// 图片本地url，通过downloadMessage下载消息后此字段有值
  String? localUrl;

  V2TimImage({
    this.uuid,
    required this.type,
    this.size,
    this.width,
    this.height,
    this.url,
    this.localUrl,
  });

  String? getDefaultLocalUrl() {
    var cacheDir = CommonUtils.appFileDir;
    String filePath = uuid ?? '';

    if (Platform.isAndroid) {
      filePath = 'image_$type$size$width${height}_$uuid';
    } else if (Platform.isIOS) {
      String filePathPrefix = '${CommonUtils.getSDKAppID()}/${CommonUtils.getLoginUser()}';
      filePath = '$filePathPrefix/image_$type$size$width${height}_$uuid';
    } else if (Platform.isMacOS) {
      String filePathPrefix = '${CommonUtils.getSDKAppID()}/${CommonUtils.getLoginUser()}';
      filePath = '$filePathPrefix/image_$type$size$width${height}_$uuid';
    } else if (Platform.isWindows) {
      String filePathPrefix = 'TencentCloudChat/DownLoad/${CommonUtils.getSDKAppID()}/${CommonUtils.getLoginUser()}';
      filePath = '$filePathPrefix/image_$type$size$width${height}_$uuid';
    } else if (Platform.operatingSystem == 'ohos') {
      filePath = 'image_${type}_$uuid';
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

  String toLogString() {
    String res = "uuid:$uuid|type:$type|size:$size|width:$width|height:$height|url:${url == null ? false : true}|localUrl:$localUrl";
    return res;
  }
}

// {
//   "uuid":"",
//   "type":0,
//   "size":0,
//   "width":0,
//   "height":0,
//   "url":""
// }
