/// 群组类型
///
/// {@category Enums}
///
// ignore_for_file: constant_identifier_names

enum GroupTypeEnum {
    // 公开群（Public），成员上限 2000 人，任何人都可以申请加群，但加群需群主或管理员审批，适合用于类似 QQ 中由群主管理的兴趣群。
    kTIMGroup_Public,
    // 工作群（Work），成员上限 200 人，不支持由用户主动加入，需要他人邀请入群，适合用于类似微信中随意组建的工作群（对应老版本的 Private 群）。
    kTIMGroup_Private,
    // 会议群（Meeting），成员上限 6000 人，任何人都可以自由进出，且加群无需被审批，适合用于视频会议和在线培训等场景（对应老版本的 ChatRoom 群）。
    kTIMGroup_ChatRoom,
    // 在线成员广播大群，推荐使用 直播群（AVChatRoom）
    kTIMGroup_BChatRoom,
    // 直播群（AVChatRoom），人数无上限，任何人都可以自由进出，消息吞吐量大，适合用作直播场景中的高并发弹幕聊天室。
    kTIMGroup_AVChatRoom,
    // 社群（Community），成员上限 100000 人，任何人都可以自由进出，且加群无需被审批，适合用于知识分享和游戏交流等超大社区群聊场景。5.8 版本开始支持，需要您购买旗舰版套餐。
    kTIMGroup_Community,
}
