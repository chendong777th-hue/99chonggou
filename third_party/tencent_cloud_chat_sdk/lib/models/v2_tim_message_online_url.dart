import 'package:tencent_cloud_chat_sdk/models/v2_tim_file_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_image_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_sound_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_video_elem.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimMessageOnlineUrl
///
/// {@category Models}
///
class V2TimMessageOnlineUrl {
  V2TimImageElem? imageElem;
  V2TimSoundElem? soundElem;
  V2TimVideoElem? videoElem;
  V2TimFileElem? fileElem;

  V2TimMessageOnlineUrl({
    this.imageElem,
    this.soundElem,
    this.videoElem,
    this.fileElem,
  });

  V2TimMessageOnlineUrl.fromJson(Map json) {
    json = Utils.formatJson(json);
    imageElem = json['imageElem'] != null ? V2TimImageElem.fromJson(json['imageElem']) : null;
    soundElem = json['soundElem'] != null ? V2TimSoundElem.fromJson(json['soundElem']) : null;
    videoElem = json['videoElem'] != null ? V2TimVideoElem.fromJson(json['videoElem']) : null;
    fileElem = json['fileElem'] != null ? V2TimFileElem.fromJson(json['fileElem']) : null;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['imageElem'] = imageElem?.toJson();
    data['soundElem'] = soundElem?.toJson();
    data['videoElem'] = videoElem?.toJson();
    data['fileElem'] = fileElem?.toJson();
    return data;
  }

  String toLogString() {
    String res = "imageElem:${imageElem?.toLogString()}|soundElem:${soundElem?.toLogString()}|videoElem:${videoElem?.toLogString()}|fileElem:${fileElem?.toLogString()}";
    return res;
  }
}

// {
//   "userID":"",
//   "timestamp":0
// }
