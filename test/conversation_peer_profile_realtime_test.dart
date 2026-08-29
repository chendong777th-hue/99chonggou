import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('fresh profile commits name and avatar before projecting the row', () {
    final source = File('lib/src/user_profile.dart').readAsStringSync();
    final publish = source.indexOf('void _publishConversationProfile(');
    final enrich = source.indexOf('_publishConversationProfile(info);');

    expect(publish, greaterThanOrEqualTo(0));
    expect(enrich, greaterThan(publish));
    final body = source.substring(publish, enrich);
    expect(body, contains('applyConversationMetadataPatch'));
    expect(body, contains('showName: showName'));
    expect(body, contains('faceUrl: avatar.isEmpty ? null : avatar'));
    expect(body, isNot(contains('applyShowNameLocally')));
    expect(body, isNot(contains('applyFaceUrlLocally')));
    expect(body, contains('PeerProfileRefreshBus.instance.notify'));
    expect(body, contains('_publishingProfile'));
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

  test('profile refresh only reacts to the current peer-change event', () {
    final source = File('lib/src/user_profile.dart').readAsStringSync();
    final start = source.indexOf('void _onPeerProfileRefresh()');
    final end = source.indexOf('\n  }', start);

    expect(start, greaterThanOrEqualTo(0));
    final body = source.substring(start, end);
    expect(body, contains('_profileEnrichmentInFlight'));
    expect(body, contains('_publishingProfile'));
    expect(body, contains('matchesLatest(widget.userID)'));
  });
}
