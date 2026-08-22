import 'dart:convert';

import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_c_enum.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimMergerElem extends V2TIMElem {
  late bool? isLayersOverLimit;
  late String? title;
  List<String>? abstractList = List.empty(growable: true);

  late String? compatibleText;
  List<V2TimMessage> messageList = List.empty(growable: true);

  String? _relayPbKey;
  String? _relayJsonKey;
  String? _relayBuffer;



  V2TimMergerElem({
    this.isLayersOverLimit,
    this.title,
    this.abstractList,
    this.compatibleText,
    this.messageList = const [],
  }): super(elemType: MessageElemType.V2TIM_ELEM_TYPE_MERGER);

  V2TimMergerElem.fromJson(Map json) {
    elemType = MessageElemType.V2TIM_ELEM_TYPE_MERGER;
    json = Utils.formatJson(json);
    isLayersOverLimit = json['merge_elem_layer_over_limit'];
    title = json['merge_elem_title'];
    abstractList = json['merge_elem_abstract_array']?.cast<String>() ?? [];
    compatibleText = json['merge_elem_compatible_text'];
    final messageArray = json['merge_elem_message_array']; 
    if (messageArray is List<dynamic>  && messageArray.isNotEmpty) {
      messageList = messageArray.map((v) => V2TimMessage.fromJson(v)).toList();
    }

    _relayPbKey = json['merge_elem_relay_pb_key'];
    _relayJsonKey = json['merge_elem_relay_json_key'];
    _relayBuffer = json['merge_elem_relay_buffer'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['elem_type'] = CElemType.ElemMerge;
    data['merge_elem_layer_over_limit'] = isLayersOverLimit;
    data['merge_elem_title'] = title;
    data['merge_elem_abstract_array'] = abstractList;
    data['merge_elem_message_array'] = messageList.map((v) => v.toJson()).toList();
    data['merge_elem_compatible_text'] = compatibleText;
    data['merge_elem_relay_pb_key'] = _relayPbKey;
    data['merge_elem_relay_json_key'] = _relayJsonKey;
    data['merge_elem_relay_buffer'] = _relayBuffer;

    return data;
  }

  String toLogString() {
    String res = "isLayersOverLimit:$isLayersOverLimit|title:$title|abstractList:${json.encode(abstractList ?? [])}";
    return res;
  }
}

// {
//   "isLayersOverLimit":true,
//   "title":"",
//   "abstractList":[""],
// }
