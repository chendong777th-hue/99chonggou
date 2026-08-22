import 'dart:io';

import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/common_utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_c_enum.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimVideoElem
///
/// {@category Models}
///
class V2TimVideoElem extends V2TIMElem {
  /// 视频本地路径，仅在消息发送成功之前有效，用作消息发送成功之前视频预览
  late String? videoPath;
  // ignore: non_constant_identifier_names
  late String? UUID;

  /// 视频大小
  late int? videoSize;

  /// 视频播放时长
  late int? duration;

  /// 视频文件类型
  late String? videoType; // C 接口新增

  /// 视频封面路径，仅在消息发送之前有效，用作视频发送之前预览
  late String? snapshotPath;

  /// 封面ID
  late String? snapshotUUID;

  /// 封面大小
  late int? snapshotSize;

  /// 封面宽度
  late int? snapshotWidth;

  /// 封面高度
  late int? snapshotHeight;

  /// 视频url，默认不返回，通过getMessageOnlineUrl获取
  late String? videoUrl;

  /// 视频封面url，默认不返回，通过getMessageOnlineUrl获取
  late String? snapshotUrl;

  /// 视频本地路径，downloadMessage之后有值
  String? localVideoUrl;

  /// 封面本地路况，downloadMessage之后有值
  String? localSnapshotUrl;

  V2TimVideoElem({
    this.videoPath,
    // ignore: non_constant_identifier_names
    this.UUID,
    this.videoSize,
    this.duration,
    this.videoType,
    this.snapshotPath,
    this.snapshotUUID,
    this.snapshotSize,
    this.snapshotWidth,
    this.snapshotHeight,
    this.videoUrl,
    this.snapshotUrl,
    this.localVideoUrl,
    this.localSnapshotUrl,
  }): super(elemType: MessageElemType.V2TIM_ELEM_TYPE_VIDEO);

  String? getDefaultLocalUrl({bool isSnapshot = false}) {
    var cacheDir = CommonUtils.appFileDir;
    String filePath = isSnapshot ? snapshotUUID ?? '' : UUID ?? '';

    if (Platform.isAndroid) {
      filePath = isSnapshot ? 'video_$snapshotUUID' : 'video_$UUID';
    } else if (Platform.isIOS) {
      String filePathPrefix = '${CommonUtils.getSDKAppID()}/${CommonUtils.getLoginUser()}';
      filePath = '$filePathPrefix/video_${isSnapshot ? snapshotUUID : UUID}';
    } else if (Platform.isMacOS) {
      String filePathPrefix = '${CommonUtils.getSDKAppID()}/${CommonUtils.getLoginUser()}';
      filePath = '$filePathPrefix/video_${isSnapshot ? snapshotUUID : UUID}';
    } else if (Platform.isWindows) {
      String filePathPrefix = 'TencentCloudChat/DownLoad/${CommonUtils.getSDKAppID()}/${CommonUtils.getLoginUser()}';
      filePath = '$filePathPrefix/video_${isSnapshot ? snapshotUUID : UUID}';
    } else if (Platform.operatingSystem == 'ohos') {
      filePath = isSnapshot ? 'video_$snapshotUUID' : 'video_$UUID';
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

  V2TimVideoElem.fromJson(Map json) {
    elemType = MessageElemType.V2TIM_ELEM_TYPE_VIDEO;
    json = Utils.formatJson(json);
    videoPath = json['video_elem_video_path'];
    UUID = json['video_elem_video_id'];
    videoSize = json['video_elem_video_size'];
    duration = json['video_elem_video_duration'];
    videoType = json['video_elem_video_type'];
    videoUrl = json['video_elem_video_url'];
    snapshotPath = json['video_elem_image_path'];
    snapshotUUID = json['video_elem_image_id'];
    snapshotSize = json['video_elem_image_size'];
    snapshotWidth = json['video_elem_image_width'];
    snapshotHeight = json['video_elem_image_height'];
    snapshotUrl = json['video_elem_image_url'];

    localVideoUrl = getDefaultLocalUrl(isSnapshot: false);
    localSnapshotUrl = getDefaultLocalUrl(isSnapshot: true);
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['elem_type'] = CElemType.ElemVideo;
    data['video_elem_video_path'] = videoPath;
    data['video_elem_video_id'] = UUID;
    data['video_elem_video_size'] = videoSize;
    data['video_elem_video_duration'] = duration;
    data['video_elem_video_type'] = videoType;
    data['video_elem_video_url'] = videoUrl;
    data['video_elem_image_path'] = snapshotPath;
    data['video_elem_image_id'] = snapshotUUID;
    data['video_elem_image_size'] = snapshotSize;
    data['video_elem_image_width'] = snapshotWidth;
    data['video_elem_image_height'] = snapshotHeight;
    data['video_elem_image_url'] = snapshotUrl;

    data['localVideoUrl'] = localVideoUrl;
    data['localSnapshotUrl'] = localSnapshotUrl;
    return data;
  }
  String toLogString() {
    String res = "UUID:$UUID|videoSiz:$videoSize|localVideoUrl:$localVideoUrl|localSnapshotUrl:$localSnapshotUrl";
    return res;
  }
}
