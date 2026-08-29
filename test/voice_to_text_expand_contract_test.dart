import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('voice transcript panel supports persisted expand and collapse', () {
    final model = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/widgets/link_preview/models/link_preview_content.dart',
    ).readAsStringSync();
    final viewModel = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();
    final soundBubble = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/TIMUIKitMessageItem/tim_uikit_chat_sound_elem.dart',
    ).readAsStringSync();

    expect(model, contains('voiceToTextDisplayState'));
    expect(model, contains("voiceToTextDisplayState != 'collapsed'"));
    expect(viewModel, contains('setVoiceToTextExpanded'));
    expect(viewModel, contains('await _persistLocalCustomData'));
    expect(soundBubble, contains("isExpanded ? '收起文字' : '展开文字'"));
    expect(soundBubble, isNot(contains('转文字完成')));
  });
}
