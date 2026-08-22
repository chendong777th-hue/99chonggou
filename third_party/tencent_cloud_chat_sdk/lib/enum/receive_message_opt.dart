// ignore_for_file: constant_identifier_names

class  ReceiveMsgOptType {
  // 在线正常接收消息，离线时会进行 APNs 推送
  static const int kTIMRecvMsgOpt_Receive = 0;
  // 不会接收到消息，离线不会有推送通知
  static const int kTIMRecvMsgOpt_Not_Receive = 1;
  // 在线正常接收消息，离线不会有推送通知
  static const int kTIMRecvMsgOpt_Not_Notify = 2;
  // 在线接收消息，离线只接收 at 消息的推送
  static const int kTIMRecvMsgOpt_Not_Notify_Except_At = 3;
  // 在线和离线都只接收@消息
  static const int kTIMRecvMsgOpt_Not_Receive_Except_At = 4;
}