import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'keyboard viewport changes retain bottom visibility for inbound messages',
      () {
    final model = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
      'tui_chat_global_model.dart',
    ).readAsStringSync();
    final chat = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'tim_uikit_chat.dart',
    ).readAsStringSync();

    expect(model.contains('beginKeyboardViewportTransition'), isTrue);
    expect(
      model.contains('_wasAtBottomBeforeKeyboardViewportChange(convID)'),
      isTrue,
    );
    expect(
      model.contains(
          'userInitiated: true,\n    );\n    _storeHistoryMessagePosition'),
      isTrue,
    );
    expect(
      chat.contains(
        'chatGlobalModel.beginKeyboardViewportTransition(_getConvID())',
      ),
      isTrue,
    );
  });
}
