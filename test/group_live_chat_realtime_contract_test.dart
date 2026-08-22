import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('open group chat polls live/current and listens to live-index', () {
    final chat = File('lib/src/chat.dart').readAsStringSync();

    expect(chat.contains('_startGroupLiveCurrentPoll'), isTrue);
    expect(chat.contains('_groupLiveCurrentPollInterval'), isTrue);
    expect(chat.contains('_onGroupLiveIndexStoreChanged'), isTrue);
    expect(
      chat.contains(
        'GroupLiveIndexStore.instance.addListener(_onGroupLiveIndexStoreChanged)',
      ),
      isTrue,
    );

    final tcpAt = chat.indexOf("notice.action == 'group_live_changed'");
    expect(tcpAt, greaterThanOrEqualTo(0));
    final tcpBody = chat.substring(tcpAt, tcpAt + 900);
    // Always reconcile with REST after TCP (not only when detail empty).
    expect(tcpBody.contains('unawaited(_loadGroupLiveCurrent())'), isTrue);
    expect(
      RegExp(
        r"detail\.isEmpty\)\s*\{\s*unawaited\(_loadGroupLiveCurrent\(\)\)",
      ).hasMatch(tcpBody),
      isFalse,
    );
  });

  test('waiting-for-push inline watch polls at most every 4s', () {
    final source = File(
      'lib/src/widgets/group_live/group_live_inline_watch_banner.dart',
    ).readAsStringSync();
    expect(
      source.contains('Timer.periodic(const Duration(seconds: 4)'),
      isTrue,
    );
    expect(
      source.contains('Timer.periodic(const Duration(seconds: 8)'),
      isFalse,
    );
  });
}
