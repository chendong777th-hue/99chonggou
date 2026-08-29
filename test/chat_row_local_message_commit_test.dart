import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final globalModel = File(
    'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
    'tui_chat_global_model.dart',
  ).readAsStringSync();
  final separateModel = File(
    'third_party/tencent_cloud_chat_uikit/lib/business_logic/separate_models/'
    'tui_chat_separate_view_model.dart',
  ).readAsStringSync();

  test('stable identity replacement rejects unsafe row commits', () {
    expect(globalModel, contains('replaceMessageRowByStableIdentity'));
    expect(
      globalModel,
      contains('RowLocalMessageReplacementResult.notFound'),
    );
    expect(
      globalModel,
      contains('RowLocalMessageReplacementResult.ambiguous'),
    );
    expect(
      globalModel,
      contains('RowLocalMessageReplacementResult.semanticChange'),
    );
    expect(
      globalModel,
      contains('RowLocalMessageReplacementResult.reordered'),
    );
    expect(globalModel, contains('!isNewestFirstStorageOrderValid(next)'));
  });

  test('optimistic, sdk id, msg id and local path form one-way aliases', () {
    expect(globalModel, contains('_rowLocalAliasByConversation'));
    expect(globalModel, contains('readOutgoingStableId(expected)'));
    expect(globalModel, contains('readOutgoingStableId(replacement)'));
    expect(globalModel, contains('_rememberRowLocalAliases'));
    expect(separateModel, contains('newMessage.imageElem?.path'));
  });

  test('row selectors resolve the authoritative replacement', () {
    expect(
      globalModel,
      contains('_rowLocalAliasByConversation[storageKey]?[key] ?? key'),
    );
    expect(globalModel, contains('_markMessageRowChanged(storageKey'));
  });

  test('final receipts are row-local only for outgoing media', () {
    final start = globalModel.indexOf('_isRowLocalOutgoingMediaReceipt(');
    final end = globalModel.indexOf('updateMessage(', start);
    final body = globalModel.substring(start, end);
    for (final type in const <String>[
      'V2TIM_ELEM_TYPE_IMAGE',
      'V2TIM_ELEM_TYPE_VIDEO',
      'V2TIM_ELEM_TYPE_FILE',
      'V2TIM_ELEM_TYPE_SOUND',
    ]) {
      expect(body, contains(type));
    }
    expect(body, isNot(contains('V2TIM_ELEM_TYPE_CUSTOM')));
  });

  test('full-list fallback remains for missing duplicate and reorder', () {
    expect(
      separateModel,
      contains('setMessageList(convID, next, replace: true)'),
    );
    expect(globalModel, contains('send_done_row_local_fallback'));
    expect(globalModel, contains('send_done_duplicate_collapse'));
    expect(globalModel, contains('send_done_reorder'));
  });
}
