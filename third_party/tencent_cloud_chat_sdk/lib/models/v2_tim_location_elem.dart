
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_c_enum.dart';
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
      {this.desc, required this.longitude, required this.latitude}): super(elemType: MessageElemType.V2TIM_ELEM_TYPE_LOCATION);

  V2TimLocationElem.fromJson(Map json) {
    elemType = MessageElemType.V2TIM_ELEM_TYPE_LOCATION;
    json = Utils.formatJson(json);
    desc = json['location_elem_desc'];
    longitude = (json['location_elem_longitude'] ?? 0.0).toDouble();
    latitude = (json['location_elem_latitude'] ?? 0.0).toDouble();
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['elem_type'] = CElemType.ElemLocation;
    data['location_elem_desc'] = desc;
    data['location_elem_longitude'] = longitude;
    data['location_elem_latitude'] = latitude;
    return data;
  }
  String toLogString() {
    String res = "desc:$desc|longitude:$longitude|latitude:$latitude";
    return res;
  }
}
