import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('keyboard scroll sync defers while an IME composition is active', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_text_field.dart',
    ).readAsStringSync();

    expect(source.contains('bool get _hasActiveTextComposition'), isTrue);
    expect(
        source.contains('composing.isValid && !composing.isCollapsed'), isTrue);
    expect(
      source.contains(
        'if (_hasActiveTextComposition) {\n'
        '      _keyboardGeometrySyncTimer?.cancel();\n'
        '      return;',
      ),
      isTrue,
    );
    expect(
      source.contains(
        'if (_hasActiveTextComposition) {\n'
        '        return;\n'
        '      }\n'
        '      _applyKeyboardScrollSync();',
      ),
      isTrue,
    );
    expect(source.contains('void _setProgrammaticText(String text'), isTrue);
    expect(source.contains('composing: TextRange.empty'), isTrue);

    final narrow = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_text_field_layout/narrow.dart',
    ).readAsStringSync();
    expect(
        narrow.contains('textCapitalization: TextCapitalization.none'), isTrue);
    expect(narrow.contains('autocorrect: false'), isTrue);
    expect(narrow.contains('enableSuggestions: true'), isTrue);
  });

  test('draft clear invalidates a queued stale write', () {
    final source =
        File('lib/src/chat_page/chat_draft_controller.dart').readAsStringSync();
    expect(source.contains('int _writeGeneration = 0;'), isTrue);
    expect(source.contains('generation == _writeGeneration'), isTrue);
    expect(source.contains('_writeGeneration++;'), isTrue);
  });
}
