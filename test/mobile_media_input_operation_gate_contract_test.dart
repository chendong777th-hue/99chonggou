import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('draft persistence uses a conversation-scoped commit gate', () {
    final source = File(
      'lib/src/services/conversation_local/conversation_draft_service.dart',
    ).readAsStringSync();
    expect(source, contains('MobileAsyncCommitGuard'));
    expect(source, contains("'draft-write'"));
    expect(source, contains('_commitGuard.canCommit(token)'));
  });

  test('IME field keeps composing-aware update and callback path', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_text_field.dart',
    ).readAsStringSync();
    expect(source, contains('value.composing'));
    expect(source, contains('TextEditingValue('));
    expect(source, contains('onChanged: widget.onChanged'));
  });

  test('media pipeline retains stable identity and cancellation path', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();
    expect(source, contains('existingOptimisticId'));
    expect(source, contains('cancelOptimisticMediaPlaceholder'));
    expect(source, contains('_mediaCommitGuard.canCommit(mediaToken)'));
  });
}
