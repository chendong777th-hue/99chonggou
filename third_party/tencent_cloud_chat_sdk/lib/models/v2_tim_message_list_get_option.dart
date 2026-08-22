import 'package:tencent_cloud_chat_sdk/enum/history_message_get_type.dart';
import 'package:tencent_cloud_chat_sdk/models/v2_tim_message.dart';

class V2TIMMessageListGetOption {
  /// 拉取消息类型，可以设置拉取本地、云端更老或者更新的消息。
  ///
  /// @note 请注意
  /// <p>当设置从云端拉取时，会将本地存储消息列表与云端存储消息列表合并后返回。如果无网络，则直接返回本地消息列表。
  /// <p>关于 getType、拉取消息的起始消息、拉取消息的时间范围 的使用说明：
  /// - getType 可以用来表示拉取的方向：往消息时间更老的方向 或者 往消息时间更新的方向；
  /// - lastMsg/lastMsgSeq 用来表示拉取时的起点，第一次拉取时可以不填或者填 0；
  /// - getTimeBegin/getTimePeriod 用来表示拉取消息的时间范围，时间范围的起止时间点与拉取方向(getType)有关；
  /// - 当起始消息和时间范围都存在时，结果集可理解成：「单独按起始消息拉取的结果」与「单独按时间范围拉取的结果」 取交集；
  /// - 当起始消息和时间范围都不存在时，结果集可理解成：从当前会话最新的一条消息开始，按照 getType 所指定的方向和拉取方式拉取。
  ///
  /// @param getType 拉取类型，取值为 V2TIM_GET_CLOUD_OLDER_MSG，V2TIM_GET_CLOUD_NEWER_MSG，V2TIM_GET_LOCAL_OLDER_MSG，V2TIM_GET_LOCAL_NEWER_MSG
  int? getType;
  /// 拉取单聊历史消息
  late String? userID;
  /// 拉取群组历史消息
  late String? groupID;
  /// 拉取消息数量
  int? count;
  /// 拉取消息的起始消息
  /// @note 请注意
  /// <p>拉取 C2C 消息，只能使用 lastMsg 作为消息的拉取起点；如果没有指定 lastMsg，默认使用会话的最新消息作为拉取起点
  /// <p>拉取 Group 消息时，除了可以使用 lastMsg 作为消息的拉取起点外，也可以使用 lastMsgSeq 来指定消息的拉取起点，二者的区别在于：
  /// - 使用 lastMsg 作为消息的拉取起点时，返回的消息列表里不包含 lastMsg；
  /// - 使用 lastMsgSeq 作为消息拉取起点时，返回的消息列表里包含 lastMsgSeq 所表示的消息；
  ///
  /// @note 在拉取 Group 消息时
  /// <p>如果同时指定了 lastMsg 和 lastMsgSeq，SDK 优先使用 lastMsg 作为消息的拉取起点
  /// <p>如果 lastMsg 和 lastMsgSeq 都未指定，消息的拉取起点分为如下两种情况：
  /// — 如果设置了拉取的时间范围，SDK 会根据 @getTimeBegin 所描述的时间点作为拉取起点
  /// — 如果未设置拉取的时间范围，SDK 默认使用会话的最新消息作为拉取起点
  V2TimMessage? lastMsg;
  /// 拉取群消息的起始 sequence。
  int? lastMsgSeq;
  /// 拉取消息的时间范围
  /// <p>getTimeBegin  表示时间范围的起点；默认为 0，表示从现在开始拉取；UTC 时间戳，单位：秒
  /// <p>getTimePeriod 表示时间范围的长度；默认为 0，表示不限制时间范围；单位：秒
  ///
  /// @note
  /// <p> 时间范围的方向由参数 getType 决定
  /// <p> 如果 getType 取 V2TIM_GET_CLOUD_OLDER_MSG/V2TIM_GET_LOCAL_OLDER_MSG，表示从 getTimeBegin 开始，过去的一段时间，时间长度由 getTimePeriod 决定
  /// <p> 如果 getType 取 V2TIM_GET_CLOUD_NEWER_MSG/V2TIM_GET_LOCAL_NEWER_MSG，表示从 getTimeBegin 开始，未来的一段时间，时间长度由 getTimePeriod 决定
  /// <p> 取值范围区间为闭区间，包含起止时间，二者关系如下：
  /// - 如果 getType 指定了朝消息时间更老的方向拉取，则时间范围表示为 [getTimeBegin-getTimePeriod, getTimeBegin]
  /// - 如果 getType 指定了朝消息时间更新的方向拉取，则时间范围表示为 [getTimeBegin, getTimeBegin+getTimePeriod]
  int? getTimeBegin;
  /// 拉取消息的时间范围
  int? getTimePeriod;
  /// 拉取的消息类型集合，getType 为 V2TIM_GET_LOCAL_OLDER_MSG 和 V2TIM_GET_LOCAL_NEWER_MSG 有效，传空列表表示拉取全部类型消息，取值详见 MessageElemType
  List<int> messageTypeList = [];
  /// 拉取群组历史消息时，支持按照消息序列号 seq 拉取
  ///
  /// @note
  /// - 仅拉取群组历史消息时有效；
  /// - 消息序列号 seq 可以通过 V2TIMMessage 对象的 seq 字段获取；
  /// - 当 getType 设置为从云端拉取时，会将本地存储消息列表与云端存储消息列表合并后返回；如果无网络，则直接返回本地消息列表；
  /// - 当 getType 设置为从本地拉取时，直接返回本地的消息列表；
  /// - 当 getType 设置为拉取更旧的消息时，消息列表按照时间逆序，也即消息按照时间戳从大往小的顺序排序；
  /// - 当 getType 设置为拉取更新的消息时，消息列表按照时间顺序，也即消息按照时间戳从小往大的顺序排序。
  List<int> messageSeqList = [];

  /// 内部使用
  bool _toOlderMessage = true;
  bool _getCloudMessage = true;

  V2TIMMessageListGetOption({
    this.getType,
    this.userID,
    this.groupID,
    this.count,
    this.lastMsg,
    this.getTimeBegin,
    this.getTimePeriod,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['msg_getmsglist_param_count'] = count;
    data['msg_getmsglist_param_last_msg'] = lastMsg?.toJson();
    data['msg_getmsglist_param_last_msg_seq'] = lastMsgSeq;

    switch (getType) {
      case HistoryMessageGetType.V2TIM_GET_LOCAL_NEWER_MSG:
        _toOlderMessage = false;
        _getCloudMessage = false;
        break;
      case HistoryMessageGetType.V2TIM_GET_LOCAL_OLDER_MSG:
        _toOlderMessage = true;
        _getCloudMessage = false;
        break;
      case HistoryMessageGetType.V2TIM_GET_CLOUD_NEWER_MSG:
        _toOlderMessage = false;
        _getCloudMessage = true;
        break;
      case HistoryMessageGetType.V2TIM_GET_CLOUD_OLDER_MSG:
        _toOlderMessage = true;
        _getCloudMessage = true;
        break;
      default:
        print('V2TIMMessageListGetOption, getType is invalid');
        break;
    }

    data['msg_getmsglist_param_is_forward'] = _toOlderMessage;
    data['msg_getmsglist_param_is_ramble'] = _getCloudMessage;
    data['msg_getmsglist_param_time_begin'] = getTimeBegin;
    data['msg_getmsglist_param_time_period'] = getTimePeriod;
    data['msg_getmsglist_param_message_type_array'] = messageTypeList;
    data['msg_getmsglist_param_message_seq_array'] = messageSeqList;
    return data;
  }

}