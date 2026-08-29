import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_demo/src/chat_page/chat_draft_controller.dart';

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
    expect(source.contains('void _setProgrammaticText('), isTrue);
    expect(source.contains('bool notifyChanged = true'), isTrue);
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

  test('successful send suppresses stale lifecycle save until a new edit', () {
    final draft = ChatDraftController();
    draft.onChanged('before send', persist: (_, __) {});
    draft.markSendCompleted();
    expect(draft.shouldSuppressLifecyclePersist, isTrue);

    draft.onChanged('new edit', persist: (_, __) {});
    expect(draft.shouldSuppressLifecyclePersist, isFalse);
    draft.dispose();
  });

  test('host has a barrier in both lifecycle save and send cleanup paths', () {
    final source = File('lib/src/chat.dart').readAsStringSync();
    expect(source.contains('shouldSuppressLifecyclePersist'), isTrue);
    expect(source.contains('markSendCompleted()'), isTrue);
    expect(source.contains('sendMsgRes.code == 0 && conversationId.isNotEmpty'),
        isTrue);
    expect(source.contains('clearDraftForConversationIds'), isTrue);
  });

  test('programmatic send clear is forwarded to the draft owner', () {
    final source = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_text_field.dart',
    ).readAsStringSync();
    expect(
        RegExp(r'textEditingController\.clear\(\);').allMatches(source).length,
        2);
    expect(
        RegExp(r'widget\.onChanged\?\.call\(""\);').allMatches(source).length,
        2);
  });

  test('programmatic input distinguishes user edits from draft restore', () {
    final inputSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_text_field.dart',
    ).readAsStringSync();
    final controllerSource = File(
      'third_party/tencent_cloud_chat_uikit/lib/ui/views/TIMUIKitChat/'
      'TIMUIKitTextField/tim_uikit_text_field_controller.dart',
    ).readAsStringSync();
    final chatSource = File('lib/src/chat.dart').readAsStringSync();

    expect(inputSource, contains('bool notifyChanged = true'));
    expect(
      inputSource,
      contains('if (notifyChanged && previousText != text)'),
    );
    expect(controllerSource, contains('bool notifyOnSetTextField = true;'));
    expect(controllerSource, contains('bool notifyChanged = true'));
    expect(chatSource, contains('setTextField(text!, notifyChanged: false)'));
  });

  test('host flushes drafts on background and isolates conversation switch',
      () {
    final source = File('lib/src/chat.dart').readAsStringSync();
    final lifecycle = source.substring(
      source
          .indexOf('void didChangeAppLifecycleState(AppLifecycleState state)'),
      source.indexOf('void deactivate()'),
    );
    final switchHandler = source.substring(
      source.indexOf('void didUpdateWidget(Chat oldWidget)'),
      source.indexOf('_itemClick('),
    );

    expect(source, contains('with WidgetsBindingObserver'));
    expect(lifecycle, contains('AppLifecycleState.inactive'));
    expect(lifecycle, contains('_persistChatLocalDraft()'));
    expect(switchHandler, contains('conversationID: oldConversationID'));
    expect(switchHandler, contains('enforceCurrentGeneration: false'));
    expect(switchHandler, contains('_draft.beginConversation()'));
    expect(
      source,
      contains('_isCurrentConversation(conversationId)'),
    );
  });
}
