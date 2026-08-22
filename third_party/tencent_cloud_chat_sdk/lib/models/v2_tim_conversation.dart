import 'package:tencent_cloud_chat_sdk/enum/conversation_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/utils.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_at_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_conversation_draft.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/web/compatible_models/v2_tim_text_elem.dart';

/// V2TimConversation
///
/// {@category Models}
///
class V2TimConversation {
  late String conversationID;
  int? type;
  String? userID;
  String? groupID;
  String? showName;
  String? faceUrl;
  String? groupType;
  int? unreadCount;
  V2TimMessage? lastMessage;
  String? draftText;
  int? draftTimestamp;
  bool? isPinned;
  int? recvOpt;
  List<V2TimGroupAtInfo?>? groupAtInfoList = List.empty(growable: true);
  int? orderkey;
  List<int?>? markList;
  String? customData;
  List<String?>? conversationGroupList;
  int? c2cReadTimestamp;
  int? groupReadSequence;

  V2TimConversation({
    required this.conversationID,
    this.type,
    this.userID,
    this.groupID,
    this.showName,
    this.faceUrl,
    this.groupType,
    this.unreadCount,
    this.lastMessage,
    this.draftText,
    this.draftTimestamp,
    this.groupAtInfoList,
    this.isPinned,
    this.recvOpt,
    this.orderkey,
    this.markList,
    this.customData,
    this.conversationGroupList,
    this.c2cReadTimestamp,
    this.groupReadSequence,
  });

  V2TimConversation.fromJson(Map json) {
    json = Utils.formatJson(json);
    String cConvID = json['conv_id'] ?? '';
    type = json['conv_type'] ?? ConversationType.CONVERSATION_TYPE_INVALID;
    switch (type) {
      case ConversationType.V2TIM_C2C:
        userID = cConvID;
        conversationID = 'c2c_$userID';
        break;
      case ConversationType.V2TIM_GROUP:
        groupID = cConvID;
        conversationID = 'group_$groupID';
        break;
      default:
        conversationID = cConvID;
        print('invalid conversation type!');
        break;
    }

    showName = json['conv_show_name'];
    faceUrl = json['conv_face_url'];
    if (json['conv_group_type'] != null) {
      groupType = EnumUtils.cGroupType2DartType(json['conv_group_type']);
    }
    unreadCount = json['conv_unread_num'];
    isPinned = json['conv_is_pinned'];
    recvOpt = EnumUtils.cReceiveMessageOpt2DartOpt(json['conv_recv_opt']).index;
    orderkey = json['conv_active_time'];
    lastMessage = json['conv_last_msg'] != null
        ? V2TimMessage.fromJson(json['conv_last_msg'])
        : null;
    if (json['conv_is_has_draft'] ?? false) {
        V2TimConversationDraft draft = V2TimConversationDraft.fromJson(json['conv_draft'] ?? {});
        draftText = draft.message?.textElem?.text;
        draftTimestamp = draft.editTime;
    }
    customData = json['conv_custom_data'];
    if (json['conv_mark_array'] != null) {
      markList = List.empty(growable: true);
      json['conv_mark_array'].forEach((v) {
        markList?.add(v);
      });
    }
    if (json['conv_conversation_group_array'] != null) {
      conversationGroupList = List.empty(growable: true);
      json['conv_conversation_group_array'].forEach((v) {
        conversationGroupList?.add(v);
      });
    }

    if (json['conv_group_at_info_array'] != null) {
      groupAtInfoList = List.empty(growable: true);
      json['conv_group_at_info_array'].forEach((v) {
        groupAtInfoList!.add(V2TimGroupAtInfo.fromJson(v));
      });
    }

    c2cReadTimestamp = json["conv_c2c_read_timestamp"] ?? 0;
    groupReadSequence = json["conv_group_read_sequence"] ?? 0;
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['conv_type'] = type;
    String cConvID = '';
    switch (type) {
      case ConversationType.V2TIM_C2C:
        cConvID = userID ?? '';
        break;
      case ConversationType.V2TIM_GROUP:
        cConvID = groupID ?? '';
        break;
      default:
        cConvID = conversationID;
        print('invalid conversation type!');
        break;
    }
    data['conv_id'] = cConvID;
    data['conv_show_name'] = showName;
    data['conv_face_url'] = faceUrl;
    data['conv_group_type'] = groupType;
    data['conv_unread_num'] = unreadCount;
    data['conv_is_pinned'] = isPinned;
    data['conv_recv_opt'] = recvOpt;
    data['conv_active_time'] = orderkey;
    data['conv_custom_data'] = customData;
    data['conv_c2c_read_timestamp'] = c2cReadTimestamp ?? 0;
    data['conv_group_read_sequence'] = groupReadSequence ?? 0;

    if (lastMessage != null) {
      data['conv_last_msg'] = lastMessage!.toJson();
    }

    if (draftText != null && draftText!.isNotEmpty) {
      data['conv_is_has_draft'] = true;

      V2TimTextElem textElem = V2TimTextElem(text: draftText);
      V2TimMessage v2timMessage = V2TimMessage(elemType: MessageElemType.V2TIM_ELEM_TYPE_TEXT);
      v2timMessage.elemList.add(textElem);
      data['conv_draft'] = V2TimConversationDraft(message: v2timMessage, customData: draftText, editTime: draftTimestamp).toJson();
    }

    if (groupAtInfoList != null) {
      data['conv_group_at_info_array'] =
          groupAtInfoList?.map((v) => v?.toJson()).toList();
    }
    if (conversationGroupList != null) {
      data['conv_conversation_group_array'] =
          conversationGroupList?.map((v) => v).toList();
    }
    if (markList != null) {
      data['conv_mark_array'] = markList?.map((v) => v).toList();
    }
    return data;
  }

  String toLogString() {
    String markListBinary = '';
    if (markList != null) {
      markListBinary = markList!.map((mark) {
        if (mark == null) return 'null';
        // 将64位整数转换为二进制字符串，不补前导0
        return mark.toUnsigned(64).toRadixString(2);
      }).join(', ');
    }

    String res =
        "conversationID:$conversationID|type:$type|userID:$userID|groupID:$groupID|showName:$showName|groupType:$groupType|unreadCount:$unreadCount|isPinned:$isPinned|recvOpt:$recvOpt|customData:$customData|c2cReadTimestamp:$c2cReadTimestamp|groupReadSequence:$groupReadSequence|markList: $markListBinary|lastMessage:${lastMessage?.msgID}";
    return res;
  }
}
