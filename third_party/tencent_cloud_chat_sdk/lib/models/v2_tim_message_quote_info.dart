import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimMessageQuoteInfo
///
/// {@category Models}
///
class V2TimMessageQuoteInfo {
  /// 被引用的消息 ID
  String? msgID;

  /// 被引用的消息时间
  int? messageTime;

  /// 被引用的消息 sequence
  int? messageSequence;

  V2TimMessageQuoteInfo({
    this.msgID,
    this.messageTime,
    this.messageSequence,
  });

  V2TimMessageQuoteInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    msgID = json['message_quote_info_msg_id'];
    messageTime = json['message_quote_info_message_time'];
    messageSequence = json['message_quote_info_message_sequence'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['message_quote_info_msg_id'] = msgID;
    data['message_quote_info_message_time'] = messageTime;
    data['message_quote_info_message_sequence'] = messageSequence;
    return data;
  }

  String toLogString() {
    return "msgID:$msgID|messageTime:$messageTime|messageSequence:$messageSequence";
  }

  @override
  String toString() {
    return "V2TimMessageQuoteInfo{msgID: $msgID, messageTime: $messageTime, messageSequence: $messageSequence}";
  }
}
