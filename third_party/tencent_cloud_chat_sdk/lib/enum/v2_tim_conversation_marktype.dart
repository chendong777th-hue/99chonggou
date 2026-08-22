// ignore_for_file: constant_identifier_names

///
/// {@category Models}
///
class V2TimConversationMarkType {
  ///会话标星
  ///
  static const int V2TIM_CONVERSATION_MARK_TYPE_STAR = 0x1;

  ///会话标记未读（重要会话）
  ///
  static const int V2TIM_CONVERSATION_MARK_TYPE_UNREAD = 0x1 << 1;

  ///会话折叠
  ///
  static const int V2TIM_CONVERSATION_MARK_TYPE_FOLD = 0x1 << 2;

  ///会话隐藏
  ///
  static const int V2TIM_CONVERSATION_MARK_TYPE_HIDE = 0x1 << 3;
}
