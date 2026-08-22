import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_elem.dart';
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
  late String? videoType; // web 端不支持

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
  });

  V2TimVideoElem.fromJson(Map json) {
    json = Utils.formatJson(json);
    videoPath = json['videoPath'];
    UUID = json['UUID'];
    videoSize = json['videoSize'];
    duration = json['duration'];
    snapshotPath = json['snapshotPath'];
    snapshotUUID = json['snapshotUUID'];
    snapshotSize = json['snapshotSize'];
    snapshotWidth = json['snapshotWidth'];
    snapshotHeight = json['snapshotHeight'];
    videoUrl = json['videoUrl'];
    snapshotUrl = json['snapshotUrl'];
    localVideoUrl = json['localVideoUrl'];
    localSnapshotUrl = json['localSnapshotUrl'];
    if (json['nextElem'] != null) {
      nextElem = Utils.formatJson(json['nextElem']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['videoPath'] = videoPath;
    data['UUID'] = UUID;
    data['videoSize'] = videoSize;
    data['duration'] = duration;
    data['snapshotPath'] = snapshotPath;
    data['snapshotUUID'] = snapshotUUID;
    data['snapshotSize'] = snapshotSize;
    data['snapshotWidth'] = snapshotWidth;
    data['snapshotHeight'] = snapshotHeight;
    data['videoUrl'] = videoUrl;
    data['snapshotUrl'] = snapshotUrl;
    data['localVideoUrl'] = localVideoUrl;
    data['localSnapshotUrl'] = localSnapshotUrl;
    if (nextElem != null) {
      data['nextElem'] = nextElem;
    }
    return data;
  }
  String toLogString() {
    String res = "UUID:$UUID|videoSiz:$videoSize|localVideoUrl:${localVideoUrl == null ? false : true}|localSnapshotUrl:${localSnapshotUrl == null ? false : true}";
    return res;
  }
}

// {
//   "videoPath":"",
//   "UUID":"",
//   "videoSize":0,
//   "duration":0,
//   "snapshotPath":"",
//   "snapshotUUID":"",
//   "snapshotSize":0,
//   "snapshotWidth":0,
//   "snapshotHeight":0,
//   "videoUrl":"",
//   "snapshotUrl":""
// }
