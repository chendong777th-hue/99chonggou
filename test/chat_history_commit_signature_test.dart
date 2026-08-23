import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final source = File(
    'third_party/tencent_cloud_chat_uikit/lib/business_logic/view_models/'
    'tui_chat_global_model.dart',
  ).readAsStringSync();

  test('history commit signature covers mutable message state', () {
    expect(source, contains('message.status'));
    expect(source, contains('message.progress'));
    expect(source, contains('message.localCustomInt'));
    expect(source, contains('_messageMediaAvailabilitySignature(message)'));
  });

  test('media availability covers remote and local urls', () {
    expect(source, contains('item.url'));
    expect(source, contains('item.localUrl'));
    expect(source, contains('video?.videoUrl'));
    expect(source, contains('video?.snapshotUrl'));
    expect(source, contains('sound?.url'));
    expect(source, contains('file?.url'));
  });

  test('equivalent history windows return before full sorting', () {
    final earlyReturn = source.indexOf(
      '_historyWindowCommitSignatureByConv[storageKey] == commitSignature',
    );
    final fullSort = source.indexOf('ChatMainThreadPerf.setMessageListMs');
    expect(earlyReturn, greaterThan(0));
    expect(fullSort, greaterThan(earlyReturn));
  });
}
