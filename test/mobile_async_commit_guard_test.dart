import 'package:flutter_test/flutter_test.dart';
import 'package:tencent_cloud_chat_uikit/business_logic/mobile_async_commit_guard.dart';

void main() {
  test('stale account/page/conversation results cannot commit', () {
    final guard = MobileAsyncCommitGuard();
    final token = guard.begin('history', key: 'group-a');
    expect(guard.canCommit(token), isTrue);
    guard.advanceConversation();
    expect(guard.canCommit(token), isFalse);
    final pageToken = guard.begin('history', key: 'group-a');
    guard.advancePage();
    expect(guard.canCommit(pageToken), isFalse);
    final authToken = guard.begin('history', key: 'group-a');
    guard.advanceAuth();
    expect(guard.canCommit(authToken), isFalse);
    expect(guard.stats.staleDrops, 3);
  });

  test('same operation is latest-wins, while different keys do not conflict', () {
    final guard = MobileAsyncCommitGuard();
    final old = guard.begin('group-details', key: 'group-a');
    final latest = guard.begin('group-details', key: 'group-a');
    final other = guard.begin('group-details', key: 'group-b');
    expect(guard.canCommit(old), isFalse);
    expect(guard.canCommit(latest), isTrue);
    expect(guard.canCommit(other), isTrue);
  });

  test('higher authority replaces lower authority and duplicates are dropped', () {
    final guard = MobileAsyncCommitGuard();
    expect(
      guard.acceptIdentity('call:1', authority: MobileCommitAuthority.fallback),
      isTrue,
    );
    expect(
      guard.acceptIdentity('call:1', authority: MobileCommitAuthority.remoteRequest),
      isTrue,
    );
    expect(
      guard.acceptIdentity('call:1', authority: MobileCommitAuthority.fallback),
      isFalse,
    );
    expect(
      guard.acceptIdentity('call:1', authority: MobileCommitAuthority.remoteRequest),
      isFalse,
    );
    expect(guard.stats.authorityDrops, 1);
    expect(guard.stats.duplicateDrops, 1);
  });

  test('same identity accepts newer revision from same authority', () {
    final guard = MobileAsyncCommitGuard();
    expect(
      guard.acceptIdentity('message:1', authority: MobileCommitAuthority.sdkEvent, revision: 1),
      isTrue,
    );
    expect(
      guard.acceptIdentity('message:1', authority: MobileCommitAuthority.sdkEvent, revision: 1),
      isFalse,
    );
    expect(
      guard.acceptIdentity('message:1', authority: MobileCommitAuthority.sdkEvent, revision: 2),
      isTrue,
    );
  });

  test('conversation switch clears operation and identity state', () {
    final guard = MobileAsyncCommitGuard();
    final token = guard.begin('history', key: 'group-a');
    expect(
      guard.acceptIdentity(
        'call:1',
        authority: MobileCommitAuthority.sdkEvent,
      ),
      isTrue,
    );
    guard.advanceConversation();
    expect(guard.canCommit(token), isFalse);
    expect(
      guard.acceptIdentity(
        'call:1',
        authority: MobileCommitAuthority.fallback,
      ),
      isTrue,
    );
  });

  test('authority ordering is fallback, remote, SDK, then local action', () {
    expect(
      MobileCommitAuthority.fallback.index,
      lessThan(MobileCommitAuthority.remoteRequest.index),
    );
    expect(
      MobileCommitAuthority.remoteRequest.index,
      lessThan(MobileCommitAuthority.sdkEvent.index),
    );
    expect(
      MobileCommitAuthority.sdkEvent.index,
      lessThan(MobileCommitAuthority.localUserAction.index),
    );
  });
}
