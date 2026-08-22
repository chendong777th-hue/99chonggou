import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_elem.dart';

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
  });

  V2TimStreamElem.fromJson(Map json) {
    json = Utils.formatJson(json);
    markdown = json['stream_elem_markdown'];
    data = json['stream_elem_data'];
    isStreamEnded = json['stream_elem_is_stream_ended'];
    if (json['nextElem'] != null) {
      nextElem = Utils.formatJson(json['nextElem']);
    }
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> mapData = <String, dynamic>{};
    mapData['stream_elem_markdown'] = markdown;
    mapData['stream_elem_data'] = data;
    mapData['stream_elem_is_stream_ended'] = isStreamEnded;
    if (nextElem != null) {
      mapData['nextElem'] = nextElem;
    }
    return mapData;
  }
  String toLogString() {
    String res = "markdown:$markdown|data:$data|isStreamEnded:$isStreamEnded";
    return res;
  }
}
