import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_c_enum.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimFaceElem
///
/// {@category Models}
///
class V2TimFaceElem extends V2TIMElem {
  late int? index;
  late String? data;

  V2TimFaceElem({
    this.index,
    this.data,
  }): super(elemType: MessageElemType.V2TIM_ELEM_TYPE_FACE);

  V2TimFaceElem.fromJson(Map json) {
    elemType = MessageElemType.V2TIM_ELEM_TYPE_FACE;
    json = Utils.formatJson(json);
    index = json['face_elem_index'];
    data = json['face_elem_buf'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['elem_type'] = CElemType.ElemFace;
    data['face_elem_index'] = index;
    data['face_elem_buf'] = this.data;
    return data;
  }
  String toLogString() {
    String res = "index:$index|data:$data";
    return res;
  }
}
