import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_c_enum.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_elem.dart';

/// V2TimStreamElem
///
/// {@category Models}
///
class V2TimStreamElem extends V2TIMElem {
  late String? markdown;
  late String? data;
  late bool? isStreamEnded;

  V2TimStreamElem({
    this.markdown,
    this.data,
    this.isStreamEnded,
  }): super(elemType: MessageElemType.V2TIM_ELEM_TYPE_STREAM);

  V2TimStreamElem.fromJson(Map json) {
    elemType = MessageElemType.V2TIM_ELEM_TYPE_STREAM;
    json = Utils.formatJson(json);
    markdown = json['stream_elem_markdown'];
    data = json['stream_elem_data'];
    isStreamEnded = json['stream_elem_is_stream_ended'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> mapData = <String, dynamic>{};
    mapData['elem_type'] = CElemType.ElemStream;
    mapData['stream_elem_markdown'] = markdown;
    mapData['stream_elem_data'] = data;
    mapData['stream_elem_is_stream_ended'] = isStreamEnded;
    return mapData;
  }
  String toLogString() {
    String res = "markdown:$markdown|data:$data|isStreamEnded:$isStreamEnded";
    return res;
  }
}
