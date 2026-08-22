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
    msgID = json['msgID'];
    messageTime = json['messageTime'];
    messageSequence = json['messageSequence'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['msgID'] = msgID;
    data['messageTime'] = messageTime;
    data['messageSequence'] = messageSequence;
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
