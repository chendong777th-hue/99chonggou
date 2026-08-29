import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('mobile keyboard send has no time-based throttle', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_text_field_layout/narrow.dart',
    ).readAsStringSync();

    expect(source, isNot(contains('_lastKeyboardSendAtMs')));
    expect(source, isNot(contains('Duration(milliseconds: 120)')));
    expect(
      source,
      contains(
        'void _submitOutgoingMessage({required bool fromKeyboard}) {\n'
        '    if (fromKeyboard) {\n'
        '      widget.controller?.markKeyboardSendRetain();\n'
        '    }\n\n'
        '    widget.onSubmitted();',
      ),
    );
  });
}
