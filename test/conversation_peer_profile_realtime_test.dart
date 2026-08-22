import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh profile publishes both name and avatar to conversation row', () {
    final source = File('lib/src/user_profile.dart').readAsStringSync();
    final publish = source.indexOf('void _publishConversationProfile(');
    final enrich = source.indexOf('_publishConversationProfile(info);');

    expect(publish, greaterThanOrEqualTo(0));
    expect(enrich, greaterThan(publish));
    final body = source.substring(publish, enrich);
    expect(body, contains('applyShowNameLocally'));
    expect(body, contains('applyFaceUrlLocally'));
    expect(body, contains('PeerProfileRefreshBus.instance.notify'));
  });

  test('open conversation list rebuilds when peer profile bus changes', () {
    final source = File('lib/src/conversation.dart').readAsStringSync();
    final start = source.indexOf('void _onPeerProfileRefreshForListCache()');
    final end = source.indexOf('\n  }', start);
    expect(start, greaterThanOrEqualTo(0));
    expect(source.substring(start, end), contains('setState'));
  });

  test('chat reopen seeds and reloads the local peer profile', () {
    final source = File('lib/src/chat.dart').readAsStringSync();

    expect(
      source,
      contains('UserProfileLocalService.instance.readCached(peerId)'),
    );
    expect(source, contains('unawaited(_loadPeerLocalProfile());'));
    expect(source, contains('localPeerFace'));
    expect(source, contains('localPeerName'));
  });
}
