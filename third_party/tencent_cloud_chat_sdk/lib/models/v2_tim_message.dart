import 'package:tencent_cloud_chat_sdk/enum/conversation_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/message_elem_type.dart';
import 'package:tencent_cloud_chat_sdk/enum/offlinePushInfo.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_at_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_report_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_merger_elem.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message_quote_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_full_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_user_info.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_group_member_info.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_manager.dart';
import '../enum/message_status.dart';
import 'v2_tim_custom_elem.dart';
import 'v2_tim_face_elem.dart';
import 'v2_tim_file_elem.dart';
import 'v2_tim_group_tips_elem.dart';
import 'v2_tim_image_elem.dart';
import 'v2_tim_location_elem.dart';
import 'v2_tim_sound_elem.dart';
import 'v2_tim_text_elem.dart';
import 'v2_tim_video_elem.dart';
import 'v2_tim_stream_elem.dart';
import 'package:tencent_cloud_chat_sdk/utils/utils.dart';
import 'package:tencent_cloud_chat_sdk/native_im/adapter/tim_c_enum.dart';

/// V2TimMessageReceipt
///
/// {@category Models}
///

class V2TimMessage {
  static const createIDPrefix = 'created_temp_id-';
  /// 消息ID
  String? msgID;
  /// 消息时间戳
  int? timestamp;
  /// 消息发送进度，只有多媒体消息才会有，其余消息为100
  int? progress;
  /// 消息发送者
  String? sender;
  /// 消息发送者昵称
  String? nickName;
  /// 消息发送者好友备注，只有当与消息发送者有好友关系，且给好友设置过备注，才会有值
  String? friendRemark;
  /// 发送者头像
  String? faceUrl;
  /// 发送者备注
  String? nameCard;
  /// 群ID，只有群消息才会有
  String? groupID;
  /// 会话用户 ID。假设自己和 userA 聊天，无论是自己发给 userA 的消息还是 userA 发给自己的消息，这里的 userID 均为 userA
  String? userID;
  /// UI 消息状态
  int? _uiStatus;
  /// 消息状态，真正用来跟底层数据传递
  int? _status;
  /// 消息类型 文本消息 图片消息等 [MessageElemType]
  int elemType = MessageElemType.V2TIM_ELEM_TYPE_NONE;
  /// 文本消息
  V2TimTextElem? textElem;
  /// 自定义消息
  V2TimCustomElem? customElem;
  /// 图片消息
  V2TimImageElem? imageElem;
  /// 语音消息
  V2TimSoundElem? soundElem;
  /// 视频消息
  V2TimVideoElem? videoElem;
  /// 文件消息
  V2TimFileElem? fileElem;
  /// 位置消息
  V2TimLocationElem? locationElem;
  /// 表情消息
  V2TimFaceElem? faceElem;
  /// 群提示消息
  V2TimGroupTipsElem? groupTipsElem;
  /// 合并消息
  V2TimMergerElem? mergerElem;
  /// 群系统通知消息
  V2TimGroupReportElem? groupReportElem;
  /// 流式消息
  V2TimStreamElem? streamElem;
  /// 消息的本地自定义字段（string类型），只存在于本地，删除应用后丢失
  String? localCustomData;
  /// 消息的本地自定义字段（int 类型），只存在于本地，删除应用后丢失
  int? localCustomInt;
  /// 消息的云端自定义字段（string类型）
  String? cloudCustomData;
  /// 是否是当前登录用户的消息
  bool? isSelf;
  /// 消息是否自己已读
  bool? isRead;
  /// 消息是否接收方已读，仅c2c消息有效
  bool? isPeerRead;
  /// 消息优先级
  int? priority;
  /// 离线推送相关配置
  OfflinePushInfo? offlinePushInfo;
  /// 群@消息@数组
  List<String>? groupAtUserList = List.empty(growable: true);
  /// 消息序列号
  String? seq;
  /// 合并消息
  int? random;
  /// 消息是否计入会话未读数
  bool? isExcludedFromUnreadCount;
  /// 消息是否计入会话lastMessage
  bool? isExcludedFromLastMessage;
  /// 消息是否支持消息扩展
  bool? isSupportMessageExtension;
  /// 来自web的消息，仅在flutter for web时有用
  String? messageFromWeb;
  /// 消息id，仅在 createXXXMessage后sendMessage调用异步返回后有效
  String? id; // plugin自己维护的id，在onProgressListener的监听中才返回
  /// 是否要群消息已读回执
  bool? needReadReceipt;
  /// 消息是否有风险内容
  bool? hasRiskContent;
  /// 消息撤回原因
  String? revokeReason;
  /// 是否是广播消息
  bool? isBroadcastMessage;
  /// 消息是否不过内容审核（云端审核）
  bool? isExcludedFromContentModeration;
  /// 消息撤回者信息
  V2TimUserFullInfo? _revokerInfo;
  /// 是否禁用消息发送前云端回调
  bool? isDisableCloudMessagePreHook;
  /// 是否禁用消息发送后云端回调
  bool? isDisableCloudMessagePostHook;
  /// ****************** C 接口新增 ******************
  /// 消息的发送者的用户资料
  V2TimUserInfo? senderProfile;
  /// 消息发送者在群里面的信息，只有在群会话有效。目前仅能获取字段 kTIMGroupMemberInfoIdentifier、kTIMGroupMemberInfoNameCard 其他的字段建议通过 TIMGroupGetMemberInfoList 接口获取
  V2TimGroupMemberInfo? senderGroupMemberInfo;
  /// 是否在线消息
  bool? isOnlineOnly;
  /// 发送者 tinyID
  int? _senderTinyID;
  /// 接收者 tinyID
  int? _receiverTinyID;
  /// 对方是否已读（消息维度，已读的条件：对端针对该消息上报了已读）
  bool? _receiptPeerRead;
  /// 是否已经发送了已读回执（只有Group 消息有效）
  bool? _messageHasSentReceipt;
  /// 该字段是内部字段，不推荐使用，推荐调用 TIMMsgGetMessageReadReceipts 获取群消息已读回执
  int? _messageGroupReceiptReadCount;
  /// 该字段是内部字段，不推荐使用，推荐调用 TIMMsgGetMessageReadReceipts 获取群消息已读回执
  int? _messageGroupReceiptUnreadCount;
  /// 如果需要转发一条消息，不能直接调用 sendMessage 接口发送原消息，该字段设置为 true 再发送。
  bool? isForwardMessage;
  /// 指定群消息接收成员（定向消息）；不支持群 @ 消息设置，不支持社群（Community）和直播群（AVChatRoom）消息设置；该字段设置后，消息会不计入会话未读数。
  List<String>? targetGroupMemberList = [];
  /// 消息版本
  int? _messageVersion;
  /// 消息自定义审核配置 ID
  String? customModerationConfigurationID;
  /// 消息安全打击结果
  int _riskTypeIdentified = 0;
  /// 消息撤回者的 user_id, 仅当消息为撤回状态时有效
  String? _revokerUserID;
  /// 消息撤回者的昵称, 仅当消息为撤回状态时有效
  String? _revokerNickname;
  /// 消息撤回者的头像地址, 仅当消息为撤回状态时有效
  String? _revokerFaceUrl;
  /// 消息置顶者的 user_id, 只有通过 GetPinnedGroupMessageList 获取到的置顶消息才包含该字段
  String? _pinnerUserID;
  /// 消息置顶者的昵称, 只有通过 GetPinnedGroupMessageList 获取到的置顶消息才包含该字段
  String? _pinnerNickname;
  /// 消息置顶者的好友备注, 只有通过 GetPinnedGroupMessageList 获取到的置顶消息才包含该字段
  String? _pinnerRemark;
  /// 消息置顶的群成员名片, 只有通过 GetPinnedGroupMessageList 获取到的置顶消息才包含该字段
  String? _pinnerNameCard;
  /// 消息置顶者的头像, 只有通过 GetPinnedGroupMessageList 获取到的置顶消息才包含该字段
  String? _pinnerFaceUrl;
  /// 消息引用信息
  V2TimMessageQuoteInfo? quoteInfo;
  /// 消息所属会话类型
  int? _messageConvType;
  /// 消息所属会话 ID
  String? _messageConvID;
  /// 服务器时间
  int? _serverTime;
  /// 客户端时间
  int? _clientTime;
  /// 消息元素列表
  List<dynamic> elemList = List.empty(growable: true);
  /// 发消息的平台（选填）
  int? _platform;

  V2TimMessage({
    this.msgID,
    this.timestamp,
    this.progress,
    this.sender,
    this.nickName,
    this.friendRemark,
    this.faceUrl,
    this.nameCard,
    this.groupID,
    this.userID,
    required this.elemType,
    this.textElem,
    this.customElem,
    this.imageElem,
    this.soundElem,
    this.videoElem,
    this.fileElem,
    this.locationElem,
    this.faceElem,
    this.groupTipsElem,
    this.mergerElem,
    this.streamElem,
    this.localCustomData,
    this.localCustomInt,
    this.cloudCustomData,
    this.isSelf,
    this.isRead,
    this.isPeerRead,
    this.priority,
    this.offlinePushInfo,
    this.groupAtUserList,
    this.seq,
    this.random,
    this.isExcludedFromUnreadCount,
    this.isExcludedFromLastMessage,
    this.isSupportMessageExtension,
    this.messageFromWeb,
    this.id,
    this.needReadReceipt,
  }) {
    _clientTime = TIMManager.instance.getServerTime();
    if (timestamp == null || timestamp == 0) {
      timestamp = _clientTime;
    }
  }

  @override
  bool operator ==(Object other) => identical(this, other) || other is V2TimMessage && runtimeType == other.runtimeType && msgID == other.msgID && id == other.id && status == other.status;

  @override
  int get hashCode => msgID.hashCode + id.hashCode + status.hashCode;

  V2TimUserFullInfo? get revokerInfo => _revokerInfo;
  set revokerInfo(V2TimUserFullInfo? userInfo) {
    _revokerInfo = userInfo;
    _revokerUserID = userInfo?.userID;
    _revokerNickname = userInfo?.nickName;
    _revokerFaceUrl = userInfo?.faceUrl;
  }

  /// 消息状态 发送中 成功 失败 撤回 [MessageStatus]
  set status(int? messageStatus) {
    _uiStatus = messageStatus;
  }

  int? get status {
    // 调用方操作撤回消息时，没有全局撤回回调，uikit-v1 调用方会设置状态，但是消息状态不能给底层
    // uikit-v1 在发送消息时也会设置消息为 sending 状态，该状态也不能给底层，否则会导致底层的 random 和 seq 都为 0
    if (_status == null || _uiStatus == MessageStatus.V2TIM_MSG_STATUS_LOCAL_REVOKED) {
      return _uiStatus;
    }

    return _status;
  }

  V2TimMessage.fromJson(Map json) {
    json = Utils.formatJson(json);
    _messageConvType = json['message_conv_type'];
    _messageConvID = json['message_conv_id'];
    if (_messageConvType == ConversationType.V2TIM_GROUP) {
      groupID = _messageConvID;
    } else {
      userID = _messageConvID;
    }
    sender = json['message_sender'];
    _senderTinyID = json['message_sender_tiny_id'];
    _receiverTinyID = json['message_receiver_tiny_id'];
    priority = json['message_priority'];
    _clientTime = json['message_client_time'];
    _serverTime = json['message_server_time'];
    if (_serverTime != null && _serverTime! > 0) {
      timestamp = _serverTime;
    } else {
      timestamp = _clientTime ?? 0;
    }
    isSelf = json['message_is_from_self'];
    _platform = json['message_platform'];
    isRead = json['message_is_read'];
    isOnlineOnly = json['message_is_online_msg'];
    isPeerRead = json['message_is_peer_read'];
    _receiptPeerRead = json['message_receipt_peer_read'];
    needReadReceipt = json['message_need_read_receipt'];
    isBroadcastMessage = json['message_is_broadcast_message'];
    _messageHasSentReceipt = json['message_has_sent_receipt'];
    _messageGroupReceiptReadCount = json['message_group_receipt_read_count'];
    _messageGroupReceiptUnreadCount = json['message_group_receipt_unread_count'];
    isSupportMessageExtension = json["message_support_message_extension"];
    _messageVersion = json['message_version'];
    _status = json['message_status'];
    // 只是给 Flutter 层使用
    _uiStatus = json['ui_status'];
    msgID = json['message_msg_id'];
    seq = json['message_seq']?.toString();
    random = json['message_rand'];
    localCustomInt = json['message_custom_int'];
    localCustomData = json['message_custom_str'] ?? "";
    cloudCustomData = json['message_cloud_custom_str'] ?? "";
    isExcludedFromUnreadCount = json['message_is_excluded_from_unread_count'];
    senderProfile = json['message_sender_profile'] != null ? V2TimUserInfo.fromJson(json['message_sender_profile']) : null;
    nickName = senderProfile?.nickName;
    faceUrl = senderProfile?.faceUrl;
    if (senderProfile != null) {
      friendRemark = json['message_sender_profile']['user_profile_friend_remark'];
    }
    isExcludedFromLastMessage = json['message_excluded_from_last_message'];
    isExcludedFromContentModeration = json['message_excluded_from_content_moderation'];
    customModerationConfigurationID = json['message_custom_moderation_configuration_id'];
    _riskTypeIdentified = json['message_risk_type_identified'];
    hasRiskContent = _riskTypeIdentified > 1 ? true : false;
    isDisableCloudMessagePreHook = json['message_disable_cloud_message_pre_hook'];
    isDisableCloudMessagePostHook = json['message_disable_cloud_message_post_hook'];
    revokeReason = json['message_revoke_reason'];
    _revokerUserID = json['message_revoker_user_id'];
    _revokerNickname = json['message_revoker_nick_name'];
    _revokerFaceUrl = json['message_revoker_face_url'];
    if (_revokerUserID != null) {
      _revokerInfo = V2TimUserFullInfo();
      _revokerInfo!.userID = _revokerUserID;
      _revokerInfo!.nickName = _revokerNickname;
      _revokerInfo!.faceUrl = _revokerFaceUrl;
    }

    _pinnerUserID = json['message_pinner_user_id'];
    _pinnerNickname = json['message_pinner_nick_name'];
    _pinnerRemark = json['message_pinner_friend_remark'];
    _pinnerNameCard = json['message_pinner_name_card'];
    _pinnerFaceUrl = json['message_pinner_face_url'];
    quoteInfo = json['message_quote_info'] != null ? V2TimMessageQuoteInfo.fromJson(json['message_quote_info']) : null;
    targetGroupMemberList = json['message_target_group_member_array']?.cast<String>() ?? [];
    groupAtUserList = json['message_group_at_user_array']?.cast<String>() ?? [];
    groupAtUserList = groupAtUserList!.map((item) => item == V2TimGroupAtInfo.c_api_tag ? V2TimGroupAtInfo.AT_ALL_TAG : item).toList();
    senderGroupMemberInfo = V2TimGroupMemberInfo.fromJson(json['message_sender_group_member_info'] ?? {});
    nameCard = senderGroupMemberInfo?.nameCard;
    offlinePushInfo = json['message_offline_push_config'] != null ? OfflinePushInfo.fromJson(json['message_offline_push_config']) : null;

    var jsonElemList = json["message_elem_array"] ?? List.empty(growable: true);
    for (int elemIndex = 0; elemIndex < jsonElemList.length; ++elemIndex) {
      var jsonElem = jsonElemList[elemIndex] as Map<String, dynamic>;

      // elemType 和 elem 取第一个值作为消息的元素内容
      int cElemType = jsonElem['elem_type'] ?? -1;
      if (cElemType == CElemType.ElemText) {
        var element = V2TimTextElem.fromJson(jsonElem);
        if (elemIndex == 0) {
          elemType = MessageElemType.V2TIM_ELEM_TYPE_TEXT;
          element.setMessageInternal(this);
          element.setElemIndexInternal(0);
          textElem = element;
        }

        elemList.add(element);
      } else if (cElemType == CElemType.ElemCustom) {
        var element = V2TimCustomElem.fromJson(jsonElem);
        if (elemIndex == 0) {
          elemType = MessageElemType.V2TIM_ELEM_TYPE_CUSTOM;
          element.setMessageInternal(this);
          element.setElemIndexInternal(0);
          customElem = element;
        }

        elemList.add(element);
      } else if (cElemType == CElemType.ElemImage) {
        var element = V2TimImageElem.fromJson(jsonElem);
        if (elemIndex == 0) {
          elemType = MessageElemType.V2TIM_ELEM_TYPE_IMAGE;
          element.setMessageInternal(this);
          element.setElemIndexInternal(0);
          imageElem = element;
        }

        elemList.add(element);
      } else if (cElemType == CElemType.ElemSound) {
        var element = V2TimSoundElem.fromJson(jsonElem);
        if (elemIndex == 0) {
          elemType = MessageElemType.V2TIM_ELEM_TYPE_SOUND;
          element.setMessageInternal(this);
          element.setElemIndexInternal(0);
          soundElem = element;
        }

        elemList.add(element);
      } else if (cElemType == CElemType.ElemVideo)  {
        var element = V2TimVideoElem.fromJson(jsonElem);
        if (elemIndex == 0) {
          elemType = MessageElemType.V2TIM_ELEM_TYPE_VIDEO;
          element.setMessageInternal(this);
          element.setElemIndexInternal(0);
          videoElem = element;
        }

        elemList.add(element);
      } else if (cElemType == CElemType.ElemFile) {
        var element = V2TimFileElem.fromJson(jsonElem);
        if (elemIndex == 0) {
          elemType = MessageElemType.V2TIM_ELEM_TYPE_FILE;
          element.setMessageInternal(this);
          element.setElemIndexInternal(0);
          fileElem = element;
        }

        elemList.add(element);
      } else if (cElemType == CElemType.ElemLocation)  {
        var element = V2TimLocationElem.fromJson(jsonElem);
        if (elemIndex == 0) {
          elemType = MessageElemType.V2TIM_ELEM_TYPE_LOCATION;
          element.setMessageInternal(this);
          element.setElemIndexInternal(0);
          locationElem = element;
        }

        elemList.add(element);
      } else if (cElemType == CElemType.ElemFace)  {
        var element = V2TimFaceElem.fromJson(jsonElem);
        if (elemIndex == 0) {
          elemType = MessageElemType.V2TIM_ELEM_TYPE_FACE;
          element.setMessageInternal(this);
          element.setElemIndexInternal(0);
          faceElem = element;
        }

        elemList.add(element);
      } else if (cElemType == CElemType.ElemGroupTips) {
        var element = V2TimGroupTipsElem.fromJson(jsonElem);
        if (elemIndex == 0) {
          elemType = MessageElemType.V2TIM_ELEM_TYPE_GROUP_TIPS;
          element.setMessageInternal(this);
          element.setElemIndexInternal(0);
          groupTipsElem = element;
        }
        elemList.add(element);
      } else if (cElemType == CElemType.ElemGroupReport) {
        var element = V2TimGroupReportElem.fromJson(jsonElem);
        if (elemIndex == 0) {
          elemType = MessageElemType.V2TIM_ELEM_TYPE_GROUP_REPORT;
          element.setMessageInternal(this);
          element.setElemIndexInternal(0);
          groupReportElem = element;
        }
        elemList.add(element);
      } else if (cElemType == CElemType.ElemMerge)  {
        var element = V2TimMergerElem.fromJson(jsonElem);
        if (elemIndex == 0) {
          elemType = MessageElemType.V2TIM_ELEM_TYPE_MERGER;
          element.setMessageInternal(this);
          element.setElemIndexInternal(0);
          mergerElem = element;
        }
        elemList.add(element);
      } else if (cElemType == CElemType.ElemStream) {
        var element = V2TimStreamElem.fromJson(jsonElem);
        if (elemIndex == 0) {
          elemType = MessageElemType.V2TIM_ELEM_TYPE_STREAM;
          element.setMessageInternal(this);
          element.setElemIndexInternal(0);
          streamElem = element;
        }
        elemList.add(element);
      }
    }

    if (jsonElemList.length == 0)   {
      elemType = json['elem_type'] ?? -1;
    }

    isForwardMessage = json['message_is_forward_message'];

    progress = json['progress'];
    id = json['id'];
  }

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['elem_type'] = elemType;
    data['message_conv_type'] = _messageConvType;
    data['message_is_from_self'] = isSelf;
    data['message_sender'] = sender;
    data['message_sender_tiny_id'] = _senderTinyID;
    data['message_receiver_tiny_id'] = _receiverTinyID;
    data['message_priority'] = priority;
    data['message_client_time'] = _clientTime;
    data['message_server_time'] = _serverTime;
    data['message_platform'] = _platform;
    data['message_is_online_msg'] = isOnlineOnly;
    data['message_is_read'] = isRead;
    data['message_is_peer_read'] = isPeerRead;
    data['message_receipt_peer_read'] = _receiptPeerRead;
    data['message_need_read_receipt'] = needReadReceipt;
    data['message_has_sent_receipt'] = _messageHasSentReceipt;
    data['message_group_receipt_read_count'] = _messageGroupReceiptReadCount;
    data['message_group_receipt_unread_count'] = _messageGroupReceiptUnreadCount;
    data['message_support_message_extension'] = isSupportMessageExtension;
    data['message_version'] = _messageVersion;
    data['message_status'] = _status;
    // 只是给 Flutter 层使用
    data['ui_status'] = _uiStatus;
    data['message_seq'] = seq != null ? int.tryParse(seq!) : seq;
    data['message_rand'] = random;
    data['message_custom_int'] = localCustomInt;
    data['message_custom_str'] = localCustomData;
    data['message_cloud_custom_str'] = cloudCustomData;
    data['message_is_excluded_from_unread_count'] = isExcludedFromUnreadCount;
    data['message_is_forward_message'] = isForwardMessage;
    data['message_excluded_from_last_message'] = isExcludedFromLastMessage;
    data['message_excluded_from_content_moderation'] = isExcludedFromContentModeration;
    data['message_custom_moderation_configuration_id'] = customModerationConfigurationID;
    data['message_risk_type_identified'] = _riskTypeIdentified;
    data['message_disable_cloud_message_pre_hook'] = isDisableCloudMessagePreHook;
    data['message_disable_cloud_message_post_hook'] = isDisableCloudMessagePostHook;
    data['message_revoker_user_id'] = _revokerUserID;
    data['message_revoker_nick_name'] = _revokerNickname;
    data['message_revoker_face_url'] = _revokerFaceUrl;
    data['message_revoke_reason'] = revokeReason;
    data['message_pinner_user_id'] = _pinnerUserID;
    data['message_pinner_nick_name'] = _pinnerNickname;
    data['message_pinner_friend_remark'] = _pinnerRemark;
    data['message_pinner_name_card'] = _pinnerNameCard;
    data['message_pinner_face_url'] = _pinnerFaceUrl;
    data['message_quote_info'] = quoteInfo?.toJson();
    data['message_target_group_member_array'] = targetGroupMemberList;
    data['message_conv_id'] = _messageConvID;
    data['message_group_at_user_array'] = groupAtUserList;
    data['message_sender_profile'] = senderProfile?.toJson();
    if (senderProfile != null) {
      data['message_sender_profile']['user_profile_friend_remark'] = friendRemark;
    }
    data['message_sender_group_member_info'] = senderGroupMemberInfo?.toJson();
    data['message_offline_push_config'] = offlinePushInfo?.toJson();
    data['message_elem_array'] = elemList.map((e) => e.toJson()).toList();

    data['id'] = id;
    data['progress'] = progress;
    if (msgID != null && !msgID!.startsWith(createIDPrefix)) {
      data['message_msg_id'] = msgID;
    }
    return data;
  }

  get messageConvType => _messageConvType;
  get messageConvID => _messageConvID;

  String toLogString() {
    var res =
        "|msgID:$msgID|seq:$seq|random:$random|isSelf:$isSelf|sender:$sender|timestamp:$timestamp|elemType:$elemType|groupID:$groupID|hasRiskContent:$hasRiskContent|isRead:$isRead|isPeerRead:$isPeerRead|isExcludedFromUnreadCount:$isExcludedFromUnreadCount|isExcludedFromLastMessage:$isExcludedFromLastMessage|isSupportMessageExtension:$isSupportMessageExtension|isExcludedFromContentModeration:$isExcludedFromContentModeration|isDisableCloudMessagePreHook:$isDisableCloudMessagePreHook|isDisableCloudMessagePostHook:$isDisableCloudMessagePostHook|cloudCustomData:$cloudCustomData|localCustomData:$localCustomData|offlinePushInfo:${offlinePushInfo?.toLogString()}";
    return res;
  }
}
// {
//   "msgID":"",
//     "timestamp":0,
//     "progress":100,
//     "sender":"",
//     "nickName":"",
//     "friendRemark":"",
//     "faceUrl":"",
//     "nameCard":"",
//     "groupID":"",
//     "userID":"",
//     "status":1,
//     "elemType":1,
//     "textElem":{},
//     "customElem":{},
//     "imageElem":{},
//     "soundElem":{},
//     "videoElem":{},
//     "fileElem":{},
//     "locationElem":{},
//     "faceElem":{},
//     "groupTipsElem":{},
//     "mergerElem":{},
//     "localCustomData":"",
//     "localCustomInt":0,
//     "isSelf":false,
//     "isRead":false,
//     "isPeerRead":false,
//     "priority":0,
//     "offlinePushInfo":{},
//     "groupAtUserList":[{}],
//     "seq":0,
//     "random":0,
//     "isExcludedFromUnreadCount":false
// }
