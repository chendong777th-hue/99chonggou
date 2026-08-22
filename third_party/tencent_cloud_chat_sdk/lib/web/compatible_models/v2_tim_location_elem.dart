import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimLocationElem
///
/// {@category Models}
///
class V2TimLocationElem extends V2TIMElem {
  late String? desc;
  late double longitude;
  late double latitude;

  V2TimLocationElem(
      {this.desc, required this.longitude, required this.latitude});

  V2TimLocationElem.fromJson(Map json) {
    json = Utils.formatJson(json);
    desc = json['desc'];
    longitude = json['longitude'];
    latitude = json['latitude'];
    if (json['nextElem'] != null) {
      nextElem = Utils.formatJson(json['nextElem']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['desc'] = desc;
    data['longitude'] = longitude;
    data['latitude'] = latitude;
    if (nextElem != null) {
      data['nextElem'] = nextElem;
    }
    return data;
  }
  String toLogString() {
    String res = "desc:$desc|longitude:$longitude|latitude:$latitude";
    return res;
  }
}

// {
//   "desc":"",
//   "longitude":0.0,
// "latitude":0.0
// }
