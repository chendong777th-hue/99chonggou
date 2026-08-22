import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/ui/views/TIMUIKitConversation/tim_uikit_conversation_last_msg.dart';

void main() {
  group('buildGroupConversationPreviewLine', () {
    test('merges sender into a single preview line', () {
      expect(
        buildGroupConversationPreviewLine(
          previewText: '[图片]',
          senderName: '京东六合彩自动机器人',
        ),
        '京东六合彩自动机器人: [图片]',
      );
    });

    test('keeps c2c preview without sender prefix', () {
      expect(
        buildGroupConversationPreviewLine(
          previewText: '发了什么',
          senderName: '',
        ),
        '发了什么',
      );
    });

    test('does not prefix drafts', () {
      expect(
        buildGroupConversationPreviewLine(
          previewText: '未发送完的草稿',
          senderName: '张三',
          isDraft: true,
        ),
        '未发送完的草稿',
      );
    });

    test('falls back to sender when preview is empty', () {
      expect(
        buildGroupConversationPreviewLine(
          previewText: '  ',
          senderName: '张三',
        ),
        '张三',
      );
    });
  });
}
