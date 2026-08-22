import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

class V2TimConversationFilter {
  int? conversationType;

  String? conversationGroup;

  int? markType;

  bool? hasUnreadCount;

  bool? hasGroupAtInfo;

  V2TimConversationFilter({
    this.conversationGroup,
    this.conversationType,
    this.hasGroupAtInfo,
    this.hasUnreadCount,
    this.markType,
  });

  V2TimConversationFilter.fromJson(Map json) {
    json = Utils.formatJson(json);
    conversationType = json['conversationType'];
    conversationGroup = json['conversationGroup'];
    markType = json['markType'] ?? 0;
    hasUnreadCount = json['hasUnreadCount'];
    hasGroupAtInfo = json['hasGroupAtInfo'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['conversationType'] = conversationType;
    data['conversationGroup'] = conversationGroup;
    data['markType'] = markType;
    data['hasUnreadCount'] = hasUnreadCount;
    data['hasGroupAtInfo'] = hasGroupAtInfo;
    return data;
  }
  String toLogString() {
    String res = "conversationType:$conversationType|conversationGroup:$conversationGroup|markType:$markType|hasUnreadCount:$hasUnreadCount|hasGroupAtInfo:$hasGroupAtInfo";
    return res;
  }
}
