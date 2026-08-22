// ignore_for_file: file_names

import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_at_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';

/// V2TimTopicInfo
///
/// {@category Models}
///
class V2TimTopicInfo {
  String? topicID;
  String? topicName;
  String? topicFaceUrl;
  String? introduction;
  String? notification;
  bool? isAllMute = false;
  int? selfMuteTime;
  String? customString;
  int? recvOpt;
  String? draftText;
  int? unreadCount = 0;
  V2TimMessage? lastMessage;
  int? messageReadSequence;
  List<V2TimGroupAtInfo>? groupAtInfoList = List.empty(growable: true);
  int? createTime;
  int? defaultPermissions = 0;
  bool? isInheritMessageReceiveOptionFromCommunity = false;

  V2TimTopicInfo({
    this.topicID,
    this.topicName,
    this.topicFaceUrl,
    this.introduction,
    this.notification,
    this.isAllMute,
    this.selfMuteTime,
    this.customString,
    this.draftText,
    this.unreadCount,
    this.lastMessage,
    this.messageReadSequence,
    this.groupAtInfoList,
    this.createTime,
    this.defaultPermissions,
    this.isInheritMessageReceiveOptionFromCommunity,
  });
  V2TimTopicInfo.fromJson(Map json) {
    json = Utils.formatJson(json);
    topicID = json['group_topic_info_topic_id'];
    topicName = json['group_topic_info_topic_name'];
    topicFaceUrl = json['group_topic_info_topic_face_url'];
    introduction = json['group_topic_info_introduction'];
    notification = json['group_topic_info_notification'];
    isAllMute = json['group_topic_info_is_all_muted'];
    selfMuteTime = json['group_topic_info_self_mute_time'];
    customString = json['group_topic_info_custom_string'];
    draftText = json['group_topic_info_draft_text'];
    recvOpt = json['group_topic_info_recv_opt'];
    unreadCount = json['group_topic_info_unread_count'];
    messageReadSequence = json['topic_info_read_sequence'];
    createTime = json['topic_create_time'];
    defaultPermissions = json["default_permissions"] ?? 0;

    if (json['group_topic_info_last_message'] != null) {
      lastMessage = V2TimMessage.fromJson(json['group_topic_info_last_message']);
    }

    if (json['group_topic_info_group_at_info_array'] != null) {
      groupAtInfoList = List.empty(growable: true);
      json['group_topic_info_group_at_info_array'].forEach((v) {
        groupAtInfoList!.add(V2TimGroupAtInfo.fromJson(v));
      });
    }
  }
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['group_topic_info_topic_id'] = topicID;
    data['group_topic_info_topic_name'] = topicName;
    data['group_topic_info_topic_face_url'] = topicFaceUrl;
    data['group_topic_info_introduction'] = introduction;
    data['group_topic_info_notification'] = notification;
    data['group_topic_info_is_all_muted'] = isAllMute;
    data['group_topic_info_self_mute_time'] = selfMuteTime;
    data['group_topic_info_custom_string'] = customString;
    data['group_topic_info_draft_text'] = draftText;
    data['group_topic_info_unread_count'] = unreadCount;
    data['group_topic_info_recv_opt'] = recvOpt;
    data['group_topic_info_last_message'] = lastMessage?.toJson();
    data['topic_info_read_sequence'] = messageReadSequence;
    data['topic_create_time'] = createTime;
    data['default_permissions'] = defaultPermissions ?? 0;

    if (groupAtInfoList != null) {
      data['group_topic_info_group_at_info_array'] = groupAtInfoList!.map((v) => v.toJson()).toList();
    }

    return data;
  }

  String toLogString() {
    String res = "topicID: $topicID|topicName: $topicName|isAllMute: $isAllMute|selfMuteTime: $selfMuteTime|recvOpt: $recvOpt|unreadCount: $unreadCount|messageReadSequence: $messageReadSequence|defaultPermissions: $defaultPermissions||lastMessageID:${lastMessage?.msgID}";
    return res;
  }
}
