class CElemType {
  // 文本元素
  static const int ElemText = 0;
  // 图片元素
  static const int ElemImage = 1;
  // 声音元素
  static const int ElemSound = 2;
  // 自定义元素
  static const int ElemCustom = 3;
  // 文件元素
  static const int ElemFile = 4;
  // 群组系统消息元素
  static const int ElemGroupTips = 5;
  // 表情元素
  static const int ElemFace = 6;
  // 位置元素
  static const int ElemLocation = 7;
  // 群组系统通知元素
  static const int ElemGroupReport = 8;
  // 视频元素
  static const int ElemVideo = 9;
  // 关系链变更消息元素
  static const int ElemFriendChange = 10;
  // 资料变更消息元素
  static const int ElemProfileChange = 11;
  // 合并消息元素
  static const int ElemMerge = 12;
  // 流式消息元素
  static const int ElemStream = 13;
  // 未知元素类型
  static const int ElemInvalid = -1;
}

// 用户加好友的选项
class CFriendAddPermission {
  // 未知
  static const int Unknown = 0;
  // 允许任何人添加好友
  static const int AllowAny = 1;
  // 添加好友需要验证
  static const int NeedConfirm = 2;
  // 拒绝任何人添加好友
  static const int DenyAny = 3;
}

// 群 Tips 通知类型
class CGroupTipsType {
  static const int GROUP_TIPS_TYPE_JOIN = 1;
  static const int GROUP_TIPS_TYPE_QUIT = 2;
  static const int GROUP_TIPS_TYPE_KICK = 3;
  static const int GROUP_TIPS_TYPE_GRANT_ADMINISTRATOR = 4;
  static const int GROUP_TIPS_TYPE_REVOKE_ADMINISTRATOR = 5;
  static const int GROUP_TIPS_TYPE_GROUP_INFO_CHANGE = 6;
  static const int GROUP_TIPS_TYPE_GROUP_MEMBER_INFO_CHANGE = 7;
  static const int GROUP_TIPS_TYPE_TOPIC_INFO_CHANGE = 9;
  static const int GROUP_TIPS_TYPE_PINNED_MESSAGE_ADDED = 10;
  static const int GROUP_TIPS_TYPE_PINNED_MESSAGE_DELETED = 11;
}

// 群类型
class CGroupType {
  // 公开群（Public），成员上限 2000 人，任何人都可以申请加群，但加群需群主或管理员审批，适合用于类似 QQ 中由群主管理的兴趣群。
  static const int groupPublic = 0;
  // 工作群（Work），成员上限 200 人，不支持由用户主动加入，需要他人邀请入群，适合用于类似微信中随意组建的工作群（对应老版本的 Private 群）。
  static const int groupPrivate = 1;
  // 会议群（Meeting），成员上限 6000 人，任何人都可以自由进出，且加群无需被审批，适合用于视频会议和在线培训等场景（对应老版本的 ChatRoom 群）。
  static const int groupChatRoom = 2;
  // 在线成员广播大群，推荐使用 直播群（AVChatRoom）
  static const int groupBChatRoom = 3;
  // 直播群（AVChatRoom），人数无上限，任何人都可以自由进出，消息吞吐量大，适合用作直播场景中的高并发弹幕聊天室。
  static const int groupAVChatRoom = 4;
  // 社群（Community），成员上限 100000 人，任何人都可以自由进出，且加群无需被审批，适合用于知识分享和游戏交流等超大社区群聊场景。5.8 版本开始支持，需要您购买旗舰版套餐。
  static const int groupCommunity = 5;
}

// 群组加群选项
class CGroupAddOption {
    // 禁止加群
    static const int groupAddOptForbid = 0;
    // 需要管理员审批
    static const int groupAddOptAuth = 1;
    // 任何人都可以加群
    static const int groupAddOptAny = 2;
    // 未定义
    static const int groupAddOptUnknown = 3;
}

// 好友类型
class CFriendType {
    // 单向好友：用户A的好友表中有用户B，但B的好友表中却没有A
    static const int friendTypeSingle = 0;
    // 双向好友：用户A的好友表中有用户B，B的好友表中也有A
    static const int friendTypeBoth = 1;
}

// 两个用户之间的好友关系类型
class CFriendshipRelationType {
  // 未知关系
  static const int friendshipRelationTypeNone = 0;
  // 单向好友：对方是我的好友，我不是对方的好友
  static const int friendshipRelationTypeInMyFriendList = 1;
  // 单向好友：对方不是我的好友，我是对方的好友
  static const int friendshipRelationTypeInOtherFriendList = 2;
  // 双向好友
  static const int friendshipRelationTypeBothFriend = 3;
}

// 1.4 检查好友返回的类型
class CFriendCheckRelationType {
    // 无关系
    static const int friendCheckNoRelation = 0;
    // 仅A中有B
    static const int friendCheckAWithB = 1;
    // 仅B中有A
    static const int friendCheckBWithA = 2;
    // 双向
    static const int friendCheckBothWay = 3;
}

// 好友申请未决类型
class CFriendPendencyType {
  // 别人发给我的
  static const int friendPendencyTypeComeIn = 0;
  // 我发给别人的
  static const int friendPendencyTypeSendOut = 1;
  // 双向的
  static const int friendPendencyTypeBoth = 2;
}

// 响应好友申请的动作类型
class CFriendResponseAction {
    // 同意单向好友
    static const int responseActionAgree = 0;
    // 同意双向好友
    static const int responseActionAgreeAndAdd = 1;
    // 拒绝
    static const int responseActionReject = 2;
}

// 关注类型
class CFollowType {
  // 无任何关注关系
  static const int followLTypeNone = 0;
  // 对方在我的关注列表中
  static const int followLTypeInMyFollowingList = 1;
  // 对方在我的粉丝列表中
  static const int followLTypeInMyFollowersList = 2;
  // 对方与我互相关注
  static const int followLTypeInBothFollowersList = 3;
}

class CConversationEvent {
    // 会话新增,例如收到一条新消息,产生一个新的会话是事件触发
    static const int conversationEventAdd = 0;
    // 会话删除,例如自己删除某会话时会触发
    static const int conversationEventDel = 1;
    // 会话更新,会话内消息的未读计数变化和收到新消息时触发
    static const int conversationEventUpdate = 2;
    // 会话开始
    static const int conversationEventStart = 3;
    // 会话结束
    static const int conversationEventFinish = 4;
}
