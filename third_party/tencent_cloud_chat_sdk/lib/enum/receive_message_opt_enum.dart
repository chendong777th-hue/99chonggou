// ignore_for_file: constant_identifier_names

enum ReceiveMsgOptEnum {
  //在线正常接收消息，离线时会进行离线推送
  V2TIM_RECEIVE_MESSAGE,
  //不会接收到消息
  V2TIM_NOT_RECEIVE_MESSAGE,
  //在线正常接收消息，离线不会有推送通知
  V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE,
  // 在线接收消息，离线只接收 at 消息的推送
  V2TIM_RECEIVE_NOT_NOTIFY_MESSAGE_EXCEPT_AT,
  // 在线和离线都只接收 at 消息
  V2TIM_NOT_RECEIVE_MESSAGE_EXCEPT_AT,
}
