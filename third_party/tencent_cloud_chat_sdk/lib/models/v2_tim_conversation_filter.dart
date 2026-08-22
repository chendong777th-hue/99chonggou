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
    conversationType = json['conversation_list_filter_conv_type'];
    conversationGroup = json['conversation_list_filter_conversation_group'] ?? "";
    markType = json['conversation_list_filter_mark_type'] ?? 0;
    hasUnreadCount = json['conversation_list_filter_has_unread_count'];
    hasGroupAtInfo = json['conversation_list_filter_has_group_at_info'];
  }

  Map<String, dynamic> toJson() {
    // C 接口在底层转化时，参数如果没有填则不要设置。比如 conversation_list_filter_has_unread_count，底层会判断传了该 key 后，就会使用该值。
    final Map<String, dynamic> data = <String, dynamic>{};
    if (conversationType != null) {
      data['conversation_list_filter_conv_type'] = conversationType;
    }

    if (conversationGroup != null) {
      data['conversation_list_filter_conversation_group'] = conversationGroup;
    }

    if (markType != null) {
      data['conversation_list_filter_mark_type'] = markType;
    }

    if (hasUnreadCount != null) {
      data['conversation_list_filter_has_unread_count'] = hasUnreadCount;
    }

    if (hasGroupAtInfo != null) {
      data['conversation_list_filter_has_group_at_info'] = hasGroupAtInfo;
    }

    return data;
  }

  String toLogString() {
    String res = "conversationType:$conversationType|conversationGroup:$conversationGroup|markType:$markType|hasUnreadCount:$hasUnreadCount|hasGroupAtInfo:$hasGroupAtInfo";
    return res;
  }
}
