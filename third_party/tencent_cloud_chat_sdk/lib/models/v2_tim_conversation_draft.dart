import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimConversationDraft
///
/// {@category Models}
///
class V2TimConversationDraft {
  V2TimMessage? message;
  String? customData;
  int? editTime;


  V2TimConversationDraft({
    this.message,
    this.customData,
    this.editTime,
  });

  V2TimConversationDraft.fromJson(Map json) {
    json = Utils.formatJson(json);
    message = json['draft_msg'] != null ? V2TimMessage.fromJson(json['draft_msg']) : null;
    customData = json['draft_user_define'];
    editTime = json['draft_edit_time'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['draft_msg'] = message?.toJson();
    data['draft_user_define'] = customData;
    data['draft_edit_time'] = editTime;
    return data;
  }

  String toLogString() {
    String res = "message:${message?.toLogString()}|customData:$customData|editTime:$editTime";
    return res;
  }
}

// {
//   "nextSeq":0,
//   "isFinished":true,
//   "conversationList":[{}]
// }
