import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
      'official SDK tail cursor is restricted to C2C and direction mismatch is traced',
      () {
    final pagination = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_history_pagination_load.dart',
    ).readAsStringSync();
    final model = File(
      'third_party/tencent_cloud_chat_uikit/lib/business_logic/'
      'separate_models/tui_chat_separate_view_model.dart',
    ).readAsStringSync();

    expect(pagination.contains('useC2cOlderCursor'), isTrue);
    expect(
      pagination.contains(
        "model.conversationType == ConvType.c2c",
      ),
      isTrue,
    );
    expect(pagination.contains('load_previous_direction_mismatch'), isTrue);
    expect(
      model.contains(
        'usesOfficialSdkHistory && conversationType == ConvType.c2c',
      ),
      isTrue,
    );
  });
}
